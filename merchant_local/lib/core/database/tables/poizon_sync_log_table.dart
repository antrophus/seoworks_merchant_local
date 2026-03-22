import 'package:drift/drift.dart';

/// 포이즌 동기화 로그 테이블
@DataClassName('PoizonSyncLogData')
class PoizonSyncLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get syncType => text()(); // orders, inspection, settlement, etc.
  TextColumn get windowStart => text().nullable()();
  TextColumn get windowEnd => text().nullable()();
  TextColumn get syncedAt => text().nullable()();
  IntColumn get recordsIn => integer().nullable().withDefault(const Constant(0))();
  IntColumn get recordsOk => integer().nullable().withDefault(const Constant(0))();
  IntColumn get recordsSkip => integer().nullable().withDefault(const Constant(0))();
  TextColumn get status => text()(); // success, partial, error
  TextColumn get errorMsg => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
