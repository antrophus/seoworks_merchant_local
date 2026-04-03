import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:url_launcher/url_launcher.dart';
import 'google_oauth_secrets.dart';

class GoogleDriveService {
  static const _scope = 'https://www.googleapis.com/auth/drive.appdata';

  // Android: com.example.merchant_local + 등록된 SHA-1으로 인증
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_scope]);

  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;
  auth.AutoRefreshingAuthClient? _desktopClient;

  bool get isSignedIn => _driveApi != null;
  String? get accountEmail => _account?.email;
  String? get accountDisplayName => _account?.displayName;

  /// 로그인 (플랫폼별 분기)
  Future<bool> signIn() async {
    try {
      if (Platform.isWindows) {
        return await _signInDesktop();
      }
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;
      await _initDriveApiMobile();
      return true;
    } catch (e) {
      debugPrint('GoogleDriveService.signIn error: $e');
      return false;
    }
  }

  /// 앱 시작 시 자동 로그인 시도 (Android만 — Windows는 토큰 미지속)
  Future<bool> trySilentSignIn() async {
    if (Platform.isWindows) return false;
    try {
      _account = await _googleSignIn.signInSilently();
      if (_account == null) return false;
      await _initDriveApiMobile();
      return true;
    } catch (e) {
      debugPrint('GoogleDriveService.trySilentSignIn error: $e');
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    if (!Platform.isWindows) {
      await _googleSignIn.signOut();
      _account = null;
    }
    _desktopClient?.close();
    _desktopClient = null;
    _driveApi = null;
  }

  // ── 내부 초기화 ──────────────────────────────────────

  Future<void> _initDriveApiMobile() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _driveApi = drive.DriveApi(httpClient);
    }
  }

  /// Windows 데스크톱: 브라우저 기반 OAuth2
  Future<bool> _signInDesktop() async {
    final clientId = auth.ClientId(
      kDesktopOAuthClientId,
      kDesktopOAuthClientSecret,
    );
    _desktopClient = await auth.clientViaUserConsent(
      clientId,
      [_scope],
      (url) => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
    );
    _driveApi = drive.DriveApi(_desktopClient!);
    return true;
  }

  // ── 파일 업로드 / 다운로드 ────────────────────────────

  /// appDataFolder에 JSON 파일 업로드 (기존 파일 덮어쓰기)
  Future<void> uploadFile(String fileName, String jsonContent) async {
    final api = _driveApi!;
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName'",
      $fields: 'files(id)',
    );

    if (existing.files?.isNotEmpty == true) {
      await api.files.update(
        drive.File(),
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  /// appDataFolder에서 JSON 파일 다운로드. 없으면 null 반환.
  Future<String?> downloadFile(String fileName) async {
    final api = _driveApi!;
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName'",
      $fields: 'files(id)',
    );

    if (files.files?.isEmpty != false) return null;

    final response = await api.files.get(
      files.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  /// appDataFolder 파일 목록
  Future<List<drive.File>> listFiles() async {
    final result = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, modifiedTime, size)',
    );
    return result.files ?? [];
  }
}
