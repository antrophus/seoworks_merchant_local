import 'dart:convert';
import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import 'google_drive_service.dart';
import 'hlc_clock_service.dart';

// ── Sync Manifest ────────────────────────────────────────────────────────────

class SyncManifest {
  final String schemaVersion;
  final Map<String, String> tableHlcs;
  final String lastSyncedAt;
  final String lastSyncedBy;

  SyncManifest({
    required this.schemaVersion,
    required this.tableHlcs,
    required this.lastSyncedAt,
    required this.lastSyncedBy,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'tableHlcs': tableHlcs,
        'lastSyncedAt': lastSyncedAt,
        'lastSyncedBy': lastSyncedBy,
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
        schemaVersion: json['schemaVersion'] as String? ?? '',
        tableHlcs: Map<String, String>.from(
            (json['tableHlcs'] as Map?) ?? {}),
        lastSyncedAt: json['lastSyncedAt'] as String? ?? '',
        lastSyncedBy: json['lastSyncedBy'] as String? ?? '',
      );
}

// ── Sync Result ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncResult {
  final SyncStatus status;
  final String? errorMessage;
  final int tablesDownloaded;
  final int tablesUploaded;
  final DateTime completedAt;

  const SyncResult({
    required this.status,
    this.errorMessage,
    this.tablesDownloaded = 0,
    this.tablesUploaded = 0,
    required this.completedAt,
  });

  static SyncResult get idle => SyncResult(
        status: SyncStatus.idle,
        completedAt: DateTime.now(),
      );
}

// ── Sync Engine ───────────────────────────────────────────────────────────────

class SyncEngine {
  final AppDatabase db;
  final GoogleDriveService driveService;
  final HlcClockService clock;

  static const _schemaVersion = '5';
  static const _manifestFile = 'sync_manifest.json';

  /// FK 의존성 순서 (부모 → 자식) — 머지 시 반드시 준수
  static const _syncOrder = [
    'brands',
    'sources',
    'platform_fee_rules',
    'products',
    'size_charts',
    'items',
    'purchases',
    'sales',
    'sale_adjustments',
    'status_logs',
    'inspection_rejections',
    'repairs',
    'shipments',
    'supplier_returns',
    'order_cancellations',
    'sample_usages',
  ];

  SyncEngine({
    required this.db,
    required this.driveService,
    required this.clock,
  });

  // ── 메인 동기화 ───────────────────────────────────────────────────────────

  /// hlc 없는 기존 레코드에 일괄 HLC 스탬프 (최초 1회)
  Future<void> _backfillMissingHlcs() async {
    for (final table in _syncOrder) {
      final rows = await db.customSelect(
        "SELECT COUNT(*) AS cnt FROM $table WHERE hlc = ''",
        readsFrom: {},
      ).get();
      final count = rows.firstOrNull?.read<int>('cnt') ?? 0;
      if (count == 0) continue;

      final hlc = clock.increment().toString();
      await db.customStatement(
        "UPDATE $table SET hlc = ? WHERE hlc = ''",
        [hlc],
      );
      debugPrint('[SyncEngine] 백필: $table ($count개)');
    }
  }

  Future<SyncResult> sync() async {
    if (!driveService.isSignedIn) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: '로그인이 필요합니다.',
        completedAt: DateTime.now(),
      );
    }

    try {
      // 0. 기존 데이터 HLC 백필 (hlc = '' 레코드)
      await _backfillMissingHlcs();

      // 1. 로컬 max HLC 수집
      final localHlcs = await _getLocalMaxHlcs();

      // 2. 리모트 manifest 다운로드 (항상)
      SyncManifest? remoteManifest;
      final manifestJson = await driveService.downloadFile(_manifestFile);
      if (manifestJson != null) {
        remoteManifest =
            SyncManifest.fromJson(jsonDecode(manifestJson) as Map<String, dynamic>);
        if (remoteManifest.schemaVersion != _schemaVersion) {
          return SyncResult(
            status: SyncStatus.error,
            errorMessage:
                '스키마 버전 불일치 (local: $_schemaVersion, remote: ${remoteManifest.schemaVersion}). '
                '모든 기기의 앱을 업데이트하세요.',
            completedAt: DateTime.now(),
          );
        }
      }

      // 3. 테이블별 동기화 대상 결정
      //    HLC가 다르면 항상 다운로드→머지→업로드 (데이터 유실 방지)
      final needSync = <String>[];

      for (final table in _syncOrder) {
        final local = localHlcs[table] ?? '';
        final remote = remoteManifest?.tableHlcs[table] ?? '';

        if (remoteManifest == null) {
          // 최초 동기화 — 로컬 데이터가 있으면 업로드
          if (local.isNotEmpty) needSync.add(table);
        } else if (local != remote) {
          // HLC가 다르면 무조건 양방향 동기화
          needSync.add(table);
        }
      }

      // 변경할 테이블이 없으면 스킵
      if (needSync.isEmpty) {
        debugPrint('[SyncEngine] 변경 없음 — 스킵');
        return SyncResult(
          status: SyncStatus.success,
          completedAt: DateTime.now(),
        );
      }

      // 4. 다운로드 + CRDT 머지 먼저 (FK 순서대로)
      for (final table in needSync) {
        final json = await driveService.downloadFile('data_$table.json');
        if (json == null) continue;
        final records =
            List<Map<String, dynamic>>.from(jsonDecode(json) as List);
        await _mergeRecords(table, records);
      }

      // 5. status_logs 기반 상태 보정 (행 단위 LWW로 인한 상태 역행 복구)
      await reconcileStatusFromLogs();

      // 6. 머지+보정 완료 후 업로드 (FK 순서대로)
      for (final table in needSync) {
        final records = await _getAllRecords(table);
        if (records.isEmpty) continue;
        await driveService.uploadFile(
            'data_$table.json', jsonEncode(records));
      }

      // 7. Manifest 갱신 + 업로드
      final updatedHlcs = await _getLocalMaxHlcs();
      final newManifest = SyncManifest(
        schemaVersion: _schemaVersion,
        tableHlcs: updatedHlcs,
        lastSyncedAt: DateTime.now().toIso8601String(),
        lastSyncedBy: clock.nodeId,
      );
      await driveService.uploadFile(
          _manifestFile, jsonEncode(newManifest.toJson()));

      // 8. SyncMeta에 마지막 동기화 시각 저장
      final now = DateTime.now();
      await db.customStatement(
        "INSERT OR REPLACE INTO sync_meta (key, value, updated_at) "
        "VALUES ('last_sync_at', ?, ?)",
        [now.toIso8601String(), now.millisecondsSinceEpoch],
      );

      debugPrint(
          '[SyncEngine] 완료 — 동기화: ${needSync.length}개 테이블');

      return SyncResult(
        status: SyncStatus.success,
        tablesDownloaded: needSync.length,
        tablesUploaded: needSync.length,
        completedAt: DateTime.now(),
      );
    } catch (e, st) {
      debugPrint('[SyncEngine] 오류: $e\n$st');
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  // ── HLC 비교 ──────────────────────────────────────────────────────────────

  bool _hlcGreaterThan(String a, String b) {
    if (a.isEmpty) return false;
    if (b.isEmpty) return true;
    try {
      return Hlc.parse(a).compareTo(Hlc.parse(b)) > 0;
    } catch (_) {
      return a.compareTo(b) > 0;
    }
  }

  // ── 로컬 HLC 수집 ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _getLocalMaxHlcs() async {
    final result = <String, String>{};
    for (final table in _syncOrder) {
      final rows = await db.customSelect(
        "SELECT MAX(hlc) AS max_hlc FROM $table WHERE hlc != ''",
        readsFrom: {},
      ).get();
      final maxHlc = rows.firstOrNull?.readNullable<String>('max_hlc') ?? '';
      if (maxHlc.isNotEmpty) result[table] = maxHlc;
    }
    return result;
  }

  // ── CRDT 머지 ─────────────────────────────────────────────────────────────

  Future<void> _mergeRecords(
      String table, List<Map<String, dynamic>> remoteRecords) async {
    for (final remote in remoteRecords) {
      final remoteHlc = remote['hlc'] as String? ?? '';
      if (remoteHlc.isEmpty) continue;

      final id = remote['id'];
      if (id == null) continue;

      final localRows = await db.customSelect(
        'SELECT hlc FROM $table WHERE id = ?',
        variables: [Variable<String>(id.toString())],
        readsFrom: {},
      ).get();

      if (localRows.isEmpty) {
        // 새 레코드 → 삽입
        await _insertRaw(table, remote);
        _tryMergeClock(remoteHlc);
      } else {
        final localHlc =
            localRows.first.readNullable<String>('hlc') ?? '';
        if (_hlcGreaterThan(remoteHlc, localHlc)) {
          // 리모트 승리 → 덮어쓰기
          await _updateRaw(table, remote);
          _tryMergeClock(remoteHlc);
        }
        // else: 로컬 승리 → 유지
      }
    }
  }

  void _tryMergeClock(String hlcStr) {
    try {
      clock.merge(Hlc.parse(hlcStr));
    } catch (_) {}
  }

  // ── Raw SQL INSERT / UPDATE ───────────────────────────────────────────────

  Future<void> _insertRaw(
      String table, Map<String, dynamic> record) async {
    final cols = record.keys.join(', ');
    final placeholders = List.filled(record.length, '?').join(', ');
    await db.customStatement(
      'INSERT OR IGNORE INTO $table ($cols) VALUES ($placeholders)',
      record.values.map(_toSqlValue).toList(),
    );
  }

  Future<void> _updateRaw(
      String table, Map<String, dynamic> record) async {
    final setClauses = record.keys
        .where((k) => k != 'id')
        .map((k) => '$k = ?')
        .join(', ');
    if (setClauses.isEmpty) return;

    final values = record.entries
        .where((e) => e.key != 'id')
        .map((e) => _toSqlValue(e.value))
        .toList()
      ..add(record['id']);

    await db.customStatement(
      'UPDATE $table SET $setClauses WHERE id = ?',
      values,
    );
  }

  /// bool → int 변환 (SQLite는 bool을 모름)
  dynamic _toSqlValue(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    return value;
  }

  // ── 전체 레코드 읽기 ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getAllRecords(String table) async {
    final rows = await db.customSelect(
      "SELECT * FROM $table WHERE hlc != ''",
      readsFrom: {},
    ).get();
    return rows.map((r) => r.data).toList();
  }

  // ── 상태 보정: status_logs 기반 ────────────────────────────────────────

  /// status_logs에서 각 아이템의 최신 상태를 읽어 items.current_status를 보정.
  /// 행 단위 LWW로 인해 상태가 역행한 경우를 복구한다.
  Future<int> reconcileStatusFromLogs() async {
    final rows = await db.customSelect(
      '''
      SELECT sl.item_id, sl.new_status
      FROM status_logs sl
      INNER JOIN (
        SELECT item_id, MAX(changed_at) AS max_at
        FROM status_logs
        WHERE is_deleted = 0
        GROUP BY item_id
      ) latest ON sl.item_id = latest.item_id AND sl.changed_at = latest.max_at
      INNER JOIN items i ON i.id = sl.item_id
      WHERE i.current_status != sl.new_status
        AND i.is_deleted = 0
        AND sl.is_deleted = 0
      ''',
      readsFrom: {db.statusLogs, db.items},
    ).get();

    if (rows.isEmpty) return 0;

    final hlcValue = clock.increment().toString();
    final now = DateTime.now().toIso8601String();

    for (final r in rows) {
      final itemId = r.read<String>('item_id');
      final correctStatus = r.read<String>('new_status');
      await db.customStatement(
        'UPDATE items SET current_status = ?, updated_at = ?, hlc = ? WHERE id = ?',
        [correctStatus, now, hlcValue, itemId],
      );
      debugPrint('[SyncEngine] 상태 보정: $itemId → $correctStatus');
    }

    debugPrint('[SyncEngine] 상태 보정 완료 — ${rows.length}건');
    return rows.length;
  }

  // ── GC: 소프트 삭제 레코드 정리 ──────────────────────────────────────────

  /// 90일 이상 경과한 soft-deleted 레코드 하드 삭제
  Future<void> purgeOldDeletedRecords() async {
    // HLC 형식: "2026-04-03T07:15:00.000Z-0000-nodeId"
    // 앞 24자가 ISO8601 UTC 타임스탬프 — 이것만 잘라서 비교
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 90))
        .toUtc()
        .toIso8601String()
        .substring(0, 24); // "2026-01-03T07:15:00.000Z"
    for (final table in _syncOrder) {
      await db.customStatement(
        "DELETE FROM $table WHERE is_deleted = 1 AND SUBSTR(hlc, 1, 24) < ?",
        [cutoff],
      );
    }
    debugPrint('[SyncEngine] GC 완료 (90일 이상 삭제 레코드 제거)');
  }
}
