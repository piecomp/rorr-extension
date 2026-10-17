# 05. 규칙·상태 모델

- 작성일: 2026-10-17 · 근거: 정책 v1.3(§ 번호), 목업 v46 상수
- 서버가 판단할 것과 클라이언트가 표시만 할 것을 구분. **차감·적립·발급·판정은 모두 서버**, 클라이언트는 결과를 받아 표시

---

## 1. 주요 상수 (서버 설정값으로 둘 것)

| 이름 | 목업 값 | 근거 | 비고 |
|---|---|---|---|
| `STEP_ENERGY` | 10 / 50 / 100 / 500 | 13 §15(스테퍼) | 기본 선택 10 |
| `STEP_SPARK` | 5 / 10 / 20 / 50 | 정책 §4 | 기본 선택 10 |
| `BADGE_ENERGY_L2`·`L3` | 10 → 1단계, 50 → 2단계, 100 → 3단계 | §4·§8 `deco.e2/e3` | 같은 순간 **누적** 기준 |
| `BADGE_SPARK_L2`·`L3` | 5 → 1단계, 20 → 2단계, 50 → 3단계 | §4·§8 `deco.s2/s3` | 재화별 따로 계산·표기 |
| `CHEER_POINTS` | 순간당 1회 +50(골드 순간 예시) | §5-3 | 재Boost는 포인트 없음 |
| `MOMENT_TIER` | 승률 변화 ≥30%p 홀로그램, ≥12%p 골드, 그 외 실버 | §4 | 목업 `tierOf` |
| `CONFIRM_WINDOW` | 5초 | 웹 4e72431 | 두 번 누르기 |
| `HEADSUP_COUNTDOWN` | 40초 | F-04 | 순간별 서버 값 |
| `QUIZ_WINDOW` | 12초 | F-20 | |
| `SPONSOR_BOX_ODDS` | 꽝 75 / Spark 5 20 / Spark 10 5 | §6-1 B·§8 | [논의 중] 임시값, 확률 상시 표시 |
| `SPONSOR_BOX_POOL` | 미정 | §8 | 소진 시 박스 미노출(후원 라벨만) |
| `HEADSUP_FREQ` | 웹: 3분 간격·방문당 3회 / 확장: 더 높게 허용 | 15 §2-6 | 값은 실측 후 |
| `WATCH_REPLAY_BEHIND_S` | 60초 | v46 | 라이브 끝에서 이만큼 뒤처지면 다시보기로 판정(실측 후 확정) |
| `WATCH_STATE_HOLD_MS` | 3000 | v46 | 상태가 이 시간 유지돼야 띠 전환 |
| `OFFSET_STEP_MS` | 2000 | v46 | 1탭 보정 단위 |
| `OFFSET_DRIFT_ALERT_MS` | 3000 | v46 | 사용자 보고 중앙값과 기본값 차이 경보 기준 |
| `BOOST_GRACE_MS` | 상한(30000 제안, 통합본 현재 0) — 실제 여유 = min(채널 기본 지연, 값) | v46·BE-4·16 C-8 | 마감 여유. 사용자 보정값은 쓰지 않음 |

## 2. Boost 처리 순서

```
[1차 탭] → client: 대기 상태(5초), 서버 호출 없음
[2차 탭] → POST /v1/boosts {moment_id, currency, amount, message?}
   server: 잔액 확인(유료 Energy만 · v1.3 §1-1) → 차감 → 순간 누적 갱신 → 배지 단계 재계산
           → 첫 Boost면 카드 발급 + 응원 포인트 적립, 재Boost면 배지만 갱신
   response: {card_id, is_new, badges:{energy:lv, spark:lv}, totals:{energy, spark},
              level_up:{currency, from, to}|null, points_awarded, star_player, sponsor_label}
   client: 축하 연출 → 카드 공개(is_new / level_up / 남은 양 표시)
```

- 실패 시: 차감 반영 없음, '보내지 못했어요. 차감되지 않았어요.' — 낙관적 차감 금지
- 순간 종료(알림 0초) 이후 요청은 서버가 거절 → '이 순간의 Boost가 마감됐어요'

## 3. 배지 누적 (정책 §4, 2026-10-17 개정)

- 순간별·사용자별·재화별 누적 합계 `total[currency]`
- 단계 = `BADGE_*_L2`·`L3` 임계값(1단계 = 첫 Boost)을 넘은 개수(0~3)
- 카드는 순간당 1장. 재Boost는 **배지만** 상승, 테두리(등급)·포인트 불변
- 두 재화를 모두 쓰면 배지 2개를 세로로 표시(재화별)
- 화면 문구
  - 첫 Boost 안내: 'N단계 배지 · 골드 모먼트 카드 함께 발급'
  - 재Boost 안내: '{재화} {단계}단계 · 이 순간 누적 {합계} · {다음 단계}단계까지 {차이} 남음' / 최고 단계면 '최고 단계'
  - 카드 발급 줄: 단계 상승 예정 '카드는 이미 받았어요 · {재화} 배지 {n}단계로' / 그 재화 첫 사용 '{재화} {n}단계 배지 추가' / 불변 '이 순간 누적에 더해져요'

## 4. 카드 주인공 [논의 중 — §4-1 개정 초안, docs/05 하단]

```
participants = moment.players            // 서버 순간 데이터(교전 참여·오브젝트 관여)
top          = moment.top_performer      // RORR 기여도 1위
star = (user.fav && participants.includes(user.fav)) ? user.fav : top
```

- 카드 발급 시점(첫 Boost)에 고정. 이후 `fav`를 바꿔도 발급된 카드는 그대로
- `fav` 상태: `undefined`(아직 안 물음) → 경기 시작 때 묻기 / `null`(자동) / 선수 ID
- 파트너 팀 선수만. 비제휴 팀은 RORR 모먼트 카드(선수 이름·사진 없음)
- 카드 공개 문구: 일치 '내 선수 {P}의 순간' / 미참여 '이번엔 {top}의 순간이었어요 · {fav}는 이 교전에 없었어요' / 자동 '가장 크게 기여한 선수 · {top}'
- 내 선수 일치 여부로 포인트·등급·희소성 차등 없음

## 5. 두 번 누르기 상태

```
idle --tap--> armed(5s)
armed --tap--> sending --ok--> celebrate --> card
armed --5s | amount/currency change | sheet close--> idle
idle --tap & balance < amount--> idle + 부족 안내(대기 없음)
```

## 6. 큰 순간 알림 상태

```
none --server push(moment.upcoming)--> headsup(40s countdown, Boost 버튼 hot)
headsup --countdown 0 | moment resolved--> none
headsup --Boost 2차 탭--> sp-busy(후원 줄 숨김) --card closed--> headsup|none
```

- 퀴즈가 열려 있으면 큰 순간 알림이 오기 전에 퀴즈 마감
- 알림 수준 설정(메뉴): 전체 / 결정적 순간만(홀로그램) / 끄기

## 7. 스폰서 행운 박스 [논의 중]

- 노출 조건(모두 충족): `sponsor_moment_enabled` · 파트너 팀 경기 · 순간 등급 골드 이상 · 사용자 이번 알림 기회 미사용 · `SPONSOR_BOX_POOL` 잔량 · 로그인
- 결과 판정은 **서버**(클라이언트 난수 금지). 박스 선택은 연출이며 확률 동일
- 당첨 Spark는 일반 Spark 지갑에 적립(유효기간·용도 동일, 광고 1일 한도와 별도 집계)
- 결과는 카드·배지·포인트·연출에 직접 반영 없음
- 측정 이벤트: `box_shown`, `box_open`, `box_result{prize}`, `box_cta{spark|energy}`, 같은 순간 Boost 여부(홀드아웃 비교용, §6-1 측정 가설)
- 미성년 사용자: 법률 확인 전 미노출(§9 블로커)

## 8. 서버 상태와 클라이언트 표시의 분리

| 데이터 | 소유 | 클라이언트 캐시 |
|---|---|---|
| 잔액(유료 Energy·Spark) | 서버(웹과 공유) | 패널 포커스 복귀 시 재조회(§2-14 충전 복귀) |
| 카드·배지·누적 | 서버 | 순간 종료 전까지 |
| 내 선수 | 서버(계정) | 메뉴 변경 즉시 반영 |
| 퀴즈 점수·연속 정답 | 서버 | 경기 중 |
| 코치마크 확인 여부 | 로컬(chrome.storage) | — |
| 언어 | 로컬 + 계정 기본값 | — |

## 9. 시청 상태·방송 지연 (v46)

```
data_time      = 서버 이벤트 시각(server_ts)
channel_offset = broadcasts.default_offset_ms        // 데이터 시각 → 라이브 끝 화면 시각
behind_edge    = video.seekable.end − video.currentTime  // 확장이 재생 위치로 자동 측정
user_nudge     = Σ 1탭 보정(±2초)                     // 로컬 저장, 익명 보고
personal_offset = channel_offset + behind_edge + user_nudge
```

- 결과형 이벤트 표시 시각 = `data_time + personal_offset`. 예고형은 즉시
- 상태 판정: 탭 없음 / 공식 채널 / 다른 방송(미등록 채널) / 다시보기(`behind_edge ≥ WATCH_REPLAY_BEHIND_S` 또는 일시정지 60초)
- '탭 없음'·'다른 방송'은 개인 측정이 불가 → `channel_offset`만 사용(공식 채널 중 사용자 언어 우선 채널의 값)
- 마감 계산(서버): Boost는 `closes_at + min(channel_offset, 상한)`. **퀴즈는 결과가 실제로 일어난 데이터 시각 이후 답을 무효**(지연과 무관, 상금 공정성) — 문항은 결과까지 여유 있는 것으로 출제
- 사용자 보정값은 마감 계산에 쓰지 않음(임의로 마감을 늦추는 것 방지)
- 범위: 초기 공식 채널만, 코스트리밍은 2단계(같은 구조, 채널별 기본값만 별도 측정)

## 10. 한국어 조사 처리

- 선수·팀 이름 뒤 조사는 마지막 글자 받침으로 판별
  - 라틴 문자: 끝이 n·m·l·ng 계열이면 받침으로 취급(목업은 `n`만 처리 — Doran이, Faker가). 구현 시 사전형 예외 목록 권장
  - 숫자: 읽는 소리 기준 받침 판별(예: 'Spark 5로', 'Spark 10으로', 'Energy 50을'). 목업은 일부만 규칙화되어 있으므로 숫자 읽기 표 기반 함수로 구현
- 문구 조합은 i18n 템플릿에서 처리하고, 화면에서 문자열을 이어 붙이지 않음(목업의 정규식 번역은 이식 대상 아님)
