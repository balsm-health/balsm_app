import 'dart:ui' show PlatformDispatcher;

import 'package:core/core.dart';
import 'storage_target.dart';

/// App-shell preference group (`pa.*` namespace) — language, accent, country,
/// backup target, signed-in flag. All storage goes through the injected
/// [KeyValueDataSource]; nothing here (or in callers) touches
/// `SharedPreferences` directly.
class PatientAppPrefs extends ModulePreferences {
  const PatientAppPrefs(super.kv, {this.deviceLanguages = systemLanguages}) : super(namespace: 'pa');

  /// The phone's languages as BCP-47 tags, most preferred first. Injected so a
  /// test can pretend to be an Arabic phone; the default asks the platform.
  final Iterable<String> Function() deviceLanguages;

  /// The platform's own answer. Reads `PlatformDispatcher.instance` directly
  /// rather than a binding, so it works before any binding exists (the boot
  /// tests build the state without one).
  static Iterable<String> systemLanguages() => PlatformDispatcher.instance.locales.map((l) => l.toLanguageTag());

  /// The UI language: the saved choice, else the device's, else Arabic (see
  /// [LanguageCode.resolveUi]). Never null, and always one the app can render.
  Future<String> lang() async =>
      LanguageCode.resolveUi(saved: await read<String>('lang'), deviceTags: deviceLanguages()).value;
  Future<void> setLang(String v) => write('lang', v);

  Future<String?> accent() => read<String>('accent');
  Future<void> setAccent(String v) => write('accent', v);

  Future<String> country() async => await read<String>('country') ?? 'EG';
  Future<void> setCountry(String v) => write('country', v);

  Future<StorageTarget> storage() async =>
      StorageTarget.tryFromId(await read<String>('storage') ?? '') ?? StorageTarget.local;
  Future<void> setStorage(StorageTarget v) => write('storage', v.id);

  Future<bool> signedIn() async => await read<bool>('signedIn') ?? false;
  Future<void> setSignedIn(bool v) => write('signedIn', v);

  /// First-run onboarding walkthrough (Vision → "day with Balsm" → Data) —
  /// shown once ever, before a never-signed-in device reaches Welcome.
  Future<bool> walkthroughSeen() async => await read<bool>('walkthroughSeen') ?? false;
  Future<void> setWalkthroughSeen(bool v) => write('walkthroughSeen', v);

  /// True when neither [signedIn] nor [walkthroughSeen] has ever been
  /// written — a first launch since install. Anyone who reached an account
  /// left the walkthrough (which writes [walkthroughSeen]), so an account in
  /// the keychain with this true is a leftover from an uninstalled copy (iOS
  /// keeps keychain items across uninstall; prefs go with the app).
  Future<bool> isFreshInstall() async => !await contains('signedIn') && !await contains('walkthroughSeen');

  /// Last device timezone marker seen on app foreground (FR-023 / gap G9).
  /// Null until first recorded. Non-PHI — a coarse zone name/abbreviation only.

  /// Last in-app feedback rating (1–5) and when it was sent. App feedback, not
  /// PHI — it stays in the KV group rather than the encrypted PHI database.
  Future<int?> feedbackRating() => read<int>('fbRating');
  Future<void> setFeedbackRating(int v) => write('fbRating', v);

  Future<DateTime?> feedbackSentAt() async {
    final raw = await read<String>('fbSentAt');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setFeedbackSentAt(DateTime v) => write('fbSentAt', v.toUtc().toIso8601String());

  /// Whether the care team is mirrored to Balsm Cloud. On unless the patient
  /// turned it off in Storage & sync.
  Future<bool> careCloudSync() async => await read<bool>('careCloudSync') ?? true;
  Future<void> setCareCloudSync(bool v) => write('careCloudSync', v);

  Future<String?> lastTimezone() => read<String>('lastTz');
  Future<void> setLastTimezone(String v) => write('lastTz', v);
}
