import 'package:flutter/painting.dart';

/// The one Balsm colour palette: brand hues, neutrals, semantic roles, surfaces, text roles and the
/// translucent overlays. The patient app and every module read colour from here.
///
/// Never write a hex colour, a `Colors.*` value or a `Color(0x…)` outside this file: add a token here.
/// Alpha variants are named by what they are for (`scrim`, `shadow`) or, for plain white/cream, by their
/// opacity (`white70`, `creamVeil`), so they stay `const`.
class AppColors {
  AppColors._();

  // ── Brand hues ─────────────────────────────────────────────
  static const hueAqua = Color(0xFF02BBB5);
  static const hueEmerald = Color(0xFF01C4A2);
  static const hueBlue = Color(0xFF1283FF);
  static const hueMint = Color(0xFF55D77F);
  static const hueViolet = Color(0xFF724DD0);

  static const hueAqua600 = Color(0xFF029E99);
  static const hueEmerald600 = Color(0xFF019A7F);
  static const hueBlue600 = Color(0xFF0F6BCC);
  static const hueMint600 = Color(0xFF3FC366);
  static const hueViolet600 = Color(0xFF5C3AB0);

  static const hueAqua100 = Color(0xFFB8EDE8);
  static const hueBlue100 = Color(0xFFB8D4FF);

  static const hueAqua50 = Color(0xFFE2F8F6);
  static const hueEmerald50 = Color(0xFFE1F8F1);
  static const hueBlue50 = Color(0xFFE4F0FF);
  static const hueMint50 = Color(0xFFE8F9EE);
  static const hueViolet50 = Color(0xFFECE6FA);

  static const hueBlue25 = Color(0xFFEAF3FF);

  /// Member-tone "ink" (Mother & Child `MC_TONES.ink`): text and icon colour on a petal-50 wash, darker
  /// than the -600 step so it reads on the tint.
  static const hueAquaInk = Color(0xFF0B6B66);
  static const hueEmeraldInk = Color(0xFF0A6B58);
  static const hueBlueInk = Color(0xFF10508F);
  static const hueVioletInk = Color(0xFF4B2F95);
  static const hueMintInk = Color(0xFF1F6A36);

  /// Lighter hues for a dark surface.
  static const hueBlueOnDark = Color(0xFF5AA8FF);
  static const hueAquaOnDark = Color(0xFF3FD3CD);
  static const dangerOnDark = Color(0xFFE57A6E);

  // ── Neutrals (cool, navy-slate-biased, keyed to the #1F2D3D wordmark) ──
  static const ink900 = Color(0xFF14202B);
  static const ink800 = Color(0xFF1F2D3D); // = wordmark
  static const ink700 = Color(0xFF384756);
  static const ink600 = Color(0xFF526174); // = wordmark ".health" TLD
  static const ink500 = Color(0xFF78838F);

  // Was 0xFF9BA4AD, which measured 2.42:1 on cream — below the 4.5 WCAG asks for body text, and this ink
  // carries placeholders and disabled labels. 0xFF677281 clears it at 4.67:1 while staying the same cool grey.
  static const ink400 = Color(0xFF677281);
  static const ink300 = Color(0xFFC0C6CC);
  static const ink200 = Color(0xFFDBDFE3);
  static const ink100 = Color(0xFFEBEDF0);
  static const ink50 = Color(0xFFF5F6F8);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  /// Warm near-black: the "Sign in with Apple" button, dark theme surface and the developer console.
  static const nearBlack = Color(0xFF1A1A17);
  static const nearBlackSoft = Color(0xFF3C3C3A);

  static const cream50 = Color(0xFFFAFAF7);
  static const cream100 = Color(0xFFF4F3EC);
  static const cream200 = Color(0xFFEAE9DD);

  static const sun400 = Color(0xFFF5C842);
  static const sun500 = Color(0xFFE5B428);
  static const sun600 = Color(0xFFD9A020);

  /// Text on a [sun500]-ish fill (the lightest mood swatches).
  static const onSun = Color(0xFF3A2E05);
  static const onSunWash = Color(0x1F3A2E05); // onSun at 12%

  // ── Semantic ───────────────────────────────────────────────
  static const Color success = hueMint;
  static const Color successBackground = hueMint50;
  static const Color warning = sun500;
  static const warningBackground = Color(0xFFFDF5DC);

  // Was 0xFFD44A3C: 4.15:1 on cream and 4.34:1 under white text, both short of 4.5 at the sizes buttons
  // and error lines actually use. Darkened to clear both (5.80 and 6.06) without leaving the red it was.
  static const danger = Color(0xFFB4342A);
  static const dangerBackground = Color(0xFFFBEBE7);

  /// Outline of a danger-tinted panel on [dangerBackground] (25% of the red the app used before [danger] was darkened).
  static const dangerBorder = Color(0x40D44A3C);
  static const Color controlled = hueViolet;
  static const Color controlledBackground = hueViolet50;
  static const expiring = Color(0xFFD97A20);
  static const expiringBackground = Color(0xFFFBEEDC);
  static const Color neutralBackground = ink100;

  /// Text on a semantic background wash (pills, banners, status chips).
  static const Color onSuccessBackground = hueMintInk;
  static const onInfoBackground = Color(0xFF08407A);
  static const onWarningBackground = Color(0xFF7A5A0F);
  static const onDangerBackground = Color(0xFF7A2A20);
  static const onExpiringBackground = Color(0xFF7A4310);
  static const onControlledBackground = Color(0xFF3D2872);

  /// `.h2-vfoot`: ink for a reading above its range, and the pending/symptom amber.
  static const warningInk = Color(0xFF9A5A00);

  // ── Brand, surfaces, borders ───────────────────────────────
  static const Color wordmark = ink800; // بلسم · Balsm — navy slate
  static const Color wordmarkTld = ink600; // .health — same hue, lighter
  static const Color surface = white;
  static const Color surfaceMuted = ink50;
  static const Color border = ink200;
  static const Color borderStrong = ink300;
  static const Color borderFocus = hueBlue;

  /// `--v2-line`: the dashed rule above the week strip.
  static const hairline = Color(0x141F2D3D); // rgba(31,45,61,.08)

  /// `--v2-line-2`: card borders and the hairlines between vitals.
  static const hairlineSoft = Color(0x0D1F2D3D); // rgba(31,45,61,.05)

  // ── Text roles ─────────────────────────────────────────────
  static const Color textPrimary = ink900;
  static const Color textSecondary = ink700;
  static const Color textTertiary = ink600; // meta
  static const Color textHint = ink400; // placeholder / disabled

  // ── Overlays: scrims and shadows (ink900 unless noted) ─────
  /// Behind a modal sheet or dialog: `rgba(20,32,43,.38)`.
  static const scrim = Color(0x6114202B);

  /// Behind a blocking spinner or a photo caption: ink900 at 55%.
  static const scrimHeavy = Color(0x8C14202B);

  /// Bottom of a gradient that carries white text over a photo or camera: ink900 at 85%.
  static const scrimDeep = Color(0xD914202B);

  /// A badge or gradient laid over a photo (ink800 at 72%).
  static const overPhoto = Color(0xB81F2D3D);

  /// Shadow colour of a floating control, at 6%, 14% and 28% (ink900).
  static const shadowSoft = Color(0x0F14202B);
  static const shadow = Color(0x2414202B);
  static const shadowStrong = Color(0x4714202B);

  /// Map "you are here" halo and glow ([hueBlue] at 10% and 22%).
  static const hueBlueHalo = Color(0x1A1283FF);
  static const hueBlueGlow = Color(0x381283FF);

  // ── White at a given opacity (on dark fills, photos and the welcome watercolour) ──
  static const white12 = Color(0x1FFFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white38 = Color(0x61FFFFFF);
  static const white54 = Color(0x8AFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white85 = Color(0xD9FFFFFF);
  static const white94 = Color(0xF0FFFFFF);

  // ── Cream-50 at a given opacity (fades into the page background) ──
  static const creamClear = Color(0x00FAFAF7);
  static const creamMist = Color(0x14FAFAF7);
  static const creamVeil = Color(0x57FAFAF7);
  static const creamFrost = Color(0xF0FAFAF7);
}
