import 'package:drift/drift.dart';
import 'item_table.dart';

/// 수선 테이블
@DataClassName('RepairData')
class Repairs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get startedAt => text()(); // YYYY-MM-DD
  TextColumn get completedAt => text().nullable()();
  IntColumn get repairCost => integer().nullable()();
  TextColumn get repairNote => text().nullable()();
  TextColumn get outcome =>
      text().nullable()(); // RELISTED, SUPPLIER_RETURN, DISPOSED, PERSONAL
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
