# RunLog - Handoff

## 현재 상태

- **버전**: v1.6.3+15 — 개발 재개 (2026-07-23, 삼성헬스 동기화 정상화 확인됨)
- **빌드 상태**: v1.6.0 기능 전부 + AI 요약 버그 수정 3건(잘림/사고과정 노출/400 에러) 반영해 빌드 완료 (58.3MB)
- **배포 상태**: GitHub 저장소 공개 전환 완료, v1.6.0~v1.6.3 Release 전부 생성 완료.
  v1.6.3 폰 설치 및 AI 러닝 요약 실기기 정상 동작 확인 완료 (2026-07-23)
- **실행 방법**: `flutter run` 또는 `flutter build apk --release` (JDK 21, `unset JAVA_HOME` 필요 — 시스템 JAVA_HOME이 깨진 JDK11)

## 최근 작업

- **2026-07-23 (v1.6.3)**: AI 요약 요청이 400 INVALID_ARGUMENT로 실패하는 버그 수정
  - v1.6.1에서 넣은 `thinkingConfig` 필드가 실제 라우팅되는 모델 버전에서 미지원 필드라
    요청 자체가 거부됨. 필드를 완전히 제거하고 `maxOutputTokens`를 2048로 상향, 대신
    v1.6.2의 `thought:true` 필터링에 의존하는 방식으로 전환 (모델이 사고를 하든 말든
    결과만 걸러 쓰므로 모델 버전 변화에 더 안전함)
- **2026-07-23 (v1.6.2)**: AI 러닝 요약에 모델의 "사고 초안"이 그대로 노출되는 버그 수정
  - v1.6.1 수정(thinkingBudget:0)만으로는 부족했음 — 실기기 재현: "*Sentence 3: Heart rate
    efficiency/coaching"처럼 답변이 아닌 개요/메모 텍스트가 그대로 표시됨
  - 원인: Gemini 응답 `content.parts`에 `thought:true` 사고 초안 파트가 섞여 오는데
    기존 코드는 파트 종류 구분 없이 전부 이어붙이고 있었음
  - 수정: `lib/services/gemini_service.dart`에서 `thought:true` 파트를 걸러내고
    최종 답변 파트만 사용하도록 방어적 필터링 추가
- **2026-07-23 (v1.6.1)**: AI 러닝 요약 문장이 중간에 끊기는 버그 수정
  - 원인: `gemini-flash-latest`의 기본 사고(thinking) 모드가 `maxOutputTokens` 예산을
    답변보다 먼저 소모해 텍스트가 잘림
  - 수정: `generationConfig.thinkingConfig.thinkingBudget: 0` 추가, `maxOutputTokens` 400→500
- **2026-07-23 (v1.6.0)**: 앱 자동 업데이트 + AI 러닝 요약(Gemini API) 기능 추가
  - GitHub 저장소를 공개로 전환 (자동 업데이트가 Releases API를 인증 없이 조회하려면 필요.
    PRD·코드·커밋이력에 개인정보·비밀정보 없음 확인 후 전환)
  - `lib/services/update_service.dart`: 홈 진입 시 조용히 최신 버전 확인, 있으면 다이얼로그로
    다운로드·설치(open_filex) 안내. 메뉴에 "업데이트 확인" 수동 실행도 추가
  - `lib/services/gemini_service.dart` + `lib/ui/settings_screen.dart`: 러닝 상세 화면에
    "AI 러닝 요약" 카드 추가. API 키는 설정 화면에서 입력해 기기 로컬(Hive)에만 저장 — 코드에
    하드코딩하지 않음
  - **중요**: 앞으로 새 버전 배포 시마다 `vX.Y.Z` 태그 + APK 첨부한 GitHub Release 생성 필수
    (안 하면 자동 업데이트가 무용지물)
- **2026-07-23**: 삼성헬스 업데이트로 동기화 재개됐으나 7/1~7/13 구간 기록이 안 잡히는 문제 확인
  - **원인**: `sync()`가 새 데이터 유무와 무관하게 매번 `lastSyncedAt`을 현재 시각으로 갱신해,
    장애 기간에도 커서가 계속 전진 → 장애 해소 후에도 이미 지나친 구간을 다시 조회하지 않음
    (RunLog만의 버그, 삼성헬스 버그와는 별개)
  - **수정**: `sync()`가 커서 없이 매번 최근 30일을 고정 스캔하도록 변경 (UUID dedupe로 안전)
  - **확인 결과**: 7/1~7/13 구간은 Health Connect 자체에 데이터가 없음(영구 유실) 확인 — 복구 불가
  - **대응**: "기록 수동 추가" 기능 신설 (`lib/ui/manual_add_screen.dart`, 홈 메뉴 진입)

## 알려진 이슈

- 스플릿이 평균 페이스로만 나옴 — 삼성헬스가 HC에 상세 데이터를 안 내보내는 정책 한계 (해결 불가)
- 홈 화면 버전 라벨(`home_screen.dart`)이 하드코딩 문자열 — pubspec.yaml 버전 올릴 때마다 수동으로 같이 바꿔야 함
- 자동 업데이트 다운로드·설치 플로우 자체(앱 내 "업데이트 확인"으로 새 버전 받기)는 아직 미검증
  (지금까지는 매번 수동 설치로 테스트함 — 다음 배포 때 실제로 검증 필요)

## 다음 TODO

1. [ ] 폰에서 정기 동기화(↻)가 최근 30일을 매번 재스캔하는지, 중복 저장 없는지 확인
2. [ ] 다음 버전 배포 때 "업데이트 확인" 메뉴로 실제 자동 업데이트 다운로드·설치 플로우 검증
3. [ ] 진단 화면(`debug_screen.dart`, `getRawSessions`/`getPlannedSessions`)을 프로덕션에 남길지 제거할지 결정
4. [ ] GitHub Release 태그(v1.5.1)와 실제 버전(1.5.5) 불일치 정리 — v1.6.0부터는 태그·버전 일치 유지

**Phase 2 후보 (보류):**
5. [ ] 23일 러닝 프로그램 트래커
6. [ ] 목표 설정 기능
7. [ ] 공유 카드
8. [ ] 데이터 내보내기 (CSV/GPX 백업)
9. [ ] 캘린더 히트맵 고도화, 업적 Lottie 애니메이션
