import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/privacy/screen_privacy.dart';

void main() {
  testWidgets(
    'native capture events and frame acknowledgments follow the current root',
    (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        (call) async {
          calls.add(call.method);
          return call.method == 'status' ? {'captured': true} : null;
        },
      );
      final firstEvents = <bool>[], currentEvents = <bool>[];
      final first = ScreenPrivacy(firstEvents.add);
      await first.start();
      var backgrounds = 0;
      final current = ScreenPrivacy(
        currentEvents.add,
        onBackground: () async {
          backgrounds++;
        },
      );
      await current.start();
      first.dispose();
      ui.channelBuffers.push(
        ScreenPrivacy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('state', {
            'captured': false,
            'backgrounded': true,
            'generation': 1,
          }),
        ),
        (_) {},
      );
      await tester.pump();
      expect(firstEvents, [true]);
      expect(currentEvents, [true, false]);
      expect(backgrounds, 1);
      expect(calls.where((c) => c == 'ready'), isNotEmpty);
      current.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        null,
      );
    },
  );
  testWidgets('a failing background callback still acknowledges the cover', (
    tester,
  ) async {
    final acknowledged = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ScreenPrivacy.channel,
      (call) async {
        if (call.method == 'ready') acknowledged.add(call.arguments);
        return call.method == 'status' ? {'captured': false} : null;
      },
    );
    final privacy = ScreenPrivacy(
      (_) {},
      onBackground: () async => throw StateError('keystore unavailable'),
    );
    await privacy.start();
    ui.channelBuffers.push(
      ScreenPrivacy.channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('state', {
          'captured': false,
          'backgrounded': true,
          'generation': 1,
        }),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump();
    expect(acknowledged, contains(1));
    expect(tester.takeException(), isNull);
    privacy.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ScreenPrivacy.channel,
      null,
    );
  });

  testWidgets(
    'resume waits for the lock gate and rejects stale native frames',
    (tester) async {
      final ready = <int>[];
      final events = <bool>[];
      final background = Completer<void>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        (call) async {
          if (call.method == 'ready') ready.add(call.arguments as int);
          return call.method == 'status'
              ? {'captured': false, 'generation': 0}
              : null;
        },
      );
      final privacy = ScreenPrivacy(
        events.add,
        onBackground: () => background.future,
      );
      addTearDown(() {
        privacy.dispose();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ScreenPrivacy.channel,
          null,
        );
      });
      await privacy.start();
      void state(int generation, bool captured, {bool backgrounded = false}) =>
          ui.channelBuffers.push(
            ScreenPrivacy.channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('state', {
                'generation': generation,
                'captured': captured,
                'backgrounded': backgrounded,
              }),
            ),
            (_) {},
          );
      state(1, false, backgrounded: true);
      await tester.pump();
      expect(
        ready,
        isEmpty,
        reason: 'No frame may uncover a pending resume lock',
      );
      state(2, true);
      await tester.pump();
      expect(events, [false, true]);
      expect(ready, [2]);
      background.complete();
      state(1, false);
      await tester.pump();
      expect(events, [false, true]);
      expect(ready, [
        2,
      ], reason: 'The old background result and frame are obsolete');
      state(3, false);
      await tester.pump();
      expect(events.last, isFalse);
      expect(ready, [2, 3]);
    },
  );
}
