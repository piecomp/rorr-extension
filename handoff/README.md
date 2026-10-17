# RORR 확장 프로그램 v2.0 — 개발 핸드오프 패키지

- 작성일: 2026-10-17 · 기준 목업: **v45** (`mockup/index.html`, 핸드오프 커밋) · 기준 태그: `handoff-ext-2026-10-17`
- 대상: 확장 프로그램 구현 개발(Jun·Kazel), QA, 디자인 리뷰
- 배포본(목업): https://yhc-pie.github.io/rorr-extension/mockup/ (push 후 반영)
- 상태: 화면·동작 **확정본**. 단, 표시된 '논의 중' 항목(행운 박스·브랜드 모먼트, 파트너 에디션, 응원 롤 전달)은 콘셉트 테스트·법률 검토 결과에 따라 바뀔 수 있음

---

## 1. 읽는 순서

| 순서 | 문서 | 내용 | 주 독자 |
|---|---|---|---|
| 1 | [01-handoff-rules.md](01-handoff-rules.md) | 핸드오프 원칙 — 기준 우선순위, 확정/논의 중 구분, 옮기지 않을 것, 금지 문구, 변경 관리, 완료 기준 | 전원 |
| 2 | [02-screen-spec.md](02-screen-spec.md) | 화면별 명세 — 레이아웃·상태·상호작용·예외·모션·접근성 | 개발·QA |
| 3 | [05-state-logic.md](05-state-logic.md) | 규칙·상태 모델 — 금액 단계, 배지 누적, 카드 주인공, 두 번 누르기, 행운 박스, 큰 순간 알림, 타이밍 상수 | 개발 |
| 4 | [04-components.md](04-components.md) | 컴포넌트 목록 — 변형·속성·상태 | 개발 |
| 5 | [03-design-tokens.md](03-design-tokens.md) + [css/tokens.css](css/tokens.css) | 토큰 표·사용처·신규 토큰 후보 | 개발·디자인 |
| 6 | [css/components.css](css/components.css) | 목업 CSS를 컴포넌트별로 묶은 참조본(키프레임 포함) | 개발 |
| 7 | [i18n-ko.json](i18n-ko.json) | 한국어 문구 원본(정확 일치 536개 + 패턴 59개) | 개발·카피 |
| 8 | [06-qa-checklist.md](06-qa-checklist.md) | 수용 기준·테스트 시나리오·회귀 항목 | QA |
| 9 | [screens/](screens/) | 주요 상태 캡처 27장(한국어, 380px 패널) | 전원 |
| 10 | [policy/boost-economy-policy-v1.3.md](policy/boost-economy-policy-v1.3.md) | 정책 사본(원본은 사업 담당 관리) | 전원 |

## 2. 기존 기획 문서와의 관계

- `docs/01~15`는 **왜·무엇**(기획·결정·정책 매핑), 이 패키지는 **어떻게 보이고 움직이는가**(구현 기준)
- 충돌 시 우선순위: 정책 v1.3 → `docs/07-decision-log.md`·`docs/13-design-review.md`(최신 결정) → **이 패키지** → `docs/02-feature-spec.md`(일부 문구는 v45 이전 기준, 차이는 02-screen-spec §0에 정리)
- 결정 경위는 `docs/13-design-review.md` §8~24, 웹과의 의도된 차이는 `docs/15-web-ext-gap.md`

## 3. 화면 캡처 목록

| 파일 | 상태 |
|---|---|
| 01-prematch-chat | 경기 전 대화(서하) |
| 02-live-fav-ask · 03-live-after-pick | 경기 시작 — '오늘 누구 응원해?' 묻기 · 고른 뒤 서하 답 |
| 04-quiz | 이벤트 퀴즈(다음 드래곤?) |
| 05-big-moment-heads-sponsor | 큰 순간 알림 + 후원 1줄 + 행운 박스 버튼 |
| 06 · 07 · 26 | Boost 창(Spark 기본 · Energy + ⓘ 펼침 · 영어) |
| 08 · 09 | 두 번 누르기 대기(5초 타이머) · 축하 연출 |
| 10 · 11 | 새 카드 공개 앞면 · 뒷면 |
| 12 · 13 · 14 | 재Boost 창 · 배지 상승 · 단계 불변('N 남음') |
| 15 · 16 · 17 | 오늘의 모먼트 패널 · 경기 요약 · 메뉴 |
| 18 · 19a · 19b | 행운 박스 고르기 · 꽝 · 당첨 |
| 20 · 21 | 팀 페이지 T1(파트너) · GEN 응원 탭(비제휴) |
| 22 · 23 · 24 | 서포터 순위 T1 · GEN(Spark 비공식) · 퀴즈 순위 |
| 25 | 선수 페이지 응원 탭 — 기념할 순간(기념 에디션) |

## 4. 목업 실행 방법

- `mockup/index.html`을 크롬에서 직접 열기(단일 파일, 외부 의존 없음)
- 하단 '시연 조작': 단계(경기 전·라이브·퀴즈·큰 순간·Boost·요약), 전체 흐름 재생, 화면 바로가기, 언어, 스폰서 미리보기(기본 켬)
- 키보드: 패널 포커스 상태에서 `1`/`2` 퀴즈 답, `B` Boost 창, `Esc` 닫기
- 쿼리: `?box=0|5|10` 행운 박스 결과 고정(시연·QA용)
- 목업의 샘플 데이터·데모 저장은 구현 대상 아님(01-handoff-rules §3)
