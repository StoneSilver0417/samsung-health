# RunLog - Handoff

## 현재 상태

- **버전**: v1.6.8+20 — 보안·안정성 패치 완료 (2026-09-02)
- **빌드 상태**:
  - `flutter test` **32/32 PASS** (8개 파일)
  - `flutter analyze` **No issues found**
  - `flutter build apk --debug` **✓ 성공** (APK 생성 확인)
  - `flutter build apk --release` → `key.properties` 없으면 **의도적 빌드 실패** (fail-closed 서명 가드 정상 작동)
- **커밋 상태**: 9개 원자적 커밋 완료 (미푸시 상태, `origin/main` 대비 9 ahead)

## 최근 작업 (2026-09-02 보안·안정성 패치)

| 커밋 | 내용 |
|------|------|
| `chore: flutter_secure_storage, convert 의존성 추가` | pubspec.yaml/lock 업데이트 |
| `fix: release 서명 미설정 시 빌드 실패(fail-closed) 처리` | `build.gradle.kts` — key.properties 없으면 빌드 차단 |
| `fix: Android 백업 차단 및 데이터 추출 규칙 추가` | `allowBackup=false`, `backup_rules.xml`, `data_extraction_rules.xml` |
| `fix: Health Connect 페이지네이션 및 세션 출처 필터링 적용` | `MainActivity.kt` readAllRecords 페이지네이션, 세션 출처 기준 데이터 필터 |
| `fix: Hive 데이터 AES-256 암호화 마이그레이션 및 API 키 secure storage 이전` | `run_repository.dart` — 박스 v2로 마이그레이션, Gemini 키 secure storage |
| `fix: 동시 mutation 직렬화 큐 추가 및 RunsNotifier 적용` | `mutation_queue.dart` 신규, `providers.dart` 전체 큐 통과 |
| `fix: APK 업데이트 다운로드 redirect 호스트 검증 및 SHA-256 강화` | `update_service.dart` — redirect allowlist 재검증, .part 임시파일 원자적 rename |
| `fix: UI 비동기 mounted/finally 가드, 버전 라벨 동적화, 차트 경계 수정` | 5개 UI 파일 mounted 가드, `package_info_plus` 런타임 버전, `safePaceRange()` |
| `test: Gemini 평균 페이스, 수동 ID, 차트 경계 테스트 추가 및 분석 설정 개선` | 4개 신규 테스트, `gemini_service.dart` averagePaceSecPerKm 헬퍼 |

## 알려진 이슈 (기존 → 해결 여부)

- ~~홈 화면 버전 라벨 하드코딩~~ → **해결** (`_loadVersion()` 런타임 로드)
- ~~자동 업데이트 redirect 검증 미흡~~ → **해결** (allowlist 재검증 + 최대 3회 제한)
- ~~Hive 데이터 평문 저장~~ → **해결** (AES-256 암호화 마이그레이션)
- ~~동시 sync/import 경쟁 조건~~ → **해결** (MutationQueue 직렬화)
- ~~비동기 UI mounted 미가드~~ → **해결** (5개 화면 전반)
- **스플릿이 평균 페이스로만 나옴** — 삼성헬스 HC 정책 한계 (해결 불가)
- **자동 업데이트 다운로드·설치 플로우** — 코드 강화 완료, 실기기 검증 전
- **캘린더·월간 분석·AI 추천** — 코드 검증만, 실기기 확인 전

## 다음 TODO

### 즉시 (기기 테스트)
1. [ ] `git push origin main` — 9개 패치 커밋 원격 반영
2. [ ] 폰에서 앱 최초 실행 → Hive v2 마이그레이션 정상 완료 및 기존 데이터 유지 확인
3. [ ] 폰에서 Gemini AI 요약 생성 → API 키 secure storage 정상 읽기 확인
4. [ ] 폰에서 동기화(↻) 두 번 동시 탭 → 중복 저장 없는지 확인 (MutationQueue)
5. [ ] 폰에서 \"업데이트 확인\" → 실제 다운로드·설치 플로우 검증 (redirect allowlist)
6. [ ] 릴리즈 APK 서명: `android/key.properties` + keystore 준비 후 `flutter build apk --release`

### 보류 (Phase 2 후보)
7. [ ] 23일 러닝 프로그램 트래커
8. [ ] 목표 설정 기능
9. [ ] 공유 카드
10. [ ] 데이터 내보내기 (CSV/GPX 백업)
11. [ ] 캘린더 히트맵 고도화, 업적 Lottie 애니메이션
12. [ ] 진단 화면(`debug_screen.dart`) 프로덕션 유지 여부 결정

## 빌드 환경 (서버 기준 — /root)

```bash
export ANDROID_HOME=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/opt/flutter/bin:$PATH"

flutter test                    # 32/32 PASS
flutter analyze                 # No issues
flutter build apk --debug       # ✓ 정상
flutter build apk --release     # key.properties 없으면 의도적 실패 (정상)
```

- Flutter v3.47.2 / Dart v3.13.2 (`/opt/flutter`)
- JDK 21 (`/usr/lib/jvm/java-21-openjdk-amd64`)
- Android SDK 36 (`/opt/android-sdk`, platforms 34/35/36, build-tools 34/35/36)
- **로컬(Windows) 빌드**: `flutter config --jdk-dir=C:\java\jdk-21.0.11+10` — 시스템 JAVA_HOME(JDK 11) 사용 금지
