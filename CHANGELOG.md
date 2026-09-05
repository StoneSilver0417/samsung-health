# Changelog

## 2026-09-05 (5단계 Repository 책임 분할 & 세분화된 Store 아키텍처 도입)

### Repository 책임 분할 (Single Responsibility Principle) & Store 모듈화
- **`RunStore` 신설 (`lib/repositories/stores/run_store.dart`)**:
  - 러닝 기록 CRUD(`getAll`, `getById`, `upsertAll`, `delete`), VO2max 시계열(`getVo2Series`, `saveVo2Series`), 동기화 제외 ID(`getIgnoredIds`, `addIgnoredIds`, `removeIgnoredIds`), 동기화 시각(`lastSyncedAt`, `setLastSyncedAt`) 영속화 전담
- **`AchievementStore` 신설 (`lib/repositories/stores/achievement_store.dart`)**:
  - 획득 업적 및 배지(`getEarnedBadges`, `saveEarnedBadges`, `clear`) 영속화 전담
- **`SettingsStore` 신설 (`lib/repositories/stores/settings_store.dart`)**:
  - Android Keystore 기반 Gemini API 키(`getGeminiApiKey`, `setGeminiApiKey`), 세션별 AI 요약 캐시(`getAiSummary`, `saveAiSummary`), AI 목표 추천 캐시(`getGoalRecommendation`, `saveGoalRecommendation`, `getGoalRecommendedAt`), 캐시 정리(`clearCache`) 전담
- **`RunRepository` 파사드(Facade) 슬림화 & 100% 하위 호환성 보장 (`lib/repositories/run_repository.dart` & `lib/data/run_repository.dart`)**:
  - `RunRepository` 인터페이스를 통해 기존의 모든 메서드 시그니처 100% 유지 및 위임
  - `HiveRunRepository`가 `RunStore`, `AchievementStore`, `SettingsStore`를 주입받아 조율(Coordination)하고 `clear()` 호출 시 원자적 복합 클리어 수행
  - `lib/data/run_repository.dart`에서 `repositories/run_repository.dart`를 re-export하여 기존 import 경로와의 완벽한 하위 호환 제공

### 테스트 및 품질 안정화
- **신규 단위 테스트 추가 (`test/repository_stores_test.dart`)**:
  - `RunStore` CRUD/정렬/제외ID/VO2max/초기화 단위 테스트 6종
  - `AchievementStore` 배지 저장/조회/초기화 단위 테스트 1종
  - `SettingsStore` API 키/AI 요약/목표 추천/캐시 클리어 단위 테스트 4종
  - `RunRepository` Facade 조율 및 위임/복합 클리어/Store 게터 단위 테스트 2종
  - `test/run_repository_test.dart` Base64 포맷 예외 검증 테스트 추가 (총 14종 신규/강화 테스트)
- **전체 테스트 156종 100% 통과 (`flutter test` 156/156 PASS, `flutter analyze` 0 issues)**

## 2026-09-05 (4단계 서비스 및 저장소 최적화 — Health Connect 벌크 쿼리 & Gemini 파이프라인 정비)

### Health Connect 서비스 쿼리 성능 최적화 및 헬퍼 분리 (`lib/services/health/`)
- **세션별 반복 Sequential 쿼리 제거 및 기간 단위 Bulk 쿼리(readRecords) 전환**:
  - `fetchRuns()` 시 기존 러닝 세션 N개마다 각각 심박/거리/칼로리/걸음 수를 동기적으로 질의하던 $N \times 4\sim 6$회 Sequential IPC 호출을 단일 병렬 Bulk 쿼리(`Future.wait`)로 전면 개편
  - 세션들의 전체 기간(`[bulkStart, bulkEnd]`)을 산출하여 데이터 타입별 1회 벌크 조회 후, 메모리 상에서 세션별 시간 범위 및 패키지 출처(`sameSource`)를 고속 매칭
- **Health Connect 서브 서비스 및 헬퍼 클래스 모듈화**:
  - `lib/services/health/native_health_channel.dart`: 네이티브 MethodChannel(`runlog/hc_extra`) 통신, 고도/VO2max/세션상세 조회 및 DTO(`NativeSessionDetail`, `NativeRawSegment`, `NativeRawLap`) 격리
  - `lib/services/health/health_data_matcher.dart`: 인메모리 심박/거리델타/칼로리/걸음수 매칭, 스플릿 산출(`computeSplits`), 다운샘플링(`downsampleHr`), 세션 빌더(`buildRunSession`) 캡슐화
  - `lib/services/health_service.dart`: 인터페이스 및 위임 계층 유지로 기존 코드 및 테스트 100% 하위 호환 보장

### Gemini AI 서비스 파이프라인 정비 및 DTO 모듈화 (`lib/services/gemini/`)
- **Dynamic JSON 파싱 격리 및 Typed DTO 도입 (`lib/services/gemini/gemini_dto.dart`)**:
  - `GeminiGenerateRequestDto`, `GeminiGenerateResponseDto`, `GeminiCandidateDto`, `GeminiContentDto`, `GeminiPartDto`, `GeminiGenerationConfigDto`
  - `thought: true` 내부 사고 과정 필터링 및 빈 응답 검증을 타입 안전한 DTO 메서드(`extractCleanText()`)로 격리
- **Prompt Builder 분리 (`lib/services/gemini/gemini_prompt_builder.dart`)**:
  - `buildRunSummaryPrompt()`: 단일 러닝 요약/스플릿/랩/심박존/러닝역학/최근비교 구조화 프롬프트 빌더
  - `buildGoalRecommendationPrompt()`: 누적/월간 통계 및 최근 4주 볼륨 기반 3섹션 목표 추천 프롬프트 빌더
  - `averagePaceSecPerKm()`: 유효 페이스 기반 평균치 산출 분리
- **HTTP Engine 분리 (`lib/services/gemini/gemini_http_client.dart`)**:
  - `GeminiHttpEngine`: 60초 타임아웃, 재시도 가능 상태코드(`429, 500, 502, 503, 504`)에 대한 지수 백오프(1초, 2초), `GeminiNotConfiguredException` 및 네트워크 예외 처리 전담
- **`lib/services/gemini_service.dart` 경량화**:
  - 고수준 코디네이터 역할로 슬림화 및 생성자/메서드 100% 하위 호환 유지

### 테스트 및 품질 안정화
- **신규 단위 테스트 추가**:
  - `test/gemini_pipeline_test.dart`: DTO 직렬화/역직렬화, 프롬프트 빌더, HTTP 엔진 직접 테스트 9종
  - `test/health_data_matcher_test.dart`: 인메모리 심박/거리/칼로리/걸음수/랩/세션 조립 단위 테스트 6종
- **전체 테스트 142종 100% 통과 (`flutter test` 142/142 PASS, `flutter analyze` 0 issues)**

## 2026-09-05 (3단계 대형 UI 화면 분할 및 모듈화 리팩토링)

### 대형 UI 파일 모듈화 및 단일 책임 원칙(SRP) 적용
- **`lib/ui/analysis_screen.dart` 경량화 (958줄 → 182줄, 300줄 미만 달성)**:
  - `lib/ui/analysis/widgets/` 디렉터리에 7종 서브 위젯 분리:
    - `goal_recommend_card.dart`: 목표 추천 AI 코칭 (Gemini 연동 및 캐시)
    - `monthly_summary_card.dart`: 이번 달 요약 (`MonthlySummaryCard`) 및 지난달 비교 (`MonthCompareCard`)
    - `monthly_runs_chart_card.dart`: 최근 6개월 월별 러닝 거리 막대 차트
    - `weekly_volume_chart_card.dart`: 최근 8주간 볼륨 막대 차트
    - `pace_trend_chart_card.dart`: 회차별 평균 페이스 추이 선 차트 & `safePaceRange`
    - `vo2max_trend_chart_card.dart`: 최대 산소 섭취량 (VO₂max) 추이 차트
    - `pb_records_card.dart`: 개인 최고 기록 (PB) 카드
- **`lib/ui/run_detail_screen.dart` 경량화 (911줄 → 116줄, 300줄 미만 달성)**:
  - `lib/ui/run_detail/widgets/` 디렉터리에 7종 서브 위젯 분리:
    - `run_detail_hero_header.dart`: 상단 거리/시간/페이스 핵심 요약 카드
    - `run_detail_metrics_grid.dart`: 세부 지표(칼로리/심박수/케이던스/보폭/고도 등) 그리드
    - `run_detail_ai_summary_card.dart`: Gemini AI 세션 요약 코칭 카드
    - `run_detail_running_dynamics_card.dart`: 보폭, 심박 드리프트, 유산소 비율, 훈련부하/회복시간 분석 카드
    - `run_detail_hr_chart_card.dart`: 심박수 시계열 라인 차트 (`RunDetailHrChartCard`) & 심박존 분포 (`RunDetailHrZonesCard`)
    - `run_detail_laps_table_card.dart`: 워치 실제 랩 테이블 (`RunDetailLapsTableCard`) & 인터벌 구간 테이블 (`RunDetailSegmentsCard`)
    - `run_detail_delete_dialog.dart`: 기록 삭제 확인 다이얼로그
- **단위 및 위젯 테스트 강화 (`test/modular_widgets_test.dart`)**:
  - 각 모듈화된 서브 위젯 격리 렌더링, 엣지 케이스(기록 0/1개), Semantics 접근성 테스트 15종 추가
  - 전체 테스트 127종 100% 통과 (`flutter test` 127/127 PASS, `flutter analyze` 0 issues)

## 2026-09-05 (2단계 디자인 토큰 체계화 & ThemeExtension 도입)

### 디자인 시스템 & 토큰 체계화
- **`DESIGN.md` 가이드라인 수립**:
  - 야간 러너를 위한 다크 네온 디자인 원칙 및 토큰 사양 명문화
  - Color, Spacing Scale(4/8/12/16/20/24/32), Radius(4/8/12/16/20/24/Full), Typography Scale, Icon Sizes 사양 정의
- **`AppDesignTokens` ThemeExtension 및 `buildAppTheme()` 구축 (`lib/core/theme/`)**:
  - `AppDesignTokens`: `ThemeExtension<AppDesignTokens>` 구현으로 `context.tokens` 및 테마 인스펙션 지원
  - `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIconSizes`: 정적 상수 네임스페이스 및 `EdgeInsets`, `BorderRadius`, `SizedBox` gap 제공
  - Material 3 테마 완벽 연동: `ColorScheme`, `CardThemeData`, `AppBarTheme`, `NavigationBarThemeData`, `SnackBarThemeData`, `DialogThemeData`, `BottomSheetThemeData`, `FilledButtonThemeData`, `OutlinedButtonThemeData`, `ChipThemeData`
- **전체 4탭 및 UI 컴포넌트 하드코딩 값 추출 및 리팩토링**:
  - `HomeScreen`, `RunsScreen`, `RunDetailScreen`, `AnalysisScreen`, `AchievementsScreen`, `SettingsScreen`, `ManualAddScreen`, `ImportScreen`, `DebugScreen`
  - `WeeklyRing`, `LevelCard`, `RunCard`, `CalendarHeatmap`
- **표면 깊이(Surface Depth) 및 시각적 위계 다변화**:
  - Top Hero 카드 (`WeeklyRing`, `RunDetailScreen` 상단 메트릭 요약): `cardElevated` (`#1C222C`) 적용
  - 데이터 인셋 박스 (`_runningDynamicsCard`, 심박 드리프트/보폭 인셋): `cardSubtle` (`#11141A`) 적용
- **접근성(a11y) 및 고대비 가독성 강화**:
  - 텍스트 및 차트 축 라벨 색상 명도 대비비 강화 (`textPrimary`: 14:1+, `textSecondary`: 4.5:1+ WCAG AA 달성)
  - `WeeklyRing`, `RunCard`, `LevelCard`, `CalendarHeatmap`, `LineChart`, `BarChart` 영역에 스크린 리더용 `Semantics(label: ...)` 추가
- **단위 및 위젯 테스트 추가 (`test/design_tokens_test.dart`)**:
  - `AppDesignTokens` 기본값, `copyWith`, `lerp`, `buildAppTheme` 테스트
  - WCAG 명도 대비비(4.5:1 이상) 수학적 검증 테스트
  - `WeeklyRing`, `RunCard`, `LevelCard`, `CalendarHeatmap` `Semantics` 렌더링 테스트
  - 전체 테스트 112종 100% 통과 (`flutter test` 112/112 PASS, `flutter analyze` 0 issues)

## 2026-09-05 (1단계 안전망 구축 완료 — Riverpod Notifier, GeminiService 및 UI AsyncValue 회귀 테스트 체계 구축)

### 테스트 및 품질 안정화
- **`RunsNotifier` 상태 전이 & MutationQueue 회귀 테스트 (`test/runs_notifier_test.dart`)**:
  - 초기화(`build`), Health Connect 동기화(`sync`), 과거 기록 조회(`fetchCandidates`), 과거 기록 가져오기/제외(`importRuns`), 기록 삭제(`deleteRun`), 데모 데이터 주입(`seedDemoData`), 전체 삭제(`clearAll`) 전 시나리오 검증
  - 권한 거부 및 네트워크/동기화 예외 발생 시 안전한 `SyncResult` 에러 반환 및 상태 불변성 검증
  - `MutationQueue`를 통한 동시성 비동기 호출 순차 처리(FIFO) 및 장애 격리(이전 실패가 후속 뮤테이션을 차단하지 않음) 보장 검증
  - `statsProvider`, `vo2SeriesProvider`, `earnedBadgesProvider` 파생 프로바이더 반응성 검증
- **`GeminiService` HTTP 재시도 및 예외 핸들링 테스트 강화 (`test/gemini_service_test.dart`)**:
  - `MockClient` 및 지연 함수 주입 기반 테스트 환경 구축
  - API 미설정(`GeminiNotConfiguredException`), 유효한 요청 헤더/바디 포맷, 모델 내부 사고 과정(`thought: true`) 필터링 검증
  - 400 즉시 실패, 429/500/503/504 지수 백오프 재시도(1초, 2초) 및 3회 연속 실패 시 사용자 친화적 메시지 전파 검증
  - 일시적 503/네트워크 단절 후 2회차 재시도 성공 시 정상 복구 흐름 검증
  - `TimeoutException`(60초), `SocketException`, `http.ClientException` 예외 분기별 에러 핸들링 검증
- **UI 비동기 상태(`AsyncValue`) 및 위젯 렌더링 회귀 테스트 (`test/ui_async_value_test.dart`)**:
  - `RunsScreen`, `HomeScreen`: `AsyncLoading`(로딩 인디케이터), `AsyncError`(에러 메시지), `AsyncData([])`(빈 상태 안내), `AsyncData([runs])`(기록 카드 및 통계) 렌더링 검증
  - `RunDetailScreen`: 존재하지 않는 ID 안내, 세부 분석 카드, 수동 기록에만 편집 버튼 노출 분기 검증
  - `AnalysisScreen`: 빈 데이터 캘린더 안내 및 목표 추천/통계 차트 정상 렌더링 검증
- **버그 수정**:
  - `lib/ui/analysis_screen.dart`: 지난달 대비 증감치 행에서 고정 너비(86px)로 인해 긴 텍스트에서 발생하던 `RenderFlex` 우측 13px 오버플로우 버그 수정

## 2026-09-03 (v1.8.3 — Health Connect 워치 걸음 수 네이티브 직독 및 다중 폴백 연동)

### 버그 수정
- **네이티브 Health Connect `StepsRecord` 직독 채널 추가**:
  - `MainActivity.kt`에서 `StepsRecord`를 직접 조회하여 세션 시간대와 정확히 일치하는 걸음 수를 산출
  - Health Connect Workout 집계값(`value.totalSteps`), 네이티브 직독, health 패키지 `STEPS`의 3중 폴백 구조를 구축하여 걸음 수 누락을 원천 차단
- **기존 저장 기록 재동기화 지원**:
  - 앱에서 동기화(↻) 시 네이티브 채널로 최신 걸음 데이터가 즉시 보강되도록 처리

## 2026-09-03 (v1.8.2 — Health Connect 걸음 수 매칭 버그 수정 및 보폭/케이던스 이상치 필터링)

### 버그 수정
- **Health Connect 걸음 수(STEPS) 및 칼로리 매칭 로직 개선**:
  - Health Connect IntervalRecord 변환 시 `source_id`가 비어있고 `source_name`에 패키지명이 담기던 문제로 인해 걸음 수가 누락(0/null)되던 버그 해결
  - `sameSource` 교차 패키지 검증을 추가하여 삼성헬스 워치 걸음 수 집계 정상화
- **비정상 보폭/케이던스 이상치(Outlier) 생체역학 필터링**:
  - 불완전한 부분 걸음 수 샘플로 인해 케이던스가 80spm 미만 또는 260spm 초과인 경우 유효하지 않은 걸음으로 판단
  - 정상 보폭 범위(45cm ~ 200cm)를 벗어나는 비정상 수치(수천 cm 등) 산출 차단 및 UI에 '걸음 샘플 불완전'으로 안전하게 표시

## 2026-09-03 (v1.8.1 — 러닝 역학 & 심폐 효율 분석 카드 신설 및 가짜 스플릿 제거)

### 기능 개선
- **가짜 1km 스플릿 제거**:
  - 삼성헬스에서 단일 덩어리로 전달되던 거리 델타로 인해 모든 스플릿이 동일 페이스로 계산되던 가짜 1km 스플릿 차트 및 안내 문구 완전 제거
- **`러닝 역학 & 심폐 효율` 분석 카드 신설**:
  - **평균 보폭 (Stride)**: 총 거리 ÷ 총 걸음 수 기반 cm 단위 실시간 산출 및 보폭 피드백
  - **심박수 드리프트 (Cardiac Drift)**: 전반 50% vs 후반 50% 심박 비교로 심폐 피로도 및 지구력 안정성 측정
  - **유산소 vs 무산소 훈련 비율**: Z1~Z3(유산소) vs Z4~Z5(무산소) 비율 시각화
  - **훈련 부하(TRIMP) & 권장 회복 시간**: 심박존 가중치 기반 트레이닝 로드 및 휴식 시간 가이드
- **실제 워치 랩 (Laps) 연동**:
  - Health Connect `ExerciseLap`을 연동하여 스마트워치가 직접 측정한 실제 랩이 있는 경우에만 '워치 랩 기록' 테이블 표시
- **AI 러닝 코칭 프롬프트 고도화**:
  - Gemini 요약 프롬프트에 평균 보폭, 심박 드리프트, 훈련 부하(TRIMP), 유산소/무산소 비율 데이터 연동
- **단위 테스트 추가**:
  - `test/running_dynamics_test.dart` 추가 (총 47개 테스트 100% 통과)

## 2026-09-02 (v1.8.0 — 신규 업적 8종 추가 & 배지 시스템 확장)

### 기능 추가
- **신규 업적 8종 (총 33종 배지 체계)**:
  - `first_3k` (거리): 3K 피니셔 (단일 3km 이상 달리기)
  - `first_full` (거리): 풀 마라토너 (단일 42.195km 이상 달리기)
  - `total_2000k` (누적 거리): 누적 2,000km 클럽 달성
  - `streak_12w` (스트릭): 12주 연속 주 3회 러닝 스트릭 달성
  - `month_15runs` (스트릭): 월 15회 이상 러닝 달성
  - `speed_sub5` (스페셜): 서브 5 스피드스터 (평균 페이스 5분/km 이하 달성)
  - `calorie_1000` (스페셜): 칼로리 버너 (단일 세션 1,000kcal 이상 소모)
  - `consecutive_2days` (스페셜): 투데이 러너 (이틀 연속 러닝 달성)
- `tools/badges.html`: 신규 8종 배지 SVG 템플릿 추가
- `lib/models/achievement.dart`: `kBadges` 33종 배지 정의 등록
- `lib/logic/achievement_engine.dart`: `evaluate()`에 8종 업적 판정 로직 추가
- `test/achievement_engine_test.dart`: 8종 업적 판정 단위 테스트 추가

## 2026-09-02 (v1.7.2 — 분석 탭 다음 목표 AI 구조화 & 코칭 가이드 강화)

### 기능 개선
- `GeminiService.buildGoalPrompt()` 개선:
  - **구조화된 3섹션 목표 제안**:
    - 🎯 `[다음 1~2주 목표]`: 주당 횟수, 주간 총 거리(10% 증편 원칙 준수), 세션별 목표 거리/페이스
    - 🏃 `[추천 세션 구성]`: 이지런/템포런/롱런(LSD) 세션 분배 가이드
    - 💡 `[코칭 포인트 & 주의사항]`: 심박 관리(Z2/Z3), 부상 예방 및 페이스 조절 조언
  - **통계 데이터 보강**: 개인 최고 페이스(1km/5km), 최근 5회 평균 페이스, 월별/주간 세션 수 및 페이스 추이
- `test/gemini_service_test.dart`: `buildGoalPrompt` 구조화 프롬프트 및 통계 포함 테스트 추가

## 2026-09-02 (v1.7.1 — Gemini 및 업데이트 타임아웃 안정화)

### 수정
- `GeminiService`: 요청 제한 시간을 20초 → **60초**로 확대하고, `TimeoutException` 및 네트워크 오류 시 자동 재시도 및 친절한 안내 메시지 추가
- `UpdateService`: GitHub Release 최신 버전 확인 제한 시간을 8초 → **15초**로 확대

## 2026-09-02 (v1.7.0 — AI 러닝 요약 구조화 & 분석 데이터 심층 확장)

### 기능 개선
- `GeminiService.buildPrompt()` 개선:
  - **구조화된 3섹션 형식**: `📌 [핵심 요약]`, `📊 [페이스 & 심박 분석]`, `💡 [맞춤 코칭 팁]`
  - **1km 구간별 스플릿 데이터 제공**: km별 페이스 및 구간 평균 심박수 분석
  - **심박존 분포(Z1~Z5) 제공**: 회복/유산소/지구력/역치/무산소 비중 및 부하 평가
  - **케이던스 및 고도 데이터 반영**: 총 걸음수 기반 평균 spm 및 획득 고도 계산
  - **최근 5회 러닝 평균 비교**: 최근 평균 거리·페이스·심박 대비 성장/효율 분석
- `test/gemini_service_test.dart`: 스플릿, 심박존, 케이던스, 최근 평균 프롬프트 포맷 단위 테스트 추가

## 2026-08-20 (v1.6.8 — Gemini AI 요약 503 대응)

### 원인 판단
- 실기기 화면의 `503 UNAVAILABLE / This model is currently experiencing high demand`를 확인.
  할당량 초과인 429가 아니라 Gemini 서버의 일시적 용량 부족 응답이며, API 키나 러닝 데이터
  형식 오류가 아님
- `gemini-flash-latest`는 새 릴리스마다 뒤에서 실제 모델이 교체되는 alias라 최근 모델 업데이트와
  수요 급증의 영향을 받을 수 있음. 운영 앱은 안정 모델 ID를 고정하는 편이 안전함

### 수정
- `lib/services/gemini_service.dart`: `gemini-3.6-flash` 안정 모델로 고정
- 429·500·502·503·504 응답은 1초, 2초 간격으로 최대 3회 재시도
- 503이 반복되면 원시 JSON 대신 `Gemini 서버가 일시적으로 혼잡합니다` 안내를 표시
- API 키 저장 방식, 응답의 `thought:true` 필터, `maxOutputTokens: 2048`은 유지

### 검증
- Dart formatter 파싱과 `git diff --check` 통과
- `flutter analyze`는 관리형 환경에서 90초 동안 SDK 초기화 단계에 멈춰 차단됨
- v1.6.8 release APK를 빌드해 GitHub Release `v1.6.8`에 업로드함
- 실제 API 호출은 사용자 API 키를 읽거나 노출하지 않고 실기기에서 재확인 필요

## 2026-07-24 (월간 분석 + AI 목표 추천)

### 월간 통계·분석
- `MonthlyStats.fromRuns()` 추가: 이번 달·지난달 거리/횟수/시간/거리 가중 평균 페이스,
  이번 달 최장거리를 월 경계로 집계
- 이번 달을 포함한 최근 6개월을 월 1일 키의 `(DateTime, double)` 목록으로 생성하고,
  기록 없는 달도 `0.0`으로 채움. `DateTime(year, month offset, 1)` 정규화로 연말연초 처리
- 분석 화면의 러닝 캘린더와 주간 거리 사이에 이번 달 요약, 지난달 대비, 최근 6개월
  월별 거리 막대 차트를 추가. 페이스 비교는 값이 낮아질수록 개선이므로 화살표·색상을 반전

### AI 목표 추천
- Gemini HTTP 호출과 `thought:true` 제외 응답 파싱을 `_generate()`로 공통화하고,
  누적·스트릭·최장거리·최고 5km 페이스·월간 거리·최근 4주 거리를 근거로 다음 1~2주
  구체 목표를 한국어 2~4문장으로 생성하는 `recommendGoal()` 추가
- `generationConfig`는 기존 `maxOutputTokens: 2048`만 유지하고 400 오류를 일으킨
  `thinkingConfig`는 추가하지 않음. API 키는 기존 기기 로컬 설정만 사용
- 분석 화면 최상단에 생성/다시 생성, 로딩, 오류, API 키 설정 이동, 생성 시각을 갖춘
  목표 추천 카드 추가
- Hive meta 박스의 `goalRecommendation`, `goalRecommendedAt`에 추천과 생성 시각을
  캐시하고 전체 데이터 삭제 시 함께 제거
- Codex 초안은 `FakeRunRepository`(테스트 파일)를 건드리지 않으려고 `GoalRecommendationCache`
  capability 인터페이스 + 확장 위임을 썼으나, 로컬 검토 결과 기존 `getAiSummary` 패턴과
  달라 불필요한 추상화로 판단 — 3개 메서드를 `RunRepository`에 직접 선언하고
  `test/manual_record_achievement_test.dart`의 `FakeRunRepository`에 스텁 3개를 추가하는
  더 단순한 방식으로 정리함

### 테스트·검증
- `test/monthly_stats_test.dart` 신규 작성: 이번달/지난달 경계, 최근 6개월·0 채움,
  거리 가중 평균 페이스·0 거리 가드, 12월↔1월 연말연초 경계 4개 시나리오
- **로컬 재검증 완료**: `flutter analyze` 이슈 0건, `flutter test` 17개 전부 통과
  (기존 13개 + 월간 통계 테스트 4개 신규)

## 2026-07-24 (러닝 캘린더 일요일 시작으로 변경)

### 변경 사항
- `lib/ui/widgets/calendar_heatmap.dart`의 요일 헤더를 `월~일`에서 일반적인 `일~토` 순서로 변경
- Dart `DateTime.weekday`의 월=1~일=7 값을 일요일 시작 열 인덱스로 바꾸기 위해
  달의 첫날 앞 빈칸 수를 `firstWeekday - 1`에서 `firstWeekday % 7`로 변경
- 요일 헤더와 날짜 셀의 주말 색상 조건을 각각 첫 열(일요일)과 마지막 열(토요일)인
  `0`, `6` 인덱스를 기준으로 판단하도록 변경. 기존 다크·네온 색상은 그대로 유지

### 검증
- 파일 전체에서 월요일 시작을 가정한 로직을 검색해 위 네 군데 외 추가 의존성이 없음을 확인
- 2026년 7월 1일은 수요일이고 Dart weekday가 3이므로,
  새 계산식 `3 % 7 = 3`에서 수요일 열 인덱스 3과 일치함을 직접 확인
- 실제 diff가 요일 순서 관련 네 군데뿐이며 `git diff --check` 통과
- `flutter analyze`는 관리형 환경에서 60초 동안 출력 없이 SDK 초기화 단계에 멈춰 종료
- **로컬 재검증 완료**: `flutter analyze` 이슈 0건

## 2026-07-24 (수동 기록 평균 페이스 입력 지원)

### 변경 사항
- `ManualAddScreen`에 `소요시간으로 입력` / `페이스로 입력` 선택 칩을 추가하고 기본값은
  기존과 같은 소요시간 모드로 유지. 편집 화면도 항상 기존 `durationSec`을 정확히 분해한
  시·분·초 입력 상태로 시작
- 소요시간 모드에서는 거리와 시·분·초를 직접 입력하고 기존 평균 페이스 미리보기를 유지.
  페이스 모드에서는 거리와 분·초 단위 평균 페이스를 입력하면
  `(distanceKm * paceSecPerKm).round()`로 소요시간을 계산해 읽기 전용으로 표시
- 모드를 전환할 때 현재 거리와 활성 입력값으로 반대쪽 컨트롤러를 동기화하고, 변환할 수
  없는 불완전한 입력이면 대상 컨트롤러를 초기화해 숨겨진 과거 값이 다시 저장되지 않게 처리
- 현재 모드의 입력 필드만 `Form`에 포함하고, 시간·페이스 각 부분의 음수/비정수와 분·초
  60 이상, 전체 0초를 검증. 거리도 유한한 양수만 허용
- 저장 시 모드와 관계없이 최종 `distanceM`과 `durationSec`만 `RunSession`에 기록하고
  `endTime`에도 같은 `durationSec`을 적용. 평균 페이스 모델 필드나 저장 스키마는 추가하지 않음

### 설계 결정
- 거리·소요시간·페이스는 둘이 정해지면 나머지 하나가 결정되므로 세 값을 동시에 독립 입력으로
  두지 않고, 거리와 선택한 한 값만 원본으로 삼는 두 모드로 분리해 값 불일치를 방지
- 페이스와 소요시간은 모두 정수 초 단위라 모드 전환 시 반올림 오차가 생길 수 있으며,
  모델의 기존 평균 페이스 계산과 동일하게 `round()`를 한 번만 적용하는 규칙으로 통일

### 검증
- Dart formatter 구문 파싱 및 포맷 검사 통과, `git diff --check` 통과
- 계산 예시 확인: 5km × 6분00초/km = 1,800초 = `30:00`
- 편집값 3,725초가 1시간 2분 5초로 분해되고, 두 저장 경로 모두 확정한 동일한
  `durationSec`을 `endTime`과 `RunSession`에 사용하는지 코드 리뷰로 확인
- `flutter analyze`와 `flutter analyze --no-pub -v`는 관리형 환경에서 출력 없이 멈춰 종료.
  SDK의 `dart analyze` 직접 실행은 사용자 프로필 쓰기 경로를 임시 경로로 바꿔 시작했으나,
  관리형 권한이 Pub 캐시의 `flutter_riverpod`·`intl` 등을 읽지 못해 정상 분석이 차단됨
- **로컬 재검증 완료**: `flutter analyze` 이슈 0건, `flutter test` 13개 전부 통과
  (기존 9개 + 수동기록·업적 연동 테스트 4개, 페이스 모드로 인한 회귀 없음)

## 2026-07-24 (수동 기록 → 업적 연동 검증)

### 확인 요청
- 사용자가 "수동으로 기록추가시 업적관련 연동 제대로되는지" 확인을 요청

### 검증 방법
- `test/manual_record_achievement_test.dart` 신규 작성 — Hive/플랫폼 채널 없이 메모리 위에서
  `RunRepository`를 구현한 `FakeRunRepository`로 `providers.dart`의 `importRuns()`와 동일한
  순서(upsert → 업적 재평가)를 재현해 실제 `AchievementEngine`을 그대로 실행
- 4개 시나리오로 검증:
  1. 수동 기록 1건 추가 시 거리 업적이 `DateTime.now()`가 아니라 **입력한 러닝 날짜**로 즉시 획득
  2. 기존 HC 동기화 기록 + 수동 기록이 누적거리 업적(50km)을 함께 채움
  3. 같은 id로 수동 기록을 수정(덮어쓰기)해도 이미 획득한 업적은 중복 재발급되지 않고,
     새로 넘긴 임계값(예: 10km)만 새로 획득됨 — 저장소에 중복 레코드도 안 남음
  4. 야간 러닝 등 특수 업적(`night_owl`)도 `sourceName`과 무관하게 정상 카운트됨

### 결과
- 4개 테스트 전부 통과 (`flutter test`), `flutter analyze` 이슈 0건
- **결론: 수동 기록 추가/수정이 업적 시스템과 완전히 통합되어 있음을 실행 가능한 테스트로 확인**
  (HC 동기화 기록과 동일한 경로 — `RunSession` 리스트에 섞여 들어가는 순간부터 코드상 구분이 없음)

## 2026-07-24 (수동 기록 캘린더 추가·편집 및 입력 보강)

### 신규 기능
- `CalendarHeatmap`에 `onEmptyDayTap` 콜백을 추가하고 분석 화면에서 빈 날짜를 누르면
  해당 날짜가 선택된 `ManualAddScreen`으로 이동하도록 연결. 이번 달의 미래 날짜는
  기록 유무와 관계없이 탭 콜백을 실행하지 않으며, 전체 기록이 0건이어도 캘린더는 표시
- `ManualAddScreen`에 `initialDate`와 `editing` 모드를 추가. 편집 시 날짜/시간/거리/
  시·분·초/평균심박/최고심박/칼로리를 기존 값으로 채우고 기존 ID를 유지한 채
  `importRuns()`로 upsert하여 업적도 다시 평가
- 최고 심박 입력을 `RunSession.maxHr`에 연결하고, 거리·시간 변경 때마다 평균 페이스를
  네온 텍스트로 즉시 표시. 평균 페이스는 거리와 시간의 파생값이라 별도 저장하지 않음
- `RunDetailScreen`은 `runsProvider`를 watch한 목록에서 ID를 직접 찾아 표시하도록 변경.
  `sourceName == 'manual'`인 기록에만 편집 버튼을 노출하고 삭제 버튼은 기존대로 모두 유지

### 검증
- Dart formatter의 파서 모드로 변경된 Dart 파일 4개의 구문 검증 통과
- `git diff --check` 통과, 요구사항별 구조 점검 7개 항목 통과
- (구현: Codex codex-rescue 서브에이전트, 검증: 로컬 환경) `flutter analyze` 로컬 터미널에서
  재실행 결과 **이슈 0건 통과** — Codex 관리형 환경의 캐시 권한 제한은 로컬에는 해당 없었음
- APK 빌드는 아직 안 함 (다음 단계에서 처리)

## 2026-07-23 (v1.6.3 — AI 요약 요청이 400 INVALID_ARGUMENT로 실패하는 버그 수정)

### 문제
- v1.6.2 설치 후 실기기 테스트: "Gemini 요청 실패 (400): ... INVALID_ARGUMENT" 에러로
  AI 요약 생성 자체가 실패함

### 원인
- v1.6.1에서 추가한 `generationConfig.thinkingConfig` 필드가 이 API 키로 라우팅되는
  실제 모델 버전에서는 지원되지 않는 필드였음 — Gemini는 모델 버전에 따라 지원하는
  generationConfig 필드가 달라서, 미지원 필드를 보내면 요청 자체가 400으로 거부됨

### 수정
- `lib/services/gemini_service.dart`: `thinkingConfig` 필드를 요청에서 완전히 제거.
  대신 `maxOutputTokens`을 2048로 넉넉히 올려 사고 과정이 있어도 최종 답변이 잘리지
  않게 하고, v1.6.2에서 추가한 `thought:true` 파트 필터링으로 사고 초안 노출은 계속 방지
- 즉, 사고 비활성화를 서버에 요청하는 대신 "사고를 하든 말든 결과만 깨끗하게 걸러서 쓰기"
  방식으로 전환 — 모델 버전이 바뀌어도 더 안전한 방어 방식

### 실기기 최종 확인 (2026-07-23)
- v1.6.3 설치 후 "AI 러닝 요약 > 다시 생성"으로 정상 동작 확인 완료

## 2026-07-23 (v1.6.2 — AI 요약에 모델 사고 과정이 그대로 노출되는 버그 수정)

### 문제
- v1.6.1 적용 전 재현: "*Sentence 3: Heart rate efficiency/coaching"처럼 실제 답변이 아니라
  모델이 답변을 구상하며 남긴 개요/메모 같은 텍스트가 그대로 화면에 표시됨

### 원인
- Gemini API 응답의 `content.parts`에는 최종 답변 외에 `thought: true`로 표시된
  "사고 초안" 파트가 섞여 올 수 있음. 기존 코드는 파트를 구분 없이 전부 이어붙여서
  최종 답변이 아닌 사고 초안까지 그대로 사용자에게 노출됨
- `thinkingConfig.thinkingBudget: 0`(v1.6.1에서 추가)만으로는 모델/버전에 따라
  사고 파트 자체를 완전히 막지 못할 수 있어 근본 대책이 아니었음

### 수정
- `lib/services/gemini_service.dart`: 응답 파싱 시 `part['thought'] == true`인 파트를
  걸러내고 최종 답변 파트만 이어붙이도록 방어적으로 필터링 추가

## 2026-07-23 (v1.6.1 — AI 요약 문장 잘림 버그 수정)

### 문제
- v1.6.0에서 AI 러닝 요약을 생성하면 "이번 야간 러닝에서는 5.13km를"처럼 문장이 중간에 끊김

### 원인
- `gemini-flash-latest`(Gemini 2.5+/3.x Flash 계열)는 기본적으로 "생각(thinking)" 모드가 켜져
  있고, 이 사고 과정 토큰도 `maxOutputTokens`(당시 400) 예산을 함께 소모함
- 실제 답변 텍스트가 나오기도 전에 사고 토큰이 예산을 다 써버려 응답이 중간에 끊긴 것

### 수정
- `lib/services/gemini_service.dart`: `generationConfig`에 `thinkingConfig.thinkingBudget: 0`
  추가해 사고 모드 비활성화(짧은 요약 작업에는 불필요), `maxOutputTokens`도 400 → 500으로 상향
- 이전에 잘린 채로 캐시된 요약은 러닝 상세 화면에서 "다시 생성"을 누르면 새로 덮어써짐

## 2026-07-23 (v1.6.0 — 앱 자동 업데이트 + AI 러닝 요약)

### GitHub 저장소 공개 전환
- 자동 업데이트가 GitHub Releases API를 인증 없이 조회하려면 공개 저장소가 필요함
- 저장소 내용(PRD, 코드, 커밋 이력) 점검 결과 이름/연락처/주소 등 식별정보, API 키·자격증명
  없음을 확인 후 `StoneSilver0417/samsung-health`를 공개로 전환 (`gh repo edit --visibility public`)

### 신규 기능 — 앱 자동 업데이트
- `lib/services/update_service.dart`: GitHub Releases `latest` API로 최신 버전 태그·APK 에셋 URL 조회,
  현재 버전과 semver 비교, APK 다운로드 후 `open_filex`로 시스템 설치 프로그램 실행
- 홈 화면 진입 시 조용히 확인(새 버전 없으면 알림 없음) + 메뉴 "업데이트 확인"으로 수동 확인 가능,
  다운로드 진행률 다이얼로그 표시
- AndroidManifest에 `INTERNET`, `REQUEST_INSTALL_PACKAGES` 권한 추가
- 패키지 추가: `http`, `package_info_plus`, `open_filex`, `path_provider`
- **중요**: 이 기능은 앞으로 배포할 때마다 버전 태그(`vX.Y.Z`)와 APK 에셋을 첨부한 GitHub Release
  생성이 필수 — 없으면 사용자 폰에서 새 버전을 감지 못함

### 신규 기능 — AI 러닝 요약 (Gemini API)
- `lib/services/gemini_service.dart`: `gemini-flash-latest` 모델로 러닝 1회의 거리/시간/페이스/심박과
  최근 5회 평균을 비교하는 한국어 코멘트 생성 (2~4문장, 담백한 톤 프롬프트)
- `lib/ui/settings_screen.dart` (신규): Gemini API 키 입력 화면. 키는 Hive 로컬에만 저장, git에는
  포함되지 않음 (하드코딩 금지 원칙 준수) — 홈 메뉴 "설정 (AI 요약 등)"에서 진입
- `run_detail_screen.dart`: "AI 러닝 요약" 카드 추가. 생성 결과는 러닝별로 캐시되어 재호출 안 함
  (`RunRepository.getAiSummary`/`saveAiSummary`, meta 박스 `aiSummary:<runId>` 키)
- `RunRepository.clear()`(데이터 전체 삭제)는 AI 요약 캐시도 함께 삭제하되, API 키 설정은 유지

## 2026-07-23 (sync() 커서 버그 발견 및 수정 — 개발 재개)

### 배경
- 삼성헬스가 업데이트되어 동기화가 재개됐으나, 7/1~7/13 구간 러닝 기록이 RunLog에 안 잡힘.
  삼성헬스 앱 자체에는 해당 기간 원본 데이터가 존재함을 확인

### 원인
- `lib/providers.dart`의 `sync()`가 실제로 새 데이터를 가져왔는지와 무관하게 매 호출마다
  `repo.setLastSyncedAt(DateTime.now())`을 무조건 실행하고 있었음
- 7/1~7/13 삼성헬스 전역 버그(운동 데이터 HC 미기록) 기간에도 사용자가 앱을 열거나 ↻를 누를
  때마다 `lastSyncedAt` 커서가 계속 "지금"으로 전진함
- 삼성헬스가 고쳐진 뒤에도 일반 동기화(↻)는 `since = lastSyncedAt - 1일`부터만 Health Connect에
  질의하므로, 이미 지나쳐버린 7/1~7/13 구간은 정기 동기화로 다시는 조회되지 않음
- **RunLog 자체의 버그**이며 삼성헬스 전역 버그와는 별개의 문제. `이전 기록 가져오기` 화면은
  `lastSyncedAt`과 무관하게 지정 기간을 HC에 직접 질의하므로 이 버그의 영향을 받지 않음
  (그래서 이 화면으로 검색하면 해당 구간을 여전히 찾을 수 있는지 확인 가능)

### 수정
- `sync()`에서 `lastSyncedAt` 기반 `since` 커서 계산을 제거하고, 매 동기화마다
  `health.fetchRuns()`(인자 없음 → 기본 최근 30일 고정 스캔)를 호출하도록 변경
- 기존 UUID dedupe(`HiveRunRepository.upsertAll`)가 이미 있어 중복 저장 걱정 없음
- 앞으로 이런 유형의 일시적 동기화 장애가 다시 발생해도, 장애가 풀린 뒤 첫 정기 동기화에서
  자동으로 복구됨 (30일 이내 장애까지 커버). `lastSyncedAt`은 이제 화면 표시용으로만 사용됨
- `flutter analyze` 통과 확인. **재빌드·재설치는 아직 안 함** — 다음 세션 최우선 작업

### 확인 결과 — 7/1~7/13 구간은 영구 유실
- `이전 기록 가져오기 > 3개월`로 직접 검색했으나 해당 구간 후보가 뜨지 않음
- 즉 삼성헬스가 장애 복구 후 과거 구간을 HC에 소급해서 채워 넣지 않았다는 뜻 —
  Health Connect 자체에 데이터가 없으므로 RunLog(또는 어떤 앱이든) 코드로는 복구 불가능
- sync() 커서 수정은 여전히 유효한 재발 방지책 — 앞으로 30일 이내의 유사 장애는 자동 복구되지만,
  이미 지나간 이번 7/1~7/13 구간 자체는 수정 이전에 발생한 유실이라 복구 대상이 아님

### 신규 기능 — 기록 수동 추가
- HC 자체에 데이터가 없어 동기화로는 복구 불가능한 경우를 위해, 삼성헬스 앱에 남아있는 원본
  값(날짜/시간/거리/평균심박/칼로리)을 사용자가 직접 입력해 로컬에 저장하는 화면 추가
- `lib/ui/manual_add_screen.dart` (신규), 홈 메뉴 > "기록 수동 추가"에서 진입
- 저장 시 `id: 'manual-<epoch>'`, `sourceName: 'manual'`로 저장 — `importRuns()`를 그대로 재사용해
  업적 재평가까지 함께 처리됨. 스플릿/세그먼트/심박 시계열은 비워둠(요약 정보만 입력받음)
- `run_detail_screen.dart`: 구간 데이터 없음 안내 문구를 `sourceName == 'manual'`이면
  "수동으로 추가한 기록입니다"로, 그 외에는 기존 삼성헬스 정책 안내를 유지하도록 분기

## 2026-07-03 (동기화 누락 원인 재분석 — 잠정 중단 확정)

### 재분석 결론
- **이전 추정(배터리 최적화)은 오류**. 실제 원인은 2026년 최근 삼성헬스 업데이트 자체의
  전역 버그 — 운동(Exercise) 데이터를 Health Connect에 아예 쓰지 않음
- 근거: 삼성 커뮤니티(미국/유럽/구글 안드로이드 커뮤니티)에 동일 증상 다수 보고.
  수면 등 다른 데이터는 정상 동기화되고 운동만 누락. 권한 재설정/캐시 삭제/재설치
  전부 무효인 패턴이 우리 6/30 건과 정확히 일치
- 우리 진단 화면(3중 대조) 결과와도 부합 — 기록이 HC 자체에 없었음 = 삼성헬스가 쓰기를 안 한 것

### 결정
- **RunLog 코드는 정상. 앱 수정으로 해결 불가 → 잠정 중단 확정**
- 재개 조건: 삼성헬스 수정 업데이트 배포 후 새 러닝이 HC에 정상 기록되는지 확인되면 재개
- 대안(보류): Health Sync 앱 우회 동기화 — 유료·서드파티 의존이라 개인용 목적엔 과함

## 2026-07-01~02 (v1.5.1~1.5.5, 개발 중단)

### 배경
- 삼성헬스 업데이트 이후 "동기화는 되는데 새 기록만 안 보임" 버그 신고
- 처음엔 세션 레벨 워크아웃 타입이 RUNNING이 아닌 HIGH_INTENSITY_INTERVAL_TRAINING으로
  들어와서 필터에서 걸러지는 것으로 추정 → health_service.dart 필터 확장 (실제 원인 아니었음)
- 앱 내 진단 화면(설정 메뉴 > "진단: 원본 운동 데이터") 추가해 3중으로 대조
  1) health 패키지 경유 2) 네이티브 Health Connect SDK 직접 호출
  3) Health Connect Training Plans API(PlannedExerciseSessionRecord) — 권한 미지원으로 확인 불가
- USB 디버깅(adb)이 끝까지 기기에서 잡히지 않아 로그 확인 불가 → 대신 폰-PC MTP 연결을
  PowerShell Shell.Application COM 객체로 브라우징해 스크린샷을 직접 가져와 확인하는
  방법을 사용함 (`New-Object -ComObject Shell.Application` → NameSpace(0x11) → 기기 →
  내장 저장공간 → DCIM/Screenshots). adb 없이 폰 화면 확인이 필요할 때 재사용 가능.

### 근본 원인 확정
- 문제의 특정 러닝(6/30)이 **Health Connect 자체에 없음** (health 패키지도, 네이티브 HC
  직접 조회도, Health Connect 앱 UI도 전부 없음) → 우리 앱 버그가 아니라 삼성헬스 →
  Health Connect 동기화 자체가 안 된 것
- Health Connect 권한(읽기/쓰기)은 전부 정상 확인됨 → 권한 문제 아님
- 원인은 삼성헬스 업데이트가 배터리 최적화 설정을 리셋시켜 "최적화됨(절전)" 상태가 되면서
  백그라운드 HC 동기화가 제한된 것으로 추정 (설정 > 앱 > 삼성 헬스 > 배터리에서 확인됨)
- **배터리를 '제한 없음'으로 바꿔도 6/30 기록은 소급 복구 안 됨** (재실행, 수정 후 재저장,
  캐시 삭제 + 재부팅까지 시도했으나 전부 실패) — 삼성헬스 동기화 큐에 영구적으로 유실된 것으로 판단
- 이후 새 러닝부터 정상 동기화되는지는 **미검증 상태로 개발 중단**

### 남은 코드 상태
- `lib/services/health_service.dart`: HIGH_INTENSITY_INTERVAL_TRAINING 허용 필터 (근본 수정 아님, 무해하니 유지)
- `lib/ui/debug_screen.dart`, `MainActivity.kt`의 getRawSessions/getPlannedSessions:
  진단용으로 추가됨. 기능적으로는 무해하지만 프로덕션에 필요한 코드는 아님 — 재개 시 정리 여부 판단 필요
- 버전 1.5.0 → 1.5.5까지 홈 화면 라벨은 하드코딩 문자열이라 pubspec 버전과 수동으로 맞춰야 함 (`home_screen.dart`)
- GitHub Release `v1.5.1`에 최신 APK 첨부되어 있음 (태그명과 실제 버전 라벨 1.5.5 불일치 — 재개 시 정리 권장)

### 개발 중단 결정
- 사용자가 이 세션의 반복된 디버깅(APK 7회 재빌드, USB 디버깅 실패, 배터리/캐시 조치 무효)
  끝에 RunLog 앱 개발을 접기로 결정함 (2026-07-02)

## 2026-06-13 (v1.5.0)

### 변경 사항
- 업적 earnedAt 날짜 자동 계산: 모든 업적이 실제 달성 시점의 날짜로 기록
  - 누적거리 배지: 임계값을 처음 넘은 러닝 날짜
  - 러닝 횟수: n번째 러닝 날짜
  - 스트릭 배지: 연속 주수 완성한 마지막 주의 최종 러닝 날짜
  - 특수 배지(야행성/얼리버드/주말전사): n번째 조건 충족 러닝 날짜
  - 단일 세션 배지(거리/시간): 조건 달성한 러닝 날짜

### 사용 주의
- 이전 데이터는 자동 갱신 안 됨 → **데이터 전체 삭제** 후 재동기화 시 올바른 날짜로 재계산

## 2026-06-11 (v1.4.0)

### 변경 사항
- 가져오기 선택 영구제외(ignoredIds), 월별 달력 히트맵, 레벨 전체등급표
- 이모지 전부 제거, 차트 축 단위+해석 설명 추가
- 업적 25종으로 확대 (배지 PNG: tools/badges.html + Playwright 스크린샷 파이프라인)
- 홈 타이틀에 버전 라벨 표시 (설치 확인용)

## 2026-06-11 (Phase 1 MVP 완료)

### 변경 사항
- 동기화 / 스플릿 / 심박존 / 주간링 / 스트릭 / 업적 5종 / 4탭 다크네온 UI
- 테스트 7종 작성

### 의사결정 배경
- 로컬 우선(Hive) 저장, Firestore는 Phase 2 어댑터로 미룸 — Firebase 무료 티어 전략
- 스플릿 상세 데이터는 삼성 정책상 불가 확인 → 평균 페이스 표시로 확정
