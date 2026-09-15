import 'package:core/core.dart' show CountryCode, FamilyLinkStatus, Gender, LanguageCode, TranslationCatalog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ChangeNotifierProvider;
import 'prefs.dart';
import 'routes.dart';
import 'storage_target.dart';
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
/// (`accountSummaryProvider`, `profileDataSourceProvider`).
/// Which credential flow the auth screens run ('signup' vs 'signin' in the
/// design prototype).
enum AuthIntent { signIn, signUp }

/// How the account was reached at the credentials step.
enum AuthMethod { phone, email }

/// Handle-availability check state shared by the profile-setup and personal-
/// details username fields.
enum UsernameStatus { idle, checking, available, taken, invalid }

class PatientAppState extends ChangeNotifier {
  LanguageCode lang = LanguageCode.en;

  /// Default accent — `TWEAK_DEFAULTS.accent` in the design's `app.jsx`.
  Accent accent = Accent.violet;

  /// Auth route: walkthrough | welcome | phone | otp | profile | app
  String route = AppRoutes.welcome;

  /// Active tab/sub-screen: home | map | meds | profile | trends | records | appts
  AppTab tab = AppTab.home;

  AuthMethod authMethod = AuthMethod.phone;
  String authEmail = '';

  /// 'signup' (Get started / social) | 'signin' (Sign in link). Decides whether
  /// the email+password form registers (OTP → setPassword) or signs in.
  AuthIntent authIntent = AuthIntent.signIn;

  /// Transient — password captured on the password sign-up screen, applied via
  /// setPassword once OTP verify establishes the session. In-memory only (never
  /// persisted); cleared after use.
  String? authPassword;

  CountryCode country = kHomeCountry;

  /// User gender — drives grammatically-gendered copy (Arabic). Passed to i69n
  /// `_select` message methods, e.g. `s.strings.home.hero_q(s.gender)`.
  /// Defaults to [Gender.other] (masculine) until the profile loads.
  Gender gender = Gender.other;

  /// Active backup target. Closed catalog — see [StorageTarget].
  StorageTarget storageProvider = StorageTarget.local;

  /// Session-only extra family members the patient added from the account
  /// sheet. Name + relation only — no DOB stored here (PHI stays in profile
  /// persistence when family accounts land in P002).
  final List<FamilyMemberPreview> extraFamily = [];

  /// Selected extra family member for greeting/avatar only. Null means the
  /// signed-in account. Never switches the health profile.
  String? activeFamilyId;

  PatientAppPrefs? _prefs;

  /// The app-shell preference group, once [load] has run. Null before that and
  /// in tests that build a bare state — callers must handle the null.
  PatientAppPrefs? get prefs => _prefs;

  /// Loads the persisted session + preferences from the app-shell preference
  /// group. Returns a ready state whose `route` is `app` when a session was
  /// saved **and** [hasSession] confirms real credentials survived, else
  /// `welcome`.
  ///
  /// [hasSession] is whether secure storage still holds `balsm.user_id`. The
  /// `signedIn` flag lives in plain prefs and the credentials live in the
  /// keychain, so the two can disagree — a restored-from-backup device, a
  /// cleared keychain, or a reinstall keeps the flag but loses the id. Routing
  /// on the flag alone then dropped the patient into the signed-in shell with
  /// a null user id, where every account and PHI read resolves to nothing and
  /// nothing ever recovers: no token means no refresh, so `SessionExpired`
  /// never fires. Trust the credentials, and clear the stale flag.
  static Future<PatientAppState> load(PatientAppPrefs prefs, {required bool hasSession}) async {
    final s = PatientAppState();
    s._prefs = prefs;
    try {
      // Persisted as the bare code; anything unsupported falls back to en.
      s.lang = LanguageCode.tryParseUi(await prefs.lang()) ?? LanguageCode.en;
      // Accent is a design constant (`TWEAK_DEFAULTS.accent` in app.jsx), not a
      // user setting — nothing in the app calls [setAccent]. It is deliberately
      // NOT restored from prefs: `_save()` used to stamp the then-current
      // default into storage as a side effect of any lang/country/storage
      // write, which pinned existing installs to a stale accent and silently
      // overrode the design. Restore this read only alongside a real picker.
      // Persisted as the bare ISO code; malformed values fall back to home.
      s.country = CountryCode.tryFromCode(await prefs.country()) ?? kHomeCountry;
      // Cloud backup is disabled (see storage_sheet): only `local` is a real
      // target, so a target persisted before that change must not keep
      // claiming the record is backed up to a cloud that never received it.
      final storedTarget = await prefs.storage();
      s.storageProvider = storedTarget.isLocal ? storedTarget : StorageTarget.local;
      if (await prefs.signedIn() && hasSession) {
        s.route = AppRoutes.app;
      } else {
        // Stale flag without credentials — persist signed-out so the next
        // launch agrees with the keychain instead of re-entering the shell.
        if (!hasSession) await prefs.setSignedIn(false);
        s.route = await prefs.walkthroughSeen() ? AppRoutes.welcome : AppRoutes.walkthrough;
      }
    } catch (_) {
      s.route = AppRoutes.welcome;
    }
    return s;
  }

  /// Fire-and-forget persistence (matches the previous SharedPreferences
  /// behavior — setters are not awaited on the UI path).
  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setSignedIn(route == AppRoutes.app);
    p.setLang(lang.value);
    p.setCountry(country.value);
    p.setStorage(storageProvider);
  }

  bool get rtl => lang.isRtl;
  TextDirection get dir => rtl ? TextDirection.rtl : TextDirection.ltr;

  /// Stringly-typed lookup — keep only for keys computed at runtime
  /// (e.g. `t(rows[i].key)`). For static keys prefer [strings].
  String t(String key) => tr(key, lang.value);

  /// Locale-aware, compile-time-checked message bundle:
  /// `s.strings.meds.med_snooze15` fails to compile on a typo, whereas
  /// `s.t('meds.med_snooze15')` silently returns the key at runtime.
  Strings get strings => stringsFor(lang.value);

  bool get isHomeCountry => country == kHomeCountry;

  void setGender(Gender g) {
    if (g == gender) return;
    gender = g;
    notifyListeners();
  }

  void setLang(LanguageCode l) {
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
  void setAuthContact({required AuthMethod method, required String email}) {
    authMethod = method;
    authEmail = email;
    notifyListeners();
  }

  /// Set the auth intent (called from the welcome screen before go('phone')).
  void setAuthIntent(AuthIntent intent) {
    authIntent = intent;
    notifyListeners();
  }

  /// Stash/clear the transient sign-up password (not UI-bound, no notify).
  void setAuthPassword(String? pw) => authPassword = pw;

  void go(String r) {
    if (r == AppRoutes.app) tab = AppTab.home;
    // Leaving the first-run walkthrough (Skip or Get started) marks it seen so
    // it never shows again on this device, signed in or not.
    if (route == AppRoutes.walkthrough && r != AppRoutes.walkthrough) _prefs?.setWalkthroughSeen(true);
    route = r;
    _save(); // persist signed-in / signed-out
    notifyListeners();
  }

  void setTab(AppTab tb) {
    tab = tb;
    notifyListeners();
  }

  /// Clears every account-scoped piece of in-memory + preference state when
  /// the user signs out, so the NEXT account on this device never inherits
  /// the previous one (family members, gendered copy, completion state,
  /// transient auth fields). Language / country / storage target are device
  /// preferences and deliberately survive.
  void resetForSignOut() {
    extraFamily.clear();
    activeFamilyId = null;
    linkRequests.clear();
    gender = Gender.other;
    authEmail = '';
    authPassword = null;
    notifyListeners();
  }

  /// Debug-only: ReportFlow registers this while the check-in is open.
  VoidCallback? qaCheckinAdvance;

  void switchCloudProvider(StorageTarget to) {
    storageProvider = to;
    _save();
    notifyListeners();
  }

  void setCountry(CountryCode c) {
    country = c;
    _save();
    notifyListeners();
  }

  void addFamilyMember(
      {required String name,
      required String relation,
      DateTime? dob,
      String? linkJti,
      FamilyLinkStatus status = FamilyLinkStatus.linked}) {
    const palette = [T.petalAqua, T.petalBlue, T.petalViolet, T.petalMint, T.sun500];
    extraFamily.add(FamilyMemberPreview(
      id: 'fam_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      relation: relation,
      color: palette[extraFamily.length % palette.length],
      dob: dob,
      linkJti: linkJti,
      status: status,
    ));
    notifyListeners();
  }

  /// Withdraws an outgoing link request (design: pending row → Cancel).
  void cancelPendingLink(String id) {
    extraFamily.removeWhere((m) => m.id == id && m.status == FamilyLinkStatus.pending);
    if (activeFamilyId == id) activeFamilyId = null;
    notifyListeners();
  }

  /// Incoming link requests — someone asking to add THIS patient to their
  /// family account. Populated from the server when the link-request API
  /// lands (P002); never seeded with fabricated people.
  final List<FamilyLinkRequest> linkRequests = [];

  void approveLinkRequest(String requestId) {
    final i = linkRequests.indexWhere((r) => r.id == requestId);
    if (i < 0) return;
    final r = linkRequests.removeAt(i);
    addFamilyMember(name: r.name, relation: r.relation, dob: r.dob, linkJti: r.linkJti);
  }

  void declineLinkRequest(String requestId) {
    linkRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }

  /// Session-only visual switch. Does not change the signed-in health profile.
  void selectFamilyMember(String? id) {
    if (activeFamilyId == id) return;
    activeFamilyId = id;
    notifyListeners();
  }

  FamilyMemberPreview? get activeFamilyMember {
    final id = activeFamilyId;
    if (id == null) return null;
    for (final m in extraFamily) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// An incoming request to link accounts, shown in the account switcher.
/// Data comes from the server request row (P002 API); [linkJti] is the
/// requester's profile-QR jti.
class FamilyLinkRequest {
  const FamilyLinkRequest({
    required this.id,
    required this.name,
    required this.relation,
    this.dob,
    this.linkJti,
    this.when,
  });
  final String id;
  final String name;
  final String relation;
  final DateTime? dob;
  final String? linkJti;
  final String? when;
}

/// Local family-member row for the account switcher (user-entered, not sample PHI).
class FamilyMemberPreview {
  const FamilyMemberPreview({
    required this.id,
    required this.name,
    required this.relation,
    required this.color,
    this.dob,
    this.linkJti,
    this.status = FamilyLinkStatus.linked,
  });
  final String id;
  final String name;
  final String relation;
  final Color color;

  /// The scanned profile-QR jti this member was linked through (spec v2.0:
  /// every cross-account flow binds to the jti, never an account id).
  final String? linkJti;

  final FamilyLinkStatus status;
  bool get isPending => status == FamilyLinkStatus.pending;

  /// Date of birth, used only to show the member's age in the switcher.
  ///
  /// PHI: held in memory for this session only — never written to prefs, the
  /// database, logs or the network. Real family profiles land in P002, where
  /// DOB goes through the field-encrypted profile persistence instead.
  final DateTime? dob;

  /// Whole years since [dob], or null when no birth date was given.
  int? get age {
    final d = dob;
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    final hadBirthday = now.month > d.month || (now.month == d.month && now.day >= d.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? 0 : years;
  }
}

/// Derives up-to-two-letter avatar initials from a display name. Returns an
/// empty string when the name is blank (loading / signed out) so the avatar
/// renders neutrally rather than showing fabricated initials.
String accountInitials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// InheritedNotifier exposing [PatientAppState] to the widget tree.
/// Riverpod owns the app-shell state: the bootstrap overrides this with the
/// loaded instance, the shell watches it, and providers (identity reader,
/// backup service, …) read it without a BuildContext.
///
/// ChangeNotifierProvider is the sanctioned migration bridge — state
/// transitions still live inside [PatientAppState]; converting it to an
/// immutable [Notifier] is a follow-up that must not block screens from
/// depending on Riverpod today.
final patientAppStateProvider = ChangeNotifierProvider<PatientAppState>(
  (ref) => throw UnimplementedError('patientAppStateProvider is overridden at bootstrap'),
);

/// Context bridge over [patientAppStateProvider] for widget code.
///
/// `AppScope.of(context)` subscribes the caller to state changes exactly like
/// `ref.watch(patientAppStateProvider)` — the InheritedNotifier is the
/// context-based view binding onto the SAME Riverpod-owned instance, kept so
/// non-Consumer widgets don't each need a WidgetRef. New code with a `ref` in
/// scope should prefer the provider directly.
class AppScope extends InheritedNotifier<PatientAppState> {
  const AppScope({super.key, required PatientAppState state, required super.child}) : super(notifier: state);

  static PatientAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
