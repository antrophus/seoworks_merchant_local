import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;

class GoogleDriveService {
  static const _scopes = ['https://www.googleapis.com/auth/drive'];
  // Google Drive 공유 폴더 ID (서비스 계정에 편집자 권한 부여됨)
  static const _syncFolderId = '1LEPZccA-ZrjrC0qQvs2G5gyGqkVjjKuf';

  auth.AutoRefreshingAuthClient? _client;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _driveApi != null;

  /// 앱 시작 시 서비스 계정으로 자동 연결
  Future<bool> connect() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/service_account.json');
      final credentials = auth.ServiceAccountCredentials.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>);
      _client = await auth.clientViaServiceAccount(credentials, _scopes);
      _driveApi = drive.DriveApi(_client!);
      return true;
    } catch (e, st) {
      debugPrint('[GoogleDriveService] 연결 실패: $e\n$st');
      return false;
    }
  }

  void disconnect() {
    _client?.close();
    _client = null;
    _driveApi = null;
  }

  // ── 파일 업로드 / 다운로드 ────────────────────────────

  Future<void> uploadFile(String fileName, String jsonContent) async {
    final api = _driveApi!;
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existing = await api.files.list(
      spaces: 'drive',
      q: "name = '$fileName' and '$_syncFolderId' in parents and trashed = false",
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
        ..parents = [_syncFolderId];
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  Future<String?> downloadFile(String fileName) async {
    final api = _driveApi!;
    final files = await api.files.list(
      spaces: 'drive',
      q: "name = '$fileName' and '$_syncFolderId' in parents and trashed = false",
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

  Future<List<drive.File>> listFiles() async {
    final result = await _driveApi!.files.list(
      spaces: 'drive',
      q: "'$_syncFolderId' in parents and trashed = false",
      $fields: 'files(id, name, modifiedTime, size)',
    );
    return result.files ?? [];
  }
}
