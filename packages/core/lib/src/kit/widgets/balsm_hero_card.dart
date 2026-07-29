import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmHeroCardVariant { prompt, done }

/// Hero card porting prototype `.hero-card`.
/// `prompt` variant: accent gradient bg + CTA button.
/// `done` variant: white bg + checkmark + chevron.
class BalsmHeroCard extends StatelessWidget {
  const BalsmHeroCard.prompt({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.ctaLabel,
    required this.onCta,
    this.clockMeta,
  }) : variant = BalsmHeroCardVariant.prompt;

  const BalsmHeroCard.done({
    super.key,
    required this.eyebrow,
    required this.title,
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
        color: isDone ? BalsmColors.surface : null,
        gradient: isDone
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BalsmColors.petalBlue, Color(0xFF0F6BCC)],
              ),
        borderRadius: BorderRadius.circular(BalsmRadius.xl),
        border: isDone ? Border.all(color: BalsmColors.border) : null,
        boxShadow: isDone ? BalsmShadow.sm : BalsmShadow.brand,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BalsmRadius.xl),
        child: Stack(
          children: [
            if (!isDone)
              Positioned(
                right: isRtl ? null : -28,
                left: isRtl ? -28 : null,
                top: -28,
                child: Opacity(
                  opacity: 0.16,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Colors.white, Colors.transparent],
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDone ? BalsmColors.appAccent : Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -0.01 * 26,
                      height: 1.18,
                      color: isDone ? BalsmColors.fg1 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isDone && ctaLabel != null) _CtaButton(label: ctaLabel!, onTap: onCta),
                  if (isDone)
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18, color: BalsmColors.appAccent),
                        const SizedBox(width: 6),
                        Text(
                          ctaLabel ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: BalsmColors.fg3,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18, color: BalsmColors.fg4),
                      ],
                    ),
                  if (clockMeta != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      clockMeta!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone ? BalsmColors.fg3 : Colors.white.withOpacity(0.7),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(BalsmRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: BalsmColors.appAccent600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18, color: BalsmColors.appAccent600),
          ],
        ),
      ),
    );
  }
}
