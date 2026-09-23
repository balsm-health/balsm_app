/// The synthetic person every documentation/store screenshot shows.
///
/// FABRICATED. Nobody real, no real clinical history. The names are ordinary
/// Egyptian ones rather than "Test User" so Arabic captures show real Arabic
/// typography — letter joining, diacritics and RTL line-breaking are exactly
/// what a screenshot is meant to prove, and "E2E Tester" proves none of it.
///
/// This file is referenced ONLY by `main_docshots.dart`. It is not reachable
/// from `main_balsm.dart`, so it is tree-shaken out of every shipped build.
library;

class DocshotsPersona {
  const DocshotsPersona._();

  /// Patient. Matches the app's default `female` body-map figure.
  static const nameAr = 'نور عبد الرحمن';
  static const nameEn = 'Nour Abdelrahman';
  static const handle = 'nour.abdelrahman';
  static const email = 'test+1@balsm.test'; // .test is reserved (RFC 2606)

  /// Care team.
  static const doctorCardiologyAr = 'د. أحمد الشاذلي';
  static const doctorCardiologyEn = 'Dr. Ahmed El-Shazly';
  static const doctorEndocrineAr = 'د. سلمى فاروق';
  static const doctorEndocrineEn = 'Dr. Salma Farouk';

  /// Family members shown in the account switcher.
  static const sonAr = 'ياسين عبد الرحمن';
  static const sonEn = 'Yassin Abdelrahman';
  static const motherAr = 'فاطمة حسن';
  static const motherEn = 'Fatma Hassan';
}
