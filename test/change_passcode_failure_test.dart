import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/change_passcode_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

class _FailingStore extends MasterKeyStore {
  _FailingStore(SodiumSumo sodium) : super(sodium, Directory.systemTemp);
  Object failure = const FormatException('Use at least six characters');
  @override
  Future<void> changePasscode(String current, String next) async =>
      throw failure;
}

void main() {
  late SodiumSumo sodium;
  setUpAll(() async => sodium = await SodiumSumoInit.init());

  testWidgets('format and storage failures show a reason and keep the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _FailingStore(sodium);
    await tester.pumpWidget(
      MaterialApp(home: ChangePasscodeScreen(store: store)),
    );
    await tester.enterText(find.byKey(Keys.currentPasscode), 'current');
    await tester.enterText(find.byKey(Keys.newPasscode), 'abc');
    await tester.enterText(find.byKey(Keys.confirmPasscode), 'abc');
    await tester.tap(find.byKey(Keys.changePasscodeSubmit));
    await tester.pump();
    await tester.pump();
    expect(find.text('Use at least six characters'), findsOneWidget);
    store.failure = const FileSystemException('disk full');
    await tester.tap(find.byKey(Keys.changePasscodeSubmit));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not change passcode. Try again.'), findsOneWidget);
    expect(find.byKey(Keys.changePasscodeSubmit), findsOneWidget);
  });
}
