import 'package:flutter/widgets.dart';

/// Design tokens ported from `colors_and_type.css` + `app.css` of the
/// claude.ai/design "Patient App" prototype. Colors are the locked Balsm
/// brand palette (identical to packages/core `_tokens.dart`).
class T {
  T._();

  // ── Brand petals (5-color flower mark) ─────────────────────
  static const petalAqua = Color(0xFF02BBB5);
  static const petalEmerald = Color(0xFF01C4A2);
  static const petalBlue = Color(0xFF1283FF);
  static const petalMint = Color(0xFF55D77F);
  static const petalViolet = Color(0xFF724DD0);

  static const petalAqua600 = Color(0xFF029E99);
  static const petalEmerald600 = Color(0xFF019A7F);
  static const petalBlue600 = Color(0xFF0F6BCC);
  static const petalMint600 = Color(0xFF3FC366);
  static const petalViolet600 = Color(0xFF5C3AB0);

  static const petalAqua50 = Color(0xFFE2F8F6);
  static const petalEmerald50 = Color(0xFFE1F8F1);
  static const petalBlue50 = Color(0xFFE4F0FF);
  static const petalMint50 = Color(0xFFE8F9EE);
  static const petalViolet50 = Color(0xFFECE6FA);

  // ── Warm olive-gray neutrals ───────────────────────────────
  static const ink900 = Color(0xFF2B2B25);
  static const ink800 = Color(0xFF3D3D34);
  static const ink700 = Color(0xFF56564C);
  static const ink600 = Color(0xFF6B6B60); // wordmark
  static const ink500 = Color(0xFF8C8C82);
  static const ink400 = Color(0xFFADAEA4);
  static const ink300 = Color(0xFFC9C9C0);
  static const ink200 = Color(0xFFE1E1D9);
  static const ink100 = Color(0xFFEEEEE8);
  static const ink50 = Color(0xFFF6F6F2);
  static const white = Color(0xFFFFFFFF);

  static const cream50 = Color(0xFFFAFAF7);
  static const cream100 = Color(0xFFF4F3EC);
  static const cream200 = Color(0xFFEAE9DD);

  static const sun400 = Color(0xFFF5C842);
  static const sun500 = Color(0xFFE5B428);
  static const sun600 = Color(0xFFD9A020);

  // ── Semantic ───────────────────────────────────────────────
  static const success = petalMint;
  static const successBg = petalMint50;
  static const warning = Color(0xFFE5B428);
  static const warningBg = Color(0xFFFDF5DC);
  static const danger = Color(0xFFD44A3C);
  static const dangerBg = Color(0xFFFBEBE7);
  static const controlled = petalViolet;
  static const controlledBg = petalViolet50;

  // ── Surfaces / foreground roles ────────────────────────────
  static const surface = white;
  static const border = ink200;
  static const borderStrong = ink300;

  static const fg1 = ink900; // primary text
  static const fg2 = ink700; // secondary
  static const fg3 = ink600; // tertiary / meta
  static const fg4 = ink400; // placeholder / disabled

  // ── Radii ──────────────────────────────────────────────────
  static const rXs = 4.0;
  static const rSm = 6.0;
  static const rMd = 10.0;
  static const rLg = 14.0;
  static const rXl = 20.0;
  static const r2xl = 28.0;
  static const rPill = 999.0;

  // ── Shadows (warm, soft) ───────────────────────────────────
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0F2B2B25), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F2B2B25), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A2B2B25), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x142B2B25), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A2B2B25), blurRadius: 6, offset: Offset(0, 2)),
  ];

  // App accent shadow (blue) — `--app-accent-shadow`
  static const List<BoxShadow> accentShadow = [
    BoxShadow(color: Color(0x421283FF), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

/// The accent petal that tints CTAs, rings, active states. Default = blue.
class Accent {
  const Accent(this.main, this.d, this.bg, this.shadow);
  final Color main;
  final Color d; // darker (pressed)
  final Color bg; // wash
  final Color shadow;

  static const blue = Accent(T.petalBlue, T.petalBlue600, T.petalBlue50, Color(0x421283FF));
  static const aqua = Accent(T.petalAqua, T.petalAqua600, T.petalAqua50, Color(0x4202BBB5));
  static const emerald = Accent(T.petalEmerald, T.petalEmerald600, T.petalEmerald50, Color(0x4201C4A2));
  static const violet = Accent(T.petalViolet, T.petalViolet600, T.petalViolet50, Color(0x42724DD0));
  static const mint = Accent(T.petalMint600, Color(0xFF2FA552), T.petalMint50, Color(0x4D55D77F));

  List<BoxShadow> get boxShadow =>
      [BoxShadow(color: shadow, blurRadius: 22, offset: const Offset(0, 8))];
}
