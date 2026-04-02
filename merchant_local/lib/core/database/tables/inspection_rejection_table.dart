import 'package:drift/drift.dart';
import 'item_table.dart';

/// 검수 반려 테이블
@DataClassName('InspectionRejectionData')
class InspectionRejections extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get returnSeq => integer()();
  TextColumn get rejectedAt => text()(); // YYYY-MM-DD
  TextColumn get reason => text().nullable()();
  TextColumn get photoUrls => text().nullable()(); // JSON 배열
  TextColumn get platform => text().nullable()(); // sale_platform
  TextColumn get memo => text().nullable()();
  TextColumn get defectType => text().nullable()(); // DEFECT_SALE, DEFECT_HELD, DEFECT_RETURN
  IntColumn get discountAmount => integer().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {itemId, returnSeq},
      ];
}
