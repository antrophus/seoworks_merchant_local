import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFormat = NumberFormat('#,###');

// ══════════════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════════════

class _ShipmentItem {
  final String itemId;
  final String sku;
  final String sizeKr;
  final String modelName;
  final String modelCode;
  final String currentStatus;
  final int? sellPrice;
  final int? settlementAmount;
  final int? purchasePrice;
  final bool hasReturn; // supplier_returns 또는 RETURNING 상태

  const _ShipmentItem({
    required this.itemId,
    required this.sku,
    required this.sizeKr,
    required this.modelName,
    required this.modelCode,
    required this.currentStatus,
    this.sellPrice,
    this.settlementAmount,
    this.purchasePrice,
    required this.hasReturn,
  });
}

class _ShipmentGroup {
  final String outgoingDate;
  final String trackingNumber;
  final String platform;
  final List<_ShipmentItem> items;

  const _ShipmentGroup({
    required this.outgoingDate,
    required this.trackingNumber,
    required this.platform,
    required this.items,
  });

  int get sellTotal =>
      items.fold(0, (s, i) => s + (i.sellPrice ?? 0));

  int get settlementTotal =>
      items.fold(0, (s, i) => s + (i.settlementAmount ?? 0));

  int get purchaseTotal =>
      items.fold(0, (s, i) => s + (i.purchasePrice ?? 0));

  double get profitRate {
    if (sellTotal == 0) return 0;
    return (settlementTotal - purchaseTotal) / sellTotal * 100;
  }
}

// ══════════════════════════════════════════════════
// Provider
// ══════════════════════════════════════════════════

final _logisticsProvider =
    FutureProvider<List<_ShipmentGroup>>((ref) async {
  final db = ref.watch(databaseProvider);
  final results = await db.customSelect(
    '''
    SELECT
      sh.tracking_number,
      sh.outgoing_date,
      COALESCE(sh.platform, sa.platform, '') AS platform,
      i.id AS item_id,
      i.sku,
      i.size_kr,
      i.current_status,
      pr.model_name,
      pr.model_code,
      sa.sell_price,
      sa.settlement_amount,
      pu.purchase_price,
      CASE WHEN sr.id IS NOT NULL OR i.current_status IN ('RETURNING','SUPPLIER_RETURN','CANCEL_RETURNING')
           THEN 1 ELSE 0 END AS has_return
    FROM shipments sh
    JOIN items i ON i.id = sh.item_id
    JOIN products pr ON pr.id = i.product_id
    LEFT JOIN sales sa ON sa.item_id = sh.item_id
    LEFT JOIN purchases pu ON pu.item_id = sh.item_id
    LEFT JOIN supplier_returns sr ON sr.item_id = sh.item_id
    ORDER BY sh.outgoing_date DESC, sh.tracking_number
    ''',
    readsFrom: {
      db.shipments,
      db.items,
      db.products,
      db.sales,
      db.purchases,
      db.supplierReturns,
    },
  ).get();

  // 날짜+송장번호로 그룹화
  final groupMap = <String, _ShipmentGroup>{};
  for (final r in results) {
    final date = r.readNullable<String>('outgoing_date') ?? '날짜미상';
    final tracking = r.read<String>('tracking_number');
    final key = '$date|$tracking';

    final item = _ShipmentItem(
      itemId: r.read<String>('item_id'),
      sku: r.read<String>('sku'),
      sizeKr: r.read<String>('size_kr'),
      modelName: r.read<String>('model_name'),
      modelCode: r.read<String>('model_code'),
      currentStatus: r.read<String>('current_status'),
      sellPrice: r.readNullable<int>('sell_price'),
      settlementAmount: r.readNullable<int>('settlement_amount'),
      purchasePrice: r.readNullable<int>('purchase_price'),
      hasReturn: r.read<int>('has_return') == 1,
    );

    if (groupMap.containsKey(key)) {
      final existing = groupMap[key]!;
      groupMap[key] = _ShipmentGroup(
        outgoingDate: existing.outgoingDate,
        trackingNumber: existing.trackingNumber,
        platform: existing.platform,
        items: [...existing.items, item],
      );
    } else {
      groupMap[key] = _ShipmentGroup(
        outgoingDate: date,
        trackingNumber: tracking,
        platform: r.read<String>('platform'),
        items: [item],
      );
    }
  }

  return groupMap.values.toList();
});

// ══════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════

class LogisticsScreen extends ConsumerWidget {
  const LogisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_logisticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('물류 추적')),
      body: async.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text('발송 이력이 없습니다',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textTertiary)),
            );
          }

          // 월별 통계 계산
          final monthStats = _buildMonthStats(groups);

          return Column(
            children: [
              // ── 상단 월별 요약 ──
              _MonthlyHeader(stats: monthStats),

              // ── 그룹 목록 ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _ShipmentGroupCard(group: groups[i]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  List<Map<String, dynamic>> _buildMonthStats(List<_ShipmentGroup> groups) {
    final map = <String, Map<String, dynamic>>{};
    for (final g in groups) {
      final month = g.outgoingDate.length >= 7
          ? g.outgoingDate.substring(0, 7)
          : g.outgoingDate;
      map.putIfAbsent(month, () => {'invoices': 0, 'items': 0});
      map[month]!['invoices'] = (map[month]!['invoices'] as int) + 1;
      map[month]!['items'] =
          (map[month]!['items'] as int) + g.items.length;
    }
    return map.entries
        .map((e) => {'month': e.key, ...e.value})
        .toList()
      ..sort((a, b) =>
          (b['month'] as String).compareTo(a['month'] as String));
  }
}

// ══════════════════════════════════════════════════
// 월별 요약 헤더
// ══════════════════════════════════════════════════

class _MonthlyHeader extends StatefulWidget {
  final List<Map<String, dynamic>> stats;
  const _MonthlyHeader({required this.stats});

  @override
  State<_MonthlyHeader> createState() => _MonthlyHeaderState();
}

class _MonthlyHeaderState extends State<_MonthlyHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final displayStats =
        _expanded ? widget.stats : widget.stats.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, size: 14,
                    color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('월별 현황',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                for (final s in displayStats) ...[
                  _MonthChip(
                    month: s['month'] as String,
                    invoices: s['invoices'] as int,
                    items: s['items'] as int,
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.stats.length > 3)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _expanded ? '접기' : '+${widget.stats.length - 3}개월',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final String month;
  final int invoices;
  final int items;
  const _MonthChip(
      {required this.month, required this.invoices, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(month,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 2),
          Text('송장 $invoices건  |  물품 $items개',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 그룹 카드 (날짜+송장)
// ══════════════════════════════════════════════════

class _ShipmentGroupCard extends StatelessWidget {
  final _ShipmentGroup group;
  const _ShipmentGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final profit = group.settlementTotal - group.purchaseTotal;
    final profitColor = profit >= 0 ? AppColors.success : AppColors.error;
    final hasAnyReturn = group.items.any((i) => i.hasReturn);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.sm, 6),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.outgoingDate,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        if (hasAnyReturn)
                          const Icon(Icons.warning_amber,
                              size: 14, color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.trackingNumber,
                      style: AppTheme.dataStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 수치 요약
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${group.items.length}개  |  ${_wonFormat.format(group.sellTotal)}원',
                    style: AppTheme.dataStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '정산 ${_wonFormat.format(group.settlementTotal)}원',
                        style: AppTheme.dataStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${group.profitRate >= 0 ? '+' : ''}${group.profitRate.toStringAsFixed(1)}%',
                        style: AppTheme.dataStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: profitColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 1, indent: AppSpacing.md),
            for (final item in group.items)
              _ShipmentItemRow(item: item),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 개별 아이템 행
// ══════════════════════════════════════════════════

class _ShipmentItemRow extends StatelessWidget {
  final _ShipmentItem item;
  const _ShipmentItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/item/${item.itemId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        child: Row(
          children: [
            // 반송 경고
            SizedBox(
              width: 18,
              child: item.hasReturn
                  ? const Icon(Icons.warning_amber,
                      size: 14, color: AppColors.warning)
                  : null,
            ),
            // 사이즈
            SizedBox(
              width: 32,
              child: Text(
                item.sizeKr,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // 모델명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.modelName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.modelCode,
                    style: AppTheme.dataStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            // 판매가 / 정산가
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.sellPrice != null)
                  Text(
                    '${_wonFormat.format(item.sellPrice)}원',
                    style: AppTheme.dataStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                if (item.settlementAmount != null)
                  Text(
                    '→ ${_wonFormat.format(item.settlementAmount)}원',
                    style: AppTheme.dataStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
