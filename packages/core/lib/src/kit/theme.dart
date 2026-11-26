import 'package:material_ui/material_ui.dart';
import 'balsm_kit.dart';

// Material displayMedium; no Balsm text role uses it.
const _displayMediumSize = 28.0;

class BalsmTheme {
  static const _fontFamily = 'Inter';

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: const ColorScheme.light(
          primary: AppColors.hueBlue,
          secondary: AppColors.hueAqua,
          onSecondary: AppColors.white,
          error: AppColors.danger,
          onSurface: AppColors.ink900,
          surfaceContainerHighest: AppColors.cream100,
        ),
        textTheme: _textTheme(AppColors.ink900),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink900,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: const BorderSide(color: AppColors.ink200),
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.ink200, thickness: 1),
        inputDecorationTheme: _inputDecoration(light: true),
        elevatedButtonTheme: _elevatedButton(),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.hueBlueOnDark,
          secondary: AppColors.hueAquaOnDark,
          error: AppColors.dangerOnDark,
          surface: AppColors.nearBlack,
          onSurface: AppColors.ink50,
        ),
        textTheme: _textTheme(AppColors.ink50),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.nearBlack,
          foregroundColor: AppColors.ink50,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.nearBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: const BorderSide(color: AppColors.ink800),
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.ink800, thickness: 1),
        inputDecorationTheme: _inputDecoration(light: false),
        elevatedButtonTheme: _elevatedButton(),
      );

  static TextTheme _textTheme(Color color) => TextTheme(
        displayLarge: TextStyle(fontSize: FontSizes.display, fontWeight: FontWeight.w700, color: color, height: 1.2),
        displayMedium: TextStyle(fontSize: _displayMediumSize, fontWeight: FontWeight.w700, color: color, height: 1.2),
        headlineMedium: TextStyle(fontSize: FontSizes.headline, fontWeight: FontWeight.w600, color: color),
        headlineSmall: TextStyle(fontSize: FontSizes.subhead, fontWeight: FontWeight.w600, color: color),
        titleLarge: TextStyle(fontSize: FontSizes.subheadSm, fontWeight: FontWeight.w600, color: color),
        titleMedium: TextStyle(fontSize: FontSizes.bodyLg, fontWeight: FontWeight.w500, color: color),
        bodyLarge: TextStyle(fontSize: FontSizes.body, fontWeight: FontWeight.w400, color: color, height: 1.5),
        bodyMedium: TextStyle(fontSize: FontSizes.description, fontWeight: FontWeight.w400, color: color, height: 1.5),
        labelLarge: TextStyle(fontSize: FontSizes.bodyLg, fontWeight: FontWeight.w600, color: color),
        labelSmall:
            TextStyle(fontSize: FontSizes.eyebrow, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.3),
      );

  static InputDecorationTheme _inputDecoration({required bool light}) => InputDecorationTheme(
        filled: true,
        fillColor: light ? AppColors.surface : AppColors.nearBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: light ? AppColors.ink200 : AppColors.ink800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: light ? AppColors.ink200 : AppColors.ink800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.hueBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  static ElevatedButtonThemeData _elevatedButton() => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hueBlue,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          textStyle: const TextStyle(fontSize: FontSizes.body, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      );
}

class RtlWrapper extends StatelessWidget {
  const RtlWrapper({required this.isRtl, required this.child, super.key});

  final bool isRtl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    );
  }
}
