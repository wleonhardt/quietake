import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/keys.dart';

/// Cross the midpoint without depending on a live runner's fling velocity.
Future<void> swipeViewerPage(
  WidgetTester tester, {
  required bool forward,
}) async {
  final pager = find.byKey(Keys.viewerPager);
  final bounds = tester.getRect(pager);
  final touchSlop =
      MediaQuery.gestureSettingsOf(tester.element(pager)).touchSlop ??
      kTouchSlop;
  final start = Offset(
    bounds.center.dx,
    bounds.top + bounds.height * (forward ? 0.8 : 0.2),
  );
  await tester.dragFrom(
    start,
    Offset(0, bounds.height * (forward ? -0.6 : 0.6)),
    // Recognize the vertical drag before the nested photo's pan threshold (2x).
    touchSlopY: touchSlop * 1.5,
  );
}
