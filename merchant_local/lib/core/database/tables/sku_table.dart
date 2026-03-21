import 'package:drift/drift.dart';

/// 포이즌 SKU/SPU 로컬 캐시 테이블
class SkuItems extends Table {
  TextColumn get id => text()(); // DW skuId
  TextColumn get spuId => text()();
  TextColumn get globalSkuId => text().nullable()();
  TextColumn get articleNumber => text().nullable()();
  TextColumn get brandName => text().nullable()();
  TextColumn get productName => text()();
  TextColumn get sizeInfo => text().nullable()(); // JSON
  TextColumn get imageUrl => text().nullable()();
  TextColumn get hlc => text()(); // CRDT HLC 타임스탬프
  DateTimeColumn get cachedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
