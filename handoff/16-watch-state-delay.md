# 16. 시청 상태 안내·방송 지연 관리 (v46)

- 작성일: 2026-10-17 · 기준: 목업 v46 · 관련: 02 §17(화면), 05 §9(규칙), 08 F-2·W-1·Q-5(흐름), 06 §5-1(QA)
- 결정(2026-10-17)
  - 채널 안내는 **공식 채널부터**, 코스트리밍은 2단계에서 같은 구조로 확장
  - 다시보기는 **안내만**(Boost 막지 않음, 결과형 알림만 끔)
  - 방송 지연은 **채널 기본값 → 개인 자동 보정 → 1탭 보정** 3단계
- API·DB 기준은 웹·확장 통합본 `rorr-hero/handoff/api/openapi.yaml`·`db/schema.sql`(be35b45). 이 문서 §4는 그 통합본에 반영할 **변경 요청**이며, 이름은 통합본 규칙(`host` = `youtube|chzzk|soop|twitch`, `channel_id`)을 따름

---

## 1. 왜 필요한가

- 경기 시작 알림을 받아도 어느 채널에서 하는지 몰라 이탈 → 알림과 시청 사이 경로가 없음
- 다른 방송·다시보기를 보면서 지난 순간에 Boost하거나 결과를 미리 보는(스포일러) 혼선
- 플랫폼·화질·사용자 버퍼링마다 지연이 달라 값 하나로는 서하 반응·퀴즈 마감이 맞지 않음

## 2. 시청 상태 4종

| 상태 | 판정(확장, 지원 사이트 4곳에서 읽기만) | 패널 | 결과형 알림 | Boost |
|---|---|---|---|---|
| 공식 채널 | 등록 채널 + 라이브 끝 근접 | 띠 없음 | 개인 지연 후 | 가능 |
| 탭 없음 | 경기 중 + 지원 사이트 탭 없음 | 띠 + 공식 채널 목록 | 채널 기본 지연 후 | 가능 |
| 다른 방송 | 지원 사이트 + 미등록 채널(2단계 전 코스트리밍 포함) | 띠 + 공식 채널 버튼 | 채널 기본 지연 후 | 가능 |
| 다시보기 | 라이브 끝에서 `WATCH_REPLAY_BEHIND_S`(60초) 이상 뒤 또는 일시정지 60초 | 띠 + '라이브로' | **표시 안 함** | 가능(안내만) |

- 상태가 `WATCH_STATE_HOLD_MS`(3초) 유지돼야 전환(탭 이동·버퍼링 깜박임 방지)
- 읽는 값: 호스트·URL·제목·재생 상태·라이브 끝까지 거리(`video.seekable.end − currentTime`). 영상 화면은 읽지 않음 → **권한 추가 없음**(기존 사용자 재동의 불필요)

## 3. 방송 지연 3단계

```
personal_offset = channel_offset(서버) + behind_edge(확장 자동) + user_nudge(1탭, 로컬)
결과형 표시 시각 = server_ts + personal_offset   ·   예고형은 즉시
```

| 층 | 방법 | 담당 | 갱신 |
|---|---|---|---|
| ① 채널 기본값 | 경기·세트 시작 직후 공식 채널마다 '화면 게임 시계 vs 데이터 시계' 측정. 초기 운영자 수동(경기당 채널 3개, 5분 이내), 이후 자동화 | 서버 `broadcasts.default_offset_ms` | 경기·세트 시작 + 사용자 보고 집계 |
| ② 개인 자동 | 라이브 끝에서 뒤처진 시간을 재생 위치로 측정해 더함 | 확장 | 2초 주기 |
| ③ 1탭 보정 | '화면이 늦어요'(+2초) / '화면이 빨라요'(−2초). 로컬 저장(경기·채널별) + 익명 보고 | 사용자 → 서버 | 1분 집계 |

- 사용자 보고 집계: 채널별 최근 5분 보고의 **중앙값**, 사분위 범위 밖 이상값 제외, 최소 표본 30. 기본값과 `OFFSET_DRIFT_ALERT_MS`(3초) 이상 차이 → 기본값 갱신(source=crowd) + 운영 경보 + SSE `broadcast.offset`
- 측정 이력은 모두 저장 → 플랫폼별 지연 실측표(웹 OI-06·OI-27)의 근거
- 마감 규칙(서버)
  - Boost: `closes_at + min(채널 기본 지연, BOOST_GRACE_MS)` — ②·③은 사용자가 바꿀 수 있으므로 **마감에 쓰지 않음**
  - 퀴즈: 결과가 실제로 일어난 **데이터 시각 이후의 답은 무효**(지연과 무관, 상금 공정성). `quiz.resolved`는 마감 전 어느 채널에도 보내지 않음. 문항은 결과까지 여유 있는 것으로 출제
- 코스트리밍(2단계): 채널 등록 → 같은 측정 절차. 재송출 지연이 더해지므로 채널별 값을 따로 둠

## 4. 공용 API·DB 변경 요청 (통합본 `rorr-hero/handoff` 반영 필요)

| ID | 대상 | 변경 |
|---|---|---|
| C-1 | `db/schema.sql` `broadcasts` | 컬럼 추가: `kind text NOT NULL DEFAULT 'official' CHECK (kind IN ('official','costream'))`, `display_name text`, `lang text`, `watch_url text`, `sort_order smallint DEFAULT 0`, `offset_source text DEFAULT 'preset' CHECK (offset_source IN ('preset','ops','crowd','auto'))`, `offset_updated_at timestamptz` |
| C-2 | `db/schema.sql` 신규 | `broadcast_offset_measurements(id bigserial, broadcast_id → broadcasts, source ops/crowd/auto, offset_ms int, sample_n int, measured_at timestamptz)` |
| C-3 | `db/schema.sql` `stream_offset_reports` | 컬럼 추가: `broadcast_id bigint REFERENCES broadcasts(id)`, `behind_edge_ms int` |
| C-4 | `api/openapi.yaml` 신규 | `GET /v1/matches/{match_id}/broadcasts` → `items[{broadcast_id, host, channel_id, display_name, lang, kind, watch_url, offset_ms}]`(초기 `kind=official`만, 공개 API). 웹 경기 페이지 '어디서 보나요'에도 사용 가능 |
| C-5 | `POST /v1/ext/match/resolve` 응답 | `channel_status: official\|unregistered`, `broadcast_id` 추가 |
| C-6 | `POST /v1/ext/offset-reports` 본문 | `broadcast_id`, `behind_edge_ms` 추가(선택) |
| C-7 | `api/realtime-events.md` | `broadcast.offset {broadcast_id, offset_ms, source}` — 경기 채널. 확장은 개인 지연 재계산 |
| C-8 | 설정(06 §6·`config_values`) | `WATCH_REPLAY_BEHIND_S`=60, `WATCH_STATE_HOLD_MS`=3000, `OFFSET_STEP_MS`=2000, `OFFSET_DRIFT_ALERT_MS`=3000. `BOOST_GRACE_MS` 의미를 '상한'으로 명시(실제 여유 = min(채널 기본 지연, 값)), 값은 실측 후(30000 제안) |
| C-9 | 퀴즈 판정 규칙(17-backend 등) | 결과 데이터 시각 이후 답 무효 + `quiz.resolved` 마감 전 미발행 |
| C-10 | 06 §7 '알림 노출' 기록 | `watch_state` 추가 권장(다시보기 상태 노출은 집계에서 분리) |

- 참고: C-1~C-3을 확장 참고용 DDL 초안에 적용해 PostgreSQL 16 적용과 기존 Boost 테스트 9개 통과를 확인함(2026-10-17, 참고용 파일은 고정 상태라 커밋하지 않음). 통합본 반영 후 통합 테스트로 재검증 필요

## 5. 측정 이벤트 (14와 동일 이름)

- `watch_state{state, host, prev}`, `watch_channels_open`, `watch_channel_click{host}`, `watch_go_live`, `watch_dismiss`, `offset_adjust{delta_ms, host, behind_edge_ms}`
- 지표: 공식 채널 전환율(띠 노출 후 5분 안 `official` 전환) — 코스트리밍 확장 판단 근거 · 시청 세션당 보정 횟수 — 높으면 기본값 측정 주기 재검토

## 6. 남은 확인

| 번호 | 항목 | 현재 |
|---|---|---|
| W-OI-1 | 다시보기 판정 기준 60초 | 플랫폼별 실측 후 확정 |
| W-OI-2 | 공식 채널 목록·순서(언어별) | 운영 등록. 목업 주소는 샘플 |
| W-OI-3 | 채널 기본값 자동 측정 방식(운영 수동 → 자동) | 1단계 수동 |
| W-OI-4 | 코스트리밍 2단계 시점·대상 | 공식 채널 전환율 데이터 확인 후 |
