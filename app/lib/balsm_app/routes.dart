/// Route, tab, and public-path identifiers for the app shell.
///
/// [PatientAppState.route] / [PatientAppState.tab] are stringly-typed (they
/// mirror the design prototype's router); every identifier lives here so a
/// typo is a compile error, not a silent fall-through to the default screen.
library;

/// Top-level shell routes ([PatientAppState.route]).
abstract final class AppRoutes {
  /// First-run walkthrough (before anything else, once per install).
  static const walkthrough = 'walkthrough';

  /// Signed-out landing: logo, sign-up / sign-in entries.
  static const welcome = 'welcome';

  /// Credentials step (email + password — historic name from the phone era).
  static const phone = 'phone';

  /// Six-digit verification step (registration).
  static const otp = 'otp';

  /// Legacy profile-setup step. Unreachable since registration ends at OTP
  /// (design 2026-09); kept while the screen exists for reference.
  static const profileSetup = 'profile';

  /// The signed-in tabbed shell.
  static const app = 'app';
}

/// Tabs and sub-screens inside the signed-in shell ([PatientAppState.tab]).
///
/// [id] is the legacy wire string — the design prototype's tab id, still what
/// the `ext.balsm.setTab` debug service extension and the docshots tool speak.
enum AppTab {
  home('home'),
  map('map'),
  meds('meds'),
  profile('profile'),

  // Sub-screens reached from Home/Profile — not in the tab bar, but they
  // route through the same switch.
  prescriptions('rx'),
  records('records'),
  trends('trends');

  const AppTab(this.id);
  final String id;

  /// Wire-string lookup; unknown ids land on [home] rather than throwing —
  /// the callers are debug tooling.
  static AppTab fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => AppTab.home);
}

/// Public web paths the shell serves without a session (profile QR resolve —
/// emergency-token spec v2.0).
abstract final class PublicQrPaths {
  /// Spec v2.0 type-free path: `/t/{jti}#k={key}`.
  static const token = 't';

  /// Serving alias for dev-era codes: `/emergency/{jti}#k={key}`.
  static const legacyEmergency = 'emergency';
}
