import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

/// From Settings to the backup server screen (decision 047). Does nothing
/// when the row is not on screen, for example when that screen is open.
Future<void> openBackupSettings(WidgetTester tester) async {
  final row = find.byKey(Keys.settingsBackupOpen);
  if (row.evaluate().isEmpty) return;
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
