import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

enum BalsmMedTone { info, controlled, success }

/// Med row porting prototype `.med-row` (icon + name + dose + status/action).
/// Tone: `info` (hue-blue), `controlled` (hue-violet), `success` (mint).
class BalsmMedRow extends StatelessWidget {
  const BalsmMedRow({
    required this.name,
    required this.dose,
    required this.tone,
    super.key,
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
                      borderRadius: BorderRadius.circular(AppRadii.md),
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
                            fontSize: FontSizes.body,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dose,
                          style: const TextStyle(
                            fontSize: FontSizes.bodySm,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing case final trailing?) ...[
                    const SizedBox(width: 12),
                    trailing,
                  ],
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.ink100,
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
        return (AppColors.hueBlue50, AppColors.hueBlue);
      case BalsmMedTone.controlled:
        return (AppColors.controlledBackground, AppColors.controlled);
      case BalsmMedTone.success:
        return (AppColors.successBackground, AppColors.success);
    }
  }
}
