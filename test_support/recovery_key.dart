import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

/// Passes the recovery key screen at Setup: "I saved it", then the whole
/// shown key typed back in the confirm step (decision 042).
Future<void> saveRecoveryKey(WidgetTester tester) async {
  final shown = tester
      .widget<SelectableText>(find.byKey(Keys.recoveryKeyText))
      .data!;
  await tester.ensureVisible(find.byKey(Keys.recoveryDone));
  await tester.tap(find.byKey(Keys.recoveryDone));
  await tester.pump();
  await tester.enterText(find.byKey(Keys.recoveryConfirmField), shown);
  await tester.tap(find.byKey(Keys.recoveryConfirmOk));
}
