import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmAppBarVariant { withAvatar, titleOnly, withBackButton }

/// App bar (56pt) porting prototype `.appbar`.
/// Use inside a screen's Column header — not a PreferredSizeWidget.
class BalsmAppBar extends StatelessWidget {
  const BalsmAppBar({
    super.key,
    this.variant = BalsmAppBarVariant.titleOnly,
    this.title,
    this.leading,
    this.trailing,
    this.onBack,
  });

  const BalsmAppBar.withAvatar({
    super.key,
    required this.leading, // avatar widget
    this.title,
    this.trailing,
    this.onBack,
  }) : variant = BalsmAppBarVariant.withAvatar;

  const BalsmAppBar.withBack({
    super.key,
    this.title,
    this.trailing,
    required this.onBack,
  })  : variant = BalsmAppBarVariant.withBackButton,
        leading = null;

  final BalsmAppBarVariant variant;
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildLeading(context),
            const SizedBox(width: 12),
            Expanded(
              child: title != null
                  ? Text(
                      title!,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                        letterSpacing: -0.01 * 21,
                        color: BalsmColors.fg1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    switch (variant) {
      case BalsmAppBarVariant.withAvatar:
        return leading ?? const SizedBox(width: 44);
      case BalsmAppBarVariant.withBackButton:
        return _BackButton(onTap: onBack ?? () => Navigator.maybePop(context));
      case BalsmAppBarVariant.titleOnly:
        return const SizedBox.shrink();
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: BalsmColors.ink50,
          borderRadius: BorderRadius.circular(BalsmRadius.pill),
          border: Border.all(color: BalsmColors.border),
        ),
        child: Transform.scale(
          scaleX: isRtl ? -1 : 1,
          child: const Icon(Icons.arrow_back, size: 20, color: BalsmColors.fg2),
        ),
      ),
    );
  }
}
