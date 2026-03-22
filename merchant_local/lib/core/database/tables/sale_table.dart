import 'package:drift/drift.dart';
import 'item_table.dart';

/// 판매 테이블 (items와 1:1)
@DataClassName('SaleData')
class Sales extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().unique().references(Items, #id)();
  TextColumn get saleDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get platform => text()(); // KREAM, POIZON, SOLDOUT, DIRECT, OTHER
  TextColumn get platformOption => text().nullable()();
  IntColumn get listedPrice => integer().nullable()(); // 등록가
  IntColumn get sellPrice => integer().nullable()(); // 실판매가
  RealColumn get platformFeeRate => real().nullable()(); // 수수료율
  IntColumn get platformFee => integer().nullable()(); // 수수료
  IntColumn get settlementAmount => integer().nullable()(); // 정산금
  IntColumn get adjustmentTotal =>
      integer().withDefault(const Constant(0))(); // 조정금 합계
  TextColumn get outgoingDate => text().nullable()(); // 발송일
  TextColumn get shipmentDeadline => text().nullable()(); // 발송 기한
  TextColumn get trackingNumber => text().nullable()();
  TextColumn get settledAt => text().nullable()(); // 정산일
  TextColumn get memo => text().nullable()();
  TextColumn get poizonOrderId => text().nullable().unique()();
  TextColumn get dataSource =>
      text().nullable().withDefault(const Constant('manual'))();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
