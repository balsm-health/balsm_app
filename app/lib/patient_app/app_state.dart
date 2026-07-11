import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'strings.dart';
import 'tokens.dart';

/// Global app context — mirrors the React `AppCtx`. Holds language, accent,
/// current tab/route, active family account, country, and today's check-in.
class PatientAppState extends ChangeNotifier {
  String lang = 'en';
  Accent accent = Accent.blue;

  /// Auth route: welcome | phone | otp | profile | app
  String route = 'welcome';

  /// Active tab/sub-screen: home | map | meds | profile | trends | records | appts
  String tab = 'home';

  String authMethod = 'phone'; // phone | email
  String authEmail = '';

  String activeAccountId = 'layla';
  String countryCode = 'EG';

  /// Active backup target: local | icloud | gdrive (single active cloud).
  String storageProvider = 'local';

  /// Today's completed check-in (null until the report flow finishes).
  CheckinResult? today;

  SharedPreferences? _prefs;

  /// Loads the persisted session + preferences. Returns a ready state whose
  /// `route` is `app` when a session was saved, else `welcome`.
  static Future<PatientAppState> load() async {
    final s = PatientAppState();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      s.lang = p.getString('pa.lang') ?? 'en';
      s.accent = _accentFromKey(p.getString('pa.accent'));
      s.countryCode = p.getString('pa.country') ?? 'EG';
      s.activeAccountId = p.getString('pa.account') ?? 'layla';
      s.storageProvider = p.getString('pa.storage') ?? 'local';
      s.route = (p.getBool('pa.signedIn') ?? false) ? 'app' : 'welcome';
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

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setBool('pa.signedIn', route == 'app');
    p.setString('pa.lang', lang);
    p.setString('pa.accent', _accentKey);
    p.setString('pa.country', countryCode);
    p.setString('pa.account', activeAccountId);
    p.setString('pa.storage', storageProvider);
  }

  bool get rtl => lang == 'ar';
  TextDirection get dir => rtl ? TextDirection.rtl : TextDirection.ltr;
  String t(String key) => tr(key, lang);

  FamilyAccount get account =>
      kFamilyAccounts.firstWhere((a) => a.id == activeAccountId, orElse: () => kFamilyAccounts.first);
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

  void go(String r) {
    if (r == 'app') {
      tab = 'home';
      today = null;
    }
    if (r == 'welcome') today = null;
    route = r;
    _save(); // persist signed-in / signed-out
    notifyListeners();
  }

  void setTab(String tb) {
    tab = tb;
    notifyListeners();
  }

  void switchAccount(String id) {
    activeAccountId = id;
    _save();
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

  void completeCheckin(CheckinResult r) {
    today = r;
    notifyListeners();
  }
}

/// Result captured by the self-report flow.
class CheckinResult {
  const CheckinResult({this.bp, this.glu, this.mood, this.pain});
  final String? bp;
  final int? glu;
  final int? mood;
  final int? pain;
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
