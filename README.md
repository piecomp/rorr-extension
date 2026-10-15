# rorr-extension — RORR 크롬 확장 프로그램 v2.0 기획

- 작성일: 2026-10-15 · 작성: Charles(CBO) · 상태: **기획 초안 v0.1**
- 범위: 크롬 웹스토어 게시 중인 RORR 확장(v1.1.2)을 **Muse 컴패니언 + 순간 Boost** 중심으로 재기획하는 v2.0
- 이 저장소는 **기획 문서 전용**. 구현 코드는 별도 저장소에서 관리(개발 착수 시 결정, `docs/08` OI-15)

---

## 1. 한 줄 정의

- **팬 언어**: Muse는 크롬에서 경기 옆에 앉아 있어요. 큰 순간이 오기 전에 먼저 말을 걸고, 그 순간을 같이 응원해요
- **내부 언어**: 중계 탭(YouTube·치지직·SOOP·Twitch)을 건드리지 않고 크롬 사이드 패널에 상주하는 **실시간 경기 동기화 컴패니언**. 웹(rorr.club)과 같은 계정·재화·카드를 쓰고, 차이는 **시청 경험**뿐

## 2. 문서 지도

| 번호 | 문서 | 내용 | 주 독자 |
|---|---|---|---|
| 00 | [현황 진단](docs/00-baseline.md) | 스토어 v1.1.2·컴패니언 프로토타입 v0.1·웹 현행과의 갭 | 전원 |
| 01 | [PRD](docs/01-prd.md) | 문제·목표·타깃·원칙·범위·성공 지표 | 전원 |
| 02 | [기능 명세](docs/02-feature-spec.md) | 기능 단위 요구사항·수용 기준·우선순위 | Jun·Kazel |
| 03 | [화면·흐름](docs/03-ux-flow.md) | 패널 구조, 상태 전이, 핵심 플로우 | Jun·디자인 |
| 04 | [아키텍처](docs/04-architecture.md) | MV3 구성, 권한, 데이터·API 의존, 원가 | Kazel |
| 05 | [정책·준수](docs/05-policy-compliance.md) | Boost 정책·웹스토어·Riot·중계 플랫폼 준수 매핑 | Charles·Mansoo |
| 06 | [로드맵](docs/06-roadmap.md) | 마일스톤·게이트·담당(안) | 전원 |
| 07 | [결정 로그](docs/07-decision-log.md) | 확정 사항과 출처 | 전원 |
| 08 | [오픈 이슈](docs/08-open-issues.md) | 미결 쟁점·담당·기한 | 전원 |

## 3. 기준 문서 (충돌 시 우선순위)

1. **정책**: `~/Documents/Hermes_Brain_01/RORR/policy/boost-economy-policy.md` (v1.2, 2026-10-15) — 화면·문구·데이터 모델이 충돌하면 **정책 우선**
2. **웹 현행**: `20_RORR/02_디자인브랜드/rorr-hero` (블로그 "Meet Muse" 2026-10-15 = 확장 설치 명분의 공식 문안)
3. **디자인 시스템**: RORR Design System (2026-06, Pretendard·Primary #6F4CFF, Companion 토큰군)
4. **Muse 말투**: `20_RORR/00_노트/마케팅/2026-07-30-Muse-말투가이드-팀모드-응원.md`
5. **컴패니언 설계**: `20_RORR/01_제품/riot-esports-ontology/ai-companion/companion-design-2026-05-06.md`
6. **라이브 푸시**: `20_RORR/01_제품/riot-esports-ontology/2026-07-12-live-push-trigger-catalog.md`

- 이 저장소는 위 문서를 **복제하지 않고 참조**한다. 규칙 본문이 필요하면 링크하고, 확장에 적용되는 해석만 기술

## 4. 운영 규칙

- 서식: 개조식, 공식 톤, 날짜 `YYYY-MM-DD`
- 표기: 확정 = **[확정]** (출처·날짜 병기) / 제안 = **[제안]** / 가설 = **[H]** / 확인된 사실 = **[F]**
- 변경: 문서 수정은 커밋 단위로, 의사결정은 `docs/07`에 1줄 추가 후 본문 반영
- 금지어(팬 대면 문구): AI가 알아서 / 최적화 / 인사이트(팬 카피) / 솔루션 / 혁신 / 최첨단 — `landing-brand-voice` 기준
- 지표명: **LwRC+** (정책 v1.2 기준). IR 문서의 wGE+와의 정합은 `docs/08` OI-05

## 5. 저장소

- 로컬: `~/Documents/20_RORR/01_제품/rorr-extension`
- 원격(예정): `github.com/yhc-pie/rorr-extension` (private) — 생성·푸시 절차는 아래

```bash
# GitHub 웹에서 yhc-pie/rorr-extension 을 Private, 빈 저장소(README 없이)로 생성한 뒤
cd ~/Documents/20_RORR/01_제품/rorr-extension
git remote add origin git@github.com:yhc-pie/rorr-extension.git
git push -u origin main
```
