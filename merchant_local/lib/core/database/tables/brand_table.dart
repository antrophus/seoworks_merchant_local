import 'package:drift/drift.dart';

/// 브랜드 마스터 테이블
class Brands extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().unique()();
  TextColumn get code => text().nullable().unique()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
