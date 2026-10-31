import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

import '../test_support/viewer_gestures.dart';

/// Model a delayed pointer release on a busy live test runner. Flutter stops
/// estimating fling velocity when its last movement sample is older than 40 ms.
class _StoppedPointer extends VelocityTracker {
  _StoppedPointer(super.kind) : super.withKind();

  @override
  VelocityEstimate getVelocityEstimate() => const VelocityEstimate(
    pixelsPerSecond: Offset.zero,
    confidence: 1,
    duration: Duration.zero,
    offset: Offset.zero,
  );
}

class _DelayedReleaseScrollBehavior extends MaterialScrollBehavior {
  const _DelayedReleaseScrollBehavior();

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      (event) => _StoppedPointer(event.kind);
}

void main() {
  for (final slop in <double?>[8, null]) {
    for (final height in [600.0, 914.0, 1200.0]) {
      testWidgets(
        'viewer paging survives zero release velocity at height $height, touch slop $slop',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(411, height));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = PageController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              scrollBehavior: const _DelayedReleaseScrollBehavior(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  gestureSettings: DeviceGestureSettings(touchSlop: slop),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: PageView(
                  key: Keys.viewerPager,
                  controller: controller,
                  scrollDirection: Axis.vertical,
                  children: [
                    InteractiveViewer(
                      child: const Center(
                        child: SizedBox(
                          width: 160,
                          height: 120,
                          child: ColoredBox(color: Colors.red),
                        ),
                      ),
                    ),
                    const ColoredBox(color: Colors.blue),
                  ],
                ),
              ),
            ),
          );
          await swipeViewerPage(tester, forward: true);
          await tester.pumpAndSettle();
          expect(
            controller.page,
            1,
            reason: 'A real swipe must cross the page boundary without depending on fling velocity',
          );
          await swipeViewerPage(tester, forward: false);
          await tester.pumpAndSettle();
          expect(controller.page, 0);
        },
      );
    }
  }
}
