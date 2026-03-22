import 'package:drift/drift.dart';
import 'item_table.dart';

/// 배송 테이블
@DataClassName('ShipmentData')
class Shipments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get seq => integer()(); // 배송 순번
  TextColumn get trackingNumber => text()();
  TextColumn get outgoingDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get platform => text().nullable()(); // sale_platform
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, seq},
      ];
}
