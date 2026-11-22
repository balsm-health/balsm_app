import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../flags.dart';
import '../tokens.dart';

/// A corner ribbon over the whole app saying this release is a beta.
///
/// Painted on top of [child] and never takes a touch, so nothing under it
/// stops working. It sits in the top trailing corner — right in English, left
/// in Arabic — clear of the back button.
///
/// Shown while [AppFlags.betaBanner] is on, which is its default.
class BetaBanner extends StatelessWidget {
  const BetaBanner({required this.state, required this.child, super.key});

  final PatientAppState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!state.flags.isOn(AppFlags.betaBanner)) return child;
    return Banner(
      message: state.strings.common.beta_banner,
      location: BannerLocation.topEnd,
      // Amber, not the accent: it reads as "beta" at a glance and stays the
      // same whichever accent the patient picked.
      color: AppColors.warning,
      textDirection: state.dir,
      layoutDirection: state.dir,
      // The ribbon is 80pt long and 12pt deep; both labels fit at this size.
      textStyle: TextStyle(
        color: AppColors.ink900,
        fontSize: FontSizes.micro,
        fontWeight: FontWeight.w800,
        height: 1,
        // Arabic letters join, so spacing them apart breaks the word.
        letterSpacing: state.rtl ? 0 : 0.6,
      ),
      child: child,
    );
  }
}
