# RunLog - Handoff

## 현재 상태

- **버전**: v1.8.3+28 — 5단계 Repository 책임 분할 (SRP Store 아키텍처 & Facade 정비) 완료 (테스트 156종 확보) (2026-09-05)
- **저장소 계층 모듈화 & SRP 구조**:
  - `lib/repositories/stores/`:
    - `run_store.dart`: `RunStore` / `HiveRunStore` (러닝 기록 CRUD, VO2max 시계열, 동기화 제외 ID, 동기화 시각 영속화 전담)
    - `achievement_store.dart`: `AchievementStore` / `HiveAchievementStore` (획득 업적/배지 영속화 전담)
    - `settings_store.dart`: `SettingsStore` / `HiveSettingsStore` (Gemini API 키, 세션별 AI 요약 캐시, 목표 추천 캐시 및 캐시 클리어 전담)
  - `lib/repositories/run_repository.dart`: `RunStore`, `AchievementStore`, `SettingsStore`를 주입받아 조율하는 슬림화된 Facade 및 100% 하위 호환성 제공
  - `lib/data/run_repository.dart`: 기존 import 경로와의 100% 하위 호환 re-export
- **서비스 계층 모듈화 & 최적화**:
  - `lib/services/health/`:
    - `health_data_matcher.dart`: Bulk 쿼리 데이터 인메모리 매칭, 스플릿 산출(`computeSplits`), 다운샘플링(`downsampleHr`), 세션 조립(`buildRunSession`)
    - `native_health_channel.dart`: 네이티브 MethodChannel(`runlog/hc_extra`) 래퍼 및 DTO (`NativeSessionDetail`, `NativeRawSegment`, `NativeRawLap`)
    - `health_service.dart`: 세션별 Sequential 쿼리 제거 → $N \times 4\sim 6$회 호출을 기간 단위 Bulk 쿼리로 단축 (IPC 병목 제거)
  - `lib/services/gemini/`:
    - `gemini_dto.dart`: Typed DTO (`GeminiGenerateRequestDto`, `GeminiGenerateResponseDto`, `GeminiCandidateDto`, `GeminiContentDto`, `GeminiPartDto`)
    - `gemini_prompt_builder.dart`: `buildRunSummaryPrompt`, `buildGoalRecommendationPrompt`, `averagePaceSecPerKm`
    - `gemini_http_client.dart`: `GeminiHttpEngine` (60초 타임아웃, 429/500/502/503/504 지수 백오프, 예외 변환)
    - `gemini_service.dart`: 고수준 서비스 오케스트레이션 및 100% 하위 호환성 유지
- **UI 화면 모듈화 구조 (Single Responsibility Principle)**:
  - `lib/ui/analysis_screen.dart` (182줄): `lib/ui/analysis/widgets/` 아래 7개 서브 위젯 조합 및 상태 라우팅
    - `goal_recommend_card.dart`, `monthly_summary_card.dart`, `monthly_runs_chart_card.dart`, `weekly_volume_chart_card.dart`, `pace_trend_chart_card.dart`, `vo2max_trend_chart_card.dart`, `pb_records_card.dart`
  - `lib/ui/run_detail_screen.dart` (116줄): `lib/ui/run_detail/widgets/` 아래 7개 서브 위젯 조합 및 액션 처리
    - `run_detail_hero_header.dart`, `run_detail_metrics_grid.dart`, `run_detail_ai_summary_card.dart`, `run_detail_running_dynamics_card.dart`, `run_detail_hr_chart_card.dart`, `run_detail_laps_table_card.dart`, `run_detail_delete_dialog.dart`
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
- **빌드/테스트 상태**: `flutter test` 156/156 PASS, `flutter analyze` 0 issues (No issues found)

## 최근 작업 이력

| 버전 | 내용 |
|---|---|
| `v1.8.3` (저장소 분할) | 5단계 Repository 책임 분할: RunRepository 과중 책임 분리, `lib/repositories/stores/` (`run_store.dart`, `achievement_store.dart`, `settings_store.dart`) 모듈화, `RunRepository` Facade 경량화 및 100% 하위 호환성 유지, 단위 테스트 14종 추가 (총 156개 테스트 통과) |
| `v1.8.3` (서비스 최적화) | 4단계 서비스 및 저장소 최적화: Health Connect 세션별 반복 Sequential 쿼리 제거 및 기간 단위 Bulk 쿼리(readRecords) + In-memory 매칭 전환, Health Connect Sub-service/Helper 분리 (`lib/services/health/`), Gemini Typed DTO (`gemini_dto.dart`), Prompt Builder (`gemini_prompt_builder.dart`), HTTP Engine (`gemini_http_client.dart`) 분리 및 단위 테스트 15종 추가 (총 142개 테스트 통과) |
| `v1.8.3` (UI 모듈화) | 3단계 대형 UI 화면 분할 및 모듈화: analysis_screen.dart (182줄) 및 run_detail_screen.dart (116줄) 300줄 미만 경량화, sub-widgets 디렉터리 분리, modular_widgets_test 추가 (총 127개 테스트 통과) |
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
