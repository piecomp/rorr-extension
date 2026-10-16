# 14. UX 카피 — Boost 시트 (2026-10-16)

- 대상: Boost 시트(익스텐션 380px 패널 하단 시트), 팀 보기 '지금 이 순간' 카드, 모먼트 카드 발급 연출
- 사용자 상태: 경기 중 큰 순간 직전, 남은 시간 40초 안쪽. 읽을 여유가 없고 한 번에 결정해야 함
- 원칙: 결정에 필요한 정보만 상시 노출, 정책 고지는 CTA 옆 1줄 + ⓘ 펼침(점진 공개)

## 1. 변경 전후

| 요소 | 변경 전 | 변경 후(EN / KO) |
|---|---|---|
| 상단 | GOLD MOMENT / Boost the Baron fight / Boosting together now: 2,418 (3줄) | Gold moment · 2,418 boosting / Boost T1's Baron fight (2줄)<br>골드 모먼트 · 2,418명 Boost 중 / T1 바론 교전에 Boost |
| 응원 팀 | Cheering for [T1] 별도 행 | 제목에 팀명 포함 → 행 삭제 |
| 결제 수단 | ⚡ Energy 10 / You have 120 | ⚡ 10 Energy / 120 left · 120 남음 |
| 응원 메시지 | 라벨 + 입력창 상시 | + Add a cheer message(누르면 입력창) · + 응원 메시지 추가 |
| 카드 안내 | 박스: A gold moment card comes with this Boost | CTA 아래 1줄: Gold moment card included · 골드 모먼트 카드 함께 발급 |
| 배분·환불 고지 | 박스 1줄 + ⓘ + 별도 문단 2문장 | 1줄: Non-refundable · 70% goes to T1 · 환불 불가 · 70%는 T1에 전달 + ⓘ(전문) |
| Spark 선택 시 | Energy 문구 그대로 노출(부정확) | Spark has no cash value · Spark는 현금 가치 없음 + ⓘ(광고 월 출처·Boost 전용) |
| CTA | Boost with 10 Energy | 유지(동사 + 금액 명시) |
| 하단 링크 | Top up on rorr.club / Get Spark on rorr.club | Top up Energy / Get Spark · Energy 충전 / Spark 받기 |

- 상시 노출 문구: 약 95단어 → 약 30단어. 텍스트 블록 11개 → 6개
- 정책 필수 고지(환불 불가·70:30 배분·카드 비판매)는 삭제 없이 ⓘ 전문으로 유지, 요지는 CTA 옆에 상시 노출

## 2. 연관 화면

| 화면 | 변경 전 | 변경 후 |
|---|---|---|
| 팀 보기 '지금' 카드 | Boosting together right now: 2,418. A moment card comes with the Boost. / Boost this moment | 2,418 boosting now · moment card included / Boost now |
| 카드 발급 | Win chance 58% → 83%, 2,419 fans boosted | 2줄 분리: Win chance 58% → 83% / 2,419 fans boosted with you |
| 중복 Boost 토스트 | Boost sent · same moment, no extra card | Boost sent. One card per moment. · Boost 완료. 카드는 순간당 1장이에요. |

## 3. 대안(검토용)

| 안 | 제목 카피 | 톤 | 적합 상황 |
|---|---|---|---|
| A(채택) | Boost T1's Baron fight | 명료 | 기본 |
| B | Back T1 in the Baron fight | 응원 강조 | 팬 감성 강조 캠페인 |
| C | Baron fight. Boost now? | 긴박 | 예고 카운트다운 10초 이내 |

## 4. 현지화 메모

- 'Boost', 'Energy', 'Spark'는 고유 명사로 번역하지 않음
- 한국어 수량 표기는 숫자에 '명'을 붙여 씀(2,418명). 영어 'left'는 '남음'
- 한국어 문자열이 영어보다 길어지는 구간(결제 수단 타일·CTA) 380px 기준 1줄 확인 완료
- 법무 확인 필요: 'Non-refundable' 1줄 요약이 전자상거래법상 청약철회 제한 고지로 충분한지(결제 화면은 웹, 익스텐션은 사용 화면이므로 요약 + 전문 링크 구조 제안)

## 부록. 비파트너 팀 응원 탭 — 잠김 기능 안내 (2026-10-16, 목업 v15)
- 문제: '열리면 알림 받기' 버튼이 단독으로 있어 '무엇이' '언제' 열리는지 알 수 없음
- 원칙: 무엇이 잠겼는지 → 왜(제휴 조건) → 무엇을 할 수 있는지(알림) 순서로 한 블록에 묶음

| 요소 | 변경 전 | 변경 후 |
|---|---|---|
| 블록 제목 | (없음) | GEN이 RORR와 제휴하면 열려요 |
| 잠김 항목 1 | Energy Boost · 이 팀은 사용 불가 | Energy Boost — Boost의 일부가 GEN에 전달돼요 |
| 잠김 항목 2 | 팀 배분 · 팬덤 순위 · 제휴 후 열림 | GEN 팬덤 순위 — 시즌 목표와 서포터 순위 |
| 버튼 | 열리면 알림 받기 | GEN 제휴 소식 알림 받기 |
| 완료 상태 | ✓ 열리면 알려드릴게요 | ✓ GEN이 제휴하면 알려드릴게요 |
| 보조 문구 | 팬덤 순위와 목표는 파트너 팀만 공개돼요. … | 제휴 여부와 시점은 약속드릴 수 없어요. GEN을 응원하며 쌓은 포인트는 내 기록으로 남아요. |

- 근거: 버튼 라벨에 대상(GEN)과 사건(제휴)을 명시해 단독으로 읽혀도 의미 전달, '시점 약속 불가' 문구로 과대 기대 방지(웹 동일 원칙)
- 대안: A '제휴 소식 받기'(짧음, 블록 제목과 함께 쓸 때) / B 'GEN이 합류하면 알려줘요'(친근, 서하 말투와 맞출 때)
- 현지화: 영문 'Tell me if GEN partners'는 'if'로 불확실성 유지('when' 사용 금지), 팀명은 변수 처리

## 부록. Boost 배분 비율 표기 (2026-10-16, 목업 v17)
- 문제: 상시 노출 문구 '환불 불가 · 70%는 T1에 전달'이 T1 조건을 표준처럼 보이게 함. 팀별 약정이 달라질 경우 비교·혼선 발생
- 원칙: 상시 노출은 팀과 무관한 공통 문구, 정확한 비율은 ⓘ 상세에서 '팀별 약정 값'으로 표기

| 위치 | 변경 전 | 변경 후 |
|---|---|---|
| 상시 문구 | 환불 불가 · 70%는 T1에 전달 | 환불 불가 · 일부는 T1에 전달 |
| ⓘ 상세 | 70%는 T1에, 30%는 RORR에 배분되며 RORR이 결제 수수료를 부담합니다. | 사용한 Energy의 일부는 T1과의 파트너 약정에 따라 T1에 배분됩니다(현재 70%). 배분 비율은 팀마다 다를 수 있으며, 결제 수수료는 RORR이 부담합니다. |

- RORR 몫(30%) 직접 표기 삭제 — 팀 몫만 표기하면 나머지는 자명, 팀별로 다를 때 'RORR이 더 가져간다' 비교 프레임 방지
- 대안: A '환불 불가 · T1 파트너 응원'(비율 언급 없음, 더 부드러움) / B '환불 불가 · 팀 배분 안내 ⓘ'(정보 위치만 안내)
- 확인 필요(법무): 팀에 '전달'된다고 표시하는 경우 비율을 결제·사용 전 어느 수준으로 고지해야 하는지(표시광고법·전자상거래법). 현재안은 ⓘ 한 번 탭으로 확인 가능
- 현지화: 영문 'Part goes to T1' / 'currently 70%' — 'currently'로 약정 변경 가능성 표시, 팀명·비율은 변수 처리
