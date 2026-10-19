# 14. 측정 이벤트

- 작성일: 2026-10-17 · 전송: `POST /v1/events`(묶음 최대 50건, 10초 또는 20건마다, 패널 닫힘 시 즉시) · 저장: DW(가명 키)
- 목적: ① 두 번 누르기·시트 단순화(v44) 효과 ② 큰 순간 알림 빈도 실측(`EXT_HEADSUP_MIN_GAP`) ③ 행운 박스 측정 가설(정책 §6-1, 홀드아웃 비교) ④ 내 선수 규칙 반응
- **서버가 이미 아는 사실은 클라이언트가 다시 보내지 않음**(Boost 성공·카드 발급·포인트 = 서버 이벤트로 집계). 클라이언트 이벤트는 화면 노출·조작만

---

## 1. 공통 속성

| 속성 | 설명 |
|---|---|
| `client_event_id` | UUID(중복 제거) |
| `ts` | 클라이언트 시각(서버가 수신 시각 별도 기록) |
| `session_id` | 패널 열림 ~ 닫힘 1회 |
| `client` | `ext/2.0.0` |
| `lang` | `ko` / `en` |
| `match_id`, `moment_id` | 해당 시 |
| `panel_w` | 패널 폭(px, 50 단위 버킷) |
| `signed_in` | bool |

- 수집 금지: 중계 URL 전체·채팅 내용·입력 문장(Muse 대화 원문은 서버 대화 로그 정책을 따로 따름)

## 2. 이벤트 목록

| 이름 | 시점 | 주요 속성 | 쓰임 |
|---|---|---|---|
| `panel_open` / `panel_close` | 패널 열림·닫힘 | `state(S0~S5)`, `duration_s` | 체류 |
| `match_resolved` | 매칭 결과 | `status(matched/ambiguous/none)`, `host` | 매칭 품질 |
| `offset_adjust` | 지연 보정 탭 | `delta_ms`, `host`, `behind_edge_ms` | 지연 실측(OI-06) |
| `watch_state` | 시청 상태 전환(v46) | `state(none/official/other/replay)`, `host`, `prev` | 공식 채널 유입·다시보기 비율 |
| `watch_channels_open` / `watch_channel_click` / `watch_go_live` / `watch_dismiss` | 띠 조작 | `host`, `lang` | 채널 안내 효과 |
| `watch_chip_open` | 큰 순간 중 시청 상태 칩 펼침(v47) | `state` | 접힘 칩의 발견성 |
| `stream_state` | 연결 상태 변화 | `state`, `retry_count` | 안정성 |
| `headsup_shown` | 큰 순간 알림 표시 | `tier_hint`, `gap_since_last_s`, `sponsor(bool)` | 빈도 실측 |
| `headsup_dismiss` | 알림 닫기 | `remaining_s` | 피로도 |
| `boost_sheet_open` | 시트 열림 | `source(headsup/dock/card/box_win)`, `has_card(bool)` | 진입 경로 |
| `boost_currency_change` | 재화 변경 | `to` | — |
| `boost_arm` | 1차 탭 | `currency`, `amount` | 두 번 누르기 |
| `boost_arm_timeout` | 5초 경과 | `currency`, `amount` | 확인 이탈률 |
| `boost_confirm` | 2차 탭 | `currency`, `amount`, `arm_to_confirm_ms` | 확인 소요 |
| `boost_result_shown` | 축하·카드 표시 | `mode(new/levelup/add/same)`, `tier` | — |
| `boost_fail_shown` | 실패 안내 | `code` | 오류 체감 |
| `boost_insufficient` | 부족 안내 | `currency`, `bonus_available(bool)` | 충전 유도 |
| `topup_click` / `topup_return` | 충전 이동·복귀 | `moment_open(bool)` | 충전 복귀 |
| `boost_info_open` | ⓘ 펼침 | `kind(deduct/star)` | 고지 확인률 |
| `fav_ask_shown` / `fav_set` | 내 선수 묻기·설정 | `choice(player_id/auto/ignore)`, `where(ask/menu/sheet)` | 내 선수 규칙 |
| `card_flip` / `card_share` | 카드 뒤집기·자랑하기 | `result(copied/saved/failed)` | — |
| `quiz_shown` / `quiz_answer` | 퀴즈 | `answer_ms` | 참여 |
| `moments_panel_open` | 오늘의 모먼트 | — | — |
| `sponsor_label_shown` | 후원 줄 노출 | `sponsor_id`, `holdout(bool)` | 측정 가설 |
| `box_shown` / `box_open` / `box_result` / `box_cta` | 행운 박스 | `prize`, `cta(spark/energy/close)` | 측정 가설 |
| `muse_chat_send` | 대화 전송 | `len_bucket` | — |
| `i18n_missing` | 문구 키 없음 | `key` | 품질 |
| `client_error` | 처리 안 된 오류 | `where`, `request_id` | 품질 |

## 3. 서버 이벤트(집계 기준)

| 이름 | 발생 | 속성 |
|---|---|---|
| `boost.settled` | Boost 확정 | `currency, amount, is_new, level_up, channel, tier, team_id, star_reason` |
| `boost.rejected` | 거부 | `code` |
| `points.awarded` | 포인트 적립 | `total, base, tier_bonus, streak_bonus` |
| `sponsor.box_opened` | 박스 판정 | `result, prize, contract_id, holdout` |
| `headsup.suppressed` | 빈도 상한으로 미표시 | `reason(gap/level_off)` |

## 4. 핵심 지표 정의

| 지표 | 정의 | 목표·판단 |
|---|---|---|
| 확인 완료율 | `boost_confirm ÷ boost_arm` | 85% 이상(낮으면 5초 창·문구 재검토) |
| 알림 → Boost 전환 | 알림 노출 순간 중 Boost 확정 비율 | 기준선 확보 후 설정 |
| 알림 피로 | `headsup_dismiss` 비율, 경기당 알림 수별 다음 경기 재방문 | `EXT_HEADSUP_MIN_GAP` 결정 |
| 내 선수 일치율 | `star_reason = fav_in_play` 비율 | 낮으면 미참여 문구·묻는 방식 재검토(EXT-1) |
| 후원 효과 | 같은 순간 Boost 비율: 노출군 vs 홀드아웃 | 정책 §6-1 측정 가설. 하락 시 `SPONSOR_BOX_KILL_DROP` |
| 고지 확인 | `boost_info_open(deduct)` ÷ 첫 Energy Boost 사용자 | 참고 지표(고지는 펼침 없이도 차감 줄에 표시) |
| 공식 채널 전환율(v46) | 탭 없음·다른 방송 띠 노출 후 5분 안 `official` 전환 비율 | 코스트리밍 확장(2단계) 판단 근거 |
| 지연 보정 빈도 | 시청 세션당 `offset_adjust` 수 | 높으면 채널 기본값 측정 주기·자동 보정 재검토 |
