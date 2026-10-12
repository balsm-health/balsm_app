import 'package:material_ui/material_ui.dart';
import '../_tokens.dart';

/// Welcome background porting prototype `.wbg` / `.wgrad`.
/// Full-bleed watercolor wash with a vertical fade to the cream surface.
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
        // `.wbg` — full-bleed cover, then `.wgrad` fades it to cream.
        // Image's own `opacity`, not an Opacity wrapper: wrapping a
        // full-bleed image forces a saveLayer offscreen composite every frame,
        // while this folds the alpha into the paint.
        Positioned.fill(
          child: Image.asset(
            'packages/core/assets/brand/balsm-background.png',
            fit: BoxFit.cover,
            // `.wbg { background-position: 78% top }` — 78% across maps to
            // x = 0.78*2-1, and `top` pins y to -1.
            alignment: const Alignment(0.56, -1),
            opacity: const AlwaysStoppedAnimation(0.9),
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        // Gradient fade to cream
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Retuned in app.css: the wash goes opaque higher up the
                // screen so the copy sits on solid cream, and lands fully by
                // 88% rather than 100%.
                stops: [0.0, 0.30, 0.62, 0.88],
                colors: [
                  Color(0x14FAFAF7), // cream-50 at 8%
                  Color(0x57FAFAF7), // cream-50 at 34%
                  Color(0xF0FAFAF7), // cream-50 at 94%
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
