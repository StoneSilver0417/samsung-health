# RunLog - Handoff

## 현재 상태

- **버전**: v1.5.5+11 (2026-07-01~02) — **개발 중단 (사용자 결정)**
- **빌드 상태**: 정상 빌드됨. GitHub Release `v1.5.1`에 최신 APK(1.5.5) 첨부되어 있음
  (태그명과 버전 라벨 불일치 — 재개 시 정리 권장)
- **배포 상태**: 개인 폰에 v1.5.5 설치됨
- **실행 방법**: `flutter run` 또는 `flutter build apk --release` (JDK 21, `unset JAVA_HOME` 필요 — 시스템 JAVA_HOME이 깨진 JDK11)

## 최근 작업

- **v1.5.1~1.5.5 (2026-07-01~02)**: "삼성헬스 업데이트 후 새 러닝 기록만 동기화 안 됨" 버그 추적
  - 세션 레벨 워크아웃 타입 필터(RUNNING만 허용)를 HIGH_INTENSITY_INTERVAL_TRAINING도
    허용하도록 확장했으나 실제 원인 아니었음 (무해하니 코드는 유지)
  - 진단 화면 추가(`lib/ui/debug_screen.dart`, 홈 메뉴 > "진단: 원본 운동 데이터"):
    health 패키지 / 네이티브 HC 직접조회 / Training Plan(PlannedExerciseSessionRecord) 3중 대조
  - **근본 원인 확정**: 문제의 러닝(6/30)이 Health Connect 자체에 없음 — 우리 앱 문제가
    아니라 삼성헬스→HC 동기화 자체가 안 된 것. 권한은 정상, 배터리 최적화가 원인으로 추정되나
    설정을 고쳐도 이미 유실된 그 기록은 복구 안 됨 (재실행/재저장/캐시삭제/재부팅 다 실패)
  - 상세 경위는 CHANGELOG.md "2026-07-01~02 (v1.5.1~1.5.5, 개발 중단)" 참고
  - **부수 발견**: adb가 이 PC에서 폰을 계속 인식 못 함 → PowerShell
    `New-Object -ComObject Shell.Application`로 MTP 연결 브라우징해 스크린샷을 직접
    가져오는 방법 사용(adb 없이 폰 화면 확인 필요할 때 재사용 가능, 상세는 CHANGELOG 참고)

## 알려진 이슈

- **[미해결·중단 시점 이슈]** 삼성헬스→Health Connect 백그라운드 동기화가 특정 러닝을
  누락시키는 문제 발생 (6/30 건). 배터리 최적화 설정 수정 후 **새 러닝부터 정상 동기화되는지
  미검증** — 재개 시 가장 먼저 확인할 것
- 스플릿이 평균 페이스로만 나옴 — 삼성헬스가 HC에 상세 데이터를 안 내보내는 정책 한계 (해결 불가)
- 홈 화면 버전 라벨(`home_screen.dart`)이 하드코딩 문자열 — pubspec.yaml 버전 올릴 때마다 수동으로 같이 바꿔야 함

## 다음 TODO

**개발 중단 상태 — 재개 시:**
1. [ ] 배터리 설정 수정 이후 새 러닝이 정상적으로 Health Connect에 동기화되는지 확인
2. [ ] 진단 화면(`debug_screen.dart`, `getRawSessions`/`getPlannedSessions`)을 프로덕션에 남길지 제거할지 결정
3. [ ] GitHub Release 태그(v1.5.1)와 실제 버전(1.5.5) 불일치 정리

**Phase 2 후보 (보류):**
4. [ ] 23일 러닝 프로그램 트래커
5. [ ] 목표 설정 기능
6. [ ] 공유 카드
7. [ ] 데이터 내보내기 (CSV/GPX 백업)
8. [ ] 캘린더 히트맵 고도화, 업적 Lottie 애니메이션
