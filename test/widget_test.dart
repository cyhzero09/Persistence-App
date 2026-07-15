import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:persistence_app/app.dart';

void main() {
  testWidgets('App renders bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DailyTrackerApp()));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
