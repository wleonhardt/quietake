import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';
import 'package:quietake/lock/change_passcode_screen.dart';
import 'package:quietake/vault/master_key_store.dart';
import 'package:sodium/sodium_sumo.dart';

class _Store extends MasterKeyStore {
  _Store(SodiumSumo sodium) : super(sodium, Directory.systemTemp);
  int calls = 0;
  final saved = Completer<void>();
  @override
  Future<void> changePasscode(String current, String next) {
    calls++;
    if (current != 'current') throw WrongPasscodeException();
    return saved.future;
  }
}

void main() {
  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets(
      'passcode form validates and saves once with 2x text at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late SodiumSumo sodium;
        await tester.runAsync(() async {
          sodium = await SodiumSumoInit.init();
        });
        final store = _Store(sodium);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => ChangePasscodeScreen(store: store),
                    ),
                  ),
                  child: const Text('Open change'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open change'));
        await tester.pumpAndSettle();
        Future<void> enter(Key key, String value) async {
          await tester.ensureVisible(find.byKey(Keys.currentPasscode));
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byKey(key),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byKey(key), value);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }

        Future<void> save() async {
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(Keys.changePasscodeSubmit),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(Keys.changePasscodeSubmit));
          await tester.pumpAndSettle();
          expect(
            find.byKey(Keys.changePasscodeSubmit).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(Keys.changePasscodeSubmit));
          await tester.pump();
        }

        await enter(Keys.currentPasscode, 'wrong');
        await enter(Keys.newPasscode, 'replacement');
        await enter(Keys.confirmPasscode, 'mismatch');
        await save();
        expect(store.calls, 0);
        expect(find.text('Passcodes do not match'), findsOneWidget);
        await enter(Keys.confirmPasscode, 'replacement');
        await save();
        expect(find.text('Current passcode is incorrect'), findsOneWidget);
        await enter(Keys.currentPasscode, 'current');
        await save();
        expect(
          tester
              .widget<FilledButton>(find.byKey(Keys.changePasscodeSubmit))
              .onPressed,
          isNull,
        );
        expect(store.calls, 2);
        store.saved.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(Keys.changePasscodeError), findsNothing);
        expect(find.text('Open change'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
