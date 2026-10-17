-- [2026-10-17 통합 안내] 단일 기준은 rorr-hero/handoff/db/schema.sql · reference_boost.sql (be35b45).
-- 이 파일은 통합 전 확장 설계로 참고용. 차이·채택 근거: rorr-hero/handoff/18-canonical-merge.md
-- Boost 확정 트랜잭션 참조 구현 (BOOST_SETTLE_MODE = immediate)
-- 작성일: 2026-10-17 · 설명: handoff/13-backend-middleware.md §2
-- 목적: 규칙(유료 Energy만·FIFO·카드 1장·재화별 누적 배지·포인트 1회)을 한 트랜잭션으로 보여 주는 기준.
-- 실제 서비스 코드는 언어 무관. 이 함수의 결과와 같은지로 테스트한다(schema/boost_tx_test.sql).

CREATE OR REPLACE FUNCTION rorr_badge_level(p_currency currency, p_total integer, p_cfg jsonb)
RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_total <= 0 THEN 0
    WHEN p_currency = 'energy' THEN
      CASE WHEN p_total >= (p_cfg->>'BADGE_ENERGY_L3')::int THEN 3
           WHEN p_total >= (p_cfg->>'BADGE_ENERGY_L2')::int THEN 2 ELSE 1 END
    ELSE
      CASE WHEN p_total >= (p_cfg->>'BADGE_SPARK_L3')::int THEN 3
           WHEN p_total >= (p_cfg->>'BADGE_SPARK_L2')::int THEN 2 ELSE 1 END
  END::smallint
$$;

CREATE OR REPLACE FUNCTION rorr_boost(
  p_user text, p_moment text, p_currency currency, p_amount integer,
  p_idem uuid, p_channel client_channel, p_team text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  cfg        jsonb := (SELECT jsonb_object_agg(key, value) FROM config_values);
  m          moments%ROWTYPE;
  v_team     text;
  v_boost    text := 'bo_' || substr(md5(random()::text), 1, 10);
  v_card     cards%ROWTYPE;
  v_is_new   boolean := false;
  v_need     integer := p_amount;
  v_take     integer;
  lot        record;
  v_total    integer;
  v_old_lv   smallint;
  v_new_lv   smallint;
  v_fav      text;
  v_has_fav  boolean;
  v_star     text;
  v_reason   star_reason;
  v_partner  boolean;
  v_season   text;
  v_tierb    smallint;
  v_streak   smallint := 0;
  v_points   jsonb := '{"total":0,"base":0,"tier_bonus":0,"streak_bonus":0}';
  v_existing jsonb;
BEGIN
  -- 0. 멱등: 같은 키면 같은 결과
  SELECT jsonb_build_object('boost_id', id, 'status', status, 'replay', true) INTO v_existing
    FROM boosts WHERE user_id = p_user AND idempotency_key = p_idem;
  IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;

  -- 1. 순간·금액 검증
  SELECT * INTO m FROM moments WHERE id = p_moment FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'moment_not_found'; END IF;
  IF m.status NOT IN ('upcoming', 'open') OR now() > m.closes_at THEN RAISE EXCEPTION 'moment_closed'; END IF;
  IF NOT (cfg -> CASE p_currency WHEN 'energy' THEN 'STEP_ENERGY' ELSE 'STEP_SPARK' END) @> to_jsonb(p_amount) THEN
    RAISE EXCEPTION 'amount_not_allowed';
  END IF;
  IF p_currency = 'energy' AND (SELECT is_minor FROM users WHERE id = p_user) THEN
    RAISE EXCEPTION 'minor_restricted';
  END IF;
  v_team := COALESCE(p_team, m.team_id);

  -- 2. 차감: Energy는 유료 묶음만(v1.3 §1-1), 만료 빠른 순. Spark는 만료 빠른 순
  INSERT INTO boosts (id, user_id, moment_id, team_id, currency, amount, status, channel, idempotency_key)
    VALUES (v_boost, p_user, p_moment, v_team, p_currency, p_amount, 'settled', p_channel, p_idem);

  IF p_currency = 'energy' THEN
    FOR lot IN SELECT id, remaining FROM energy_lots
               WHERE user_id = p_user AND kind = 'paid' AND status = 'active' AND remaining > 0 AND expires_at > now()
               ORDER BY expires_at, purchased_at FOR UPDATE LOOP
      EXIT WHEN v_need = 0;
      v_take := LEAST(v_need, lot.remaining);
      UPDATE energy_lots SET remaining = remaining - v_take WHERE id = lot.id;
      INSERT INTO boost_lot_usage VALUES (v_boost, lot.id, 'energy', v_take);
      INSERT INTO wallet_ledger (user_id, currency, lot_id, delta, reason, ref_type, ref_id)
        VALUES (p_user, 'energy', lot.id, -v_take, 'boost', 'boost', v_boost);
      v_need := v_need - v_take;
    END LOOP;
    IF v_need > 0 THEN
      RAISE EXCEPTION 'insufficient_paid_energy';
    END IF;
  ELSE
    FOR lot IN SELECT id, remaining FROM spark_lots
               WHERE user_id = p_user AND remaining > 0 AND expires_at > now()
               ORDER BY expires_at, granted_at FOR UPDATE LOOP
      EXIT WHEN v_need = 0;
      v_take := LEAST(v_need, lot.remaining);
      UPDATE spark_lots SET remaining = remaining - v_take WHERE id = lot.id;
      INSERT INTO boost_lot_usage VALUES (v_boost, lot.id, 'spark', v_take);
      INSERT INTO wallet_ledger (user_id, currency, lot_id, delta, reason, ref_type, ref_id)
        VALUES (p_user, 'spark', lot.id, -v_take, 'boost', 'boost', v_boost);
      v_need := v_need - v_take;
    END LOOP;
    IF v_need > 0 THEN RAISE EXCEPTION 'insufficient_spark'; END IF;
  END IF;

  -- 3. 카드: 순간당 1장. 첫 Boost에서만 주인공 결정(§4-1 초안)
  SELECT * INTO v_card FROM cards WHERE user_id = p_user AND moment_id = p_moment FOR UPDATE;
  IF NOT FOUND THEN
    v_is_new := true;
    v_partner := EXISTS (SELECT 1 FROM partner_teams WHERE team_id = v_team);
    SELECT true, player_id INTO v_has_fav, v_fav FROM user_fav_players WHERE user_id = p_user AND team_id = v_team;
    IF NOT v_partner THEN
      v_star := NULL; v_reason := 'non_partner';
    ELSIF v_fav IS NOT NULL AND EXISTS (SELECT 1 FROM moment_participants WHERE moment_id = p_moment AND player_id = v_fav) THEN
      v_star := v_fav; v_reason := 'fav_in_play';
    ELSIF v_fav IS NOT NULL THEN
      v_star := m.top_performer; v_reason := 'fav_not_in_play';
    ELSE
      v_star := m.top_performer; v_reason := 'auto';
    END IF;
    INSERT INTO cards (id, user_id, moment_id, team_id, tier, edition, star_player_id, star_reason, serial_no, first_boost_id)
      VALUES ('ca_' || substr(md5(random()::text), 1, 10), p_user, p_moment, v_team,
              COALESCE(m.final_tier, m.tier_hint), CASE WHEN v_partner THEN 'partner' ELSE 'rorr' END::card_edition,
              v_star, v_reason,
              (SELECT COALESCE(max(serial_no), 0) + 1 FROM cards WHERE moment_id = p_moment),
              v_boost)
      RETURNING * INTO v_card;
    UPDATE moments SET boosters_count = boosters_count + 1 WHERE id = p_moment;
  END IF;
  UPDATE boosts SET card_id = v_card.id, settled_at = now() WHERE id = v_boost;

  -- 4. 재화별 누적·배지(재Boost는 배지만)
  INSERT INTO card_currency_totals (card_id, currency, total, badge_level)
    VALUES (v_card.id, p_currency, 0, 0) ON CONFLICT DO NOTHING;
  SELECT badge_level, total + p_amount INTO v_old_lv, v_total
    FROM card_currency_totals WHERE card_id = v_card.id AND currency = p_currency FOR UPDATE;
  v_new_lv := rorr_badge_level(p_currency, v_total, cfg);
  UPDATE card_currency_totals SET total = v_total, badge_level = v_new_lv, updated_at = now()
    WHERE card_id = v_card.id AND currency = p_currency;

  -- 5. 응원 포인트: 순간당 1회 (+20, 등급 보너스, 경기당 첫 Boost에 연속 보너스)
  IF v_is_new THEN
    SELECT season INTO v_season FROM matches WHERE id = m.match_id;
    v_tierb := CASE COALESCE(m.final_tier, m.tier_hint) WHEN 'silver' THEN 10 WHEN 'gold' THEN 30 ELSE 60 END;
    IF NOT EXISTS (SELECT 1 FROM cheer_points cp JOIN moments mo ON mo.id = cp.moment_id
                   WHERE cp.user_id = p_user AND cp.team_id = v_team AND mo.match_id = m.match_id) THEN
      INSERT INTO cheer_streaks (user_id, team_id, streak_matches, last_match_id)
        VALUES (p_user, v_team, 1, m.match_id)
        ON CONFLICT (user_id, team_id) DO UPDATE SET streak_matches = cheer_streaks.streak_matches + 1, last_match_id = m.match_id;
      -- 직전 경기 미참여 시 초기화는 경기 종료 배치에서 처리(13 §4)
      -- 해석: 첫 경기는 연속 0 → 보너스 없음(목업·정책 예시 "골드 = 50 P"와 일치). 사업 확인 필요(13 §6)
      SELECT LEAST((streak_matches - 1) * 10, 100) INTO v_streak FROM cheer_streaks WHERE user_id = p_user AND team_id = v_team;
    END IF;
    INSERT INTO cheer_points (user_id, team_id, season, moment_id, base, tier_bonus, streak_bonus)
      VALUES (p_user, v_team, v_season, p_moment, 20, v_tierb, v_streak) ON CONFLICT DO NOTHING;
    v_points := jsonb_build_object('total', 20 + v_tierb + v_streak, 'base', 20, 'tier_bonus', v_tierb, 'streak_bonus', v_streak);
  END IF;

  RETURN jsonb_build_object(
    'boost_id', v_boost, 'status', 'settled',
    'card', jsonb_build_object(
      'card_id', v_card.id, 'is_new', v_is_new, 'tier', v_card.tier, 'edition', v_card.edition,
      'star_player', jsonb_build_object('player_id', v_card.star_player_id, 'reason', v_card.star_reason),
      'badges', (SELECT jsonb_object_agg(currency, badge_level) FROM card_currency_totals WHERE card_id = v_card.id),
      'totals', (SELECT jsonb_object_agg(currency, total) FROM card_currency_totals WHERE card_id = v_card.id),
      'level_up', CASE WHEN v_new_lv > v_old_lv THEN jsonb_build_object('currency', p_currency, 'from', v_old_lv, 'to', v_new_lv) END),
    'points_awarded', v_points,
    'wallet', jsonb_build_object(
      'energy', jsonb_build_object(
        'paid',  (SELECT COALESCE(sum(remaining), 0) FROM energy_lots WHERE user_id = p_user AND kind = 'paid'  AND status = 'active' AND expires_at > now()),
        'bonus', (SELECT COALESCE(sum(remaining), 0) FROM energy_lots WHERE user_id = p_user AND kind = 'bonus' AND status = 'active' AND expires_at > now())),
      'spark', jsonb_build_object('balance', (SELECT COALESCE(sum(remaining), 0) FROM spark_lots WHERE user_id = p_user AND expires_at > now())))
  );
END $$;
