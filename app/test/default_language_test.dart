import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:core/core.dart' show KeyValueDataSource, LanguageCode;
import 'package:flutter_test/flutter_test.dart';

class _MemoryKV implements KeyValueDataSource {
  final store = <String, Object?>{};
  @override
  Future<T?> get<T>(String key) async => store[key] as T?;
  @override
  Future<void> put<T>(String key, T value) async => store[key] = value;
  @override
  Future<bool> exists(String key) async => store.containsKey(key);
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> clear() async => store.clear();
}

/// A fresh install used to open in English whatever the phone's language
/// (issue #100). The boot path now follows the device, then Arabic, and a
/// language the patient picked still wins.
void main() {
  /// Boots the state as a phone whose languages are [device], most preferred first.
  Future<LanguageCode> launch(List<String> device, {String? saved}) async {
    final kv = _MemoryKV();
    PatientAppPrefs prefs() => PatientAppPrefs(kv, deviceLanguages: () => device);
    if (saved != null) await prefs().setLang(saved);
    final state = await PatientAppState.load(prefs(), hasSession: false);
    return state.lang;
  }

  test('a fresh install on an Arabic phone opens in Arabic, right to left', () async {
    final lang = await launch(['ar-EG']);

    expect(lang, LanguageCode.ar);
    expect(lang.isRtl, isTrue);
  });

  test('a fresh install on an English phone opens in English', () async {
    expect(await launch(['en-US']), LanguageCode.en);
  });

  test('a phone in a language the app lacks falls back to Arabic', () async {
    expect(await launch(['fr-FR']), LanguageCode.ar);
  });

  test("a language the patient chose beats the phone's, on every launch", () async {
    expect(await launch(['ar-EG'], saved: 'en'), LanguageCode.en);
    expect(await launch(['en-US'], saved: 'ar'), LanguageCode.ar);
  });

  test("the platform's own answer is always a list of tags, never throws without a binding", () {
    expect(PatientAppPrefs.systemLanguages, returnsNormally);
  });
}
