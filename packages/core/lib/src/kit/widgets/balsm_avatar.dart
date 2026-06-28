import 'package:flutter/material.dart';
import '../_tokens.dart';

/// Avatar circle with patient initials porting prototype `.avatar`.
/// Background = passed color; text = white.
/// Per P001 directive: no photo avatars, initials of first + last name.
class BalsmAvatar extends StatelessWidget {
  const BalsmAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.backgroundColor = BalsmColors.petalAqua,
  });

  final String initials;
  final double size;
  final Color backgroundColor;

  /// Derive initials from "First Last" name.
  static String initialsFrom(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
