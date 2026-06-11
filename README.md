# RunLog — 러닝 기록 분석 & 동기부여 앱

삼성헬스(Galaxy Watch) 러닝 데이터를 **Health Connect** 경유로 가져와
추세 분석·업적(배지)·시각화를 제공하는 개인용 Flutter 앱.

📄 상세 기획: [러닝앱_PRD.md](러닝앱_PRD.md)

## 현재 상태 — Phase 1 MVP

- [x] Health Connect 권한 플로우 + 러닝 세션 읽기 (증분 동기화, UUID dedupe)
- [x] km별 스플릿·심박존(Z1~Z5) 산출 (거리 델타/심박 시계열 기반)
- [x] 홈 대시보드: 주간 요약 링(거리/횟수), 누적 통계, 주3회 스트릭
- [x] 기록 리스트 + 상세 (심박 차트, 심박존 분포, 스플릿)
- [x] 분석 탭: 주간 거리 바차트(8주), 평균 페이스 추이, PB
- [x] 업적 16종 (NRC 스타일 커스텀 배지 이미지): 거리(1ST/5K/10K) · 누적(50/100/250/500K)
      · 시간(10/20/30/60분) · 꾸준함(주3회/2주·4주 스트릭/월간 개근) · 야간 러너
- [x] 러너 레벨 시스템 (누적 거리: 옐로우 → 오렌지 → 그린 → 블루 → 퍼플 → 블랙 → 볼트)
- [x] 세분화 지표: 평균/최고 심박, 케이던스(spm), 걸음 수, 칼로리, km 스플릿, 심박존
- [x] 저장소: Hive 로컬 (Firestore는 Phase 2에 repository 어댑터로 추가 예정)
- [x] 데모 데이터 모드 (워치 없이 UI 확인)
- [x] **이전 기록 가져오기**: 기간 선택(1/3/6/12개월) → 과거 러닝 검색 → 원하는 것만 선택해 추가
      (30일 이전은 헬스 커넥트 "과거 데이터" 히스토리 권한 자동 요청)

## 빌드 & 설치

```bash
flutter pub get
flutter build apk --debug      # 또는 flutter run (폰 USB 연결)
```

APK 위치: `build/app/outputs/flutter-apk/app-debug.apk`

## 사용 전 필수 설정 (중요 ⚠️)

1. **삼성헬스 → Health Connect 동기화 켜기**
   삼성헬스 앱 > 설정 > 헬스 커넥트 > 데이터 동기화 활성화
2. 폰에 **Health Connect(헬스 커넥트)** 설치 확인 (Android 14+는 기본 내장)
3. RunLog 첫 실행 시 권한 허용 (운동, 심박수, 거리 등 읽기)

> **30일 제한**: Health Connect는 앱이 최초 권한을 받은 시점 기준
> **과거 30일 이전 데이터는 읽을 수 없습니다.** 러닝 기록 보존을 위해
> 가능한 빨리 설치·권한 허용을 해두세요. 동기화된 데이터는 앱 로컬에 영구 저장됩니다.

## 테스트

```bash
flutter test       # 스플릿 산출·통계·스트릭 로직 단위 테스트
flutter analyze
```

## 구조

```
lib/
├── main.dart                  # 앱 진입점, 4탭 셸 (홈/기록/분석/업적)
├── providers.dart             # Riverpod 프로바이더 + 동기화 오케스트레이션
├── models/                    # RunSession, Split, 배지 정의
├── data/run_repository.dart   # 저장소 추상화 + Hive 구현 (dedupe)
├── services/health_service.dart  # Health Connect 읽기, 스플릿/다운샘플링
├── logic/                     # 주간 통계·스트릭·PB, 업적 평가 엔진
└── ui/                        # 다크+네온 테마 화면들
```

## 로드맵

- **Phase 2**: 캘린더 히트맵, 업적 전체 세트+획득 애니메이션, 23일 프로그램 트래커, 공유 카드
- **Phase 3**: 목표/챌린지, GPS 경로 지도, 홈 위젯
- **Phase 4**: Firestore 백업 + 웹 대시보드
