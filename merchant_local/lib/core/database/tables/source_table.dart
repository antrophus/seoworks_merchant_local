import 'package:drift/drift.dart';

/// 매입처 마스터 테이블
class Sources extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().unique()();
  TextColumn get type => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
