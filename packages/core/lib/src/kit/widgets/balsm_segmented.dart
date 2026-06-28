import 'package:flutter/material.dart';
import '../_tokens.dart';

/// Segmented control porting prototype `.segmented`.
/// Generic over T option type.
/// Active slot: white bg + shadow-xs; inactive: transparent.
class BalsmSegmented<T> extends StatelessWidget {
  const BalsmSegmented({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
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
        color: BalsmColors.ink50,
        borderRadius: BorderRadius.circular(BalsmRadius.md),
        border: Border.all(color: BalsmColors.border),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: BalsmDuration.base,
                curve: kBalsmEaseOut,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isActive ? BalsmShadow.xs : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labelOf(opt),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isActive ? BalsmColors.fg1 : BalsmColors.fg3,
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
