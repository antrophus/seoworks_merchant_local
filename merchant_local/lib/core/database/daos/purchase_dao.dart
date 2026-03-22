import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/purchase_table.dart';
import '../tables/item_table.dart';

part 'purchase_dao.g.dart';

@DriftAccessor(tables: [Purchases, Items])
class PurchaseDao extends DatabaseAccessor<AppDatabase>
    with _$PurchaseDaoMixin {
  PurchaseDao(super.db);

  /// item_id로 매입 조회
  Future<PurchaseData?> getByItemId(String itemId) =>
      (select(purchases)..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

  /// 매입 등록 (부가세 환급액 자동 계산)
  Future<void> insertPurchase(PurchasesCompanion entry) async {
    final computed = await _computeVatRefundable(entry);
    await into(purchases).insert(computed);
  }

  /// 매입 수정 (부가세 환급액 재계산)
  Future<void> updatePurchase(String id, PurchasesCompanion entry) async {
    final computed = await _computeVatRefundable(entry);
    await (update(purchases)..where((t) => t.id.equals(id))).write(computed);
  }

  /// 부가세 환급액 계산 로직
  /// is_personal == false AND payment_method == 'CORPORATE_CARD' → price / 11
  Future<PurchasesCompanion> _computeVatRefundable(
      PurchasesCompanion entry) async {
    if (!entry.itemId.present) return entry;

    final item = await (select(items)
          ..where((t) => t.id.equals(entry.itemId.value)))
        .getSingleOrNull();
    if (item == null) return entry;

    final isPersonal = item.isPersonal;
    final paymentMethod = entry.paymentMethod.present
        ? entry.paymentMethod.value
        : 'PERSONAL_CARD';
    final price = entry.purchasePrice.present ? entry.purchasePrice.value : null;

    double? vatRefundable;
    if (!isPersonal && paymentMethod == 'CORPORATE_CARD' && price != null) {
      vatRefundable = (price / 11.0 * 100).roundToDouble() / 100;
    } else {
      vatRefundable = 0;
    }

    return entry.copyWith(vatRefundable: Value(vatRefundable));
  }

  /// 일괄 Insert (데이터 임포트용)
  Future<void> insertAll(List<PurchasesCompanion> entries) async {
    await batch((b) {
      b.insertAll(purchases, entries, mode: InsertMode.insertOrIgnore);
    });
  }
}
