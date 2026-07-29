import 'package:flutter/material.dart';

// Design tokens from Balsm-Core/brand/colors_and_type.css
// Superseded by BalsmTheme in T063 (Phase 2).
class BalsmColors {
  BalsmColors._();

  static const petalAqua = Color(0xFF02BBB5);
  static const petalEmerald = Color(0xFF01C4A2);
  static const petalBlue = Color(0xFF1283FF);
  static const petalMint = Color(0xFF55D77F);
  static const petalViolet = Color(0xFF724DD0);

  static const petalBlue600 = Color(0xFF0F6BCC);
  static const petalMint600 = Color(0xFF3FC366);
  static const petalViolet600 = Color(0xFF5C3AB0);

  static const petalAqua50 = Color(0xFFE2F8F6);
  static const petalBlue50 = Color(0xFFE4F0FF);
  static const petalMint50 = Color(0xFFE8F9EE);
  static const petalViolet50 = Color(0xFFECE6FA);

  // App accent = petal-blue (primary CTA, focus, links)
  static const appAccent = petalBlue;
  static const appAccent600 = petalBlue600;
  static const appAccent50 = petalBlue50;

  // Neutrals (warm, olive-biased)
  static const ink900 = Color(0xFF2B2B25);
  static const ink800 = Color(0xFF3D3D34);
  static const ink700 = Color(0xFF56564C);
  static const ink600 = Color(0xFF6B6B60); // wordmark
  static const ink500 = Color(0xFF8C8C82);
  static const ink400 = Color(0xFFADAEA4);
  static const ink300 = Color(0xFFC9C9C0);
  static const ink200 = Color(0xFFE1E1D9); // border
  static const ink100 = Color(0xFFEEEEE8);
  static const ink50 = Color(0xFFF6F6F2);

  static const cream50 = Color(0xFFFAFAF7);
  static const cream100 = Color(0xFFF4F3EC);

  // Semantic
  static const success = petalMint;
  static const successBg = petalMint50;
  static const warning = Color(0xFFE5B428);
  static const warningBg = Color(0xFFFDF5DC);
  static const danger = Color(0xFFD44A3C);
  static const dangerBg = Color(0xFFFBEBE7);
  static const controlled = petalViolet;
  static const controlledBg = petalViolet50;

  static const surface = Color(0xFFFFFFFF);
  static const border = ink200;
  static const borderStrong = ink300;
  static const borderFocus = petalBlue;

  // Foreground roles
  static const fg1 = ink900;
  static const fg2 = ink700;
  static const fg3 = ink600;
  static const fg4 = ink400;
}

class BalsmRadius {
  BalsmRadius._();
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class BalsmShadow {
  BalsmShadow._();
  // 0.06 * 255 ≈ 15 (0x0F), 0.04 * 255 ≈ 10 (0x0A)
  static const xs = [
    BoxShadow(color: Color(0x0F2B2B25), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sm = [
    BoxShadow(color: Color(0x0F2B2B25), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A2B2B25), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x142B2B25), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A2B2B25), blurRadius: 6, offset: Offset(0, 2)),
  ];
  // Brand / accent glow
  static const brand = [
    BoxShadow(
      color: Color(0x381283FF),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

// Duration constants from CSS motion tokens
class BalsmDuration {
  BalsmDuration._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

// Curve equivalent of CSS ease-out cubic-bezier(0.16, 1, 0.3, 1)
const kBalsmEaseOut = Curves.easeOutExpo;
