# RunLog (러닝앱) — 프로젝트 규칙

> 베이스 규칙: `D:\workspace\AGENTS.md`를 먼저 읽고 따른다. (자동 로드되지 않은 경우 직접 읽을 것)
> 현재 진행 상태·TODO는 `handoff.md`, 과거 이력은 `CHANGELOG.md` 참고.

## 개요
- 삼성헬스(Galaxy Watch 7) 러닝 데이터를 Health Connect로 가져오는 개인용 분석·동기부여 앱
- PRD: `러닝앱_PRD.md` (v1.0) — 사용자는 야간 러너, 23일 러닝 프로그램(30분 연속 → 5km 목표) 진행 중
- GitHub: StoneSilver0417/samsung-health (비공개)

## 기술 스택
- Flutter + health 패키지(Health Connect) + Hive(로컬 저장) + Riverpod + fl_chart
- Firestore는 Phase 2 어댑터 예정 (Firebase 무료 티어 전략)
- UI: 4탭 다크 네온 테마, 이모지 미사용

## 주요 명령어
```bash
flutter pub get               # 의존성 설치
flutter test                  # 테스트
flutter build apk --release   # 릴리즈 APK
flutter run                   # 디버그 실행
```
- 업적 배지 PNG 생성: `tools/badges.html` → 로컬 http 서버 + Playwright `?only=ID` 엘리먼트 스크린샷

## 빌드 환경 (중요)
- **JDK 21 필수**: `flutter config --jdk-dir=C:\java\jdk-21.0.11+10` 설정됨
- 시스템 JAVA_HOME은 깨진 JDK 11 — 그걸로 빌드하면 TLS handshake 실패함. JAVA_HOME 쓰지 말 것
- Android SDK 라이선스는 licenses 파일 직접 생성으로 수락됨

## 플랫폼 제약 (코드로 해결 불가)
- 삼성헬스가 Health Connect에 인터벌 세그먼트·상세 거리 시계열을 안 내보냄 → 스플릿은 평균 페이스로만 표시 (삼성 정책)
- Health Connect 30일 제한: 권한 받은 시점 이전 30일+ 데이터는 영구 접근 불가
- 삼성헬스 → HC 동기화는 삼성헬스 설정에서 수동 활성화 필요
