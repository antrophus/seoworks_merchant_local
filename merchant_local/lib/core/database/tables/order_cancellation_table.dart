import 'package:drift/drift.dart';
import 'item_table.dart';

/// 주문 취소 테이블
@DataClassName('OrderCancellationData')
class OrderCancellations extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().unique().references(Items, #id)();
  TextColumn get cancelledAt => text()(); // YYYY-MM-DD
  TextColumn get reason => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
