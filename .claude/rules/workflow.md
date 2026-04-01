# 작업 방식

## 기본 원칙
- 추측하지 않는다. 모르면 "모릅니다"라고 말한다.
- 파일 경로, 함수명, 필드명을 지어내지 않는다.
- 단계별로: 읽기 → 이해 → 계획 → 구현 → 검증

## 복잡한 작업
TodoWrite로 단계를 나누고, 완료 즉시 상태 업데이트.
한 번에 하나의 in_progress 항목만 유지.

## 완료 처리
작업 완료 후 `docs/작업일지.md`에 기록.
세션 종료 전 `memory/sprint_status.md` 다음 작업 항목 갱신.

## 도구 사용 우선순위
| 작업 | 도구 |
|------|------|
| 파일 읽기 | Read (cat 금지) |
| 파일 검색 | Glob (find 금지) |
| 내용 검색 | Grep (grep 금지) |
| 파일 수정 | Edit (sed/awk 금지) |
| 새 파일 | Write |
| 탐색/조사 | Explore agent |

## Dart/Flutter 빌드
```bash
cd merchant_local
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드 생성
flutter build apk --release
```
