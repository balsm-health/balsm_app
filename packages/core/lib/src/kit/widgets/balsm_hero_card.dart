import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

enum BalsmHeroCardVariant { prompt, done }

/// Hero card porting prototype `.hero-card`.
/// `prompt` variant: accent gradient bg + CTA button.
/// `done` variant: white bg + checkmark + chevron.
class BalsmHeroCard extends StatelessWidget {
  const BalsmHeroCard.prompt({
    required this.eyebrow,
    required this.title,
    required this.ctaLabel,
    required this.onCta,
    super.key,
    this.clockMeta,
  }) : variant = BalsmHeroCardVariant.prompt;

  const BalsmHeroCard.done({
    required this.eyebrow,
    required this.title,
    super.key,
    this.ctaLabel,
    this.onCta,
    this.clockMeta,
  }) : variant = BalsmHeroCardVariant.done;

  final BalsmHeroCardVariant variant;
  final String eyebrow;
  final String title;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? clockMeta;

  @override
  Widget build(BuildContext context) {
    final isDone = variant == BalsmHeroCardVariant.done;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDone ? AppColors.surface : null,
        gradient: isDone
            ? null
            : const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [AppColors.hueBlue, AppColors.hueBlue600],
              ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: isDone ? Border.all(color: AppColors.border) : null,
        boxShadow: isDone ? AppShadows.sm : AppShadows.brand,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Stack(
          children: [
            if (!isDone)
              PositionedDirectional(
                end: isRtl ? null : -28,
                start: isRtl ? -28 : null,
                top: -28,
                child: Opacity(
                  opacity: 0.16,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [AppColors.white, Colors.transparent],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      fontSize: FontSizes.bodySm,
                      fontWeight: FontWeight.w600,
                      color: isDone ? AppColors.hueBlue : AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: FontSizes.title,
                      letterSpacing: -0.01 * 26,
                      height: 1.18,
                      color: isDone ? AppColors.textPrimary : AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isDone && ctaLabel != null) _CtaButton(label: ctaLabel!, onTap: onCta),
                  if (isDone)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.hueBlue),
                        const SizedBox(width: 6),
                        Text(
                          ctaLabel ?? '',
                          style: const TextStyle(
                            fontSize: FontSizes.description,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                      ],
                    ),
                  if (clockMeta case final clockMeta?) ...[
                    const SizedBox(height: 10),
                    Text(
                      clockMeta,
                      style: TextStyle(
                        fontSize: FontSizes.meta,
                        color: isDone ? AppColors.textTertiary : AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: FontSizes.body,
                color: AppColors.hueBlue600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.hueBlue600),
          ],
        ),
      ),
    );
  }
}
