import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/licenses.dart';

import '../test_support/license_loading.dart';

void main() {
  testWidgets('Android licenses expose the bundled coroutines attribution', (
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
    final notice = find.widgetWithText(
      ListTile,
      'kotlinx.coroutines (Android)',
    );
    await tester.scrollUntilVisible(
      notice,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(notice, findsOneWidget);
    await tester.tap(notice);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Copyright 2016-2024 JetBrains s.r.o and contributors',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Apache License'), findsWidgets);
    if (notice.hitTestable().evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    final eff = find.widgetWithText(ListTile, 'EFF Long Wordlist');
    await tester.scrollUntilVisible(
      eff,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(eff);
    await tester.pumpAndSettle();
    expect(find.textContaining('CC BY 4.0'), findsWidgets);
    if (eff.hitTestable().evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    final google = find.widgetWithText(
      ListTile,
      'Google Play services / Animal Sniffer (Android)',
    );
    await tester.scrollUntilVisible(
      google,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Kohsuke Kawaguchi and codehaus.org.'),
      findsWidgets,
    );
    expect(find.textContaining('The MIT License'), findsWidgets);
  });
}
