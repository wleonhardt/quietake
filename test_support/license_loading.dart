import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// License assets use real decoding isolates, outside the widget fake clock.
Future<void> waitForLicenseLoading(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    final entries = find.descendant(
      of: find.byType(LicensePage),
      matching: find.byType(ListTile),
    );
    while (entries.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('License asset decoding did not finish');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}
