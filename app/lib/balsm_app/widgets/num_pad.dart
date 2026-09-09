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
    // `.numpad { direction: ltr }` — 1-2-3 never mirrors, even in Arabic.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // See home_screen's metric grid: a nested BoxScrollView with a null
        // `padding` inherits MediaQuery's vertical padding (the notch/home
        // indicator insets), which would push the keypad off-centre.
        padding: EdgeInsets.zero,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // `.numpad-key { height: 52px }` — the key height is fixed, so derive
        // the ratio from the measured column width instead of guessing one.
        childAspectRatio: _keyRatio(context),
        children: [
          for (var d = 1; d <= 9; d++) _Key(label: '$d', onTap: () => onKey('$d')),
          decimal ? _Key(label: '.', onTap: onDot ?? () {}) : const SizedBox.shrink(),
          _Key(label: '0', onTap: () => onKey('0')),
          _Key(icon: LucideIcons.delete, del: true, onTap: onBack),
        ],
      ),
    );
  }

  /// Column width → aspect ratio that lands each key on the design's fixed
  /// 52pt height, whatever the available width.
  static double _keyRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // 3 columns, 8pt gutters, inside the flow's 24pt side padding.
    final key = ((width - 48 - 16) / 3).clamp(48.0, 120.0);
    return key / 52.0;
  }
}

/// `.numpad-key` — borderless `ink50` tile that darkens to `ink100` and
/// scales to 0.97 while held, over `--dur-fast` ease-out. Honors reduced motion.
class _Key extends StatefulWidget {
  const _Key({this.label, this.icon, required this.onTap, this.del = false});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  /// `.numpad-key.is-del` — the delete key sits back at `fg3`.
  final bool del;
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
            color: _down ? T.ink100 : T.ink50,
            borderRadius: BorderRadius.circular(T.rMd),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, size: 22, color: widget.del ? T.fg3 : T.fg1)
              : Text(widget.label!,
                  style: Typo.num(size: 22, weight: FontWeight.w500, color: widget.del ? T.fg3 : T.fg1)),
        ),
      ),
    );
  }
}
