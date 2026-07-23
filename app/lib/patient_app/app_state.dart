import 'package:core/core.dart'
    show CountryCode, LanguageCode, TranslationCatalog;
import 'package:flutter/widgets.dart';
import 'prefs.dart';
import 'strings.dart';
import 'tokens.dart';

/// Shared-kernel reference translations (localized country/language names) —
/// resolved via the `CountryCodeL10n`/`LanguageCodeL10n` extensions.
const kCatalog = TranslationCatalog();

/// Balsm's home market — drives the "home country" badge and the default
/// dial-code country.
const kHomeCountry = CountryCode.egypt;

/// Global app context — mirrors the React `AppCtx`. Holds language, accent,
/// current tab/route, country, and the active backup target. The signed-in
/// user's identity/PHI is NOT held here — screens read it from real providers
/// (`accountSummaryProvider`, `profileDaoProvider`).
class PatientAppState extends ChangeNotifier {
  String lang = 'en';
  Accent accent = Accent.blue;

  /// Auth route: welcome | phone | otp | profile | app
  String route = 'welcome';

  /// Active tab/sub-screen: home | map | meds | profile | trends | records | appts
  String tab = 'home';

  String authMethod = 'phone'; // phone | email
  String authEmail = '';

  /// 'signup' (Get started / social) | 'signin' (Sign in link). Decides whether
  /// the email+password form registers (OTP → setPassword) or signs in.
  String authIntent = 'signin';

  /// Transient — password captured on the password sign-up screen, applied via
  /// setPassword once OTP verify establishes the session. In-memory only (never
  /// persisted); cleared after use.
  String? authPassword;

  String countryCode = 'EG';

  /// Active backup target: local | icloud | gdrive (single active cloud).
  String storageProvider = 'local';

  PatientAppPrefs? _prefs;

  /// Loads the persisted session + preferences from the app-shell preference
  /// group. Returns a ready state whose `route` is `app` when a session was
  /// saved, else `welcome`.
  static Future<PatientAppState> load(PatientAppPrefs prefs) async {
    final s = PatientAppState();
    s._prefs = prefs;
    try {
      s.lang = await prefs.lang();
      s.accent = _accentFromKey(await prefs.accent());
      s.countryCode = await prefs.country();
      s.storageProvider = await prefs.storage();
      s.route = await prefs.signedIn() ? 'app' : 'welcome';
    } catch (_) {
      s.route = 'welcome';
    }
    return s;
  }

  static Accent _accentFromKey(String? k) => switch (k) {
        'aqua' => Accent.aqua,
        'emerald' => Accent.emerald,
        'violet' => Accent.violet,
        'mint' => Accent.mint,
        _ => Accent.blue,
      };
  String get _accentKey => switch (accent) {
        Accent.aqua => 'aqua',
        Accent.emerald => 'emerald',
        Accent.violet => 'violet',
        Accent.mint => 'mint',
        _ => 'blue',
      };

  /// Fire-and-forget persistence (matches the previous SharedPreferences
  /// behavior — setters are not awaited on the UI path).
  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setSignedIn(route == 'app');
    p.setLang(lang);
    p.setAccent(_accentKey);
    p.setCountry(countryCode);
    p.setStorage(storageProvider);
  }

  bool get rtl => lang == 'ar';
  TextDirection get dir => rtl ? TextDirection.rtl : TextDirection.ltr;

  /// Stringly-typed lookup — keep only for keys computed at runtime
  /// (e.g. `t(rows[i].key)`). For static keys prefer [strings].
  String t(String key) => tr(key, lang);

  /// Locale-aware, compile-time-checked message bundle:
  /// `s.strings.med_snooze15` fails to compile on a typo, whereas
  /// `s.t('med_snooze15')` silently returns the key at runtime.
  Strings get strings => stringsFor(lang);

  CountryCode get country => CountryCode(countryCode);

  bool get isHomeCountry => country == kHomeCountry;

  /// The active UI language as a core value object.
  LanguageCode get language => LanguageCode(lang);

  void setLang(String l) {
    lang = l;
    _save();
    notifyListeners();
  }

  void setAccent(Accent a) {
    accent = a;
    _save();
    notifyListeners();
  }

  /// Records the verified sign-up contact (method + email) so the OTP step can
  /// display it and call the real verify use-case with the right address.
  void setAuthContact({required String method, required String email}) {
    authMethod = method;
    authEmail = email;
    notifyListeners();
  }

  /// Set the auth intent (called from the welcome screen before go('phone')).
  void setAuthIntent(String intent) {
    authIntent = intent;
    notifyListeners();
  }

  /// Stash/clear the transient sign-up password (not UI-bound, no notify).
  void setAuthPassword(String? pw) => authPassword = pw;

  void go(String r) {
    if (r == 'app') tab = 'home';
    route = r;
    _save(); // persist signed-in / signed-out
    notifyListeners();
  }

  void setTab(String tb) {
    tab = tb;
    notifyListeners();
  }

  void switchCloudProvider(String to) {
    storageProvider = to;
    _save();
    notifyListeners();
  }

  void setCountry(String code) {
    countryCode = code;
    _save();
    notifyListeners();
  }
}

/// Derives up-to-two-letter avatar initials from a display name. Returns an
/// empty string when the name is blank (loading / signed out) so the avatar
/// renders neutrally rather than showing fabricated initials.
String accountInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// InheritedNotifier exposing [PatientAppState] to the widget tree.
class AppScope extends InheritedNotifier<PatientAppState> {
  const AppScope({super.key, required PatientAppState state, required super.child}) : super(notifier: state);

  static PatientAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
