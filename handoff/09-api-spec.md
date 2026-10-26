# 09. API 명세

> **2026-10-17 통합 안내** — 공용 API·DB의 단일 기준은 `rorr-hero/handoff/api/openapi.yaml`·`db/schema.sql`(be35b45, 웹·확장 통합)입니다. 이 문서는 통합 전 확장 설계로 **참고용**이며, 차이·채택 근거와 확장 쪽 변경 사항(E-1~E-6)은 `rorr-hero/handoff/18-canonical-merge.md`를 보세요. 결정 사항 목록은 `rorr-hero/handoff/09-open-items.md` §0(BE-1은 '첫 경기 0'으로 결정).

- 작성일: 2026-10-17 · 기계 판독본: `api/openapi.yaml`(OpenAPI 3.1) — 이 문서와 다르면 **이 문서 우선**, 발견 시 둘 다 고칠 것
- 원칙: 웹과 **같은 API**. 확장 전용은 `/v1/ext/*` 3종(매칭·스트림·Muse — 웹 OI-20)
- 이름 규칙: 웹 `docs/specs/refund.md`(`/me/wallet`, `POST /refunds` + `Idempotency-Key`)와 웹 handoff 06 §6 설정 변수 이름을 그대로 사용

---

## 1. 공통

| 항목 | 규칙 |
|---|---|
| 기본 주소 | `https://api.rorr.club/v1` (스테이징 `api.stg.rorr.club`) |
| 인증 | `Authorization: Bearer <access_token>`. 비로그인 허용 API는 표에 '공개' 표시 |
| 클라이언트 | `X-RORR-Client: ext/2.0.0` (필수). 서버는 Boost 채널·최소 버전 판정에 사용 |
| 언어 | `Accept-Language: ko` / `en`. 서버는 문구를 조합하지 않고 **문구 키 + 변수**를 반환(§6) |
| 멱등 | 모든 `POST`·`PUT`·`PATCH`·`DELETE`에 `Idempotency-Key: <uuid v4>` 필수. 24시간 같은 키 → 첫 응답 재반환. 같은 키·다른 본문 → `422 idempotency_mismatch` |
| 시간 | ISO 8601 UTC(`2026-10-17T09:12:30.120Z`). 경기 화면 시각 계산은 `server_ts + offset_ms` |
| 금액 | 정수. Energy·Spark는 개수, 원화는 `_krw` 접미사 |
| 페이지 | 커서 방식 `?cursor=&limit=`(기본 20, 최대 100) → `{items, next_cursor}` |
| 오류 형식 | `{ "error": { "code": "moment_closed", "message_key": "err.moment_closed", "params": {}, "request_id": "…" } }` |
| 추적 | 응답 헤더 `X-Request-Id`. 클라이언트 오류 보고 시 함께 전송 |

## 2. 엔드포인트 목록

### 2-1. 계정·설정

| 메서드 | 경로 | 인증 | 설명 |
|---|---|---|---|
| GET | `/config` | 공개 | 정책 변수·기능 플래그·최소 확장 버전(§7). 5분 캐시, 변경 시 SSE `config.changed` |
| GET | `/me` | 필수 | `user_id, nickname, is_minor, cheer_teams[], rep_team_id, created_at` |
| GET | `/me/preferences` | 필수 | 아래 본문과 같은 구조 |
| PATCH | `/me/preferences` | 필수 | `{ lang?, alert_level?: all\|decisive\|off, notify_match_start?: bool, fav_players?: { "<team_id>": "<player_id>"\|null } }` |
| PUT | `/me/teams` | 필수 | 응원 팀 목록·대표 팀 `{ team_ids[], rep_team_id }` |

- `fav_players` 값: 키 없음 = 아직 안 물음(`undefined`), `null` = 자동, 선수 ID = 내 선수(05 §4)

### 2-2. 지갑 (웹 refund.md와 동일)

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/me/wallet` | `{ energy: { paid, bonus, bonus_scope: "rorr_deco" }, spark: { balance, expires_at }, lots?: [...] }` — 확장은 `lots` 생략 요청 `?fields=summary` |
| GET | `/me/wallet/ledger` | 원장 내역(커서). 사유 `purchase/bonus/boost/refund/expire/cancel/adjust/ad_reward/quiz_prize/sponsor_box` |

- **Boost 가능 Energy = `energy.paid`만**(정책 v1.3 §1-1). 패널은 `paid`를 Boost 잔액으로 표시하고 `bonus`는 'RORR 장식 전용'으로 분리 표기
- 충전·환불·광고 보상은 웹 화면에서만(확장은 링크 이동)

### 2-3. 일정·경기·순간

| 메서드 | 경로 | 인증 | 설명 |
|---|---|---|---|
| GET | `/schedule` | 공개 | `?from&to&team_ids` → 경기 목록(`match_id, starts_at, teams, partner_side, broadcast_hosts[]`) |
| GET | `/matches/{match_id}` | 공개 | 팀·라인업(포지션 순 Top/Jungle/Mid/ADC/Support)·세트·스코어·`partner_side` |
| GET | `/matches/{match_id}/moments` | 공개 | `?status=open\|closed` 경기 기록·경기 후 요약용 |
| GET | `/moments/{moment_id}` | 선택 | 순간 상세 + 로그인 시 `my` 블록 |

`GET /moments/{id}` 응답 예:

```json
{
  "moment_id": "mo_8Kc2",
  "match_id": "ma_lck_2026_f_01", "game_no": 2,
  "kind": "baron_fight", "title_key": "moment.baron_fight",
  "team_id": "t1", "status": "open",
  "tier_hint": "gold", "final_tier": null, "winprob_delta_pp": 18.4,
  "announced_at": "…", "closes_at": "…",
  "participants": ["p_oner", "p_faker", "p_keria"], "top_performer": "p_faker",
  "star_preview": { "player_id": "p_faker", "reason": "fav_in_play" },
  "boosters_count": 1284,
  "sponsor": { "sponsor_id": "sp_nova", "label": "NOVA", "logo_url": "…", "box_eligible": true, "odds": [[0,75],[5,20],[10,5]] },
  "my": { "card_id": null, "totals": { "energy": 0, "spark": 0 }, "badges": { "energy": 0, "spark": 0 } }
}
```

- `star_preview.reason`: `fav_in_play` / `fav_not_in_play` / `auto` / `non_partner`
- `sponsor`는 노출 조건(05 §7)을 서버가 판정해 충족할 때만 포함. 없으면 키 생략

### 2-4. Boost

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/boosts` | Boost 보내기(두 번째 탭 시점에만 호출) |
| GET | `/me/boosts` | `?match_id` 내 Boost 내역 |

요청:

```json
{ "moment_id": "mo_8Kc2", "currency": "energy", "amount": 50, "team_id": "t1", "message": null, "disclosure_version": "boost_no_refund@2026-10-17" }
```

- `team_id`: 양쪽 팀이 모두 응원 팀인 경기에서 응원 대상 명시(정책 §5-2). 생략 시 순간의 `team_id`
- `target_player_id`(선택): 웹 '이 교전의 선수' 칩(4dfdb4b)이 보내는 값. 카드 주인공 판정과의 관계는 웹 B-7/G-5 결정 대기 — 확장은 보내지 않음
- `disclosure_version`: 고지 문구 버전(환불 불가 고지를 본 버전 기록, 웹 06 §7)
- `amount`는 `config.STEP_ENERGY`·`STEP_SPARK` 값 중 하나만 허용

응답 `201`(`BOOST_SETTLE_MODE=immediate`) / `202`(`on_moment`, `status=pending`):

```json
{
  "boost_id": "bo_1f9", "status": "settled",
  "card": {
    "card_id": "ca_77", "is_new": true, "tier": "gold", "edition": "partner",
    "star_player": { "player_id": "p_faker", "reason": "fav_in_play" },
    "badges": { "energy": 2, "spark": 0 },
    "totals": { "energy": 50, "spark": 0 },
    "level_up": { "currency": "energy", "from": 0, "to": 2 },
    "next": { "currency": "energy", "level": 3, "remaining": 50 }
  },
  "points_awarded": { "total": 50, "base": 20, "tier_bonus": 30, "streak_bonus": 0 },
  "wallet": { "energy": { "paid": 70, "bonus": 0 }, "spark": { "balance": 35 } },
  "boosters_count": 1285
}
```

- 재Boost: `is_new=false`, `points_awarded.total=0`, `tier` 불변, `level_up`만 변화(05 §3)
- 실패 코드: `insufficient_paid_energy`(보너스만 있으면 `params.bonus_available=true` → '유료 Energy만 쓸 수 있어요'), `insufficient_spark`, `moment_closed`, `amount_not_allowed`, `minor_restricted`, `rate_limited`
- 클라이언트는 실패 시 차감 표시를 하지 않음(낙관적 차감 금지)

### 2-5. 카드·포인트·순위

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/me/cards` | `?team_id&season&cursor` 내 카드 |
| GET | `/cards/{card_id}` | 앞·뒷면 데이터(순간 제목·시각·스코어·주인공·배지·에디션·발급 번호) |
| GET | `/cards/{card_id}/share-image` | 자랑하기 이미지(팀 1개 단위, 브랜드 없음) |
| GET | `/me/points` | `?team_id` 시즌 포인트·연속 응원 경기 수·순위 |
| GET | `/rankings/supporters` | `?team_id&scope=season\|match&match_id&cursor` |
| GET | `/teams/{team_id}/fandom` | 팬덤 시즌 목표·진행·공개 배분액(파트너만, 비율 미포함) |

### 2-6. 퀴즈

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/quiz/{quiz_id}/answers` | `{ option_id }` → `202 { accepted_at }`. 마감 후 `409 quiz_closed`, 중복 `409 quiz_already_answered` |
| GET | `/quiz/ranking` | `?scope=match\|week&match_id` 내 순위·상위 목록·연속 정답 |

- 정답·점수는 SSE `quiz.resolved`로만 전달(응답에 정답 미포함)

### 2-7. 스폰서 행운 박스 [논의 중 — 플래그 `sponsor_moment_enabled`]

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/sponsor/boxes` | `{ moment_id }` → `200 { result: "win"\|"miss", prize: { spark: 5 } \| null, wallet? }` |

- 오류: `409 box_unavailable`(조건 미충족·소진·홀드아웃), `409 box_already_opened`(첫 결과는 같은 키로만 재조회), `403 minor_restricted`
- 요청에 박스 위치를 넣지 않음. 확률은 `moment.sponsor.odds`로 사전 표시

### 2-8. 응원 메시지

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/matches/{match_id}/messages` | `?filter=my_teams\|all&cursor` |
| POST | `/messages` | `{ match_id, moment_id?, body }` 최대 60자. 금칙어 `422 message_rejected` |
| POST | `/messages/{id}/reports` | `{ reason }` |

### 2-9. 확장 전용 (`/v1/ext/*`)

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/ext/match/resolve` | `{ host, url, title, channel_id? }` → `{ status: matched\|ambiguous\|none, match_id?, candidates?[], offset_ms }` |
| GET | `/ext/stream` | SSE. `?match_id` (+ 로그인 시 사용자 채널 자동 합류). §5 |
| GET | `/ext/muse/lines` | `?segment=pre\|live\|between\|post&lang&since_version` 서하 대사 묶음(캐시용) |
| POST | `/ext/muse/chat` | 1:1 대화(LLM) `{ text, context: { match_id, moment_id? } }` → 스트리밍 응답. 로그인 필수. 주간 무료 횟수(`AI_FREE_WEEKLY`) 이후 요청에 `pay: { currency: spark\|energy, qty }`(서버 가격과 불일치 시 `price_changed`), 응답 헤더에 `free_left`·차감 결과. 답변 생성 실패·타임아웃 시 차감 취소. Energy는 유료만(`BONUS_ENERGY_AI` false), 팀 배분 제외(정책 v1.4 §1) — 공용 경로·필드는 통합본 기준으로 확정 필요(C-13) |
| POST | `/ext/affinity/sessions` | 서하 친밀도 결과값 `{ match_id, watched_min, moments_together }` → `{ level, gained, capped }`. 로컬 판정 결과만 전송, 지갑·포인트와 분리(정책 v1.4 §5-8) — 신규 제안(C-14) |
| POST | `/ext/offset-reports` | 익명 지연 보정값 `{ host, match_id, delta_ms }` — 호스트별 기본 지연 산출용 |

### 2-10. 측정

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/events` | 측정 이벤트 묶음 전송(최대 50건). 14-analytics-events |

## 3. 요청 제한

| 대상 | 한도 | 초과 |
|---|---|---|
| `POST /boosts` | 사용자당 10회/10초 | `429` + `Retry-After` |
| `POST /sponsor/boxes` | 순간당 1회(판정), 사용자당 5회/분 | `409` / `429` |
| `POST /quiz/*/answers` | 문항당 1회 | `409` |
| `POST /messages` | 사용자당 1회/10초 | `429` |
| `POST /ext/muse/chat` | 사용자당 10회/분 | `429` |
| 그 외 읽기 | IP당 60회/분 | `429` |

## 4. 오류 코드

| HTTP | code | 화면 처리(문구 키) |
|---|---|---|
| 400 | `bad_request` | 일반 오류 토스트 |
| 401 | `unauthorized` | 토큰 갱신 1회 → 실패 시 로그인 안내 |
| 403 | `minor_restricted` | 해당 기능 숨김 |
| 403 | `client_outdated` | 업데이트 안내 화면 |
| 404 | `moment_not_found` | 알림 닫기 |
| 409 | `moment_closed` | 'Boost가 마감됐어요' |
| 409 | `quiz_closed` / `quiz_already_answered` | 퀴즈 카드 마감 표시 |
| 409 | `box_unavailable` / `box_already_opened` | 박스 버튼 숨김 |
| 409 | `insufficient_paid_energy` | 부족 안내 줄 + 충전 링크(보너스만 있으면 '유료 Energy만') |
| 409 | `insufficient_spark` | 부족 안내 줄 + 광고 월 링크 |
| 422 | `amount_not_allowed` / `idempotency_mismatch` / `message_rejected` | 개발 오류 로그 / 일반 오류 / '보낼 수 없는 표현이 있어요' |
| 429 | `rate_limited` | 버튼 잠깐 비활성(`Retry-After`) |
| 5xx | `server_error` | '보내지 못했어요. 차감되지 않았어요.' + 같은 키 재시도 |

## 5. 실시간 이벤트 (`GET /v1/ext/stream`, SSE)

- 형식: `id: <단조 증가>` · `event: <type>` · `data: <json>`. 하트비트 15초(`event: ping`)
- 재연결: `Last-Event-ID` 헤더 → 최대 5분 분량 재전송, 그 이상이면 `event: resync`(클라이언트가 REST로 현재 상태 재조회)
- 모든 `data`에 `server_ts` 포함. 결과형 이벤트의 표시 시각 = `server_ts + offset_ms`, 예고형(`moment.upcoming`, `quiz.opened`)은 즉시(docs/04 §4)

| event | 채널 | data 주요 필드 | 패널 처리 |
|---|---|---|---|
| `ping` | 공통 | `server_ts` | 연결 유지 |
| `resync` | 공통 | `reason` | `/matches/{id}`·`/moments?status=open`·`/me/wallet` 재조회 |
| `config.changed` | 공통 | `keys[]` | `/config` 재조회 |
| `match.state` | 경기 | `clock_s, score{t1,opp}, gold_diff, game_no` (5초마다·변화 시) | HUD 스코어 칩 |
| `match.started` / `match.ended` | 경기 | `match_id, result?` | S-1 전환 |
| `game.started` / `game.ended` | 경기 | `game_no, winner?` | 세트 간 화면 |
| `moment.upcoming` | 경기 | `moment_id, kind, title_key, team_id, tier_hint, closes_at, participants[], top_performer, sponsor?` | 큰 순간 알림(40초) |
| `moment.stats` | 경기 | `moment_id, boosters_count` (2초 묶음) | '함께 Boost N명' |
| `moment.resolved` | 경기 | `moment_id, final_tier, top_performer, winprob_delta_pp` | 카드 등급 확정 |
| `moment.cancelled` | 경기 | `moment_id, reason` | 알림 닫기(on_moment면 `boost.voided` 따라옴) |
| `quiz.opened` | 경기 | `quiz_id, question_key\|text, options[], closes_at` | 퀴즈 카드 12초 |
| `quiz.resolved` | 경기+사용자 | `quiz_id, correct_option, my?{correct, streak, score}` | 정답 표시 |
| `boost.settled` | 사용자 | `boost_id, card{…}` (on_moment 모드) | 카드 공개 |
| `boost.voided` | 사용자 | `boost_id, reason` | '순간이 성립하지 않아 돌려드렸어요' |
| `wallet.changed` | 사용자 | `energy{paid,bonus}, spark{balance}, reason` | 잔액 갱신(웹 충전·다른 기기 반영) |
| `card.updated` | 사용자 | `card_id, tier?, badges?` | 카드 목록 갱신 |

- 패널이 닫히면 SW는 스트림을 끊고 `moment.upcoming`만 받는 경량 폴링(1분, `GET /matches/{id}/moments?status=open`)으로 아이콘 배지 표시 — 정책 §5-4(푸시 금지)

## 6. 문구 키 규칙

- 서버는 `*_key` + `params`만 반환(예: `moment.baron_fight`, `card.star.fav_not_in_play {top, fav}`). 조합·조사 처리는 클라이언트 i18n(05 §9)
- 키 원본: `i18n-ko.json`의 영문 원문을 키 이름으로 정리해 이전(구현 시 키 표 작성)

## 7. `GET /v1/config` 응답 (웹 handoff 06 §6 이름 사용)

```json
{
  "min_ext_version": "2.0.0",
  "flags": { "sponsor_moment_enabled": false, "partner_official_label": false, "fav_player_star": true },
  "BOOST_SETTLE_MODE": "immediate",
  "STEP_ENERGY": [10, 50, 100, 500], "STEP_SPARK": [5, 10, 20, 50],
  "BADGE_ENERGY_L2": 50, "BADGE_ENERGY_L3": 100, "BADGE_SPARK_L2": 20, "BADGE_SPARK_L3": 50,
  "BOOST_CONFIRM_WINDOW_MS": 5000,
  "HEADSUP_COUNTDOWN_S": 40, "EXT_HEADSUP_MIN_GAP": 90, "HEADSUP_GOLD_MIN_GAP": 180,
  "QUIZ_WINDOW_S": 12, "QUIZ_GRACE_MS": 0,
  "SPARK_PER_AD": 5,
  "SPONSOR_BOX_ODDS": [[0, 75], [5, 20], [10, 5]],
  "BONUS_ENERGY_SCOPE": "rorr_deco",
  "MOMENT_TIER_GOLD_PP": 12, "MOMENT_TIER_HOLO_PP": 30
}
```

- 웹 06 §6에 없는 이름(확장 제안, 웹 handoff에 추가 요청): `BOOST_SETTLE_MODE` `BOOST_CONFIRM_WINDOW_MS` `HEADSUP_COUNTDOWN_S` `QUIZ_WINDOW_S` `QUIZ_GRACE_MS` `MOMENT_TIER_GOLD_PP` `MOMENT_TIER_HOLO_PP` `min_ext_version` `flags.*`
- 1단계 배지 기준은 '첫 Boost 최소 금액'(Energy 10·Spark 5)이라 별도 변수 없음
- 값 출처·결정 주체는 정책 §8. 화면은 이 값을 읽어 표시(하드코딩 금지)
