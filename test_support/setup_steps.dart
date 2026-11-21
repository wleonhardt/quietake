import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

Future<void> _step(WidgetTester tester, Key key) async {
  if (find.byKey(key).evaluate().isEmpty) return;
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// From Setup's welcome step to the passcode form (decision 046). Does
/// nothing when that step is not on screen.
Future<void> openSetupCreate(WidgetTester tester) =>
    _step(tester, Keys.setupCreateOpen);

/// From Setup's welcome step to the page that lists the ways to restore.
Future<void> openSetupRestore(WidgetTester tester) =>
    _step(tester, Keys.setupRestoreOpen);

/// From Setup's welcome step to the recovery key form.
Future<void> openSetupRecoveryKey(WidgetTester tester) async {
  await openSetupRestore(tester);
  await _step(tester, Keys.setupToggleRestore);
}
