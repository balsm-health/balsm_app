import 'package:flutter/material.dart';
import 'balsm_kit.dart';

class BalsmTheme {
  static const _fontFamily = 'Inter';

  // Dark-mode variants (not in the light token palette).
  static const _petalBlueLight = Color(0xFF5AA8FF);
  static const _petalAquaLight = Color(0xFF3FD3CD);
  static const _dangerLight = Color(0xFFE57A6E);
  static const _darkSurface = Color(0xFF1A1A14);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: const ColorScheme.light(
          primary: BalsmColors.petalBlue,
          onPrimary: Colors.white,
          secondary: BalsmColors.petalAqua,
          onSecondary: Colors.white,
          error: BalsmColors.danger,
          onError: Colors.white,
          surface: BalsmColors.surface,
          onSurface: BalsmColors.ink900,
          surfaceContainerHighest: BalsmColors.cream100,
        ),
        textTheme: _textTheme(BalsmColors.ink900),
        appBarTheme: const AppBarTheme(
          backgroundColor: BalsmColors.surface,
          foregroundColor: BalsmColors.ink900,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: BalsmColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: BalsmColors.ink200),
          ),
        ),
        dividerTheme: const DividerThemeData(color: BalsmColors.ink200, thickness: 1),
        inputDecorationTheme: _inputDecoration(light: true),
        elevatedButtonTheme: _elevatedButton(),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _petalBlueLight,
          onPrimary: Colors.black,
          secondary: _petalAquaLight,
          onSecondary: Colors.black,
          error: _dangerLight,
          onError: Colors.black,
          surface: _darkSurface,
          onSurface: BalsmColors.ink50,
        ),
        textTheme: _textTheme(BalsmColors.ink50),
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkSurface,
          foregroundColor: BalsmColors.ink50,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: BalsmColors.ink800),
          ),
        ),
        dividerTheme: const DividerThemeData(color: BalsmColors.ink800, thickness: 1),
        inputDecorationTheme: _inputDecoration(light: false),
        elevatedButtonTheme: _elevatedButton(),
      );

  static TextTheme _textTheme(Color color) => TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, height: 1.2),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: color, height: 1.5),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.3),
      );

  static InputDecorationTheme _inputDecoration({required bool light}) => InputDecorationTheme(
        filled: true,
        fillColor: light ? BalsmColors.surface : _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: light ? BalsmColors.ink200 : BalsmColors.ink800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: light ? BalsmColors.ink200 : BalsmColors.ink800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BalsmColors.petalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BalsmColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  static ElevatedButtonThemeData _elevatedButton() => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BalsmColors.petalBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      );
}

class RtlWrapper extends StatelessWidget {
  const RtlWrapper({super.key, required this.isRtl, required this.child});

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
