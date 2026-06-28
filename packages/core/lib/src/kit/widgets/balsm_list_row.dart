import 'package:flutter/material.dart';
import '../_tokens.dart';

/// List row porting prototype `.list-row` (icon + grow text + chevron-right).
/// RTL flips chevron via Transform.scale(-1, 1).
class BalsmListRow extends StatelessWidget {
  const BalsmListRow({
    super.key,
    this.leading,
    required this.label,
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
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: BalsmColors.ink50,
        splashColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  if (leading != null) ...[
                    _IconContainer(child: leading!),
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
                            fontSize: 16,
                            color: BalsmColors.fg1,
                          ),
                        ),
                        if (sublabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: BalsmColors.fg3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (showChevron)
                    Transform.scale(
                      scaleX: isRtl ? -1 : 1,
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: BalsmColors.fg4,
                      ),
                    ),
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
        color: BalsmColors.appAccent50,
        borderRadius: BorderRadius.circular(BalsmRadius.sm),
      ),
      child: IconTheme(
        data: const IconThemeData(
          size: 19,
          color: BalsmColors.appAccent600,
        ),
        child: Center(child: child),
      ),
    );
  }
}
