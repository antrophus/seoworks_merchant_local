import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant_local/app.dart';

void main() {
  testWidgets('App renders HomeScreen with navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MerchantApp()));
    await tester.pumpAndSettle();

    // 홈 화면의 탭 네비게이션이 표시되는지 확인
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
