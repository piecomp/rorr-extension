-- boost_tx.sql 검증 시나리오 (빈 DB: schema.sql → boost_tx.sql → 이 파일)
-- 기대값은 정책 v1.3 · 목업 v45 · 05-state-logic 기준. 실패 시 ASSERT 오류로 중단.
\set ON_ERROR_STOP 1

INSERT INTO config_values (key, value, updated_by) VALUES
 ('STEP_ENERGY', '[10,50,100,500]', 'test'), ('STEP_SPARK', '[5,10,20,50]', 'test'),
 ('BADGE_ENERGY_L2', '50', 'test'), ('BADGE_ENERGY_L3', '100', 'test'),
 ('BADGE_SPARK_L2', '20', 'test'), ('BADGE_SPARK_L3', '50', 'test');

INSERT INTO teams VALUES ('t1','T1','T1','LCK',NULL), ('gen','Gen.G','GEN','LCK',NULL);
INSERT INTO partner_agreements (id, team_id, starts_on, share_bp) VALUES ('pa1','t1','2026-01-01',7000);
INSERT INTO players (id, team_id, nickname, role) VALUES
 ('p_doran','t1','Doran','top'),('p_oner','t1','Oner','jungle'),('p_faker','t1','Faker','mid'),
 ('p_peyz','t1','Peyz','adc'),('p_keria','t1','Keria','support'),('p_chovy','gen','Chovy','mid');
INSERT INTO users (id, nickname) VALUES ('u1','fan'), ('u2','fan2');
INSERT INTO user_fav_players VALUES ('u1','t1','p_doran', now());   -- 내 선수 Doran (교전 미참여)
INSERT INTO matches (id, league, season, starts_at, team_a_id, team_b_id, status)
  VALUES ('ma1','LCK','2026','2026-10-17T09:00Z','t1','gen','live');
INSERT INTO games (match_id, game_no) VALUES ('ma1', 1);
INSERT INTO moments (id, match_id, game_no, kind, team_id, status, tier_hint, top_performer, announced_at, closes_at)
  VALUES ('mo1','ma1',1,'baron_fight','t1','open','gold','p_faker', now(), now() + interval '40 seconds'),
         ('mo2','ma1',1,'dragon_soul','gen','open','silver','p_chovy', now(), now() + interval '40 seconds');
INSERT INTO moment_participants VALUES ('mo1','p_oner',.2),('mo1','p_faker',.6),('mo1','p_keria',.2);
-- u1: 유료 40(곧 만료) + 유료 100 + 보너스 30, Spark 35
INSERT INTO energy_lots (id, user_id, kind, qty, remaining, unit_price_krw, list_unit_price_krw, expires_at) VALUES
 ('el_a','u1','paid', 40, 40, 100, 100, now() + interval '30 days'),
 ('el_b','u1','paid',100,100,  92, 100, now() + interval '5 years'),
 ('el_c','u1','bonus',30, 30,   0,   0, now() + interval '1 year');
INSERT INTO spark_lots (id, user_id, source, qty, remaining, expires_at) VALUES ('sl_a','u1','ad_reward',35,35, now() + interval '90 days');

DO $$
DECLARE r jsonb;
BEGIN
  -- T1 첫 Boost Energy 50: 유료 FIFO(40 + 10), 카드 발급, 주인공 = top(내 선수 미참여), 배지 2단계, 포인트 20+30(첫 경기 연속 보너스 0)
  r := rorr_boost('u1','mo1','energy',50,'00000000-0000-0000-0000-000000000001','ext');
  ASSERT (r#>>'{card,is_new}')::boolean, 'T1 is_new';
  ASSERT r#>>'{card,star_player,player_id}' = 'p_faker' AND r#>>'{card,star_player,reason}' = 'fav_not_in_play', 'T1 star';
  ASSERT (r#>>'{card,badges,energy}')::int = 2, 'T1 badge';
  ASSERT (r#>>'{card,level_up,to}')::int = 2, 'T1 level_up';
  ASSERT (r#>>'{points_awarded,total}')::int = 50, 'T1 points ' || (r#>>'{points_awarded,total}');
  ASSERT (r#>>'{wallet,energy,paid}')::int = 90 AND (r#>>'{wallet,energy,bonus}')::int = 30, 'T1 wallet';
  ASSERT (SELECT remaining FROM energy_lots WHERE id='el_a') = 0, 'T1 FIFO';

  -- T2 재Boost Energy 50: 카드 그대로, 누적 100 → 3단계, 포인트 0
  r := rorr_boost('u1','mo1','energy',50,'00000000-0000-0000-0000-000000000002','ext');
  ASSERT NOT (r#>>'{card,is_new}')::boolean, 'T2 not new';
  ASSERT (r#>>'{card,totals,energy}')::int = 100 AND (r#>>'{card,badges,energy}')::int = 3, 'T2 badge 3';
  ASSERT (r#>>'{points_awarded,total}')::int = 0, 'T2 no points';

  -- T3 같은 순간 Spark 5: Spark 배지 1단계 추가, Energy 배지 유지
  r := rorr_boost('u1','mo1','spark',5,'00000000-0000-0000-0000-000000000003','ext');
  ASSERT (r#>>'{card,badges,spark}')::int = 1 AND (r#>>'{card,badges,energy}')::int = 3, 'T3 two badges';
  ASSERT (r#>>'{card,level_up,currency}') = 'spark', 'T3 level_up spark';

  -- T4 멱등: 같은 키 재요청은 재생
  r := rorr_boost('u1','mo1','spark',5,'00000000-0000-0000-0000-000000000003','ext');
  ASSERT (r->>'replay')::boolean, 'T4 replay';
  ASSERT (SELECT count(*) FROM boosts WHERE user_id='u1') = 3, 'T4 no dup';

  -- T5 허용되지 않은 금액
  BEGIN r := rorr_boost('u1','mo1','energy',30,'00000000-0000-0000-0000-000000000005','ext'); ASSERT false, 'T5';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'amount_not_allowed', 'T5 ' || SQLERRM; END;

  -- T6 유료 부족(유료 40 남음 + 보너스 30): Energy 50 거절, 차감 없음 — 보너스는 Boost 불가
  BEGIN r := rorr_boost('u1','mo2','energy',50,'00000000-0000-0000-0000-000000000006','ext'); ASSERT false, 'T6';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'insufficient_paid_energy', 'T6 ' || SQLERRM; END;
  ASSERT (SELECT sum(remaining) FROM energy_lots WHERE user_id='u1' AND kind='paid') = 40, 'T6 rollback';
  ASSERT (SELECT remaining FROM energy_lots WHERE id='el_c') = 30, 'T6 bonus untouched';

  -- T7 비제휴 팀 순간: RORR 카드, 주인공 없음
  r := rorr_boost('u1','mo2','spark',5,'00000000-0000-0000-0000-000000000007','ext');
  ASSERT r#>>'{card,edition}' = 'rorr' AND r#>>'{card,star_player,reason}' = 'non_partner', 'T7 non partner';

  -- T8 마감된 순간
  UPDATE moments SET closes_at = now() - interval '1 second' WHERE id='mo1';
  BEGIN r := rorr_boost('u1','mo1','spark',5,'00000000-0000-0000-0000-000000000008','ext'); ASSERT false, 'T8';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'moment_closed', 'T8 ' || SQLERRM; END;

  -- T9 원장 합계 = 묶음 감소량
  ASSERT (SELECT -sum(delta) FROM wallet_ledger WHERE user_id='u1' AND currency='energy') = 100, 'T9 ledger';
  RAISE NOTICE 'boost_tx: 9 scenarios passed';
END $$;
