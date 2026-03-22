import 'package:drift/drift.dart';
import 'brand_table.dart';

/// 상품 모델 마스터 테이블
class Products extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get brandId => text().nullable().references(Brands, #id)();
  TextColumn get modelCode => text().unique()();
  TextColumn get modelName => text()();
  TextColumn get gender => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get poizonSpuId => text().nullable().unique()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
