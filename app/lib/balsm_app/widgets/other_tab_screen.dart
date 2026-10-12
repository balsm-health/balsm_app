import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'balsm_mark.dart';

/// Web only: shown in place of the app when another tab already owns the
/// on-device database (see `claimDatabaseTab`). Without it this tab would
/// render an empty app whose every read and write fails.
class OtherTabScreen extends StatelessWidget {
  const OtherTabScreen({super.key, required this.state});

  final PatientAppState state;

  @override
  Widget build(BuildContext context) {
    final strings = state.strings.web;
    final brand = FlavorConfig.currentOrNull?.brand ?? AppBrand.balsm;
    return Directionality(
      textDirection: state.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: AccentScope(
        accent: state.accent,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BalsmFlower(size: 52),
                    const SizedBox(height: 24),
                    Text(
                      strings.other_tab_t(brand.nameIn(state.lang.value)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: T.ink900),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.other_tab_b,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5, color: T.ink600),
                    ),
                    const SizedBox(height: 28),
                    PButton(strings.other_tab_retry, block: true, large: true, ar: state.rtl, onTap: reloadPage),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
