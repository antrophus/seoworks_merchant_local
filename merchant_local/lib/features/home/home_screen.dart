import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../listings/listings_screen.dart';
import '../orders/orders_screen.dart';
import '../scan/scan_screen.dart';
import '../../core/providers.dart';

/// 현재 선택된 탭 인덱스
final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    DashboardScreen(),
    InventoryScreen(),
    ScanScreen(),
    ListingsScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(homeTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Local'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(tabIndex),
          child: _tabs[tabIndex],
        ),
      ),
      floatingActionButton: tabIndex == 1
          ? FloatingActionButton(
              onPressed: () => context.push('/register'),
              tooltip: '입고 등록',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withAlpha(30),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: tabIndex,
          onDestinationSelected: (i) {
            if (i == 0) ref.invalidate(itemStatusCountsProvider);
            ref.read(homeTabProvider.notifier).state = i;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: '대시보드',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: '재고',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: '스캔',
            ),
            NavigationDestination(
              icon: Icon(Icons.sell_outlined),
              selectedIcon: Icon(Icons.sell),
              label: '리스팅',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: '주문',
            ),
          ],
        ),
      ),
    );
  }
}
