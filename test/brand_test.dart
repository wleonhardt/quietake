import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/brand.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      final theme = quietakeTheme(
        brightness: brightness,
        highContrast: highContrast,
      );
      testWidgets(
        'Quietake header fits large text in $brightness, contrast=$highContrast',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (_, child) => MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ListView(
                    children: const [
                      BrandHeader(
                        message: 'Your camera. Your captures. Your control.',
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Quietake'), findsOneWidget);
            expect(find.text('Private camera'), findsOneWidget);
            final mark = tester.widget<Image>(find.byType(Image));
            expect(
              (mark.image as AssetImage).assetName,
              'assets/brand/quietake.png',
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
      test(
        'studio color roles remain readable in $brightness, contrast=$highContrast',
        () {
          final colors = theme.colorScheme;
          double contrast(Color foreground, Color background) {
            final values = [
              foreground.computeLuminance(),
              background.computeLuminance(),
            ]..sort();
            return (values.last + .05) / (values.first + .05);
          }

          expect(theme.brightness, brightness);
          if (!highContrast) {
            expect(
              colors.primary,
              Color(brightness == Brightness.dark ? 0xffbfd1ff : 0xff2850b9),
            );
            expect(
              colors.surface,
              Color(brightness == Brightness.dark ? 0xff121923 : 0xfff8f9fc),
            );
          }
          // Containers rise monotonically from the page in both modes, so a
          // dialog (containerHigh) is never on the other side of a sheet
          // (containerLow) relative to the surface.
          double lum(Color c) => c.computeLuminance();
          final ramp = [
            colors.surfaceContainerLow,
            colors.surfaceContainer,
            colors.surfaceContainerHigh,
            colors.surfaceContainerHighest,
          ].map(lum).toList();
          for (var i = 1; i < ramp.length; i++) {
            expect(
              brightness == Brightness.dark
                  ? ramp[i] >= ramp[i - 1]
                  : ramp[i] <= ramp[i - 1],
              isTrue,
              reason: 'container ramp step $i',
            );
          }
          expect(
            brightness == Brightness.dark
                ? ramp.first >= lum(colors.surface)
                : ramp.first <= lum(colors.surface),
            isTrue,
            reason: 'containers sit beyond the page surface',
          );
          if (highContrast) {
            expect(
              contrast(colors.onSurface, colors.surface),
              greaterThanOrEqualTo(7),
            );
            expect(
              contrast(colors.outline, colors.surface),
              greaterThanOrEqualTo(4.5),
            );
          }
          expect(theme.dialogTheme.shape, isNotNull);
          expect(theme.bottomSheetTheme.shape, isNotNull);
          expect(
            (theme.inputDecorationTheme.focusedBorder as OutlineInputBorder)
                .borderRadius,
            BorderRadius.circular(16),
          );
          for (final pair in [
            (colors.onPrimary, colors.primary),
            (colors.onPrimaryContainer, colors.primaryContainer),
            (colors.onSecondaryContainer, colors.secondaryContainer),
            (colors.onError, colors.error),
            (colors.primary, colors.surface),
            (colors.onSurface, colors.surface),
            (colors.onSurfaceVariant, colors.surfaceContainerLow),
            (colors.onSurfaceVariant, colors.surfaceContainerHighest),
          ]) {
            expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
          }
          expect(
            contrast(colors.outline, colors.surfaceContainerLow),
            greaterThanOrEqualTo(3),
          );
        },
      );
    }
  }
}
