# CLAUDE.md

## 프로젝트
Seoworks Merchant Local — Flutter + Dart + Drift(SQLite) + Riverpod + CRDT
목적: 판매자 웹앱을 완전한 데이터 주권의 모바일 앱으로 구현

## 접근 방식
- 실행 전 읽어라. 코드 작성 전 관련 파일을 먼저 읽는다.
- 읽은 파일은 다시 읽지 않는다 (변경된 경우 제외).
- 요청된 것만 구현한다. 범위 밖 코드 수정 금지.
- 불필요한 기능 추가, 리팩토링, 주석, 타입 추가 금지.
- 새 파일보다 기존 파일 수정 우선.
- 커밋은 명시적 요청 시에만.
- 도구 호출 50회 예산 내 효율적으로 작업한다.

## UI/UX 규칙 (.claude/rules/ui-ux.md 참조)
- UI 작업 전 **ui-ux-pro-max 스킬 필수** 적용
- UI 컴포넌트 작성 전 **21st Magic MCP(/ui)** 먼저 검색

## 작업 방식 (.claude/rules/workflow.md 참조)
- 복잡한 작업: TodoWrite로 단계 분리
- 완료 후: docs/작업일지.md 기록

## 핵심 경로
| 항목 | 경로 |
|------|------|
| 앱 소스 | merchant_local/lib/ |
| 작업일지 | docs/작업일지.md |
| 현재 스프린트 | memory/sprint_status.md |
| Drive 동기화 가이드 | merchant_local/docs/google-drive-sync-guide.md |

## 서명 키
키스토어: `merchant_local/android/app/upload-keystore.jks` / PW: 별도 보관 (CLAUDE.local.md 또는 개인 메모)
APK 빌드: `cd merchant_local && flutter build apk --release`

## Claude API
모델: `claude-sonnet-4-6`
