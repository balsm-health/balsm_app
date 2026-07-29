import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../kit.dart';
import '../tokens.dart';

/// Tap keypad (.keypad) used by the vitals quick-log flows.
class NumPad extends StatelessWidget {
  const NumPad({super.key, required this.onKey, required this.onBack, this.decimal = false, this.onDot, this.pressBg});
  final ValueChanged<String> onKey;
  final VoidCallback onBack;
  final bool decimal;
  final VoidCallback? onDot;

  /// Accent wash flashed on press (`:active { background: app-accent-50 }`).
  final Color? pressBg;

  @override
  Widget build(BuildContext context) {
    final press = pressBg ?? T.petalBlue50;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (var d = 1; d <= 9; d++) _Key(label: '$d', onTap: () => onKey('$d'), pressBg: press),
        decimal ? _Key(label: '.', fn: true, onTap: onDot ?? () {}, pressBg: press) : const SizedBox.shrink(),
        _Key(label: '0', onTap: () => onKey('0'), pressBg: press),
        _Key(icon: LucideIcons.delete, fn: true, onTap: onBack, pressBg: press),
      ],
    );
  }
}

/// `.keypad button` — flashes accent wash + scales to 0.97 while held,
/// over `--dur-fast` ease-out. Honors reduced motion.
class _Key extends StatefulWidget {
  const _Key({this.label, this.icon, required this.onTap, this.fn = false, required this.pressBg});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool fn;
  final Color pressBg;
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pressed = _down && !reduce;
    final rest = widget.fn ? T.ink50 : Colors.white;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1.0,
        duration: Motion.fast,
        curve: Motion.easeOut,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? widget.pressBg : rest,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: 22, color: T.fg1)
              : Text(widget.label!, style: Typo.num(size: FS.xl, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
