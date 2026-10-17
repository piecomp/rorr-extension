-- RORR 데이터 스키마 초안 (PostgreSQL 16) — 확장 프로그램 v2.0 사용 범위 + 웹 공용
-- 작성일: 2026-10-17 · 설명 문서: handoff/10-data-schema.md
-- 지갑·환불 테이블(energy_lots, wallet_ledger, boost_lot_usage, refunds, settlements, partner_agreements)은
-- 웹 rorr-hero/docs/specs/refund.md 와 이름·컬럼을 맞춤. 추가 컬럼은 '-- (ext)' 주석.
-- ID는 접두사 문자열(ma_, mo_, bo_, ca_ …)을 쓰는 text. 금액은 정수.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ───────────── 공통 열거형 ─────────────
CREATE TYPE currency      AS ENUM ('energy', 'spark');
CREATE TYPE moment_tier   AS ENUM ('silver', 'gold', 'holo');
CREATE TYPE moment_status AS ENUM ('upcoming', 'open', 'resolved', 'closed', 'cancelled');
CREATE TYPE boost_status  AS ENUM ('pending', 'settled', 'voided', 'rejected');
CREATE TYPE lot_kind      AS ENUM ('paid', 'bonus');
CREATE TYPE lot_status    AS ENUM ('active', 'refunded', 'expired', 'cancelled');
CREATE TYPE ledger_reason AS ENUM ('purchase', 'bonus', 'boost', 'refund', 'expire', 'cancel', 'adjust',
                                   'ad_reward', 'quiz_prize', 'sponsor_box', 'deco_purchase', 'boost_hold', 'boost_release');
CREATE TYPE star_reason   AS ENUM ('fav_in_play', 'fav_not_in_play', 'auto', 'non_partner');
CREATE TYPE card_edition  AS ENUM ('partner', 'rorr');
CREATE TYPE client_channel AS ENUM ('web', 'ext');
CREATE TYPE player_role   AS ENUM ('top', 'jungle', 'mid', 'adc', 'support');

-- ───────────── 계정 ─────────────
CREATE TABLE users (
  id            text PRIMARY KEY,
  nickname      text NOT NULL,
  birth_year    smallint,                         -- 미성년 판정용(연도만)
  is_minor      boolean NOT NULL DEFAULT false,   -- 서버 계산값
  guardian_consent_at timestamptz,                -- 만 14세 미만 법정대리인 동의
  rep_team_id   text,                             -- 대표 팀
  lang          text NOT NULL DEFAULT 'ko',
  created_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE TABLE user_consents (
  user_id     text NOT NULL REFERENCES users(id),
  kind        text NOT NULL,          -- terms / privacy / promo_msg(정보통신망법 §50) / bonus_scope_notice
  version     text NOT NULL,
  agreed_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at  timestamptz,
  PRIMARY KEY (user_id, kind, version)
);

CREATE TABLE oauth_sessions (           -- 확장 PKCE 갱신 토큰
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        text NOT NULL REFERENCES users(id),
  client         client_channel NOT NULL,
  client_version text,
  refresh_hash   text NOT NULL,
  expires_at     timestamptz NOT NULL,
  revoked_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- ───────────── 팀·선수·파트너 ─────────────
CREATE TABLE teams (
  id          text PRIMARY KEY,          -- 't1', 'gen'
  name        text NOT NULL,
  short       text NOT NULL,
  league      text NOT NULL,
  logo_url    text                        -- 비제휴 팀은 화면에서 사용 안 함(텍스트만)
);
ALTER TABLE users ADD CONSTRAINT users_rep_team_fk FOREIGN KEY (rep_team_id) REFERENCES teams(id);

CREATE TABLE players (
  id          text PRIMARY KEY,          -- 'p_faker'
  team_id     text REFERENCES teams(id),
  nickname    text NOT NULL,
  role        player_role NOT NULL,
  photo_url   text,                       -- 파트너 협약 초상권 범위 안에서만 노출
  active      boolean NOT NULL DEFAULT true
);

CREATE TABLE partner_agreements (       -- 웹 refund.md 와 동일 이름
  id            text PRIMARY KEY,
  team_id       text NOT NULL REFERENCES teams(id),
  starts_on     date NOT NULL,
  ends_on       date,
  share_bp      integer NOT NULL,         -- PARTNER_SHARE_BP (대외 비공개, 화면 노출 금지)
  official_label_allowed boolean NOT NULL DEFAULT false,  -- '공식' 표기 [논의 중]
  portrait_rights boolean NOT NULL DEFAULT false
);
CREATE VIEW partner_teams AS
  SELECT team_id FROM partner_agreements WHERE starts_on <= current_date AND (ends_on IS NULL OR ends_on >= current_date);

CREATE TABLE user_teams (               -- 응원 팀(복수)
  user_id    text NOT NULL REFERENCES users(id),
  team_id    text NOT NULL REFERENCES teams(id),
  added_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, team_id)
);

CREATE TABLE user_prefs (
  user_id            text PRIMARY KEY REFERENCES users(id),
  alert_level        text NOT NULL DEFAULT 'all' CHECK (alert_level IN ('all', 'decisive', 'off')),
  notify_match_start boolean NOT NULL DEFAULT true,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_fav_players (         -- 행 없음 = 아직 안 물음, player_id NULL = 자동
  user_id    text NOT NULL REFERENCES users(id),
  team_id    text NOT NULL REFERENCES teams(id),
  player_id  text REFERENCES players(id),
  set_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, team_id)
);

-- ───────────── 경기·순간 ─────────────
CREATE TABLE matches (
  id           text PRIMARY KEY,
  league       text NOT NULL,
  season       text NOT NULL,
  starts_at    timestamptz NOT NULL,
  best_of      smallint NOT NULL DEFAULT 3,
  team_a_id    text NOT NULL REFERENCES teams(id),   -- 화면 왼쪽(파랑)
  team_b_id    text NOT NULL REFERENCES teams(id),
  status       text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'between', 'ended')),
  riot_match_ref text UNIQUE
);
CREATE INDEX matches_starts_idx ON matches (starts_at);

CREATE TABLE games (
  match_id   text NOT NULL REFERENCES matches(id),
  game_no    smallint NOT NULL,
  started_at timestamptz,
  ended_at   timestamptz,
  winner_team_id text REFERENCES teams(id),
  PRIMARY KEY (match_id, game_no)
);

CREATE TABLE match_lineups (
  match_id   text NOT NULL REFERENCES matches(id),
  game_no    smallint NOT NULL,
  team_id    text NOT NULL REFERENCES teams(id),
  player_id  text NOT NULL REFERENCES players(id),
  role       player_role NOT NULL,
  PRIMARY KEY (match_id, game_no, team_id, role)
);

CREATE TABLE broadcasts (               -- 중계 매칭(확장 /ext/match/resolve)
  id          text PRIMARY KEY,
  match_id    text NOT NULL REFERENCES matches(id),
  host        text NOT NULL,            -- youtube.com / chzzk.naver.com / sooplive.co.kr / twitch.tv
  channel_id  text,
  url_pattern text,
  default_offset_ms integer NOT NULL DEFAULT 0
);
CREATE INDEX broadcasts_host_idx ON broadcasts (host, channel_id);

CREATE TABLE stream_offset_reports (    -- 익명 지연 보정값
  id          bigserial PRIMARY KEY,
  broadcast_id text REFERENCES broadcasts(id),
  host        text NOT NULL,
  match_id    text NOT NULL REFERENCES matches(id),
  delta_ms    integer NOT NULL,
  reported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE moments (
  id              text PRIMARY KEY,
  match_id        text NOT NULL REFERENCES matches(id),
  game_no         smallint NOT NULL,
  kind            text NOT NULL,         -- teamfight / baron_fight / dragon_soul / elder / inhibitor / ace / comeback / base_race / other
  team_id         text NOT NULL REFERENCES teams(id),   -- 승리확률이 움직인 쪽 = 적립 대상 팀
  status          moment_status NOT NULL DEFAULT 'upcoming',
  tier_hint       moment_tier NOT NULL,
  final_tier      moment_tier,
  winprob_delta_pp numeric(5,2),
  top_performer   text REFERENCES players(id),
  game_clock_s    integer,
  announced_at    timestamptz NOT NULL,
  closes_at       timestamptz NOT NULL,
  resolved_at     timestamptz,
  boosters_count  integer NOT NULL DEFAULT 0,   -- 비정규화(최종 일관성)
  FOREIGN KEY (match_id, game_no) REFERENCES games(match_id, game_no)
);
CREATE INDEX moments_match_idx ON moments (match_id, announced_at);

CREATE TABLE moment_participants (
  moment_id   text NOT NULL REFERENCES moments(id),
  player_id   text NOT NULL REFERENCES players(id),
  contribution numeric(6,3),             -- RORR 기여도 점수(1위 = top_performer)
  PRIMARY KEY (moment_id, player_id)
);

-- ───────────── 지갑 (웹 refund.md 동일) ─────────────
CREATE TABLE energy_lots (
  id              text PRIMARY KEY,
  user_id         text NOT NULL REFERENCES users(id),
  kind            lot_kind NOT NULL,
  order_id        text,                   -- 유료 = 결제 주문, 보너스 = 지급 사유 ID
  qty             integer NOT NULL CHECK (qty > 0),
  remaining       integer NOT NULL CHECK (remaining >= 0),
  unit_price_krw  integer NOT NULL DEFAULT 0,   -- 실결제 환산가(결제액 ÷ 수량). 보너스 0
  list_unit_price_krw integer NOT NULL DEFAULT 0, -- (ext) v1.3 정가 환산가 — 팀 배분 기준(할인은 RORR 몫에서 부담)
  purchased_at    timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL,
  status          lot_status NOT NULL DEFAULT 'active'
);
CREATE INDEX energy_lots_fifo_idx ON energy_lots (user_id, kind, expires_at) WHERE status = 'active' AND remaining > 0;

CREATE TABLE spark_lots (               -- (ext) Spark 묶음: 광고·퀴즈 상금·행운 박스
  id          text PRIMARY KEY,
  user_id     text NOT NULL REFERENCES users(id),
  source      text NOT NULL CHECK (source IN ('ad_reward', 'quiz_prize', 'sponsor_box', 'adjust')),
  source_ref  text,                       -- 광고 노출 ID / quiz_weekly ID / sponsor_box_opens ID
  qty         integer NOT NULL CHECK (qty > 0),
  remaining   integer NOT NULL CHECK (remaining >= 0),
  granted_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL        -- 시즌 종료
);
CREATE INDEX spark_lots_fifo_idx ON spark_lots (user_id, expires_at) WHERE remaining > 0;

CREATE TABLE wallet_ledger (            -- append-only (UPDATE·DELETE 권한 회수)
  id          bigserial PRIMARY KEY,
  user_id     text NOT NULL REFERENCES users(id),
  currency    currency NOT NULL,
  lot_id      text NOT NULL,              -- energy_lots.id 또는 spark_lots.id
  delta       integer NOT NULL,           -- 증가 +, 감소 −
  reason      ledger_reason NOT NULL,
  ref_type    text,                       -- boost / refund / order / sponsor_box / quiz_weekly …
  ref_id      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX wallet_ledger_user_idx ON wallet_ledger (user_id, created_at DESC);

-- ───────────── Boost·카드 ─────────────
CREATE TABLE boosts (
  id              text PRIMARY KEY,
  user_id         text NOT NULL REFERENCES users(id),
  moment_id       text NOT NULL REFERENCES moments(id),
  team_id         text NOT NULL REFERENCES teams(id),   -- 적립 대상 팀
  target_player_id text REFERENCES players(id),         -- 웹 '이 교전의 선수' 칩 선택값(웹 B-7/G-5 결정 전). 확장은 NULL
  currency        currency NOT NULL,
  amount          integer NOT NULL CHECK (amount > 0),
  game_clock_s    integer,                -- 웹 06 §7 '게임 시각'
  disclosure_version text,                -- 환불 불가 고지 문구 버전(disclosures.key='boost_no_refund')
  disclosure_shown_at timestamptz,
  status          boost_status NOT NULL,
  channel         client_channel NOT NULL,
  client_version  text,
  idempotency_key uuid NOT NULL,
  message_id      text,
  card_id         text,                   -- 확정 후 연결
  created_at      timestamptz NOT NULL DEFAULT now(),
  settled_at      timestamptz,
  UNIQUE (user_id, idempotency_key)
);
CREATE INDEX boosts_moment_idx ON boosts (moment_id, status);
CREATE INDEX boosts_user_idx ON boosts (user_id, created_at DESC);

CREATE TABLE boost_lot_usage (          -- 웹 refund.md 동일: Boost 1건이 어느 묶음에서 몇 개
  boost_id   text NOT NULL REFERENCES boosts(id),
  lot_id     text NOT NULL,               -- currency=energy → energy_lots(paid만), spark → spark_lots
  currency   currency NOT NULL,
  qty        integer NOT NULL CHECK (qty > 0),
  PRIMARY KEY (boost_id, lot_id)
);

CREATE TABLE cards (                    -- 순간·사용자당 1장
  id            text PRIMARY KEY,
  user_id       text NOT NULL REFERENCES users(id),
  moment_id     text NOT NULL REFERENCES moments(id),
  team_id       text NOT NULL REFERENCES teams(id),
  tier          moment_tier NOT NULL,   -- final_tier 확정 시 갱신 가능
  edition       card_edition NOT NULL,
  star_player_id text REFERENCES players(id),   -- 발급 시점 고정
  star_reason   star_reason NOT NULL,
  serial_no     integer NOT NULL,         -- 순간 내 발급 순번
  first_boost_id text NOT NULL,
  issued_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, moment_id),
  UNIQUE (moment_id, serial_no)
);
ALTER TABLE boosts ADD CONSTRAINT boosts_card_fk FOREIGN KEY (card_id) REFERENCES cards(id);

CREATE TABLE card_currency_totals (     -- 재화별 누적·배지 단계
  card_id    text NOT NULL REFERENCES cards(id),
  currency   currency NOT NULL,
  total      integer NOT NULL DEFAULT 0,
  badge_level smallint NOT NULL DEFAULT 0 CHECK (badge_level BETWEEN 0 AND 3),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (card_id, currency)
);

-- ───────────── 포인트·순위 ─────────────
CREATE TABLE cheer_points (             -- 순간당 1회(UNIQUE) · 팀별 적립
  id          bigserial PRIMARY KEY,
  user_id     text NOT NULL REFERENCES users(id),
  team_id     text NOT NULL REFERENCES teams(id),
  season      text NOT NULL,
  moment_id   text NOT NULL REFERENCES moments(id),
  base        smallint NOT NULL,          -- +20
  tier_bonus  smallint NOT NULL,          -- +10/+30/+60
  streak_bonus smallint NOT NULL DEFAULT 0, -- 경기당 첫 Boost에만, 최대 +100
  total       smallint GENERATED ALWAYS AS (base + tier_bonus + streak_bonus) STORED,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, moment_id)
);
CREATE INDEX cheer_points_rank_idx ON cheer_points (team_id, season, user_id);

CREATE TABLE cheer_streaks (
  user_id     text NOT NULL REFERENCES users(id),
  team_id     text NOT NULL REFERENCES teams(id),
  streak_matches integer NOT NULL DEFAULT 0,
  last_match_id  text REFERENCES matches(id),
  PRIMARY KEY (user_id, team_id)
);

CREATE TABLE rank_snapshots (           -- 5초~1분 주기 집계(최종 일관성)
  team_id   text NOT NULL REFERENCES teams(id),
  season    text NOT NULL,
  scope     text NOT NULL CHECK (scope IN ('season', 'match')),
  scope_ref text NOT NULL DEFAULT '',
  user_id   text NOT NULL REFERENCES users(id),
  points    integer NOT NULL,
  rank      integer NOT NULL,
  taken_at  timestamptz NOT NULL,
  PRIMARY KEY (team_id, season, scope, scope_ref, user_id)
);

-- ───────────── 퀴즈 ─────────────
CREATE TABLE quiz_questions (
  id          text PRIMARY KEY,
  match_id    text NOT NULL REFERENCES matches(id),
  game_no     smallint,
  question    jsonb NOT NULL,             -- {ko, en}
  options     jsonb NOT NULL,             -- [{id, ko, en}]
  correct_option text,
  opens_at    timestamptz NOT NULL,
  closes_at   timestamptz NOT NULL,       -- 서버 기준. 판정은 + QUIZ_GRACE_MS
  resolved_at timestamptz
);

CREATE TABLE quiz_answers (
  quiz_id     text NOT NULL REFERENCES quiz_questions(id),
  user_id     text NOT NULL REFERENCES users(id),
  option_id   text NOT NULL,
  answered_at timestamptz NOT NULL DEFAULT now(),
  is_correct  boolean,
  score       smallint,
  streak_after smallint,
  PRIMARY KEY (quiz_id, user_id)
);

CREATE TABLE quiz_weekly (
  id          text PRIMARY KEY,
  week_start  date NOT NULL,
  user_id     text NOT NULL REFERENCES users(id),
  score       integer NOT NULL,
  rank        integer,
  prize_spark integer NOT NULL DEFAULT 0, -- QUIZ_PRIZE_SPARK_TABLE
  paid_at     timestamptz,
  UNIQUE (week_start, user_id)
);

-- ───────────── 스폰서 [논의 중] ─────────────
CREATE TABLE sponsors (
  id        text PRIMARY KEY,
  name      text NOT NULL,
  label     text NOT NULL,
  logo_url  text
);

CREATE TABLE sponsor_contracts (
  id            text PRIMARY KEY,
  sponsor_id    text NOT NULL REFERENCES sponsors(id),
  team_id       text REFERENCES teams(id),     -- 파트너 팀 경기 범위
  starts_at     timestamptz NOT NULL,
  ends_at       timestamptz NOT NULL,
  min_tier      moment_tier NOT NULL DEFAULT 'gold',
  box_odds      jsonb NOT NULL,                -- SPONSOR_BOX_ODDS
  box_pool_spark integer,                      -- SPONSOR_BOX_POOL (NULL = 미정 → 박스 미노출)
  box_pool_used integer NOT NULL DEFAULT 0,
  holdout_bp    integer NOT NULL DEFAULT 0,    -- 홀드아웃 비율(측정)
  kill_drop_bp  integer                        -- SPONSOR_BOX_KILL_DROP
);

CREATE TABLE sponsor_moment_exposures (       -- 순간에 후원 라벨이 붙었는지(노출 판정 결과)
  moment_id    text NOT NULL REFERENCES moments(id),
  contract_id  text NOT NULL REFERENCES sponsor_contracts(id),
  PRIMARY KEY (moment_id)
);

CREATE TABLE sponsor_box_opens (
  id          text PRIMARY KEY,
  user_id     text NOT NULL REFERENCES users(id),
  moment_id   text NOT NULL REFERENCES moments(id),
  contract_id text NOT NULL REFERENCES sponsor_contracts(id),
  odds_version text NOT NULL,             -- 확률표 버전(웹 06 §7)
  holdout     boolean NOT NULL DEFAULT false,
  result      text NOT NULL CHECK (result IN ('win', 'miss')),
  prize_spark integer NOT NULL DEFAULT 0,
  rng_seed_ref text NOT NULL,              -- 감사용(서버 난수 기록)
  opened_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, moment_id)
);

CREATE TABLE sponsor_holdout (               -- 측정 대조군 배정(사용자·계약)
  user_id     text NOT NULL REFERENCES users(id),
  contract_id text NOT NULL REFERENCES sponsor_contracts(id),
  in_holdout  boolean NOT NULL,
  PRIMARY KEY (user_id, contract_id)
);

-- ───────────── 알림 ─────────────
CREATE TABLE headsup_impressions (           -- 빈도 상한(EXT_HEADSUP_MIN_GAP) 판정·측정
  user_id     text NOT NULL REFERENCES users(id),
  moment_id   text NOT NULL REFERENCES moments(id),
  channel     client_channel NOT NULL,
  tier        moment_tier NOT NULL,
  shown_at    timestamptz NOT NULL DEFAULT now(),
  clicked_at  timestamptz,
  dismissed_at timestamptz,
  moment_cancelled boolean NOT NULL DEFAULT false,   -- 무산 여부
  PRIMARY KEY (user_id, moment_id, channel)
);

-- ───────────── 응원 메시지·신고 ─────────────
CREATE TABLE cheer_messages (
  id         text PRIMARY KEY,
  user_id    text NOT NULL REFERENCES users(id),
  match_id   text NOT NULL REFERENCES matches(id),
  moment_id  text REFERENCES moments(id),
  team_id    text REFERENCES teams(id),
  body       text NOT NULL CHECK (char_length(body) <= 60),
  status     text NOT NULL DEFAULT 'visible' CHECK (status IN ('visible', 'hidden', 'removed')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX cheer_messages_match_idx ON cheer_messages (match_id, created_at DESC);

CREATE TABLE reports (
  id          bigserial PRIMARY KEY,
  reporter_id text NOT NULL REFERENCES users(id),
  target_type text NOT NULL,              -- message
  target_id   text NOT NULL,
  reason      text NOT NULL,
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'actioned', 'dismissed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, target_type, target_id)
);

-- ───────────── Muse ─────────────
CREATE TABLE muse_lines (
  id         text PRIMARY KEY,
  segment    text NOT NULL CHECK (segment IN ('pre', 'live', 'between', 'post')),
  trigger    text NOT NULL,               -- 예: moment.upcoming.gold, quiz.correct, boost.first
  lang       text NOT NULL,
  text       text NOT NULL,
  expression text,                        -- VRM 표정 프리셋
  version    integer NOT NULL,
  active     boolean NOT NULL DEFAULT true
);

-- ───────────── 환불·정산 (웹 refund.md 동일) ─────────────
CREATE TABLE refunds (
  id           text PRIMARY KEY,
  user_id      text NOT NULL REFERENCES users(id),
  lot_ids      text[] NOT NULL,
  type         text NOT NULL CHECK (type IN ('withdrawal', 'balance', 'minor_cancel', 'service_end')),
  gross_krw    integer NOT NULL,
  fee_krw      integer NOT NULL,
  net_krw      integer NOT NULL,
  method       text NOT NULL CHECK (method IN ('pg_cancel', 'bank_transfer')),
  status       text NOT NULL CHECK (status IN ('requested', 'approved', 'processing', 'done', 'rejected')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  done_at      timestamptz,
  reason       text
);

CREATE TABLE settlements (
  id          text PRIMARY KEY,
  team_id     text NOT NULL REFERENCES teams(id),
  period      date NOT NULL,              -- 월 첫날
  base_krw    bigint NOT NULL,            -- (ext 제안) sum(qty × list_unit_price_krw), kind=paid 만 — v1.3 정가 기준
  share_bp    integer NOT NULL,
  share_krw   bigint NOT NULL,
  adjust_krw  bigint NOT NULL DEFAULT 0,  -- 정산 후 취소분(음수)
  confirmed_at timestamptz,
  UNIQUE (team_id, period)
);

-- ───────────── 운영 ─────────────
CREATE TABLE config_values (            -- GET /v1/config 원본
  key        text PRIMARY KEY,
  value      jsonb NOT NULL,
  updated_by text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE idempotency_keys (         -- 미들 계층(대안: Redis 24h TTL)
  user_id     text NOT NULL,
  key         uuid NOT NULL,
  route       text NOT NULL,
  body_hash   text NOT NULL,
  status_code smallint,
  response    jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);

CREATE TABLE disclosures (              -- 고지 문구 버전(환불·보너스 용도·행운 박스 확률)
  key        text NOT NULL,
  version    text NOT NULL,
  lang       text NOT NULL,
  body       text NOT NULL,
  effective_at timestamptz NOT NULL,
  PRIMARY KEY (key, version, lang)
);
