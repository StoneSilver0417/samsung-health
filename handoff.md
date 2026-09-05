# RunLog - Handoff

## 현재 상태

- **버전**: v1.8.3+28 — 2단계 디자인 토큰 체계화 및 ThemeExtension 도입 완료 (테스트 112종 확보) (2026-09-05)
- **디자인 시스템**:
  - `DESIGN.md`: 다크 네온 디자인 원칙, 토큰 사양 (Color, Spacing 4/8/12/16/20/24/32, Radius, Typography, Icon Sizes) 명문화
  - `lib/core/theme/`: `AppDesignTokens` (`ThemeExtension`), `AppTheme`, `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIconSizes`
  - 표면 깊이(Surface Depth) 계층화: `bg` (`#0E1116`) vs `surface`/`card` (`#161B22`) vs `cardElevated` (`#1C222C`) vs `cardSubtle` (`#11141A`)
  - 접근성(a11y): WCAG AA 4.5:1+ 대비비 충족, `WeeklyRing`, `RunCard`, `LevelCard`, `CalendarHeatmap`, `LineChart`, `BarChart` `Semantics` 라벨링
- **러닝 분석 지표**:
  - **평균 보폭 (Stride)**: `distanceM / steps * 100` (cm 단위, 45cm~200cm 정상 생체역학 범위 검증)
  - **심박수 드리프트 (Cardiac Drift)**: 전반 50% vs 후반 50% 심박 비교
  - **유산소 vs 무산소 비율**: Z1~Z3 (유산소) vs Z4~Z5 (무산소)
  - **훈련 부하(TRIMP) & 권장 회복 시간**: 심박존 가중치 기반 트레이닝 로드 및 회복 시간(h) 산출
  - **워치 랩 (Laps)**: 워치 Auto-Lap / 수동 랩 실제 기록 시에만 노출
- **업적 배지 체계**: 총 33종
- **빌드/테스트 상태**: `flutter test` 112/112 PASS, `flutter analyze` 0 issues (No issues found)

## 최근 작업 이력

| 버전 | 내용 |
|---|---|
| `v1.8.3` (디자인 토큰) | 2단계 디자인 토큰 체계화: DESIGN.md 규칙 수립, ThemeExtension 기반 AppDesignTokens 및 AppTheme 도입, 전 UI 컴포넌트 토큰화, 표면 깊이 다변화, a11y Semantics 및 4.5:1+ 대비비 강화, design_tokens_test 추가 (총 112개 테스트 통과) |
| `v1.8.3` (안전망) | 1단계 안전망 구축: RunsNotifier 단위/회귀 테스트, GeminiService HTTP 재시도/지수백오프 테스트, UI AsyncValue 상태 렌더링 회귀 테스트 추가 (총 97개 테스트 통과) |
| `v1.8.3` | Health Connect StepsRecord 네이티브 직독 및 3중 폴백 연동으로 걸음 누락 해결 |
| `v1.8.2` | Health Connect STEPS/칼로리 sourceId 매칭 수정, 보폭/케이던스 이상치 필터링 |
| `v1.8.1` | 가짜 1km 스플릿 제거, 러닝 역학 & 심폐 효율 카드(보폭, 심박 드리프트, 유산소 비율, 훈련부하/회복시간) 신설, 실제 워치 랩 연동 |
| `v1.8.0` | 신규 업적 8종 추가, `kBadges` 33종 등록, `AchievementEngine` 평가 구현, `tools/badges.html` SVG 추가 |
| `v1.7.2` | 분석 탭 '다음 목표' AI 구조화 (목표 수치, 추천 세션 구성, 코칭 포인트) |
| `v1.7.1` | Gemini API 타임아웃 20초 → 60초 확대 및 예외 복구 로직 강화 |
| `v1.7.0` | 러닝 상세 'AI 러닝 요약' 3섹션 구조화 및 스플릿/심박존/케이던스 데이터 확장 |
| `v1.6.9` | 보안 패치 (Hive AES-256 암호화, Secure Storage, MutationQueue, Release KeyStore) |

## 남은 과제 및 Phase 2 로드맵

1. [ ] 폰에서 `v1.8.0` 설치 후 업적 탭(33종 배지) 및 AI 요약/목표 확인
2. [ ] 23일 러닝 프로그램 트래커 (PRD 4.5)
3. [ ] 러닝 기록 인스타 공유 카드 생성 (PRD 4.4)
4. [ ] 사용자 주간/월간 목표 설정 UI (PRD 4.6)
5. [ ] 데이터 백업/내보내기 (JSON/CSV)
