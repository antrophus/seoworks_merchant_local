import 'package:drift/drift.dart';
import 'product_table.dart';

/// 아이템 테이블 — 재고 단위 (핵심 테이블)
@DataClassName('ItemData')
class Items extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get sku => text().unique()(); // 예: ID6600-245-001
  TextColumn get sizeKr => text()();
  TextColumn get sizeEu => text().nullable()();
  TextColumn get sizeUs => text().nullable()();
  TextColumn get sizeEtc => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get trackingNumber => text().nullable()();
  BoolColumn get isPersonal =>
      boolean().withDefault(const Constant(false))();
  TextColumn get currentStatus =>
      text().withDefault(const Constant('OFFICE_STOCK'))();
  TextColumn get location => text().nullable()();
  TextColumn get defectNote => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get poizonSkuId => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
