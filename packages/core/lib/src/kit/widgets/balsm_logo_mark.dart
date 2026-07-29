import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../_tokens.dart';

enum BalsmLogoMarkVariant { small, medium, large, spinner }

/// 5-petal flower logo from brand/logo-vertical.svg via flutter_svg.
/// spinner variant: animated 4s linear rotate (loading per design.md §6).
class BalsmLogoMark extends StatefulWidget {
  const BalsmLogoMark({
    super.key,
    this.variant = BalsmLogoMarkVariant.medium,
  });

  const BalsmLogoMark.small({super.key}) : variant = BalsmLogoMarkVariant.small;
  const BalsmLogoMark.medium({super.key}) : variant = BalsmLogoMarkVariant.medium;
  const BalsmLogoMark.large({super.key}) : variant = BalsmLogoMarkVariant.large;
  const BalsmLogoMark.spinner({super.key}) : variant = BalsmLogoMarkVariant.spinner;

  final BalsmLogoMarkVariant variant;

  @override
  State<BalsmLogoMark> createState() => _BalsmLogoMarkState();
}

class _BalsmLogoMarkState extends State<BalsmLogoMark> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.variant == BalsmLogoMarkVariant.spinner) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _size {
    switch (widget.variant) {
      case BalsmLogoMarkVariant.small:
        return 24;
      case BalsmLogoMarkVariant.medium:
        return 56;
      case BalsmLogoMarkVariant.large:
        return 96;
      case BalsmLogoMarkVariant.spinner:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      'packages/core/assets/brand/logo-vertical.svg',
      width: _size,
      height: _size,
      placeholderBuilder: (_) => SizedBox(
        width: _size,
        height: _size,
        child: const Center(
          child: CircularProgressIndicator(
            color: BalsmColors.appAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );

    if (widget.variant != BalsmLogoMarkVariant.spinner) return logo;

    return RotationTransition(
      turns: _ctrl,
      child: logo,
    );
  }
}
