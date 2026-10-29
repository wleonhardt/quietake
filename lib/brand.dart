import 'package:flutter/material.dart';

/// Brand palette per brightness. Containers rise in tone monotonically from
/// surface, so dialogs and sheets never land on the wrong side of the page.
class _Palette {
  const _Palette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.containerLowest,
    required this.containerLow,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
  });
  final Color primary,
      onPrimary,
      primaryContainer,
      onPrimaryContainer,
      secondaryContainer,
      onSecondaryContainer,
      surface,
      onSurface,
      onSurfaceVariant,
      outline,
      outlineVariant,
      surfaceDim,
      surfaceBright,
      containerLowest,
      containerLow,
      container,
      containerHigh,
      containerHighest;
}

const _dark = _Palette(
  primary: Color(0xffbfd1ff),
  onPrimary: Color(0xff15264b),
  primaryContainer: Color(0xff2c4a94),
  onPrimaryContainer: Color(0xffdce6ff),
  secondaryContainer: Color(0xff34445c),
  onSecondaryContainer: Color(0xffdbe3f2),
  surface: Color(0xff121923),
  onSurface: Color(0xffedf3ff),
  onSurfaceVariant: Color(0xffbccadd),
  outline: Color(0xff8092ad),
  outlineVariant: Color(0xff4b5d76),
  surfaceDim: Color(0xff121923),
  surfaceBright: Color(0xff35445b),
  containerLowest: Color(0xff0b1119),
  containerLow: Color(0xff1b2430),
  container: Color(0xff202c3b),
  containerHigh: Color(0xff253140),
  containerHighest: Color(0xff303f52),
);

const _light = _Palette(
  primary: Color(0xff2850b9),
  onPrimary: Color(0xffffffff),
  primaryContainer: Color(0xffdbe4ff),
  onPrimaryContainer: Color(0xff14264d),
  secondaryContainer: Color(0xffe3e8f2),
  onSecondaryContainer: Color(0xff28364d),
  surface: Color(0xfff8f9fc),
  onSurface: Color(0xff142033),
  onSurfaceVariant: Color(0xff4c5d76),
  outline: Color(0xff718099),
  outlineVariant: Color(0xffbac5d7),
  surfaceDim: Color(0xffd4dce7),
  surfaceBright: Color(0xffffffff),
  containerLowest: Color(0xffffffff),
  containerLow: Color(0xfff1f3f6),
  container: Color(0xffe8edf5),
  containerHigh: Color(0xffe2e7ef),
  containerHighest: Color(0xffd9e1ed),
);

/// Media canvases stay dark in every theme so photos and the camera preview
/// read the same way. The camera and viewer use only these tokens.
const mediaCanvas = Color(0xff000000);
const cameraCanvas = Color(0xff121923);
const onMediaCanvas = Color(0xffffffff);
const onMediaCanvasMuted = Color(0xb3ffffff);
const mediaScrim = Color(0x8a000000);
const mediaScrimStrong = Color(0xdd000000);
const mediaScrimCircle = Color(0x99000000);
const recordAccent = Color(0xffffb4ab);
const recordRing = Color(0x99ff5252);
const flashRing = Color(0x59ffffff);
const okAccent = Color(0xff69f0ae);
const warnAccent = Color(0xffffd740);

/// One corner radius family: 16 for controls and inputs, 28 for dialogs and
/// sheets, 12 for chips.
const _controlRadius = 16.0;

ThemeData quietakeTheme({
  Brightness brightness = Brightness.dark,
  bool highContrast = false,
}) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? _dark : _light;
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xff2850b9),
    brightness: brightness,
    contrastLevel: highContrast ? 1 : 0,
  );
  final colors = highContrast
      ? seeded
      : seeded.copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          primaryContainer: palette.primaryContainer,
          onPrimaryContainer: palette.onPrimaryContainer,
          secondaryContainer: palette.secondaryContainer,
          onSecondaryContainer: palette.onSecondaryContainer,
          surface: palette.surface,
          onSurface: palette.onSurface,
          onSurfaceVariant: palette.onSurfaceVariant,
          outline: palette.outline,
          outlineVariant: palette.outlineVariant,
          surfaceDim: palette.surfaceDim,
          surfaceBright: palette.surfaceBright,
          surfaceContainerLowest: palette.containerLowest,
          surfaceContainerLow: palette.containerLow,
          surfaceContainer: palette.container,
          surfaceContainerHigh: palette.containerHigh,
          surfaceContainerHighest: palette.containerHighest,
        );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_controlRadius),
  );
  OutlineInputBorder inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      border: inputBorder(colors.outline),
      enabledBorder: inputBorder(colors.outline),
      focusedBorder: inputBorder(colors.primary, width: 2),
      errorBorder: inputBorder(colors.error),
      focusedErrorBorder: inputBorder(colors.error, width: 2),
      disabledBorder: inputBorder(colors.outlineVariant),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: controlShape,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: colors.outlineVariant),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 32),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      children: [
        Image.asset(
          'assets/brand/quietake.png',
          width: 80,
          height: 80,
          excludeFromSemantics: true,
        ),
        Text(
          'Quietake',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
        ),
        Text(
          'Private camera',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
