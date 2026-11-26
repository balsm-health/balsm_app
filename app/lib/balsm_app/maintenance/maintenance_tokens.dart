import 'package:flutter/widgets.dart';

/// Maintenance amber (`maintenance.jsx` `MT`): the maintenance card and its details sheet.
class MaintenanceTokens {
  MaintenanceTokens._();

  /// Top of the maintenance page's wash.
  static const pageTop = Color(0xFFFDF8E8);

  /// Title ink on the maintenance card.
  static const ink = Color(0xFF6B4E00);

  /// Icons, eyebrow and the paused list's ink.
  static const ink2 = Color(0xFF8A6A10);

  /// Card and sheet wash, light end.
  static const bg = Color(0xFFFFF7DF);

  /// Card and sheet wash, deep end; the progress track.
  static const bg2 = Color(0xFFFDEFC4);

  /// Hairline around maintenance surfaces.
  static const line = Color(0xFFF1DFA6);

  /// The blinking dot, the badges and the progress fill.
  static const dot = Color(0xFFE5A800);

  /// Progress fill, light end (`#F2C84B`).
  static const dotLight = Color(0xFFF2C84B);

  /// `0 6px 18px rgba(138,106,16,0.12)` under the floating card.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x1F8A6A10), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// `0 6px 16px rgba(138,106,16,0.16)` under the sheet's icon tile.
  static const List<BoxShadow> tileShadow = [
    BoxShadow(color: Color(0x298A6A10), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
