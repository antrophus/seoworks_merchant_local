import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../inventory_providers.dart';

// ══════════════════════════════════════════════════
// 필터 칩
// ══════════════════════════════════════════════════

class InventoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const InventoryFilterChip(
      {super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ══════════════════════════════════════════════════
// 서브 필터 탭
// ══════════════════════════════════════════════════

class SubFilterTabs extends ConsumerWidget {
  final FilterDef filterDef;
  final int? selectedIndex;
  final String parentFilterCsv;
  final void Function(int?) onSelect;

  const SubFilterTabs({
    super.key,
    required this.filterDef,
    required this.selectedIndex,
    required this.parentFilterCsv,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentItems =
        ref.watch(multiStatusProvider(parentFilterCsv)).valueOrNull ?? [];
    final counts = <int>[];
    for (final status in filterDef.statuses) {
      counts.add(parentItems.where((i) => i.currentStatus == status).length);
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(filterDef.subLabels!.length, (i) {
          final selected = selectedIndex == i;
          final color = selected
              ? Theme.of(context).colorScheme.primary
              : AppColors.textSecondary;

          return Expanded(
            child: InkWell(
              onTap: () => onSelect(selectedIndex == i ? null : i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  '${filterDef.subLabels![i]} ${counts[i]}개',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
