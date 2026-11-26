/// The patient app's view of the design tokens. Every token type has one home, in core
/// (`packages/core/lib/src/kit/tokens.dart`), so the app and the modules share them; this file only
/// re-exports them so app code can keep importing `tokens.dart`.
library;

export 'package:core/core.dart'
    show
        Accent,
        AppColors,
        AppRadii,
        AppShadows,
        BalsmDensity,
        BalsmWindow,
        BalsmWindowClass,
        ColorContrast,
        FontSizes,
        Motion,
        Typo;
