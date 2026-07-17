import 'package:flutter/widgets.dart';
import 'data.dart';
import 'prefs.dart';
import 'strings.dart';
import 'tokens.dart';

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
  String t(String key) => tr(key, lang);

  Country get country => kCountries.firstWhere((c) => c.code == countryCode, orElse: () => kCountries.first);

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
