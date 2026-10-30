import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/licenses.dart';

import '../test_support/license_loading.dart';

void main() {
  testWidgets('Quietake license includes MPL terms and its source location', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppLicenses(context),
            child: const Text('Licenses'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Licenses'));
    await waitForLicenseLoading(tester);
    final entry = find.widgetWithText(ListTile, 'Quietake');
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mozilla Public License Version 2.0'),
      findsWidgets,
    );
    expect(
      find.textContaining('https://github.com/wleonhardt/quietake'),
      findsWidgets,
    );
  });
}
