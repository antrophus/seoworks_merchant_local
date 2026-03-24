# CLAUDE.md

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

---

## 현재 진행 상태 (세션 인계 메모)

> 이 섹션은 새 세션 시작 시 컨텍스트 복원용입니다. 작업 완료 후 업데이트하세요.

### 완료된 작업 (2026-03-23)
- [x] 프로젝트 기획 및 방향 확정
- [x] `CLAUDE.md` 작성
- [x] `docs/PRD.md` 작성 — 기능 정의, MoSCoW 우선순위, 성공 지표 포함
- [x] `docs/architecture.md` 작성 — 스택 선택, API 설계, 디렉토리 구조, 3단계 로드맵
- [x] `docs/작업일지.md` 작성

### 다음 세션에서 해야 할 작업 (Phase 1 시작)
1. **백엔드 구조 결정** — Express 별도 서버 vs Next.js API Routes (사용자 결정 필요)
2. **프로젝트 초기 세팅** — Vite + React + TypeScript + Tailwind + shadcn/ui 설치
3. **InputPanel UI 구현** — 상품 정보 입력 폼 + 이미지 업로드
4. **PreviewPanel UI 구현** — 생성 결과 미리보기 영역

### 미결 결정 사항
| 항목 | 옵션 A | 옵션 B |
|------|--------|--------|
| 백엔드 구조 | Express 별도 서버 | Next.js API Routes (풀스택) |
| 출력 형식 | HTML + Tailwind 인라인 | React 컴포넌트 코드 |
| 이미지 저장소 | 로컬 파일 | S3 / Cloudflare R2 |

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
