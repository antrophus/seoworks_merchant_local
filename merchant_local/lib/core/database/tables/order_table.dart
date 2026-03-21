import 'package:drift/drift.dart';

/// 주문 로컬 캐시 테이블
class Orders extends Table {
  TextColumn get orderId => text()();
  TextColumn get skuId => text()();
  TextColumn get status => text()(); // pending, confirmed, shipped, completed
  IntColumn get salePrice => integer()();
  TextColumn get buyerCountry => text().nullable()();
  TextColumn get trackingNo => text().nullable()();
  TextColumn get carrierCode => text().nullable()();
  TextColumn get qcResult => text().nullable()(); // JSON
  TextColumn get hlc => text()(); // CRDT HLC 타임스탬프
  DateTimeColumn get orderedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {orderId};
}
