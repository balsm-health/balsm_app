import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

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
    required this.leading, // avatar widget, super.key,, super.key,, super.key,, super.key,, super.key,, super.key,
    this.title,
    this.trailing,
    this.onBack,
  }) : variant = BalsmAppBarVariant.withAvatar;

  const BalsmAppBar.withBack({
    required this.onBack,
    super.key,
    this.title,
    this.trailing,
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
              child: switch (title) {
                final title? => Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: FontSizes.heading,
                      letterSpacing: -0.01 * 21,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                _ => const SizedBox.shrink()
              },
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 8),
              trailing,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}
