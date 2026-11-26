import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

enum BalsmCardVariant { standard, accent, danger, cream }

/// Card porting prototype `.card` (white, border, radius-lg, shadow-sm).
/// Variants: standard (white), accent (blue-50 gradient), danger (danger-bg), cream (cream-100).
class BalsmCard extends StatelessWidget {
  const BalsmCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.variant = BalsmCardVariant.standard,
  });

  const BalsmCard.accent({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.accent;

  const BalsmCard.danger({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.danger;

  const BalsmCard.cream({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.cream;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BalsmCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        gradient: _gradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  Color? get _bgColor {
    switch (variant) {
      case BalsmCardVariant.standard:
        return AppColors.surface;
      case BalsmCardVariant.danger:
        return AppColors.dangerBackground;
      case BalsmCardVariant.cream:
        return AppColors.cream100;
      case BalsmCardVariant.accent:
        return null; // uses gradient
    }
  }

  Gradient? get _gradient {
    if (variant == BalsmCardVariant.accent) {
      return const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [AppColors.hueBlue50, AppColors.hueBlue25],
      );
    }
    return null;
  }
}
