import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

/// 3-dot step indicator from prototype `AuthHeader`.
/// Current dot stretches to 22pt pill, others are 7pt circles.
class BalsmStepDots extends StatelessWidget {
  const BalsmStepDots({
    super.key,
    required this.totalSteps,
    required this.currentStep, // 1-based, super.key,, super.key,, super.key,, super.key,, super.key,, super.key,
  });

  final int totalSteps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final isCurrent = i == currentStep - 1;
        final isPast = i < currentStep - 1;
        final isActive = isCurrent || isPast;

        return AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isCurrent ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? AppColors.hueBlue : AppColors.ink200,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        );
      }),
    );
  }
}
