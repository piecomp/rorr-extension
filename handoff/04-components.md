# 04. 컴포넌트 목록

- 작성일: 2026-10-17 · CSS 참조: `css/components.css`(목업 클래스명 그대로) · 토큰: `css/tokens.css`
- 이름은 구현 권장 이름(PascalCase) / 목업 클래스

---

## 1. 골격·HUD

| 컴포넌트 | 목업 클래스 | 변형·상태 | 속성(Props) | 비고 |
|---|---|---|---|---|
| PanelTopBar | `.top` `.pclose` | 라이브(LIVE 점) / 경기 전 | `title`, `live:boolean` | 닫기 왼쪽, 메뉴 오른쪽 |
| ScorePill | `#scorePill` `.sp-row` `.sp-side` `.goldbar.mini` | 기본 / 팀 상세 열림(`aria-expanded`) | `home`, `away`, `kills`, `clock`, `goldDiff` | 44px 고정, 팀 탭 → ScoreDetail |
| ScoreDetail | `.scoredetail` `.sd-row` | 파트너 팀 / 비제휴 팀 | `team`, `role`, `gold` | 팀 페이지 링크 |
| StreakChip | `.streakchip` | — | `count` | 퀴즈 순위로 이동 |
| Coachmark | `.coach` | 1회 | `title`, `body` | 확인 후 저장 |
| SpeechBubble | `.bubble` | 기본 / 사라짐(7s) / 숨김(카드 오버레이 중) | `text`, `mood` | `aria-live="polite"` |
| Dock | `.dock` `#moBar` `#askIn` `#boostOpen` | Boost 기본 / hot(큰 순간, 골드 테두리 + 남은 시간) | `cardCount`, `hot`, `countdown` | 입력 포커스 시 확장 |
| Toast | `.toast` | 정보 / 오류 | `text` | `role="status"`, 2.6s |

## 2. 순간·후원

| 컴포넌트 | 목업 클래스 | 변형·상태 | 속성 | 비고 |
|---|---|---|---|---|
| HeadsUp | `.heads` | 표시 / 숨김 | `label`, `countdown` | 골드 칩 |
| SponsorRow [논의 중] | `.heads-sp` `.hsp-open` `.hsp-res` | 열기 전 / 당첨 / 꽝 / 숨김(`.sp-busy`) | `sponsor{name,mark}`, `boxState` | 1줄, 버튼 36px + 터치 44 |
| SponsorLock | `.sp-lock` `.sp-ad` `.sp-by` `.sp-mk` | 오버레이(흰 글자) / 면 위(회색 'presented by') / 축약(presented by 생략) | `name`, `variant` | 공통 부품 1개로 통일(v43) |
| SponsorCutIn | `.sp-tag` | 0.9s | — | 카드 뒤 z(`--z-sptag`) |
| LuckyBoxModal [논의 중] | `#spxWrap` `.spx-*` | 섞기 / 고르기 / 여는 중 / 당첨 / 꽝 | `odds`, `result`, `onCta` | 확률 상시 표시, 결과는 서버 |
| FavAsk [논의 중] | `.favask` `.fa-h` `.bh-pick` `.bh-p` | 표시 / 닫힘 | `roster[]`, `onPick` | 경기 시작 1회 |
| QuizCard | `.quiz` `.ans` `.qresult` | 대기 / 열림 / 잠김 / 정답 / 오답 | `question`, `options`, `secondsLeft`, `streak` | 키 1·2 |
| MomentsPopover | `#moPanel` `.cstrip` | 카드 있음 / 빈 상태 | `moments[]` | |

## 3. Boost

| 컴포넌트 | 목업 클래스 | 변형·상태 | 속성 | 비고 |
|---|---|---|---|---|
| BoostSheet | `.bsheet` `.bs-head` | 첫 Boost / 재Boost / 비제휴(Spark만) | `moment`, `fans`, `currency`, `amount` | 365px 목표 |
| CardStarLine | `.bs-hero` `.bh-line` `.bh-i` `.bh-help` | 내 선수 / 자동 / 발급 후 고정 | `fav`, `starPlayer`, `issued` | ⓘ 펼침 |
| CurrencyToggle | `.cur.cseg` | Energy / Spark 선택, 비활성(비제휴 Energy) | `balances`, `value` | `role="radiogroup"` |
| AmountStepper | `.stepper` `.stp` | − / + 비활성(끝·잔액) | `steps[]`, `value`, `balance` | 48px 원형 |
| BoostButton | `.boostbtn` (`.sp` Spark, `.big` Energy 100+) `.cf` `.cf-ring` | 기본 / 대기(5초 링) / 보내는 중 / 비활성 | `currency`, `amount`, `state` | 52px, 두 번 누르기 |
| AmountNote | `.amt-note` `#amtNote` `.bs-gift` `#amtTop` | 첫 Boost / 재Boost / 잔액 부족 링크 / 대기 안내(강조) | `note`, `gift`, `lowBalance` | 1줄, 넘치면 줄바꿈 가운데 |
| ChargeLine | `.bs-legal` `#shareInfo` `.fine` | Energy / Spark, ⓘ 펼침 | `currency` | ⓘ 시각 32 · 터치 44 |
| CheerMessage | `.addmsg` `.field` | 접힘 / 입력 | `maxLength=80` | 금칙어 서버 검증 |

## 4. 카드

| 컴포넌트 | 목업 클래스 | 변형·상태 | 속성 | 비고 |
|---|---|---|---|---|
| MomentCard | `.mc` (`.silver` `.gold` `.holo`, `.mini` `.tiny` `.full`) `.dc` `.dcs` | 앞 / 뒤(뒤집기), 크기 3종, 빈 카드(퀴즈만) | `tier`, `badges{energy,spark}`, `edition`, `player`, `moment`, `winSwing`, `fans`, `serial`, `owner` | 브랜드 금지 |
| CardReveal | `.cardview` `.cv-new` `.cv-star` `.cv-sp` `.cv-share` `.cv-acts` | 새 카드 / 배지 상승(`.up`) / 남은 양 | `card`, `mode`, `starText`, `sponsor`, `shareLine` | 블러 덮개 |
| Celebration | `.burst` `.fchip` `.flashring` `.live-bg.cheer` | 첫 Boost / 재Boost / 단계 상승 / 기념 | `tier`, `currency`, `chips[]` | 금액 무관 |
| BadgeChip | `.dc.energy` `.dc.spark` `.lvup` | 단계 1~3, 상승 강조 | `currency`, `level` | |

## 5. 접근 가능한 이름 (목업 기준, i18n 키로 이관)

| 요소 | 영어 | 한국어 |
|---|---|---|
| 패널 닫기 | Close panel | 패널 닫기 |
| 메뉴 | Menu | 메뉴 |
| Boost 버튼(독) | Boost this moment | 이 순간 Boost |
| 오늘의 모먼트 | Moments so far | 지금까지의 모먼트 |
| 재화 선택 | Pay with | 결제 수단 |
| 금액 −/+ | Less / More | 줄이기 / 늘리기 |
| 두 번 누르기 대기 | Tap again within 5 seconds to send {currency} {n} | 5초 안에 한 번 더 누르면 {재화} {n}을/를 보내요 |
| 카드 주인공 ⓘ | How the card star is chosen | 카드 주인공 정하는 방법 |
| 차감 ⓘ | Details | 자세히 |
| 후원 줄 | Sponsor | 후원 |
| 행운 박스 열기 | Play the NOVA Gear lucky box | NOVA Gear 행운 박스 열기 |
| 행운 박스 상자 | Box 1~3 | 1~3번 박스 |
| 내 선수 묶음 | My player | 내 선수 |
| 카드 뒤집기 | Flip card | 카드 뒤집기 |
| 스코어 | Score / T1 details / GEN details | 점수 / T1 상세 / GEN 상세 |

## 6. 포커스 순서 (Boost 창)

1. 닫기 → 2. 카드 주인공 ⓘ → 3. 재화 선택 → 4. 응원 메시지 추가 → 5. − → 6. Boost → 7. + → 8. (잔액 부족 링크) → 9. 차감 ⓘ
- 창이 열리면 포커스는 Boost 버튼(목업 동작). 창 밖 포커스 이동 차단(모달), `Esc`로 닫고 독 Boost 버튼으로 복귀
- 행운 박스 모달: 열리면 첫 박스 → 결과 후 주 버튼. 닫으면 '행운 박스 열기' 자리로 복귀
