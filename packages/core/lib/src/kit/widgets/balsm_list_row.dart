import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

/// List row porting prototype `.list-row` (icon + grow text + chevron-right).
/// RTL flips chevron via Transform.scale(-1, 1).
class BalsmListRow extends StatelessWidget {
  const BalsmListRow({
    required this.label,
    super.key,
    this.leading,
    this.sublabel,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.showDivider = true,
  });

  final Widget? leading;
  final String label;
  final String? sublabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.ink50,
        splashColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  if (leading case final leading?) ...[
                    _IconContainer(child: leading),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: FontSizes.body,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (sublabel case final sublabel?) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel,
                            style: const TextStyle(
                              fontSize: FontSizes.bodySm,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing case final trailing?) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ] else if (showChevron)
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textHint,
                    ),
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
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.hueBlue50,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: IconTheme(
        data: const IconThemeData(
          size: 19,
          color: AppColors.hueBlue600,
        ),
        child: Center(child: child),
      ),
    );
  }
}
