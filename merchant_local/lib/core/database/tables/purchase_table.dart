import 'package:drift/drift.dart';
import 'item_table.dart';
import 'source_table.dart';

/// 매입 테이블 (items와 1:1)
@DataClassName('PurchaseData')
class Purchases extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().unique().references(Items, #id)();
  TextColumn get purchaseDate => text().nullable()(); // YYYY-MM-DD
  IntColumn get purchasePrice => integer().nullable()(); // 원 단위
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('PERSONAL_CARD'))();
  TextColumn get sourceId => text()
      .nullable()
      .references(Sources, #id, onDelete: KeyAction.setNull)();
  RealColumn get vatRefundable => real().nullable()();
  TextColumn get receiptUrl => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
