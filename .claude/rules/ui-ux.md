# UI/UX 작업 규칙

## ui-ux-pro-max 스킬 필수 적용

다음 작업 전 반드시 ui-ux-pro-max 스킬을 먼저 호출한다:
- 새 페이지/화면 설계
- UI 컴포넌트 생성 또는 리팩토링
- 색상 시스템, 폰트, 간격 결정
- 반응형, 애니메이션, 네비게이션 구현

순서: 스킬 호출 → 업종/스타일/색상 결정 → 구현

## 21st Magic MCP

컴포넌트 직접 작성 전 `/ui`로 먼저 검색한다.
- 버튼, 카드, 폼, 테이블, 모달, 네비게이션
- 브랜드/서비스 로고: `/logo`

## Flutter UI 원칙
- `ListView.builder` 사용 (SliverPersistentHeader 사용 금지 — 크래시 발생 이력)
- `GroupCard(ExpansionTile)` 패턴으로 그룹 뷰 구현
- 선택 모드 진입 시 키보드 자동 숨김 (`FocusScope.of(context).unfocus()`)
