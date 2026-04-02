import 'package:drift/drift.dart';

/// 사이즈 차트 마스터 테이블
@DataClassName('SizeChartData')
class SizeCharts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get brand => text()(); // 브랜드명 (TEXT, brands FK 아님)
  TextColumn get target => text()(); // MEN / WOMEN / KIDS
  RealColumn get kr => real()(); // 한국 사이즈
  TextColumn get eu => text().nullable()();
  TextColumn get usM => text().nullable()();
  TextColumn get usW => text().nullable()();
  TextColumn get us => text().nullable()();
  TextColumn get uk => text().nullable()();
  TextColumn get jp => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get hlc => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {brand, target, kr},
      ];
}
