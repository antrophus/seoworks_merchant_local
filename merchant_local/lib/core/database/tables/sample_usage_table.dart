import 'package:drift/drift.dart';
import 'item_table.dart';

/// 샘플 전환 테이블
@DataClassName('SampleUsageData')
class SampleUsages extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().unique().references(Items, #id)();
  TextColumn get purpose => text()();
  TextColumn get usedAt => text().nullable()(); // YYYY-MM-DD
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
