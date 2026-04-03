---
name: sprint_status
description: 현재 스프린트 우선순위 및 세션 인계 메모 (새 세션 시작 시 필독)
type: project
---

# 스프린트 현황 (2026-04-04 기준)

## ⚠️ 다음 세션 최우선 작업 — Google Drive 동기화 완성

### 결정된 구현 방식: Desktop OAuth 클라이언트 공용 사용

**시행착오 요약 (이 방향들은 전부 실패 — 다시 시도하지 말 것):**

| 시도 | 실패 이유 |
|------|----------|
| `appDataFolder` 스코프 | OAuth 클라이언트별 격리 → 기기 간 공유 불가 |
| `drive.file` 스코프 | 동일하게 클라이언트별 격리 |
| `drive` 스코프 + OAuth | Android GMS가 미검증 앱의 restricted scope 차단 (ApiException: 10). 테스트 계정 등록·Cloud Console 등록 모두 소용없음 |
| 서비스 계정 방식 | 개인 Google 계정에는 저장 할당량 없음 (403). Shared Drive는 Google Workspace 유료 전용 |

**✅ 채택된 방식: Desktop OAuth 클라이언트 + `drive.file` + 브라우저 OAuth**

핵심 원리:
- Android와 Windows가 **동일한 OAuth 클라이언트 ID** 사용 → 같은 파일 공유 가능
- `drive.file`은 민감하지 않은(non-sensitive) 스코프 → Google 심사 불필요
- Android에서 `google_sign_in` 플러그인 대신 **브라우저 기반 OAuth** 사용 → GMS 차단 없음
- 토큰을 `flutter_secure_storage`에 저장 → 앱 재시작 시 자동 복원

---

### 다음 세션 구현 계획

**현재 코드 상태:**

| 파일 | 현재 상태 |
|------|----------|
| `google_drive_service.dart` | 서비스 계정 방식 (작동 안 함) — 전면 교체 필요 |
| `pubspec.yaml` | `google_sign_in` 제거됨, `assets/service_account.json` 등록됨 |
| `main.dart` | `connect()` 호출 방식 (서비스 계정) |
| `settings_screen.dart` | 로그인 UI 없는 상태 |

**구현 단계:**

1. **`pubspec.yaml`**
   - `url_launcher` 재추가 (브라우저 OAuth에 필요)
   - `assets/service_account.json` 항목 제거 (서비스 계정 파일 불필요)

2. **`google_drive_service.dart` 전면 교체**
   - 서비스 계정 코드 전부 삭제
   - Desktop OAuth 클라이언트 ID/Secret 사용 (`google_oauth_secrets.dart`에 있음)
   - `signIn()`: `auth.clientViaUserConsent()` — 브라우저 열어 OAuth (Android/Windows 동일)
   - `trySilentSignIn()`: `flutter_secure_storage`에서 토큰 복원 시도
   - `signOut()`: 토큰 삭제
   - 스코프: `drive.file`
   - 파일 저장 위치: `drive.file` 스코프 + 공유 폴더 (한 계정으로 로그인하면 같은 파일 보임)

3. **`main.dart`**: `connect()` → `trySilentSignIn()`으로 복원

4. **`settings_screen.dart`**: 로그인/로그아웃 버튼 복원

**중요 — `drive.file` 공유 방식:**
`drive.file`은 같은 클라이언트 ID로 만든 파일만 보이므로,
Android에서 로그인한 계정과 Windows에서 로그인한 계정이 **동일한 Google 계정**이어야 함.
같은 계정, 같은 클라이언트 ID → 같은 파일 공유 ✅

**참고 파일:**
- Desktop OAuth 클라이언트 ID/Secret: `lib/core/services/google_oauth_secrets.dart` (gitignored)
- 토큰 저장소: `flutter_secure_storage` (이미 `pubspec.yaml`에 있음)

---

## 완료된 작업

| 항목 | 완료일 |
|------|--------|
| Drift DB / HLC / SyncEngine / SyncScheduler 구현 | 2026-04-03 |
| 코드리뷰 / OAuth secret 보안 분리 | 2026-04-03 |
| 릴리즈 APK 빌드 (83 MB) | 2026-04-03 |
| Galaxy Z Fold 설정화면 하단 safe area 수정 | 2026-04-03 |
| 앱 이름 → SEOWORKS | 2026-04-03 |

## 동기화 완성 후 다음 작업

1. **UX: 미등록 필터 전체 선택**
2. **INV-09: 재고 위치별 탭**
3. **CAL-01~03: 캘린더 뷰**

---

## 핵심 경로

| 항목 | 경로 |
|------|------|
| 동기화 서비스 | `merchant_local/lib/core/services/google_drive_service.dart` |
| OAuth 시크릿 | `merchant_local/lib/core/services/google_oauth_secrets.dart` (gitignored) |
| 설정 화면 | `merchant_local/lib/features/settings/settings_screen.dart` |
| 앱 진입점 | `merchant_local/lib/main.dart` |
| 서명 키 PW | CLAUDE.local.md 참조 |
| APK 빌드 | `cd merchant_local && flutter build apk --release` |
| ADB 설치 | `MSYS_NO_PATHCONV=1 adb -s {device} install -r {apk}` |
| 데스크탑 실행 | `cd merchant_local && flutter run -d windows` |
