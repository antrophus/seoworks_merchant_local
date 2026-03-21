import 'package:drift/drift.dart';

/// 리스팅 로컬 캐시 테이블
class Listings extends Table {
  TextColumn get bidId => text()(); // 포이즌 bidId
  TextColumn get skuId => text()();
  IntColumn get price => integer()();
  IntColumn get quantity => integer()();
  TextColumn get status => text()(); // active, cancelled, sold
  TextColumn get listingType => text()(); // ship_to_verify, consignment, pre_sale
  TextColumn get countryCode => text()();
  TextColumn get currency => text().withDefault(const Constant('KRW'))();
  TextColumn get hlc => text()(); // CRDT HLC 타임스탬프
  DateTimeColumn get listedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {bidId};
}
