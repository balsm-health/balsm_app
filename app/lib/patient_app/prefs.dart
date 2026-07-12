import 'package:core/core.dart';

/// App-shell preference group (`pa.*` namespace) — language, accent, country,
/// active account, backup target, signed-in flag. All storage goes through
/// the injected [KeyValueDataSource]; nothing here (or in callers) touches
/// `SharedPreferences` directly.
class PatientAppPrefs extends ModulePreferences {
  const PatientAppPrefs(super.kv) : super(namespace: 'pa');

  Future<String> lang() async => await read<String>('lang') ?? 'en';
  Future<void> setLang(String v) => write('lang', v);

  Future<String?> accent() => read<String>('accent');
  Future<void> setAccent(String v) => write('accent', v);

  Future<String> country() async => await read<String>('country') ?? 'EG';
  Future<void> setCountry(String v) => write('country', v);

  Future<String> account() async => await read<String>('account') ?? 'layla';
  Future<void> setAccount(String v) => write('account', v);

  Future<String> storage() async => await read<String>('storage') ?? 'local';
  Future<void> setStorage(String v) => write('storage', v);

  Future<bool> signedIn() async => await read<bool>('signedIn') ?? false;
  Future<void> setSignedIn(bool v) => write('signedIn', v);
}
