import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';

/// The English / Arabic switch (auth.jsx WelcomeScreen): a light pill that
/// reads as the language it switches to, in that language's own face, so each
/// reads right to its own speakers. The welcome and onboarding screens both use
/// it, so they stay the same.
class LanguagePill extends StatelessWidget {
  const LanguagePill({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final toEn = s.lang == LanguageCode.ar;
    return Semantics(
      button: true,
      label: toEn ? s.strings.onboarding.lang_to_en : s.strings.onboarding.lang_to_ar,
      excludeSemantics: true,
      child: MinTapTarget(
        child: Pressable(
          onTap: () => s.setLang(toEn ? LanguageCode.en : LanguageCode.ar),
          child: Container(
            height: 40,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white85,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.ink200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.languages, size: 17, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Text(
                  toEn ? LanguageCode.en.nativeName : LanguageCode.ar.nativeName,
                  style: Typo.bodySm(ar: !toEn).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
