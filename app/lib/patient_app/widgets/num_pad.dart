import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../kit.dart';
import '../tokens.dart';

/// Tap keypad (.keypad) used by the vitals quick-log flows.
class NumPad extends StatelessWidget {
  const NumPad({super.key, required this.onKey, required this.onBack, this.decimal = false, this.onDot});
  final ValueChanged<String> onKey;
  final VoidCallback onBack;
  final bool decimal;
  final VoidCallback? onDot;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55,
      children: [
        for (var d = 1; d <= 9; d++) _Key(label: '$d', onTap: () => onKey('$d')),
        decimal
            ? _Key(label: '.', fn: true, onTap: onDot ?? () {})
            : const SizedBox.shrink(),
        _Key(label: '0', onTap: () => onKey('0')),
        _Key(icon: LucideIcons.delete, fn: true, onTap: onBack),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap, this.fn = false});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool fn;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fn ? T.ink50 : Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border),
          ),
          child: icon != null
              ? Icon(icon, size: 22, color: T.fg1)
              : Text(label!, style: Typo.num(size: FS.xl, weight: FontWeight.w600)),
        ),
      );
}
