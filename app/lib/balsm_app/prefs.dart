import 'package:core/core.dart';
import 'storage_target.dart';

/// App-shell preference group (`pa.*` namespace) — language, accent, country,
/// backup target, signed-in flag. All storage goes through the injected
/// [KeyValueDataSource]; nothing here (or in callers) touches
/// `SharedPreferences` directly.
class PatientAppPrefs extends ModulePreferences {
  const PatientAppPrefs(super.kv) : super(namespace: 'pa');

  Future<String> lang() async => await read<String>('lang') ?? 'en';
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

  Future<String?> lastTimezone() => read<String>('lastTz');
  Future<void> setLastTimezone(String v) => write('lastTz', v);
}
