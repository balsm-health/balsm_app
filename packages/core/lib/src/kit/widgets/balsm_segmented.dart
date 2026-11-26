import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

/// Segmented control porting prototype `.segmented`.
/// Generic over T option type.
/// Active slot: white bg + shadow-xs; inactive: transparent.
class BalsmSegmented<T> extends StatelessWidget {
  const BalsmSegmented({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isActive,
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.easeOut,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.segment),
                    boxShadow: isActive ? AppShadows.xs : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labelOf(opt),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: FontSizes.bodySm,
                      color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
