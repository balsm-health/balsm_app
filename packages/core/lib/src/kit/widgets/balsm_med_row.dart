import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmMedTone { info, controlled, success }

/// Med row porting prototype `.med-row` (icon + name + dose + status/action).
/// Tone: `info` (petal-blue), `controlled` (petal-violet), `success` (mint).
class BalsmMedRow extends StatelessWidget {
  const BalsmMedRow({
    super.key,
    required this.name,
    required this.dose,
    required this.tone,
    this.icon = Icons.medication_rounded,
    this.trailing,
    this.showDivider = true,
    this.onTap,
  });

  final String name;
  final String dose;
  final BalsmMedTone tone;
  final IconData icon;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _toneColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(BalsmRadius.md),
                    ),
                    child: Icon(icon, size: 21, color: fg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: BalsmColors.fg1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dose,
                          style: const TextStyle(
                            fontSize: 13,
                            color: BalsmColors.fg3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                thickness: 1,
                color: BalsmColors.ink100,
                indent: 18,
                endIndent: 18,
              ),
          ],
        ),
      ),
    );
  }

  (Color, Color) get _toneColors {
    switch (tone) {
      case BalsmMedTone.info:
        return (BalsmColors.petalBlue50, BalsmColors.petalBlue);
      case BalsmMedTone.controlled:
        return (BalsmColors.controlledBg, BalsmColors.controlled);
      case BalsmMedTone.success:
        return (BalsmColors.successBg, BalsmColors.success);
    }
  }
}
