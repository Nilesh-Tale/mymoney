import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/models/finance_models.dart';
import 'package:frontend/providers/finance_providers.dart';

void main() {
  testWidgets('Sayali Nilesh finance manager starts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) async => <FinanceAccount>[]),
          categoriesProvider.overrideWith((ref) async => <FinanceCategory>[]),
          transactionsProvider.overrideWith(
            (ref) async => <FinanceTransaction>[],
          ),
          incomeCategoriesProvider.overrideWith(
            (ref) async => <FinanceCategory>[],
          ),
          expenseCategoriesProvider.overrideWith(
            (ref) async => <FinanceCategory>[],
          ),
        ],
        child: const SayaliNileshApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(MainDashboard), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'Sayali Nilesh – Personal Finance Manager');
  });
}
