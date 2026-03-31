# CLAUDE.md

---

## 배포 빠른 참조

> 상세 내용: [`docs/배포-가이드.md`](docs/배포-가이드.md)

### 릴리즈 APK 빌드

```bash
cd merchant_local
flutter build apk --release
# 결과: build/app/outputs/flutter-apk/app-release.apk
```

### APK 배포 (파일 전달 후 설치, 마켓 제외)

1. **전달**: 카카오톡 파일 / Google Drive 링크 / USB 복사
2. **설치**: 기기에서 APK 파일 열기 → "출처를 알 수 없는 앱 허용" → 설치
3. **업데이트**: 동일 서명 키 APK로 덮어쓰기 설치 → 데이터 보존

### 데이터 JSON 전달

- **내보내기**: 앱 → 설정 → 데이터 내보내기 → JSON 백업 → 공유 시트로 전송
- **가져오기**: 앱 → 설정 → 데이터 가져오기 → JSON 파일 선택
- API 키는 JSON에 미포함 → 각 기기에서 직접 입력

### 서명 키 (분실 금지 ⚠️)

| 파일 | 경로 |
|------|------|
| 키스토어 | `merchant_local/android/app/upload-keystore.jks` |
| 키 설정 | `merchant_local/android/key.properties` (git 제외) |
| 비밀번호 | `seoworks2026` |

---

## 프로젝트 정보
- **프로젝트명**: Seoworks Merchant Local
- **기술 스택**: Flutter + Dart + Drift + Google Drive Sync + CRDT
- **목적**: seoworks merchant web을 완전한 데이터 주권을 확보를 위해 모바일 앱으로 구현하는 프로젝트

---

## UI/UX 작업 규칙

### 필수 스킬 사용
UI 구조, 시각 디자인, 컴포넌트, 레이아웃, 색상, 타이포그래피, 반응형, 접근성에 관련된 모든 작업에서 **ui-ux-pro-max 스킬을 반드시 적용**한다.

적용 기준:
- 새 페이지 또는 화면 설계 시
- UI 컴포넌트 생성 및 리팩토링 시
- 색상 시스템, 폰트, 간격 기준 결정 시
- UI 코드 리뷰 및 품질 개선 시
- 반응형, 애니메이션, 네비게이션 구현 시

### 21st Magic MCP 사용
컴포넌트가 필요한 경우 직접 코드를 작성하기 전에 **21st Magic MCP로 먼저 검색**한다.

- 버튼, 카드, 폼, 테이블, 모달, 네비게이션 등 UI 컴포넌트 생성 시 `/ui` 활용
- 브랜드/서비스 로고가 필요한 경우 `/logo` 활용

---

## 코딩 규칙

- 요청된 것만 구현한다. 불필요한 기능 추가, 리팩토링, 주석 추가 금지
- 새 파일보다 기존 파일 수정을 우선한다
- 보안 취약점(XSS, SQL Injection, 명령어 인젝션 등) 주의
- 커밋은 명시적으로 요청받을 때만 실행한다
- Claude API 호출 시 `claude-sonnet-4-6` 모델 기본 사용

---

## 작업 방식

- 복잡한 작업은 TodoWrite로 단계를 나눠 진행한다
- UI 작업 전 ui-ux-pro-max 스킬로 업종/스타일/색상을 먼저 결정한다
- 작업 완료 후 `docs/작업일지.md`에 내용을 기록한다

---

## 주요 문서 경로

| 문서 | 경로 |
|------|------|
| 작업일지 | `docs/작업일지.md` |
| PRD | `docs/PRD.md` |
| 기술 아키텍처 | `docs/architecture.md` |
| Google Drive 동기화 가이드 | `merchant_local/docs/google-drive-sync-guide.md` |

---

## 현재 진행 상태 (세션 인계 메모)

> 이 섹션은 새 세션 시작 시 컨텍스트 복원용입니다. 작업 완료 후 업데이트하세요.

### 완료된 작업 (2026-03-23)
- [x] 프로젝트 기획 및 방향 확정
- [x] `CLAUDE.md`, `docs/PRD.md`, `docs/architecture.md` 작성

### 완료된 작업 (2026-03-24~25) — Phase 2-A + 2-B
- [x] Phase 2-A: 대시보드 강화, 판매 내역 페이지, SizePicker 고도화, 검수 반려, 배치 구매
- [x] Phase 2-B: 분석 대시보드(fl_chart), 하자/물류/구매 전용 페이지, 인벤토리 정렬 확장, 데이터 내보내기

### 완료된 작업 (2026-03-26) — 코드리뷰 기반 품질 개선
- [x] Critical/High/Medium 이슈 14건 수정 (CSV Injection, FK cascade, 인덱스 14개, 지수 백오프, 상태 전이 검증 등)

### 완료된 작업 (2026-03-28) — Sprint 3 + 성능 최적화 + 4개 페이지 리뉴얼
- [x] Sprint 3: 인벤토리 그룹 뷰 `ListView.builder + GroupCard(ExpansionTile)` 재설계 (SliverPersistentHeader 크래시 수정)
- [x] SQLite WAL 모드 + synchronous=NORMAL + cache_size 64MB pragma 설정
- [x] N+1 → 배치 조회 (`getProductsByIds`), `Future.wait` 병렬 처리
- [x] Dashboard FutureProvider 5개에 `ref.watch(itemsProvider)` 의존성 추가
- [x] `didUpdateWidget` id:updatedAt 키 비교로 불필요한 재실행 방지
- [x] 하자 관리 반려 이력 — 현재 상태 뱃지(`_StatusBadge`) 추가
- [x] 분석 화면: 현재연도=1월1일~오늘 / 과거연도=전체, DateRangePicker 추가
- [x] 물류 추적: 날짜+송장 그룹화, 그룹 헤더(갯수·판매가·정산가·이익률), 월별 요약 헤더
- [x] 구매 내역: 날짜+구매처 그룹화, 상단 통계(구입수·구매액·반품수·반품액·판매수), 기간 필터
- [x] 판매 내역 이번달/지난달 버그: `COALESCE(settled_at, sale_date)` 기준으로 수정
- **전체 이식률: 92%**

### 완료된 작업 (2026-03-29) — 버그 수정 + 브랜드 선택 UI
- [x] 구매 내역: 반품/반품액 0 버그 (`EXISTS` 서브쿼리 + 상태 조건 추가)
- [x] 구매 내역: 구매처 수정 후 미반영 (`ref.watch(itemsProvider)` 추가)
- [x] 상태 변경 후 상세 페이지 미갱신 → `_itemProvider` StreamProvider 전환 + `watchById` 추가
- [x] SETTLED→SETTLED 에러 → `showStatusActionSheet` Completer 적용
- [x] 입고 등록: model_code UNIQUE 제약 에러 → 저장 전 중복 체크
- [x] 브랜드 선택: 검색 시트 + 최근 선택 칩 핀 기능 추가

### 완료된 작업 (2026-03-31) — Google Drive 동기화 설계
- [x] Google Drive 동기화 구현 가이드 작성 (`merchant_local/docs/google-drive-sync-guide.md`)
- [x] 동기화 아키텍처 결정: 동일 계정 방식 + appDataFolder + CRDT(HLC) 충돌 해결
- [x] DB 마이그레이션 v4→v5 계획 (16개 테이블에 hlc + isDeleted 추가)
- [x] migration plan Sprint 5 섹션 업데이트

### 다음 세션 작업
- **Phase 3 (Google Drive 동기화)**: `merchant_local/docs/google-drive-sync-guide.md` 참조
  - 사전 준비: Google Cloud Console OAuth 설정 + `google-services.json` 필요
  - 구현 순서: Phase 3-1(DB 마이그레이션) → 3-2(HlcClock) → 3-3(DAO 수정) → 3-4(Drive Service) → 3-5(SyncEngine) → 3-6(UI) → 3-7(자동 동기화)
- **잔여 이슈**: INV-09 재고 위치별 탭 미구현, 캘린더 뷰(CAL-01~03), 이미지 저장 로직 확인
- 상세: `merchant_local/docs/web-to-local-migration-plan.md` 참조

### 설치된 도구 (전역)

새 컴퓨터에서 아래 순서대로 실행하면 동일 환경 구성 완료.

#### 1. ui-ux-pro-max 스킬 (7개) 설치
```bash
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git
cp -r ui-ux-pro-max-skill/.claude/skills/banner-design ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/brand ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/design ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/design-system ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/slides ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/ui-styling ~/.claude/skills/
cp -r ui-ux-pro-max-skill/.claude/skills/ui-ux-pro-max ~/.claude/skills/
```

#### 2. 21st Magic MCP 등록 (user scope — 모든 프로젝트 적용)
```bash
claude mcp add magic --scope user --env API_KEY="9db4e05d9f1cb7931663579a60e52089bae4fc987823b3c048419005a39ebed8" -- npx -y @21st-dev/magic@latest
```
> Windows에서 `claude` 명령어가 PATH에 없을 경우 claude.exe 전체 경로로 실행:
> `"C:\Users\[username]\AppData\Roaming\Claude\claude-code\[version]\claude.exe" mcp add magic ...`
