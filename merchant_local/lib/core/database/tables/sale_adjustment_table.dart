import 'package:drift/drift.dart';
import 'sale_table.dart';

/// 판매 조정금 테이블
@DataClassName('SaleAdjustmentData')
class SaleAdjustments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get type => text()(); // COUPON, PENALTY, STORAGE_FEE, OTHER
  IntColumn get amount => integer()();
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
