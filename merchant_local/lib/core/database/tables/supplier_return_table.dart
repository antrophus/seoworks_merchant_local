import 'package:drift/drift.dart';
import 'item_table.dart';

/// 공급처 반품 테이블
@DataClassName('SupplierReturnData')
class SupplierReturns extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().unique().references(Items, #id)();
  TextColumn get returnedAt => text()(); // YYYY-MM-DD
  TextColumn get reason => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
