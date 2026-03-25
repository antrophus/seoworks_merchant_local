import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/inventory/item_detail_screen.dart';
import 'features/inventory/purchase_form_screen.dart';
import 'features/inventory/sale_form_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/exceptions/exceptions_screen.dart';
import 'features/logistics/logistics_screen.dart';
import 'features/purchases/purchases_screen.dart';
import 'features/sales/sales_screen.dart';
import 'features/inventory/item_register_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/item/:id',
      builder: (context, state) => ItemDetailScreen(
        itemId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/item/:id/purchase',
      builder: (context, state) => PurchaseFormScreen(
        itemId: state.pathParameters['id']!,
        purchaseId: state.uri.queryParameters['edit'],
      ),
    ),
    GoRoute(
      path: '/item/:id/sale',
      builder: (context, state) => SaleFormScreen(
        itemId: state.pathParameters['id']!,
        saleId: state.uri.queryParameters['edit'],
      ),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/exceptions',
      builder: (context, state) => const ExceptionsScreen(),
    ),
    GoRoute(
      path: '/logistics',
      builder: (context, state) => const LogisticsScreen(),
    ),
    GoRoute(
      path: '/purchases',
      builder: (context, state) => const PurchasesScreen(),
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => const SalesScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => ItemRegisterScreen(
        prefillBrand: state.uri.queryParameters['brand'],
        prefillModelCode: state.uri.queryParameters['modelCode'],
        prefillModelName: state.uri.queryParameters['modelName'],
        prefillSizeKr: state.uri.queryParameters['sizeKr'],
        prefillCategory: state.uri.queryParameters['category'],
      ),
    ),
  ],
);

class MerchantApp extends ConsumerWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SEOWORKS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
