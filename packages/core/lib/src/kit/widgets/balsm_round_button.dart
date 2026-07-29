import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmRoundButtonVariant { default_, ghost }

/// 44pt circular icon button porting prototype `.round-btn`.
/// Press animates scale → 0.97; ghost variant: transparent bg + no border.
class BalsmRoundButton extends StatefulWidget {
  const BalsmRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.variant = BalsmRoundButtonVariant.default_,
    this.size = 44,
    this.semanticLabel,
  });

  const BalsmRoundButton.ghost({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.semanticLabel,
  }) : variant = BalsmRoundButtonVariant.ghost;

  final Widget icon;
  final VoidCallback onTap;
  final BalsmRoundButtonVariant variant;
  final double size;
  final String? semanticLabel;

  @override
  State<BalsmRoundButton> createState() => _BalsmRoundButtonState();
}

class _BalsmRoundButtonState extends State<BalsmRoundButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: BalsmDuration.fast,
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: kBalsmEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(_) {
    setState(() => _pressed = true);
    _ctrl.forward();
  }

  void _onUp(_) {
    setState(() => _pressed = false);
    _ctrl.reverse();
    widget.onTap();
  }

  void _onCancel() {
    setState(() => _pressed = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.variant == BalsmRoundButtonVariant.ghost;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTapDown: _onDown,
          onTapUp: _onUp,
          onTapCancel: _onCancel,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: isGhost ? Colors.transparent : (_pressed ? BalsmColors.ink100 : BalsmColors.ink50),
              borderRadius: BorderRadius.circular(BalsmRadius.pill),
              border: isGhost ? null : Border.all(color: BalsmColors.border),
            ),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
