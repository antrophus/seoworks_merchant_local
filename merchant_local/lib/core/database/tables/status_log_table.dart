import 'package:drift/drift.dart';
import 'item_table.dart';

/// 상태 변경 이력 테이블
@DataClassName('StatusLogData')
class StatusLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get oldStatus => text().nullable()();
  TextColumn get newStatus => text()();
  TextColumn get note => text().nullable()();
  TextColumn get changedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
