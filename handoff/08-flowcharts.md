# 08. 흐름도

- 작성일: 2026-10-17 · 기준: 목업 v46, 정책 v1.3 · 표기: Mermaid(GitHub에서 그림으로 표시)
- 사용자 흐름(F-), 시퀀스(Q-), 상태(S-)로 구분. 화면 번호는 02-screen-spec, API는 09-api-spec, 이벤트는 09 §5

---

## 목록

| 번호 | 흐름 | 종류 |
|---|---|---|
| F-1 | 설치 → 첫 실행 → 로그인 | 사용자 흐름 |
| F-2 | 중계 매칭 → 시청 상태 확인(v46) | 사용자 흐름 |
| W-1 | 시청 상태 4종(v46) | 상태 |
| Q-5 | 채널 기본 지연 측정·갱신(v46) | 시퀀스 |
| S-1 | 패널 화면 상태(S0~S5) | 상태 |
| Q-1 | 큰 순간 예고 → Boost → 카드 공개 | 시퀀스 |
| S-2 | 두 번 누르기 | 상태 |
| F-3 | 재Boost 누적·배지 상승 | 사용자 흐름 |
| F-4 | 카드 주인공 결정 [논의 중] | 판정 |
| F-5 | 내 선수 묻기 | 사용자 흐름 |
| Q-2 | 스폰서 행운 박스 [논의 중] | 시퀀스 |
| F-6 | 잔액 부족 → 충전 → 복귀 | 사용자 흐름 |
| Q-3 | 퀴즈 출제 → 답 → 판정 | 시퀀스 |
| F-7 | 경기 시작 알림(패널 닫힘) | 사용자 흐름 |
| F-8 | 비제휴 팀 경기 | 분기 |
| S-3 | 실시간 연결·재연결 | 상태 |
| Q-4 | Boost 확정 방식(OI-13 두 방식) | 시퀀스 |

---

## F-1. 설치 → 첫 실행 → 로그인

```mermaid
flowchart TD
  A[크롬 웹 스토어 설치·업데이트] --> B[툴바 아이콘 클릭 → 사이드 패널 열림]
  B --> C{첫 실행?}
  C -- 예 --> S0[S0 첫 실행: 서하 인사 → 응원 팀 칩<br/>웹에서 고른 팀 있으면 이어받기 OI-19]
  C -- 아니오 --> F
  S0 --> L{로그인?}
  L -- 'RORR 계정으로 시작' --> E[auth.request → launchWebAuthFlow PKCE]
  L -- 나중에 --> D2[둘러보기: 대화·경기 보기만<br/>Boost·퀴즈는 로그인 유도]
  E -- 취소·실패 --> D2
  E -- 성공 --> F[토큰 SW 보관 · GET /v1/me · GET /v1/config]
  D2 --> G
  F --> G{config.min_ext_version 충족?}
  G -- 아니오 --> G1[업데이트 안내 · 기능 잠금]
  G -- 예 --> H{현재 탭이 지원 호스트 + 진행 경기?}
  H -- 아니오 --> I[S1 평시: 서하 컴패니언 채팅 + 오늘 일정]
  H -- LCK 외 리그 --> S5[S5 비지원 리그: '준비 중' · 알림 신청]
  H -- 예 --> J[S2 매칭 → F-2]
```

- 둘러보기에서 Boost를 누르면 시트 대신 로그인 안내(잔액 0 표시 금지)
- 미성년 계정(`users.is_minor`): 행운 박스·충전 진입 미노출, Energy Boost 불가(정책 §7)

## F-2. 중계 매칭 → 시청 상태 확인 (v46)

```mermaid
flowchart TD
  A[경기 진행 중 · 패널 열림] --> B{지원 사이트 탭?<br/>CS: host·url·title·재생 위치}
  B -- 없음 --> N[W-1 '탭 없음': 공식 채널 안내 띠 + 채널 목록]
  B -- 있음 --> C[SW: POST /v1/ext/match/resolve]
  C --> D{channel_status}
  D -- official --> E[match.resolved · offset = 채널 기본값 + 라이브 끝 뒤처짐]
  D -- unregistered --> O[W-1 '다른 방송': 안내 띠 + 공식 채널 버튼<br/>경기 연결은 유지, 기본 지연 사용]
  D -- none 경기 없음 --> F[S1 평시 유지]
  E --> G{라이브 끝에서 뒤처짐 ≥ WATCH_REPLAY_BEHIND_S?}
  G -- 예 --> R[W-1 '다시보기': 안내 띠 · 결과형 알림 끔 · Boost 허용]
  G -- 아니오 --> H[S3 경기 중 · 띠 없음]
  N -- 채널 선택 --> T[새 탭으로 공식 채널 열기] --> C
  O -- 공식 채널 --> N
  R -- 라이브로 --> L[라이브 끝으로 이동 안내] --> H
  H --> I{'화면이 늦어요/빨라요'}
  I -- 탭 --> J[개인 보정 ±2초 · 로컬 저장 · 익명 보고] --> H
```

- 판정 입력은 Content Script가 읽는 **호스트·URL·제목·재생 상태·라이브 끝까지 거리**뿐(`video.seekable.end − currentTime`). 영상 화면은 읽지 않음, 권한 추가 없음
- 초기 등록 범위: **공식 채널만**(`channels.kind=official`). 코스트리밍은 2단계에서 같은 구조로 등록 — 그전까지 코스트리밍은 '다른 방송'으로 판정
- 다시보기·다른 방송에서도 **Boost는 막지 않음**(안내만, 2026-10-17 결정)
- 표시 시점(docs/04 §4): **예고형**(`moment.upcoming`, `quiz.opened`)은 받는 즉시, **결과형**(`moment.resolved`, `match.state` 스코어·골드, `quiz.resolved`, 킬·오브젝트 대사)은 개인 지연 도달 후. 다시보기 상태에서는 결과형 알림 표시 안 함
- 중계 URL은 매칭 후 서버에서 폐기(docs/04 §6)

## W-1. 시청 상태 (v46)

```mermaid
stateDiagram-v2
  [*] --> 탭없음: 경기 중 + 지원 사이트 탭 없음
  [*] --> 공식채널: 등록 채널 + 라이브 근접
  [*] --> 다른방송: 지원 사이트 + 미등록 채널
  탭없음 --> 공식채널: 채널 목록에서 열기 · 사용자가 직접 이동
  다른방송 --> 공식채널: 공식 채널로 이동
  공식채널 --> 다시보기: 뒤처짐 ≥ 60초 또는 일시정지 60초
  다시보기 --> 공식채널: 라이브로 · 뒤처짐 < 60초
  공식채널 --> 다른방송: 탭 URL이 미등록 채널로 바뀜
  공식채널 --> 탭없음: 중계 탭 닫힘
```

| 상태 | 띠 문구(제목 / 보조 / 버튼) | 결과형 알림 | Boost |
|---|---|---|---|
| 공식 채널 | (띠 없음) | 개인 지연 후 표시 | 가능 |
| 탭 없음 | '지금 T1 vs GEN 경기 중이에요' / '공식 채널에서 보면 서하가 화면에 맞춰요' / '채널 보기' | 채널 기본 지연 후 표시 | 가능 |
| 다른 방송 | '이 방송은 경기와 맞춰지지 않아요' / '알림이 화면과 어긋날 수 있어요' / '공식 채널' | 채널 기본 지연 후 표시 | 가능 |
| 다시보기 | '라이브보다 N분 늦게 보고 있어요' / '스포일러가 없도록 결과 알림은 꺼 둘게요' / '라이브로' | **표시 안 함** | 가능(안내만) |

- 상태 전환은 3초 이상 유지될 때만 반영(탭 이동·버퍼링으로 띠가 깜박이지 않게)
- 사용자가 띠를 닫으면 그 경기 동안 같은 상태로는 다시 띄우지 않음(상태가 바뀌면 다시 표시)

## Q-5. 채널 기본 지연 측정·갱신 (v46)

```mermaid
sequenceDiagram
  autonumber
  participant OP as 운영자(초기) / 자동 측정(이후)
  participant BC as Broadcast Service
  participant RT as Realtime GW
  participant SW as 확장 SW
  participant U as 사용자
  OP->>BC: 경기 시작 직후 채널별 측정<br/>화면 게임 시계 vs 데이터 시계
  BC->>BC: broadcasts.default_offset_ms 갱신 (source=ops)
  BC--)RT: broadcast.offset {broadcast_id, offset_ms}
  RT-->>SW: 채널 기본값 갱신
  SW->>SW: 개인 지연 = 기본값 + 라이브 끝 뒤처짐 + 개인 보정
  U->>SW: '화면이 늦어요' (+2초)
  SW->>BC: POST /v1/ext/offset-reports {delta_ms, behind_edge_ms} (익명)
  BC->>BC: 1분마다 채널별 보고 중앙값(이상값 제외, 최소 표본 30)
  alt 중앙값이 기본값과 OFFSET_DRIFT_ALERT_MS 이상 차이
    BC->>BC: 기본값 갱신 (source=crowd) + 운영 경보
    BC--)RT: broadcast.offset
  end
```

## S-1. 패널 화면 상태 (이름은 docs/03-ux-flow §2와 동일)

```mermaid
stateDiagram-v2
  [*] --> S0_첫실행: 설치 직후
  S0_첫실행 --> S1_평시: 팀 선택 완료
  [*] --> S1_평시: 재실행
  S1_평시 --> S2_매칭: 지원 호스트 + 진행 경기
  S1_평시 --> S5_비지원리그: LCK 외 경기
  S2_매칭 --> S3_경기중: match.resolved
  S2_매칭 --> S1_평시: 매칭 실패·취소
  S3_경기중 --> S4_세트사이_경기후: game.ended / match.ended
  S4_세트사이_경기후 --> S3_경기중: game.started
  S4_세트사이_경기후 --> S1_평시: 탭 이동 · 30분 경과
  state S3_경기중 {
    [*] --> 기본
    기본 --> 내선수묻기: fav 미설정(첫 진입 1회)
    내선수묻기 --> 기본
    기본 --> 퀴즈: quiz.opened
    퀴즈 --> 기본: 마감·판정
    기본 --> 큰순간예고: moment.upcoming
    큰순간예고 --> Boost시트: Boost 탭
    Boost시트 --> 축하: 2차 탭 성공
    축하 --> 카드공개
    카드공개 --> 기본: 닫기
    큰순간예고 --> 기본: 카운트다운 0
  }
```

- 화면 매핑(02-screen-spec): S1·S2 = 경기 전 대화(§2), S3 = 경기 중(§1 골격, §3~§11), S4 = 경기 요약(§12)
- 경기 시작 전 대기(매칭됨·시작 전)는 S3 진입 전 S2 안의 하위 상태로 처리 — 대화 화면 유지 + 스코어 칩 '곧 시작'
- 퀴즈가 열린 상태에서 `moment.upcoming`이 오면 퀴즈를 먼저 마감(05 §6)

## Q-1. 큰 순간 예고 → Boost → 카드 공개

```mermaid
sequenceDiagram
  autonumber
  participant ME as Moment Engine
  participant RT as Realtime GW
  participant P as Side Panel
  participant U as 사용자
  participant API as API GW
  participant BS as Boost Service
  participant WL as Wallet Ledger
  participant CD as Card Service
  ME->>RT: moment.upcoming {moment_id, tier_hint, closes_at, players[], sponsor?}
  RT-->>P: SSE event (offset 적용 후 표시)
  P->>U: 큰 순간 알림 40초 · Boost 버튼 강조 · (후원 줄)
  U->>P: Boost 탭
  P->>API: GET /v1/me/wallet (캐시 30초 지났으면)
  P->>U: Boost 시트 (재화·금액·카드 주인공 줄)
  U->>P: 금액 버튼 1차 탭
  P->>U: armed 5초 '한 번 더 누르면 보내요'
  U->>P: 2차 탭
  P->>API: POST /v1/boosts (Idempotency-Key)
  API->>BS: accept
  BS->>WL: debit(유료 Energy 묶음 FIFO | Spark)
  WL-->>BS: ledger_id
  BS->>CD: upsert card (moment, user) + 누적·배지
  CD-->>BS: card{is_new, badges, level_up, star_player}
  BS-->>API: 201 boost + card + wallet
  API-->>P: 응답
  P->>U: 축하 0.9초(재Boost 0.7초) → 카드 공개
  BS--)RT: boost.settled (함께 Boost 수 집계용)
  RT-->>P: moment.stats {boosters_count}
  ME->>RT: moment.resolved {final_tier, top_performer}
  RT-->>P: 카드 등급 확정 갱신(필요 시)
```

- 등급 확정 시점: 예고 단계 `tier_hint`, 종료 시 `final_tier`. 카드 테두리는 `final_tier` 기준(목업은 예고 등급으로 바로 표시 — 구현 시 확정 전엔 '등급 확정 중' 표시 없이 hint 사용, 확정 값이 다르면 카드에서 조용히 갱신)
- 실패(4xx/5xx/시간 초과 8초): 시트 유지 · '보내지 못했어요. 차감되지 않았어요.' · 같은 키로 재시도 버튼

## S-2. 두 번 누르기

```mermaid
stateDiagram-v2
  [*] --> idle
  idle --> armed: 금액 탭 · 잔액 충분
  idle --> idle: 금액 탭 · 잔액 부족 → 부족 안내 줄
  armed --> sending: 같은 버튼 재탭 (5초 안)
  armed --> idle: 5초 경과
  armed --> idle: 금액·재화 변경
  armed --> idle: 시트 닫기 · 순간 마감
  sending --> success: 201
  sending --> failed: 오류·시간 초과
  failed --> idle: 안내 후
  success --> [*]
```

- armed 표시: 버튼 테두리 링 5초 감소(`--cfp`), 문구 '한 번 더 누르면 보내요', 스크린리더 알림 1회
- sending 중 버튼 비활성·회전 표시. 중복 탭 무시

## F-3. 재Boost 누적·배지 상승

```mermaid
flowchart TD
  A[이미 카드 받은 순간에 Boost] --> B[시트 상단: 'N단계 · 이 순간 누적 X · 다음 단계까지 Y']
  B --> C[금액 선택 → 두 번 누르기]
  C --> D[POST /v1/boosts]
  D --> E{level_up?}
  E -- 예 --> F[축하 0.7초 → 카드 앞면 배지 상승 연출 '배지 n단계로']
  E -- 그 재화 첫 사용 --> G[배지 추가 연출 '재화 n단계 배지 추가']
  E -- 아니오 --> H[토스트 '이 순간 누적에 더해졌어요' · 남은 양]
  F --> I[응원 포인트 추가 없음 · 카드 등급 불변]
  G --> I
  H --> I
```

## F-4. 카드 주인공 결정 [논의 중]

```mermaid
flowchart TD
  A[첫 Boost 확정] --> B{파트너 팀 순간?}
  B -- 아니오 --> R[RORR 모먼트 카드 · 선수 없음]
  B -- 예 --> C{user.fav 설정됨?}
  C -- 아니오/자동 --> T[주인공 = top_performer · '가장 크게 기여한 선수']
  C -- 예 --> D{fav ∈ moment.participants?}
  D -- 예 --> F[주인공 = fav · '내 선수 P의 순간']
  D -- 아니오 --> G[주인공 = top_performer · '이번엔 top의 순간 · fav는 이 교전에 없었어요']
  F --> Z[card.star_player 고정 저장]
  G --> Z
  T --> Z
```

- 판정은 Card Service. 시트에는 예상 주인공을 미리 표시(`GET /v1/moments/{id}`의 `star_preview`)

## F-5. 내 선수 묻기

```mermaid
flowchart TD
  A[S3 진입] --> B{prefs.fav_player 팀별 값}
  B -- undefined 아직 안 물음 --> C[대화 영역 카드: '이번 경기 누구를 응원해요?' 선수 5명 + '자동으로 둘게요']
  C -- 선수 선택 --> D[PUT /v1/me/preferences fav_player=id]
  C -- 자동 --> E[PUT fav_player=null]
  C -- 무시 --> F[다음 경기에 다시 묻지 않음? → 결정 필요 EXT-1]
  B -- 값 있음 --> G[묻지 않음 · 메뉴 '내 선수'에서 변경]
```

- EXT-1(미결): '한 번만 묻기(기본값)' vs '경기마다 묻기'. 목업은 한 번만 묻기

## Q-2. 스폰서 행운 박스 [논의 중]

```mermaid
sequenceDiagram
  autonumber
  participant P as Side Panel
  participant U as 사용자
  participant API as API GW
  participant SS as Sponsor Service
  participant WL as Wallet Ledger
  Note over P: moment.upcoming 에 sponsor{label, box_eligible} 포함 (조건 05 §7)
  P->>U: 큰 순간 알림 아래 후원 줄 'presented by 브랜드 · 행운 박스 열기'
  U->>P: 열기
  P->>U: 박스 모달 3개 선택 · 확률 표시
  U->>P: 박스 하나 선택
  P->>API: POST /v1/sponsor/boxes {moment_id} (Idempotency-Key)
  API->>SS: 자격·총량·홀드아웃 확인 → 서버 난수
  alt 당첨
    SS->>WL: credit Spark (source=sponsor_box)
    SS-->>P: {result: win, prize:{spark:5|10}, wallet}
    P->>U: 당첨 연출 · 'Spark로 Boost' CTA
  else 꽝
    SS-->>P: {result: miss}
    P->>U: '다음 기회에' · 'Boost 하러 가기'
  else 자격 없음·소진
    SS-->>P: 409 box_unavailable
    P->>U: 후원 줄만 유지, 박스 버튼 숨김
  end
```

- 클라이언트는 박스 선택 위치를 보내지 않음(결과와 무관)
- 같은 순간 재요청은 첫 결과 그대로(멱등 + 순간당 1회)

## F-6. 잔액 부족 → 충전 → 복귀

```mermaid
flowchart TD
  A[Energy 금액 탭] --> B{eBal ≥ amount?}
  B -- 예 --> C[S-2 armed]
  B -- 아니오 --> D[부족 안내 줄 'Energy가 부족해요 · 충전하기']
  D --> E[충전하기 → 새 탭 rorr.club/wallet/topup?return=ext&moment_id]
  E --> F[웹 결제 완료]
  F --> G[패널 visibilitychange 포커스 복귀]
  G --> H[GET /v1/me/wallet 재조회]
  H --> I{순간 아직 열림?}
  I -- 예 --> J[시트 다시 열기 · 선택 금액 유지 · topupBack]
  I -- 아니오 --> K[토스트 '충전됐어요 · 이 순간은 마감됐어요']
```

- 확장 안에서 결제하지 않음(웹 결제 화면으로 이동). Spark 부족 시 '광고 보고 Spark 받기'는 웹 광고 월로 이동

## Q-3. 퀴즈

```mermaid
sequenceDiagram
  participant QS as Quiz Service
  participant RT as Realtime GW
  participant P as Side Panel
  participant U as 사용자
  QS->>RT: quiz.opened {quiz_id, question, options[], closes_at(서버) }
  RT-->>P: 표시(offset 적용) · 12초 타이머
  U->>P: 보기 선택
  P->>QS: POST /v1/quiz/{quiz_id}/answers {option_id} (Idempotency-Key)
  QS-->>P: 202 accepted
  QS->>RT: quiz.resolved {correct_option, stats}
  RT-->>P: 정답 표시 · 내 결과 · 연속 정답
  P->>QS: GET /v1/quiz/ranking?scope=match|week (탭할 때)
```

- 마감 판정은 서버 시각 기준 + 호스트 지연 여유(`QUIZ_GRACE_MS`). 클라이언트 타이머는 표시용

## F-7. 경기 시작 알림 (패널 닫힘)

```mermaid
flowchart TD
  A[chrome.alarms 일정 동기화 1시간마다] --> B[GET /v1/schedule?teams=내 팀]
  B --> C[경기 시작 10분 전 알람]
  C --> D{알림 설정 켬?}
  D -- 예 --> E[chrome.notifications '곧 T1 경기가 시작돼요']
  E -- 클릭 --> F[중계 탭 열기 + 패널 열기]
  D -- 아니오 --> G[아이콘 배지만]
```

- 패널이 닫힌 상태의 큰 순간: 아이콘 배지 점만(알림 팝업 금지 — 빈도 정책)

## F-8. 비제휴 팀 경기

```mermaid
flowchart TD
  A[match.partner_side 확인] --> B{응원 팀이 파트너?}
  B -- 예 --> C[일반 흐름]
  B -- 아니오 --> D[팀 화면 '비제휴 팀' 표기]
  D --> E[Boost 가능 · 카드 = RORR 모먼트 카드 선수 없음]
  E --> F[수익 배분 문구 미표시 · 후원 박스 미노출]
```

## S-3. 실시간 연결

```mermaid
stateDiagram-v2
  [*] --> connecting
  connecting --> open: 200 + 첫 heartbeat
  open --> retrying: 끊김 · heartbeat 30초 없음
  retrying --> open: 재연결 성공 (Last-Event-ID로 누락분 재전송)
  retrying --> offline: 5회 실패 또는 navigator.onLine=false
  offline --> connecting: online 이벤트 · 패널 포커스
  open --> [*]: panel.closed
```

- `retrying` 3초 이상: 상단 얇은 띠 '연결 중…'. `offline`: Boost·퀴즈 버튼 비활성 + '연결이 끊겼어요'
- 재연결 후 놓친 순간이 이미 마감됐으면 표시하지 않음(경기 기록에만)

## Q-4. Boost 확정 방식 (OI-13 미결 — 두 방식 모두 지원)

```mermaid
sequenceDiagram
  participant P as Panel
  participant BS as Boost Service
  participant WL as Wallet
  participant ME as Moment Engine
  alt BOOST_SETTLE_MODE = immediate (목업 동작)
    P->>BS: POST /v1/boosts
    BS->>WL: 즉시 차감
    BS-->>P: 201 status=settled + card
  else BOOST_SETTLE_MODE = on_moment
    P->>BS: POST /v1/boosts
    BS->>WL: hold(가차감)
    BS-->>P: 202 status=pending (카드 미리보기)
    ME->>BS: moment.resolved | moment.cancelled
    alt resolved
      BS->>WL: capture
      BS--)P: SSE boost.settled + card
    else cancelled (순간 불발)
      BS->>WL: release
      BS--)P: SSE boost.voided '순간이 성립하지 않아 돌려드렸어요'
    end
  end
```

- 모드는 `GET /v1/config`의 `BOOST_SETTLE_MODE`. 클라이언트는 `status`로 분기(목업 화면은 `settled` 기준)
