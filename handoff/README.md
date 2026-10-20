# RORR 확장 프로그램 v2.0 — 개발 핸드오프 패키지

> **2026-10-17 통합 안내** — 이 패키지 중 **API·DB(09·10·13, `api/`, `schema/`)만** 웹·확장 공용 단일 기준 `rorr-hero/handoff/api/openapi.yaml`·`db/schema.sql`(be35b45)로 대체되었습니다(차이·채택 근거와 확장 쪽 변경 E-1~E-6: `rorr-hero/handoff/18-canonical-merge.md`). 화면 명세·컴포넌트·토큰·상태 로직·QA 등 나머지는 그대로 확장 구현 기준입니다. 결정 사항 목록은 `rorr-hero/handoff/09-open-items.md` §0(BE-1 '첫 경기 0' 결정).

- 작성일: 2026-10-17 · 기준 목업: **v53** (`mockup/index.html`) · 기준 태그: `handoff-ext-2026-10-17`(v45) → `-v46` → `handoff-ext-2026-10-19-v47` → `-v47b` → `-v47c` → `-v47d` → `-v48` → `-v49` → `-v50` → `-v51` → `-v52` → `-v53`
- 대상: 확장 프로그램 구현 개발(Jun·Kazel), QA, 디자인 리뷰
- 배포본(목업): https://yhc-pie.github.io/rorr-extension/mockup/ (push 후 반영)
- 상태: 화면·동작 **확정본**, 시스템·API·스키마는 **초안**(2026-10-17, 웹·백엔드 검토 전). 단, 표시된 '논의 중' 항목(행운 박스·브랜드 모먼트, 파트너 에디션, 응원 롤 전달)은 콘셉트 테스트·법률 검토 결과에 따라 바뀔 수 있음

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
| 9 | [screens/](screens/) | 주요 상태 캡처 41장(한국어, 380px 패널) | 전원 |
| 10 | [policy/boost-economy-policy-v1.3.md](policy/boost-economy-policy-v1.3.md) | 정책 사본(원본은 사업 담당 관리) | 전원 |

### 1-1. 시스템·구현 설계 (2026-10-17 추가)

| 순서 | 문서 | 내용 | 주 독자 |
|---|---|---|---|
| 11 | [07-system-architecture.md](07-system-architecture.md) | 전체 구성도(클라이언트·미들·백엔드·데이터), MV3 내부, SW↔패널 메시지, 서비스 13종 책임, 비기능 요구 | 전원 |
| 12 | [08-flowcharts.md](08-flowcharts.md) | 흐름도 17종(Mermaid) — 설치·매칭·시청 상태·지연 측정·화면 상태·Boost 시퀀스·두 번 누르기·재Boost·카드 주인공·행운 박스·충전 복귀·퀴즈·알림·재연결·확정 방식 | 개발·QA |
| 13 | [09-api-spec.md](09-api-spec.md) + [api/openapi.yaml](api/openapi.yaml) | REST 30개 경로·오류 코드·요청 제한·SSE 이벤트 18종·`/config` (OpenAPI 3.1 검증 통과) | 프론트·백엔드 |
| 14 | [10-data-schema.md](10-data-schema.md) + [schema/schema.sql](schema/schema.sql) | 관계도·테이블 43개 DDL(PostgreSQL 16 적용 확인)·규칙을 지키는 제약 | 백엔드 |
| 15 | [11-interaction-spec.md](11-interaction-spec.md) | 요소별 트리거·반응·시간/곡선·키보드·보조기술·측정, 문구 길이, 빈·로딩·오류 | 프론트·QA |
| 16 | [12-frontend-impl.md](12-frontend-impl.md) | 확장 저장소 구조·컴포넌트 트리·상태 저장소·핵심 의사 코드·성능 예산·테스트·보안 | 프론트 |
| 17 | [13-backend-middleware.md](13-backend-middleware.md) + [schema/boost_tx.sql](schema/boost_tx.sql) | 게이트웨이·실시간 팬아웃·Boost 트랜잭션(참조 구현, 테스트 9개 통과)·순간 엔진·배치·관측 | 백엔드 |
| 18 | [14-analytics-events.md](14-analytics-events.md) | 클라이언트·서버 측정 이벤트와 핵심 지표 | 데이터·기획 |
| 19 | [15-web-handoff-crosscheck.md](15-web-handoff-crosscheck.md) | 웹 핸드오프와 교차 점검 — 범위 비교, 불일치 X-1~X-6, 설정 이름 추가 제안, 미결 | 전원 |
| 20 | [16-watch-state-delay.md](16-watch-state-delay.md) | **v46** 시청 상태 안내(탭 없음·다른 방송·다시보기)·공식 채널 목록·방송 지연 3단계 관리 + 공용 API·DB 변경 요청 C-1~C-10 | 전원 |
| 21 | [17-viewing-growth.md](17-viewing-growth.md) | **2026-10-20** 시청 확장 — 비전·KPI(동반 시청 시간)·v2.0/v2.1 기능·3층 기준선·측정 이벤트·리포팅·정책 변경 | 전원 |

- 참조 구현 실행: 빈 PostgreSQL 16에 `schema.sql` → `boost_tx.sql` → `boost_tx_test.sql` 순서로 적용, 마지막에 `boost_tx: 9 scenarios passed` 출력

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
| 27 · 28 | 시청 상태 — 중계 탭 없음 안내 · 공식 채널 목록(v46) |
| 29 · 30 | 시청 상태 — 다른 방송 · 다시보기(v46) |
| 31 · 32 | 중계 맞춤 — 스코어 상세 · 메뉴(v46) |
| 33 · 34 | 큰 순간 상단 우선순위 — 시청 상태 칩 접힘 · 펼침(v47) |
| 36~41 | 팬 드래프트 초대 · 선택 중 · 완성 · 밴픽 리뷰 · 지켜볼 포인트 패널 · 경기 요약(v48) |
| 42~46 | 팬 드래프트 v49: 미리 채운 기본 · 후보 트레이 · 바꾼 칸·★ · 검색 · 밴픽 리뷰(★·희소 적중) |
| 47~49 | 팬 드래프트 v50: 드래프트 보드(1/2) · 후보 트레이 막대 · ★ 고르기(2/2) |
| 50 | 팬 드래프트 v52 문구 흐름(초대 · 후보 · 랜덤 채우기 · ★ 고르기) |
| 51~53 | 팬 드래프트 카드 · 경기 요약의 카드 줄 · 내 기록 › 팬 드래프트(v53) |

## 4. 목업 실행 방법

- `mockup/index.html`을 크롬에서 직접 열기(단일 파일, 외부 의존 없음)
- 하단 '시연 조작': 단계(경기 전·라이브·퀴즈·큰 순간·Boost·요약), 전체 흐름 재생, 화면 바로가기, 언어, 스폰서 미리보기(기본 켬)
- 키보드: 패널 포커스 상태에서 `1`/`2` 퀴즈 답, `B` Boost 창, `Esc` 닫기
- 쿼리: `?box=0|5|10` 행운 박스 결과 고정(시연·QA용)
- 시청 상태(v46): '시청 상태' 버튼으로 공식 채널 / 중계 탭 없음 / 다른 방송 / 다시보기 전환(왼쪽 브라우저 주소·탭 제목도 바뀜). 경기 중 단계에서 확인
- 목업의 샘플 데이터·데모 저장은 구현 대상 아님(01-handoff-rules §3)

---

## 웹과 함께 보기 (2026-10-17 추가)

- 웹(rorr-hero) 쪽 핸드오프 패키지: `20_RORR/02_디자인브랜드/rorr-hero/handoff/README.md`
- 웹·확장 공통 확인 문서: `07-web-vs-extension.md`(정합 과제 G-1~G-7), `02-tokens.md` §4(웹·확장 토큰 불일치 T-1~T-6), `09-open-items.md`(결정 대기)
- 이 패키지의 교차 점검 결과: [15-web-handoff-crosscheck.md](15-web-handoff-crosscheck.md)
