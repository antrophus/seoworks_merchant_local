import 'package:drift/drift.dart';

/// 플랫폼 수수료 규칙 테이블
@DataClassName('PlatformFeeRuleData')
class PlatformFeeRules extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get platform => text()();
  TextColumn get category => text().withDefault(const Constant('default'))();
  RealColumn get feeRate => real()();
  IntColumn get minFee => integer().withDefault(const Constant(0))();
  IntColumn get maxFee => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {platform, category},
      ];
}
