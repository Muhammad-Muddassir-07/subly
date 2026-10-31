import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subly/app.dart';
import 'package:subly/data/services/local_store.dart';
import 'package:subly/features/search/search_screen.dart';
import 'package:subly/shared/providers/app_providers.dart';

void main() {
  testWidgets('SublyApp renders successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
        ],
        child: const SublyApp(),
      ),
    );

    expect(find.byType(SublyApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SearchScreen renders search input and empty state without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SearchScreen()),
        ),
      ),
    );

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search your subscriptions'), findsWidgets);
    await tester.pump();
  });
}
