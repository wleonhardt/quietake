import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/change_passcode_screen.dart';
import 'package:quietake/lock/lock_screen.dart';
import 'package:quietake/lock/setup_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test_support/fake_authenticator.dart';

class _RejectingStore extends MasterKeyStore {
  _RejectingStore(SodiumSumo sodium) : super(sodium, Directory.systemTemp);
  @override
  Future<bool> get hasCachedKey async => false;
  @override
  Future<SecureKey> unlockWithPasscode(String passcode) async =>
      throw WrongPasscodeException();
  @override
  Future<void> changePasscode(String current, String next) async =>
      throw WrongPasscodeException();
}

void main() {
  late MasterKeyStore store;
  setUpAll(() async {
    store = _RejectingStore(await SodiumSumoInit.init());
  });

  void expectAnnouncement(WidgetTester tester, Key key, String message) {
    final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
    expect(data.label, message);
    expect(data.flagsCollection.isLiveRegion, isTrue);
  }

  for (final form in ['setup', 'unlock', 'change']) {
    testWidgets(
      '$form stays readable on wide windows and scrolls above keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (screen, field, submit) = switch (form) {
          'setup' => (
            SetupScreen(store: store, onUnlocked: (_) => fail('Unlocked')),
            Keys.setupPasscode,
            Keys.setupSubmit,
          ),
          'unlock' => (
            LockScreen(
              store: store,
              auth: FakeAuthenticator(isAvailable: false),
              onUnlocked: (_) => fail('Unlocked'),
            ),
            Keys.lockPasscode,
            Keys.lockUnlock,
          ),
          _ => (
            ChangePasscodeScreen(store: store),
            Keys.currentPasscode,
            Keys.changePasscodeSubmit,
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: quietakeTheme(),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: tester.view.physicalSize,
                textScaler: TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pump();
        expect(tester.getSize(find.byKey(field)).width, lessThanOrEqualTo(600));
        if (form != 'unlock') {
          final next = form == 'setup' ? Keys.setupConfirm : Keys.newPasscode;
          expect(
            tester.getTopLeft(find.byKey(next)).dy -
                tester.getBottomLeft(find.byKey(field)).dy,
            greaterThanOrEqualTo(16),
          );
        }
        await tester.ensureVisible(find.byKey(submit));
        await tester.pumpAndSettle();
        expect(find.byKey(submit).hitTestable(), findsOneWidget);
        tester.view.physicalSize = const Size(320, 640);
        await tester.pump();
        await tester.ensureVisible(find.byKey(field));
        await tester.enterText(find.byKey(field), 'synthetic');
        await tester.ensureVisible(find.byKey(submit));
        await tester.pumpAndSettle();
        expect(find.byKey(submit).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> expectGuidelines(WidgetTester tester) async {
    for (final guideline in [
      androidTapTargetGuideline,
      iOSTapTargetGuideline,
      labeledTapTargetGuideline,
      textContrastGuideline,
    ]) {
      await expectLater(tester, meetsGuideline(guideline));
    }
  }

  testWidgets('setup announces short and mismatched passcodes', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: quietakeTheme(),
          home: SetupScreen(store: store, onUnlocked: (_) => fail('Unlocked')),
        ),
      );
      await tester.tap(find.byKey(Keys.setupSubmit));
      await tester.pump();
      expectAnnouncement(
        tester,
        Keys.setupError,
        'Passcode needs at least 6 characters',
      );
      await tester.enterText(find.byKey(Keys.setupPasscode), 'test-passcode');
      await tester.tap(find.byKey(Keys.setupSubmit));
      await tester.pump();
      expectAnnouncement(tester, Keys.setupError, 'Passcodes do not match');
      await expectGuidelines(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unlock announces rejected passcode without exposing input', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: quietakeTheme(),
          home: LockScreen(
            store: store,
            auth: FakeAuthenticator(isAvailable: false),
            onUnlocked: (_) => fail('Unlocked'),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(Keys.lockPasscode), 'wrong');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expectAnnouncement(tester, Keys.lockError, 'wrong passcode');
      expect(
        tester.widget<TextField>(find.byKey(Keys.lockPasscode)).obscureText,
        isTrue,
      );
      await expectGuidelines(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'passcode change announces validation and authentication errors',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: quietakeTheme(),
            home: ChangePasscodeScreen(store: store),
          ),
        );
        await tester.enterText(find.byKey(Keys.newPasscode), 'replacement');
        await tester.tap(find.byKey(Keys.changePasscodeSubmit));
        await tester.pump();
        expectAnnouncement(
          tester,
          Keys.changePasscodeError,
          'Passcodes do not match',
        );
        await tester.enterText(find.byKey(Keys.confirmPasscode), 'replacement');
        await tester.tap(find.byKey(Keys.changePasscodeSubmit));
        await tester.pump();
        expectAnnouncement(
          tester,
          Keys.changePasscodeError,
          'Current passcode is incorrect',
        );
        await expectGuidelines(tester);
      } finally {
        semantics.dispose();
      }
    },
  );
}
