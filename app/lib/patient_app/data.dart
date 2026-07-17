// Static reference data for the patient app shell.
//
// This file holds ONLY non-PHI configuration/reference data that the
// prototype needs regardless of the signed-in user: the localized-string
// helper, the supported-languages list, and the countries list (dial codes +
// emergency numbers) used by the travel-mode country picker.
//
// All sample/fake user data (family accounts, medications, history, trends,
// doctors, appointments, prescriptions, health records, map entities) has been
// removed — those surfaces now read real providers or render empty/neutral
// states. Do NOT reintroduce fabricated PHI here.

/// Bilingual string. `s.of('ar')` picks the locale, falling back to en.
typedef L = Map<String, String>;

extension LocalizedMap on L {
  String of(String lang) => this[lang] ?? this['en'] ?? '';
}

// ── Languages ────────────────────────────────────────────────
class Lang {
  const Lang(this.code, this.native, this.en, this.rtl, this.full);
  final String code;
  final String native;
  final String en;
  final bool rtl;
  final bool full;
}

const List<Lang> kLanguages = [
  Lang('ar', 'العربية', 'Arabic', true, true),
  Lang('en', 'English', 'English', false, true),
  Lang('fr', 'Français', 'French', false, false),
  Lang('ur', 'اردو', 'Urdu', true, false),
  Lang('fa', 'فارسی', 'Persian', true, false),
  Lang('tr', 'Türkçe', 'Turkish', false, false),
];

// ── Countries (travel mode) ──────────────────────────────────
class Country {
  const Country(this.code, this.name, this.dial, this.emergency, {this.home = false});
  final String code;
  final L name;
  final String dial;
  final String emergency;
  final bool home;
}

const List<Country> kCountries = [
  Country('EG', {'en': 'Egypt', 'ar': 'مصر'}, '+20', '123', home: true),
  Country('SA', {'en': 'Saudi Arabia', 'ar': 'السعودية'}, '+966', '997'),
  Country('AE', {'en': 'UAE', 'ar': 'الإمارات'}, '+971', '998'),
  Country('JO', {'en': 'Jordan', 'ar': 'الأردن'}, '+962', '911'),
  Country('KW', {'en': 'Kuwait', 'ar': 'الكويت'}, '+965', '112'),
  Country('QA', {'en': 'Qatar', 'ar': 'قطر'}, '+974', '999'),
  Country('MA', {'en': 'Morocco', 'ar': 'المغرب'}, '+212', '150'),
  Country('LB', {'en': 'Lebanon', 'ar': 'لبنان'}, '+961', '140'),
];
