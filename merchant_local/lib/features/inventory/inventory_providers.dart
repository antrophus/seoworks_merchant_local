import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════
// Providers
// ══════════════════════════════════════════════════

final inventoryFilterProvider = StateProvider<String?>((ref) => null);
final inventorySearchProvider = StateProvider<String>((ref) => '');
final inventorySortAscProvider = StateProvider<bool>((ref) => false);

/// 대시보드에서 서브탭 인덱스를 지정할 때 사용 (null = 미지정)
final inventorySubIndexOverride = StateProvider<int?>((ref) => null);

/// 검수 지연 하이라이트 모드 (대시보드 경고 배너 탭 시 활성)
final overdueHighlightMode = StateProvider<bool>((ref) => false);

/// 정렬 기준: 'created' | 'purchasePrice' | 'listedPrice' | 'sellPrice'
final inventorySortByProvider = StateProvider<String>((ref) => 'created');

/// 개인용 필터: null=전체, true=개인만, false=사업용만
final inventoryPersonalFilterProvider = StateProvider<bool?>((ref) => null);

// ── 선택 상태 ──

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});

  bool get isActive => state.isNotEmpty;

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  }

  void clear() => state = {};
  void addAll(Iterable<String> ids) => state = {...state, ...ids};
  void removeAll(Iterable<String> ids) => state = state.difference(ids.toSet());
  void selectAll(Iterable<String> ids) {
    state = state.length == ids.length ? {} : ids.toSet();
  }
}

final selectionProvider =
    StateNotifierProvider<SelectionNotifier, Set<String>>(
        (ref) => SelectionNotifier());

/// 현재 필터에서 일괄 선택 가능 여부 (정산완료·기타는 상태 변경 없으므로 불가)
final selectionEnabledProvider = Provider<bool>((ref) {
  final filter = ref.watch(inventoryFilterProvider);
  if (filter == null) return true;
  const disabled = {
    'SETTLED,DEFECT_SETTLED',
    'ORDER_CANCELLED,SUPPLIER_RETURN,DISPOSED,SAMPLE',
    'SETTLED', 'DEFECT_SETTLED',
    'ORDER_CANCELLED', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE',
  };
  return !disabled.contains(filter);
});

final searchResultProvider =
    FutureProvider.family<List<ItemData>, String>((ref, key) {
  // key format: "query|status1,status2" or just "query"
  final parts = key.split('|');
  final query = parts[0].trim();
  if (query.isEmpty) return Future.value([]);
  final statuses = parts.length > 1 && parts[1].isNotEmpty
      ? parts[1].split(',')
      : null;
  return ref.watch(itemDaoProvider).search(query, statuses: statuses);
});

final inventoryFilteredProvider =
    StreamProvider.family<List<ItemData>, String>((ref, status) {
  return ref.watch(itemDaoProvider).watchByStatus(status);
});

final multiStatusProvider =
    StreamProvider.family<List<ItemData>, String>((ref, csv) {
  return ref.watch(itemDaoProvider).watchByStatuses(csv.split(','));
});

// ══════════════════════════════════════════════════
// 필터 설정
// ══════════════════════════════════════════════════

class FilterDef {
  final String label;
  final List<String> statuses;
  final List<String>? subLabels;

  const FilterDef(this.label, this.statuses, {this.subLabels});
}

const mainFilters = [
  FilterDef('판매중', ['LISTED', 'POIZON_STORAGE'],
      subLabels: ['리스팅', '포이즌보관']),
  FilterDef('발송·검수', ['OUTGOING', 'IN_INSPECTION'],
      subLabels: ['발송중', '검수중']),
  FilterDef('미등록', ['ORDER_PLACED', 'OFFICE_STOCK'],
      subLabels: ['입고대기', '미등록재고']),
  FilterDef('정산완료', ['SETTLED', 'DEFECT_SETTLED']),
];

const moreFilters = [
  FilterDef('판매완료', ['SOLD']),
  FilterDef('불량보류', ['DEFECT_HELD']),
  FilterDef('수선중', ['REPAIRING']),
  FilterDef('반송중', ['RETURNING', 'CANCEL_RETURNING'],
      subLabels: ['하자반송', '취소반송']),
  FilterDef('기타', ['ORDER_CANCELLED', 'SUPPLIER_RETURN', 'DISPOSED', 'SAMPLE']),
];

// ══════════════════════════════════════════════════
// 상수
// ══════════════════════════════════════════════════

const statusLabels = <String, String>{
  'ORDER_PLACED': '주문완료',
  'ORDER_CANCELLED': '주문취소',
  'OFFICE_STOCK': '사무실재고',
  'OUTGOING': '발송중',
  'IN_INSPECTION': '검수중',
  'LISTED': '리스팅',
  'SOLD': '판매완료',
  'SETTLED': '정산완료',
  'RETURNING': '반송중',
  'DEFECT_FOR_SALE': '불량판매',
  'DEFECT_SOLD': '불량판매완료',
  'DEFECT_SETTLED': '불량정산',
  'POIZON_STORAGE': '포이즌보관',
  'CANCEL_RETURNING': '취소반송',
  'SUPPLIER_RETURN': '공급처반품',
  'DISPOSED': '폐기',
  'SAMPLE': '샘플',
  'DEFECT_HELD': '불량보류',
  'REPAIRING': '수선중',
};

final fmt = NumberFormat('#,###');

// ══════════════════════════════════════════════════
// 이미지 헬퍼
// ══════════════════════════════════════════════════

Widget productImage(String? url, {double size = 56}) {
  if (url == null || url.isEmpty) {
    return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.inventory_2, size: size * 0.57, color: AppColors.textTertiary));
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.14),
    child: CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          SizedBox(width: size, height: size, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
      errorWidget: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.broken_image, color: AppColors.textTertiary)),
    ),
  );
}

// ══════════════════════════════════════════════════
// 헬퍼 함수
// ══════════════════════════════════════════════════

final _allFilters = [...mainFilters, ...moreFilters];

FilterDef? findCurrentFilter(String? filterCsv) {
  if (filterCsv == null) return null;
  for (final f in _allFilters) {
    if (f.statuses.join(',') == filterCsv) return f;
    if (f.statuses.contains(filterCsv) && f.statuses.length > 1) return f;
  }
  return null;
}
