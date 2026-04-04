import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;


import 'package:retry/retry.dart';

import 'google_oauth_secrets.dart';


class GoogleDriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _tokenKey = 'google_drive_token';
  static const _syncFolderName = 'MerchantLocalSync';

  final _storage = const FlutterSecureStorage();

  auth.AuthClient? _client;
  drive.DriveApi? _driveApi;
  String? _syncFolderId;
  String? _userEmail;

  bool get isSignedIn => _driveApi != null;
  String? get userEmail => _userEmail;

  // ── OAuth 설정 ─────────────────────────────────────────

  auth.ClientId get _clientId => auth.ClientId(
        kDesktopOAuthClientId,
        kDesktopOAuthClientSecret,
      );

  // ── 로그인 (브라우저 기반, 직접 localhost 서버) ─────────

  Future<bool> signIn() async {
    HttpServer? server;
    try {
      // 1) localhost 서버 시작
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      // 2) OAuth 인증 URL 생성
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': kDesktopOAuthClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
      });

      // 3) 브라우저 열기
      await launcher.launchUrl(authUrl, mode: launcher.LaunchMode.inAppBrowserView);


      // 4) 콜백 대기
      final request = await server.first;
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

      if (code == null || error != null) {
        request.response
          ..statusCode = 400
          ..write('OAuth error');
        await request.response.close();
        await server.close();
        server = null;
        if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
          // TODO: 실기기에서 브라우저가 자동으로 닫히지 않을 경우 대응 필요
        }


        return false;
      }

      // 5) ★ 안드로이드/iOS의 경우 브라우저 복귀 시 네트워크 스택 안정을 위한 지연
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('[GoogleDriveService] 브라우저 복귀 대기 (1.5초)...');
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // 6) DNS 명시적 조회 및 네트워크 예열
      final httpClient = http.Client();
      await _resolveGoogleDns();
      
      // 안드로이드 DNS 룩업 지연 대응: 점진적 재시도 및 타임아웃 추가
      // (oauth2.googleapis.com뿐만 아니라 www.googleapis.com의 v4/token도 함께 고려)
      final tokenRes = await retry(
        () async {
          // v4/token 엔드포인트가 일부 네트워크에서 더 안정적인 것으로 알려짐
          return await httpClient.post(
            Uri.parse('https://www.googleapis.com/oauth2/v4/token'),
            body: {
              'client_id': kDesktopOAuthClientId,
              'client_secret': kDesktopOAuthClientSecret,
              'code': code,
              'grant_type': 'authorization_code',
              'redirect_uri': redirectUri,
            },
          ).timeout(const Duration(seconds: 20));
        },
        retryIf: (e) => e is SocketException || e is http.ClientException,
        maxAttempts: 4,
        delayFactor: const Duration(seconds: 1),
      );

      // 7) 토큰 교환 결과에 따라 브라우저 응답
      final exchangeOk = tokenRes.statusCode == 200;
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write(
          '<html><body style="text-align:center;padding-top:60px;font-family:sans-serif;">'
          '<h2>${exchangeOk ? "로그인 완료" : "로그인 실패"}</h2>'
          '<p>${exchangeOk ? "앱으로 돌아가세요." : "다시 시도해 주세요."}</p>'
          '<script>window.close();</script>'
          '</body></html>',
        );
      await request.response.close();
      await server.close();
      server = null;
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        // TODO: 실기기에서 브라우저가 자동으로 닫히지 않을 경우 대응 필요
      }



      if (!exchangeOk) {
        debugPrint('[GoogleDriveService] 토큰 교환 실패: ${tokenRes.body}');
        httpClient.close();
        return false;
      }

      final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
      final credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          tokenData['access_token'] as String,
          DateTime.now()
              .toUtc()
              .add(Duration(seconds: tokenData['expires_in'] as int)),
        ),
        tokenData['refresh_token'] as String?,
        _scopes,
      );

      final client =
          auth.autoRefreshingClient(_clientId, credentials, httpClient);
      _client = client;
      _driveApi = drive.DriveApi(client);
      await _fetchUserEmail();
      await _saveToken(credentials);
      await _ensureSyncFolder();
      return true;
    } catch (e, st) {
      debugPrint('[GoogleDriveService] signIn 실패: $e\n$st');
      return false;
    } finally {
      try { await server?.close(); } catch (_) {}
    }
  }

  /// 저장된 토큰으로 자동 로그인 시도
  Future<bool> trySilentSignIn() async {
    try {
      final tokenJson = await _storage.read(key: _tokenKey);
      if (tokenJson == null) return false;

      final map = jsonDecode(tokenJson) as Map<String, dynamic>;
      final credentials = auth.AccessCredentials(
        auth.AccessToken(
          map['type'] as String,
          map['data'] as String,
          DateTime.parse(map['expiry'] as String).toUtc(),
        ),
        map['refreshToken'] as String?,
        _scopes,
      );

      final baseClient = http.Client();
      final client = auth.autoRefreshingClient(
        _clientId,
        credentials,
        baseClient,
      );

      // 토큰 유효성 검증 — 간단한 API 호출 (재시도 및 타임아웃 추가)
      final driveApi = drive.DriveApi(client);
      await retry(
        () => driveApi.about.get($fields: 'user').timeout(const Duration(seconds: 10)),
        retryIf: (e) => e is SocketException || e is http.ClientException,
        maxAttempts: 2,
      );

      _client = client;
      _driveApi = driveApi;
      await _fetchUserEmail();
      await _ensureSyncFolder();

      // 갱신된 토큰 저장
      await _saveToken(client.credentials);

      return true;
    } catch (e, st) {
      debugPrint('[GoogleDriveService] silentSignIn 실패: $e\n$st');
      // 유효하지 않은 토큰 삭제
      await _storage.delete(key: _tokenKey);
      return false;
    }
  }

  void signOut() {
    _client?.close();
    _client = null;
    _driveApi = null;
    _syncFolderId = null;
    _userEmail = null;
    _storage.delete(key: _tokenKey);
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────

  Future<void> _saveToken(auth.AccessCredentials cred) async {
    final map = {
      'type': cred.accessToken.type,
      'data': cred.accessToken.data,
      'expiry': cred.accessToken.expiry.toIso8601String(),
      'refreshToken': cred.refreshToken,
    };
    await _storage.write(key: _tokenKey, value: jsonEncode(map));
  }

  /// DNS 조회 강제 실행 및 네트워크 예열
  Future<void> _resolveGoogleDns() async {
    try {
      debugPrint('[GoogleDriveService] DNS 룩업 시도 (IPv4): www.googleapis.com');
      final addresses = await InternetAddress.lookup(
        'www.googleapis.com', 
        type: InternetAddressType.IPv4
      );
      for (final addr in addresses) {
        debugPrint('[GoogleDriveService] 해석된 IP (IPv4): ${addr.address}');
      }
      
      // 네트워크 스택 예열 (간단한 GET 요청)
      final ping = await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
      debugPrint('[GoogleDriveService] 네트워크 예열 결과: ${ping.statusCode}');
    } catch (e) {
      debugPrint('[GoogleDriveService] DNS 조회 또는 예열 실패 (무시): $e');
    }
  }

  Future<void> _fetchUserEmail() async {
    try {
      final about = await _driveApi!.about.get($fields: 'user(emailAddress)');
      _userEmail = about.user?.emailAddress;
    } catch (_) {}
  }

  /// drive.file 스코프로 생성한 전용 동기화 폴더 확보
  Future<void> _ensureSyncFolder() async {
    final api = _driveApi!;
    final found = await api.files.list(
      q: "name = '$_syncFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (found.files?.isNotEmpty == true) {
      _syncFolderId = found.files!.first.id!;
    } else {
      final folder = drive.File()
        ..name = _syncFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      _syncFolderId = created.id!;
    }
  }

  // ── 파일 업로드 / 다운로드 ────────────────────────────

  Future<void> uploadFile(String fileName, String jsonContent) async {
    final api = _driveApi!;
    final folderId = _syncFolderId!;
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existing = await api.files.list(
      spaces: 'drive',
      q: "name = '$fileName' and '$folderId' in parents and trashed = false",
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
        ..parents = [folderId];
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  Future<String?> downloadFile(String fileName) async {
    final api = _driveApi!;
    final folderId = _syncFolderId!;
    final files = await api.files.list(
      spaces: 'drive',
      q: "name = '$fileName' and '$folderId' in parents and trashed = false",
      $fields: 'files(id)',
    );

    if (files.files?.isEmpty != false) return null;

    final response = await api.files.get(
      files.files!.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final byteList = <int>[];
    await for (final chunk in response.stream) {
      byteList.addAll(chunk);
    }
    return utf8.decode(byteList);
  }

  Future<List<drive.File>> listFiles() async {
    final folderId = _syncFolderId!;
    final result = await _driveApi!.files.list(
      spaces: 'drive',
      q: "'$folderId' in parents and trashed = false",
      $fields: 'files(id, name, modifiedTime, size)',
    );
    return result.files ?? [];
  }
}
