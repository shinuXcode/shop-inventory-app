import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbill/app.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  testWidgets('SBILL app shell boots with the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const SBillApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Today’s sales'), findsOneWidget);
    expect(find.text('Invoices today'), findsOneWidget);
    expect(find.text('Low-stock items'), findsOneWidget);
  });
}
