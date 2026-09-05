# RunLog Design System & Token Specifications (DESIGN.md)

RunLog 앱의 시각적 일관성, 접근성(a11y), 다크 네온 아이덴티티 및 계층적 UI 시스템을 정의하는 디자인 가이드 문서입니다.

---

## 1. 디자인 철학 및 원칙

1. **야간 러너를 위한 다크 네온 (Dark Neon)**
   - 메인 베이스: 깊은 흑색 배경 (`#0E1116`)과 카드 표면 (`#161B22`)
   - 포인트 컬러: 강렬한 볼트/네온 라임 (`#C8FF3D`)과 디밍 네온 (`#8BB22A`)
   - 이모지 미사용 원칙: 아이콘과 정제된 타이포그래피, 마이크로 뱃지 컴포넌트로 정보 전달
2. **시각적 위계 및 표면 깊이 (Visual Hierarchy & Surface Depth)**
   - Top Hero 카드 (주간 목표 링, 상세 메트릭): 고대비 네온 강조 + 상위 표면 (`#1A202A` ~ `#1F242C`)
   - Trend Chart / Heatmap: 중간 표면 (`#161B22`) + 시계열/그리드 정렬
   - Inset Metric / Data Grid: 내부 인셋 박스 (`#11141A` 또는 `white with alpha 0.03~0.06`)
3. **접근성(a11y) & 고대비 가독성**
   - 모든 텍스트 및 라벨은 다크 배경에서 최소 4.5:1 (WCAG AA) 이상의 명도 대비율 충족
   - 모든 주요 메트릭, 차트, 액션 컴포넌트에 스크린 리더용 `Semantics` 라벨 적용
   - 숫자는 `tabularFigures`를 적용하여 수치 변동 시 레이아웃 흔들림 방지

---

## 2. 디자인 토큰 사양 (Design Tokens)

### 2.1 Color Tokens

| 토큰명 | Hex 코드 | 용도 | 대비비(배경 대비) |
|---|---|---|---|
| `bg` | `#0E1116` | 최하단 캔버스 배경 | - |
| `surface` / `card` | `#161B22` | 기본 카드 및 바텀시트 표면 | - |
| `cardElevated` | `#1C222C` | 강조/히어로 카드 표면 | - |
| `cardSubtle` | `#11141A` | 인셋 데이터 셀, 내부 컨테이너 | - |
| `neon` | `#C8FF3D` | 주요 액션, 핵심 수치, 활성 탭 | 15.2:1 (AAA) |
| `neonDim` | `#8BB22A` | 보조 강조, 획득 완료 상태 | 7.1:1 (AAA) |
| `neonMuted` | `#4B5E1A` | 비활성 프로그레스 트랙 | - |
| `textPrimary` | `#F0F3F6` | 헤드라인, 핵심 메트릭 수치 | 14.1:1 (AAA) |
| `textSecondary` | `#9EABB8` | 메트릭 라벨, 차트 축 레이블, 설명문 | 6.8:1 (AA+) |
| `textTertiary` | `#768390` | 플레이스홀더, 보조 타임스탬프 | 4.6:1 (AA) |
| `danger` | `#FF5D5D` | 경고, 최고 심박, 심폐 과부하 | 5.8:1 (AA) |
| `warning` | `#FFB23D` | 주의, 유산소 경계, 인터벌 | 9.4:1 (AAA) |
| `cardioGreen` (Z2) | `#4AD9A5` | 심박 안정존, 유산소 효율 | 10.2:1 (AAA) |
| `cardioBlue` (Z1) | `#4A90D9` | 웜업존, 회복 러닝 | 6.5:1 (AA) |
| `cardioPurple` | `#B07AFF` | 고강도 레벨, 특수 지표 | 7.4:1 (AA) |

#### 심박존 (HR Zone Palette)
- **Z1 (회복)**: `#4A90D9`
- **Z2 (유산소 기초)**: `#4AD9A5`
- **Z3 (유산소 지구력)**: `#C8FF3D`
- **Z4 (역치/무산소)**: `#FFB23D`
- **Z5 (최대 심박)**: `#FF5D5D`

---

### 2.2 Spacing Scale

모든 간격, 패딩, 마진은 4의 배수 그리드 체계를 준수합니다.

| 토큰 | 크기 | 용도 |
|---|---|---|
| `s4` | 4px | 초소형 간격, 인라인 뱃지 패딩 |
| `s8` | 8px | 칩 간격, 서브 텍스트 간격, 작은 컴포넌트 내부 여백 |
| `s12` | 12px | 카드 내부 요소 간격, 인셋 박스 간격 |
| `s16` | 16px | 기본 카드 패딩, 리스트 타일 수평 여백 |
| `s20` | 20px | 화면 기본 좌우 패딩, 섹션 헤더 패딩 |
| `s24` | 24px | 큰 섹션 간 간격, 다이얼로그 패딩 |
| `s32` | 32px | 화면 하단 안전 여백, 빈 상태(Empty State) 패딩 |

---

### 2.3 Radius & Elevation

| 토큰 | 반경(px) | 적용 대상 |
|---|---|---|
| `r4` / `br4` | 4px | 프로그레스 바, 인라인 태그 |
| `r8` / `br8` | 8px | 캘린더 날짜 셀, 작은 버튼 |
| `r12` / `br12` | 12px | 인셋 데이터 박스, 칩 컴포넌트 |
| `r16` / `br16` | 16px | 기본 카드(`Card`), 리스트 카드 |
| `r20` / `br20` | 20px | 모달 바텀시트, 강조 컨테이너 |
| `r24` / `br24` | 24px | 바텀시트 상단 모서리, 대형 다이얼로그 |
| `rFull` / `brFull` | 999px | 원형 뱃지, 필터 칩, 라운드 버튼 |

---

### 2.4 Typography Scale

숫자와 메트릭은 고정폭 폰트 기능(`FontFeature.tabularFigures()`)을 적용합니다.

| 스타일명 | 폰트 크기 | 굵기 | 높이(행간) | 특징 및 용도 |
|---|---|---|---|---|
| `heroMetric` | 40sp | w900 (Black) | 1.0 | 주간 총 거리, 홈/상세 Hero 메트릭 |
| `largeMetric` | 34sp | w900 (Black) | 1.0 | 월간 통계 수치, VO2max 메트릭 |
| `metric` | 22sp | w900 (Black) | 1.1 | 러닝 역학, 심박 드리프트 수치 |
| `metricSub` | 19sp | w900 (Black) | 1.1 | 카드 요약 행 수치, 상세 메트릭 그리드 |
| `metricLabel` | 12sp | w500 (Medium) | 1.3 | 수치 단위 라벨 (`textSecondary`) |
| `titleLarge` | 20sp | w800 (ExtraBold) | 1.3 | 앱바 타이틀, 팝업 헤더 |
| `titleMedium` | 17sp | w800 (ExtraBold) | 1.3 | 섹션 헤더 (`최근 러닝`, `러닝 역학` 등) |
| `titleSmall` | 15sp | w800 (ExtraBold) | 1.3 | 카드 서브 타이틀 |
| `bodyLarge` | 15sp | w500 (Medium) | 1.4 | 주요 목록 본문 |
| `bodyMedium` | 13.5sp | w400 (Regular) | 1.5 | AI 코칭 코멘트, 가이드 본문 |
| `bodySmall` | 12sp | w400 (Regular) | 1.4 | 캡션 가이드, 도움말 텍스트 |
| `caption` | 11sp | w400 (Regular) | 1.3 | 보조 정보, 타임스탬프 |
| `captionBold` | 11sp | w700 (Bold) | 1.3 | 캘린더 요일, 상태 강조 태그 |

---

### 2.5 Icon Sizes

| 토큰 | 크기 | 용도 |
|---|---|---|
| `iconXs` | 14px | 인라인 화살표 증감치, 보조 상태 아이콘 |
| `iconSm` | 16px | AI 자동 생성 별표, 카드 서브 아이콘 |
| `iconMd` | 20px | 훈련 부하 번개 아이콘, 리스트 트레일링 |
| `iconLg` | 24px | 앱바 액션 버튼, 다이얼로그 아이콘 |
| `iconXl` | 32px | 레벨 뱃지 내부 아이콘 |
| `iconHero` | 58px | 레벨 뱃지 외곽 원형 컨테이너 |

---

## 3. Flutter 구현 아키텍처

- `AppDesignTokens` (ThemeExtension) 및 정적 토큰 네임스페이스 (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIconSizes`)
- `ThemeData.extension<AppDesignTokens>()` 등록 및 `context.tokens` 확장 메서드 지원
- 기존 하드코딩된 값 완벽 마이그레이션

---

## 5. 재사용 UI 프리미티브 및 상태

### AI 보고서 점진적 공개
- **요약 카드**: AI 원문의 첫 문장을 임의 절단하지 않고 `[핵심 요약]` 또는 `[다음 1~2주 목표]` 섹션만 2~3줄로 제한해 표시한다.
- **전체 보고서 바텀시트**: `cardElevated`, `r24`, `s24` 토큰을 사용하며 화면 높이의 40~92%에서 드래그할 수 있다. 본문은 스크롤 및 텍스트 선택을 지원한다.
- **상태**: API 키 미설정, 생성 전, 생성 중, 생성 실패, 캐시 완료 상태를 서로 배타적으로 표시한다. 캐시된 내용은 API 키가 제거되어도 계속 읽을 수 있다.
- **접근성**: 닫기 액션에 툴팁을 제공하고 전체 보고서 영역에 의미론적 레이블을 부여한다.
