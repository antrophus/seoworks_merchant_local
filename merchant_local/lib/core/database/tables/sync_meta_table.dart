import 'package:drift/drift.dart';

/// 동기화 메타데이터 테이블 (Google Drive 동기화 상태 관리)
class SyncMeta extends Table {
  TextColumn get key => text()(); // 예: 'last_poizon_sync', 'last_gdrive_sync'
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
