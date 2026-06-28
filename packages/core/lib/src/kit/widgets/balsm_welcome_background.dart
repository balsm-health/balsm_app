import 'package:flutter/material.dart';
import '../_tokens.dart';

/// Welcome background porting prototype `.wbg` / `.wgrad`.
/// Watercolor petal pattern at top-right with gradient fade to cream surface.
/// Asset: `packages/core/assets/brand/balsm-background.png`
class BalsmWelcomeBackground extends StatelessWidget {
  const BalsmWelcomeBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cream surface
        Container(color: BalsmColors.cream50),
        // Watercolor petal at top-right
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Opacity(
            opacity: 0.9,
            child: Image.asset(
              'packages/core/assets/brand/balsm-background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Gradient fade to cream
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 0.78, 1.0],
                colors: [
                  Color(0x1AFAFAF7), // cream-50 at 10%
                  Color(0x66FAFAF7), // cream-50 at 40%
                  Color(0xF5FAFAF7), // cream-50 at 96%
                  BalsmColors.cream50,
                ],
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
