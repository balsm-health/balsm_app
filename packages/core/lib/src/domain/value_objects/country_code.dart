// ignore_for_file: constant_identifier_names
import 'currency_code.dart';
import 'value_object.dart';

/// ISO 3166-1 alpha-2 country — the reference hub for country-derived
/// **structural** i18n facts: [dialCode], [currency], [defaultTimezone],
/// [emergencyNumber], plus English fallbacks [englishName] / [englishDemonym].
/// These never change and are needed synchronously in pure logic (e.g. phone
/// validation), so they stay compile-time const.
///
/// Locale is deliberately NOT here — it is a user preference (any country
/// hosts speakers of many languages), resolved from device locale + user
/// setting, not derived from country.
///
/// Localized names and demonyms are NOT here — they live in the core i69n
/// bundle (`country.<code>.name` / `.demonym`); resolve them via the
/// `CountryCodeL10n` extension (see `localization/reference_l10n.dart`). The
/// baked-in [englishName] / [englishDemonym] are the English fallbacks that
/// L10n layer uses when no translation exists.
///
/// The launch-market countries are exposed as full-name consts ([egypt],
/// [saudi_arabia], …), gathered in [supportedCountries] (aliased [known] for
/// existing callers). [all] holds every ISO 3166-1 alpha-2 country — each entry
/// carries an English name, demonym, and dial code — and [supportedNationalities]
/// aliases [all] so any citizenship is accepted. The `String` factory resolves
/// via [all] and returns neutral defaults for any other well-formed 2-letter
/// code, so the type never blocks an unlisted country.
class CountryCode extends ValueObject {
  const CountryCode._(this.value, this._meta);

  /// Resolve an arbitrary ISO code (from JSON/API/DB/route params) to a
  /// curated instance, or a bare one with neutral defaults. Throws
  /// [ArgumentError] on malformed input; for a non-throwing parse of
  /// untrusted input use [tryFromCode].
  factory CountryCode.fromCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2 || !_isAlpha(upper)) {
      throw ArgumentError('Invalid ISO 3166-1 country code: $code');
    }
    return _byCode[upper] ?? CountryCode._(upper, null);
  }

  /// Like [CountryCode.fromCode] but returns null on malformed input —
  /// for stored/external values where the caller supplies a fallback.
  static CountryCode? tryFromCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2 || !_isAlpha(upper)) return null;
    return _byCode[upper] ?? CountryCode._(upper, null);
  }

  /// The 2-letter uppercase ISO code, e.g. `EG`.
  final String value;

  final _CountryMeta? _meta;

  // Denied/geofenced countries are NOT modelled here — that list is
  // server-driven (geofence_block's DeniedCountriesPort, GET
  // /geofence/denied-countries), never a hardcoded const.

  /// English country name, e.g. `Egypt`. Falls back to the raw code for an
  /// unlisted country.
  String get englishName => _meta?.nameEn ?? value;

  /// English demonym, e.g. `Egyptian`. Falls back to the raw code.
  String get englishDemonym => _meta?.demonymEn ?? value;

  /// International calling code including `+`, e.g. `+20`. Empty when unknown.
  String get dialCode => _meta?.dialCode ?? '';

  /// Official currency; defaults to USD when the country is unlisted.
  CurrencyCode get currency => _meta?.currency ?? CurrencyCode.usd;

  String get defaultTimezone => _meta?.timezone ?? 'UTC';

  /// National emergency/ambulance number, e.g. `123` for Egypt. Empty when
  /// unknown — callers must render nothing rather than a wrong number.
  String get emergencyNumber => _meta?.emergency ?? '';

  /// True for the curated set (has full metadata).
  bool get isKnown => _meta != null;

  // ── Launch markets (full metadata: currency / timezone / emergency) ───────
  static const egypt = CountryCode._('EG',
      _CountryMeta('Egypt', 'Egyptian', '+20', currency: CurrencyCode.egp, timezone: 'Africa/Cairo', emergency: '123'));
  static const saudi_arabia = CountryCode._(
      'SA',
      _CountryMeta('Saudi Arabia', 'Saudi', '+966',
          currency: CurrencyCode.sar, timezone: 'Asia/Riyadh', emergency: '997'));
  static const united_arab_emirates = CountryCode._(
      'AE',
      _CountryMeta('United Arab Emirates', 'Emirati', '+971',
          currency: CurrencyCode.aed, timezone: 'Asia/Dubai', emergency: '998'));
  static const qatar = CountryCode._('QA',
      _CountryMeta('Qatar', 'Qatari', '+974', currency: CurrencyCode.qar, timezone: 'Asia/Qatar', emergency: '999'));
  static const kuwait = CountryCode._('KW',
      _CountryMeta('Kuwait', 'Kuwaiti', '+965', currency: CurrencyCode.kwd, timezone: 'Asia/Kuwait', emergency: '112'));
  static const bahrain = CountryCode._(
      'BH',
      _CountryMeta('Bahrain', 'Bahraini', '+973',
          currency: CurrencyCode.bhd, timezone: 'Asia/Bahrain', emergency: '999'));
  static const oman = CountryCode._('OM',
      _CountryMeta('Oman', 'Omani', '+968', currency: CurrencyCode.omr, timezone: 'Asia/Muscat', emergency: '999'));
  static const jordan = CountryCode._(
      'JO',
      _CountryMeta('Jordan', 'Jordanian', '+962',
          currency: CurrencyCode.jod, timezone: 'Asia/Amman', emergency: '911'));
  static const lebanon = CountryCode._(
      'LB',
      _CountryMeta('Lebanon', 'Lebanese', '+961',
          currency: CurrencyCode.usd, timezone: 'Asia/Beirut', emergency: '140'));
  static const morocco = CountryCode._(
      'MA',
      _CountryMeta('Morocco', 'Moroccan', '+212',
          currency: CurrencyCode.usd, timezone: 'Africa/Casablanca', emergency: '150'));
  static const united_states = CountryCode._(
      'US',
      _CountryMeta('United States', 'American', '+1',
          currency: CurrencyCode.usd, timezone: 'America/New_York', emergency: '911'));
  static const united_kingdom = CountryCode._(
      'GB',
      _CountryMeta('United Kingdom', 'British', '+44',
          currency: CurrencyCode.gbp, timezone: 'Europe/London', emergency: '999'));

  /// The app's operating markets, in reference order.
  static const supportedCountries = [
    egypt,
    saudi_arabia,
    united_arab_emirates,
    qatar,
    kuwait,
    bahrain,
    oman,
    jordan,
    lebanon,
    morocco,
    united_states,
    united_kingdom,
  ];

  /// Back-compat alias for [supportedCountries] — existing callers use
  /// `CountryCode.known`.
  static const known = supportedCountries;

  /// Every current ISO 3166-1 alpha-2 country exactly once: the launch markets
  /// above followed by all remaining countries and territories. Each entry
  /// carries an English name, demonym, and international dial code; non-market
  /// entries take neutral currency / timezone / emergency defaults.
  static const all = [
    // ── Launch markets ───────────────────────────────────────────────────
    egypt,
    saudi_arabia,
    united_arab_emirates,
    qatar,
    kuwait,
    bahrain,
    oman,
    jordan,
    lebanon,
    morocco,
    united_states,
    united_kingdom,
    // ── Every other ISO 3166-1 alpha-2 country / territory ───────────────
    CountryCode._('AD', _CountryMeta('Andorra', 'Andorran', '+376')),
    CountryCode._('AF', _CountryMeta('Afghanistan', 'Afghan', '+93')),
    CountryCode._('AG', _CountryMeta('Antigua and Barbuda', 'Antiguan and Barbudan', '+1268')),
    CountryCode._('AI', _CountryMeta('Anguilla', 'Anguillan', '+1264')),
    CountryCode._('AL', _CountryMeta('Albania', 'Albanian', '+355')),
    CountryCode._('AM', _CountryMeta('Armenia', 'Armenian', '+374')),
    CountryCode._('AO', _CountryMeta('Angola', 'Angolan', '+244')),
    CountryCode._('AQ', _CountryMeta('Antarctica', 'Antarctic', '+672')),
    CountryCode._('AR', _CountryMeta('Argentina', 'Argentine', '+54')),
    CountryCode._('AS', _CountryMeta('American Samoa', 'American Samoan', '+1684')),
    CountryCode._('AT', _CountryMeta('Austria', 'Austrian', '+43')),
    CountryCode._('AU', _CountryMeta('Australia', 'Australian', '+61')),
    CountryCode._('AW', _CountryMeta('Aruba', 'Aruban', '+297')),
    CountryCode._('AX', _CountryMeta('Åland Islands', 'Åland Island', '+358')),
    CountryCode._('AZ', _CountryMeta('Azerbaijan', 'Azerbaijani', '+994')),
    CountryCode._('BA', _CountryMeta('Bosnia and Herzegovina', 'Bosnian and Herzegovinian', '+387')),
    CountryCode._('BB', _CountryMeta('Barbados', 'Barbadian', '+1246')),
    CountryCode._('BD', _CountryMeta('Bangladesh', 'Bangladeshi', '+880')),
    CountryCode._('BE', _CountryMeta('Belgium', 'Belgian', '+32')),
    CountryCode._('BF', _CountryMeta('Burkina Faso', 'Burkinabé', '+226')),
    CountryCode._('BG', _CountryMeta('Bulgaria', 'Bulgarian', '+359')),
    CountryCode._('BI', _CountryMeta('Burundi', 'Burundian', '+257')),
    CountryCode._('BJ', _CountryMeta('Benin', 'Beninese', '+229')),
    CountryCode._('BL', _CountryMeta('Saint Barthélemy', 'Barthélemois', '+590')),
    CountryCode._('BM', _CountryMeta('Bermuda', 'Bermudian', '+1441')),
    CountryCode._('BN', _CountryMeta('Brunei Darussalam', 'Bruneian', '+673')),
    CountryCode._('BO', _CountryMeta('Bolivia', 'Bolivian', '+591')),
    CountryCode._('BQ', _CountryMeta('Bonaire, Sint Eustatius and Saba', 'Bonaire', '+599')),
    CountryCode._('BR', _CountryMeta('Brazil', 'Brazilian', '+55')),
    CountryCode._('BS', _CountryMeta('Bahamas', 'Bahamian', '+1242')),
    CountryCode._('BT', _CountryMeta('Bhutan', 'Bhutanese', '+975')),
    CountryCode._('BV', _CountryMeta('Bouvet Island', 'Bouvet Island', '+47')),
    CountryCode._('BW', _CountryMeta('Botswana', 'Botswanan', '+267')),
    CountryCode._('BY', _CountryMeta('Belarus', 'Belarusian', '+375')),
    CountryCode._('BZ', _CountryMeta('Belize', 'Belizean', '+501')),
    CountryCode._('CA', _CountryMeta('Canada', 'Canadian', '+1')),
    CountryCode._('CC', _CountryMeta('Cocos (Keeling) Islands', 'Cocos Island', '+61')),
    CountryCode._('CD', _CountryMeta('Congo, Democratic Republic of the', 'Congolese', '+243')),
    CountryCode._('CF', _CountryMeta('Central African Republic', 'Central African', '+236')),
    CountryCode._('CG', _CountryMeta('Congo', 'Congolese', '+242')),
    CountryCode._('CH', _CountryMeta('Switzerland', 'Swiss', '+41')),
    CountryCode._('CI', _CountryMeta("Côte d'Ivoire", 'Ivorian', '+225')),
    CountryCode._('CK', _CountryMeta('Cook Islands', 'Cook Island', '+682')),
    CountryCode._('CL', _CountryMeta('Chile', 'Chilean', '+56')),
    CountryCode._('CM', _CountryMeta('Cameroon', 'Cameroonian', '+237')),
    CountryCode._('CN', _CountryMeta('China', 'Chinese', '+86')),
    CountryCode._('CO', _CountryMeta('Colombia', 'Colombian', '+57')),
    CountryCode._('CR', _CountryMeta('Costa Rica', 'Costa Rican', '+506')),
    CountryCode._('CU', _CountryMeta('Cuba', 'Cuban', '+53')),
    CountryCode._('CV', _CountryMeta('Cabo Verde', 'Cabo Verdean', '+238')),
    CountryCode._('CW', _CountryMeta('Curaçao', 'Curaçaoan', '+599')),
    CountryCode._('CX', _CountryMeta('Christmas Island', 'Christmas Island', '+61')),
    CountryCode._('CY', _CountryMeta('Cyprus', 'Cypriot', '+357')),
    CountryCode._('CZ', _CountryMeta('Czechia', 'Czech', '+420')),
    CountryCode._('DE', _CountryMeta('Germany', 'German', '+49')),
    CountryCode._('DJ', _CountryMeta('Djibouti', 'Djiboutian', '+253')),
    CountryCode._('DK', _CountryMeta('Denmark', 'Danish', '+45')),
    CountryCode._('DM', _CountryMeta('Dominica', 'Dominican', '+1767')),
    CountryCode._('DO', _CountryMeta('Dominican Republic', 'Dominican', '+1809')),
    CountryCode._('DZ', _CountryMeta('Algeria', 'Algerian', '+213')),
    CountryCode._('EC', _CountryMeta('Ecuador', 'Ecuadorian', '+593')),
    CountryCode._('EE', _CountryMeta('Estonia', 'Estonian', '+372')),
    CountryCode._('EH', _CountryMeta('Western Sahara', 'Sahrawi', '+212')),
    CountryCode._('ER', _CountryMeta('Eritrea', 'Eritrean', '+291')),
    CountryCode._('ES', _CountryMeta('Spain', 'Spanish', '+34')),
    CountryCode._('ET', _CountryMeta('Ethiopia', 'Ethiopian', '+251')),
    CountryCode._('FI', _CountryMeta('Finland', 'Finnish', '+358')),
    CountryCode._('FJ', _CountryMeta('Fiji', 'Fijian', '+679')),
    CountryCode._('FK', _CountryMeta('Falkland Islands', 'Falkland Island', '+500')),
    CountryCode._('FM', _CountryMeta('Micronesia, Federated States of', 'Micronesian', '+691')),
    CountryCode._('FO', _CountryMeta('Faroe Islands', 'Faroese', '+298')),
    CountryCode._('FR', _CountryMeta('France', 'French', '+33')),
    CountryCode._('GA', _CountryMeta('Gabon', 'Gabonese', '+241')),
    CountryCode._('GD', _CountryMeta('Grenada', 'Grenadian', '+1473')),
    CountryCode._('GE', _CountryMeta('Georgia', 'Georgian', '+995')),
    CountryCode._('GF', _CountryMeta('French Guiana', 'French Guianese', '+594')),
    CountryCode._('GG', _CountryMeta('Guernsey', 'Guernsey', '+44')),
    CountryCode._('GH', _CountryMeta('Ghana', 'Ghanaian', '+233')),
    CountryCode._('GI', _CountryMeta('Gibraltar', 'Gibraltarian', '+350')),
    CountryCode._('GL', _CountryMeta('Greenland', 'Greenlandic', '+299')),
    CountryCode._('GM', _CountryMeta('Gambia', 'Gambian', '+220')),
    CountryCode._('GN', _CountryMeta('Guinea', 'Guinean', '+224')),
    CountryCode._('GP', _CountryMeta('Guadeloupe', 'Guadeloupean', '+590')),
    CountryCode._('GQ', _CountryMeta('Equatorial Guinea', 'Equatorial Guinean', '+240')),
    CountryCode._('GR', _CountryMeta('Greece', 'Greek', '+30')),
    CountryCode._('GS', _CountryMeta('South Georgia and the South Sandwich Islands', 'South Georgia Island', '+500')),
    CountryCode._('GT', _CountryMeta('Guatemala', 'Guatemalan', '+502')),
    CountryCode._('GU', _CountryMeta('Guam', 'Guamanian', '+1671')),
    CountryCode._('GW', _CountryMeta('Guinea-Bissau', 'Bissau-Guinean', '+245')),
    CountryCode._('GY', _CountryMeta('Guyana', 'Guyanese', '+592')),
    CountryCode._('HK', _CountryMeta('Hong Kong', 'Hong Konger', '+852')),
    CountryCode._('HM', _CountryMeta('Heard Island and McDonald Islands', 'Heard Island', '+672')),
    CountryCode._('HN', _CountryMeta('Honduras', 'Honduran', '+504')),
    CountryCode._('HR', _CountryMeta('Croatia', 'Croatian', '+385')),
    CountryCode._('HT', _CountryMeta('Haiti', 'Haitian', '+509')),
    CountryCode._('HU', _CountryMeta('Hungary', 'Hungarian', '+36')),
    CountryCode._('ID', _CountryMeta('Indonesia', 'Indonesian', '+62')),
    CountryCode._('IE', _CountryMeta('Ireland', 'Irish', '+353')),
    CountryCode._('IL', _CountryMeta('Israel', 'Israeli', '+972')),
    CountryCode._('IM', _CountryMeta('Isle of Man', 'Manx', '+44')),
    CountryCode._('IN', _CountryMeta('India', 'Indian', '+91')),
    CountryCode._('IO', _CountryMeta('British Indian Ocean Territory', 'British Indian Ocean Territory', '+246')),
    CountryCode._('IQ', _CountryMeta('Iraq', 'Iraqi', '+964')),
    CountryCode._('IR', _CountryMeta('Iran', 'Iranian', '+98')),
    CountryCode._('IS', _CountryMeta('Iceland', 'Icelandic', '+354')),
    CountryCode._('IT', _CountryMeta('Italy', 'Italian', '+39')),
    CountryCode._('JE', _CountryMeta('Jersey', 'Jersey', '+44')),
    CountryCode._('JM', _CountryMeta('Jamaica', 'Jamaican', '+1876')),
    CountryCode._('JP', _CountryMeta('Japan', 'Japanese', '+81')),
    CountryCode._('KE', _CountryMeta('Kenya', 'Kenyan', '+254')),
    CountryCode._('KG', _CountryMeta('Kyrgyzstan', 'Kyrgyzstani', '+996')),
    CountryCode._('KH', _CountryMeta('Cambodia', 'Cambodian', '+855')),
    CountryCode._('KI', _CountryMeta('Kiribati', 'I-Kiribati', '+686')),
    CountryCode._('KM', _CountryMeta('Comoros', 'Comoran', '+269')),
    CountryCode._('KN', _CountryMeta('Saint Kitts and Nevis', 'Kittitian and Nevisian', '+1869')),
    CountryCode._('KP', _CountryMeta("Korea, Democratic People's Republic of", 'North Korean', '+850')),
    CountryCode._('KR', _CountryMeta('Korea, Republic of', 'South Korean', '+82')),
    CountryCode._('KY', _CountryMeta('Cayman Islands', 'Caymanian', '+1345')),
    CountryCode._('KZ', _CountryMeta('Kazakhstan', 'Kazakhstani', '+7')),
    CountryCode._('LA', _CountryMeta("Lao People's Democratic Republic", 'Laotian', '+856')),
    CountryCode._('LC', _CountryMeta('Saint Lucia', 'Saint Lucian', '+1758')),
    CountryCode._('LI', _CountryMeta('Liechtenstein', 'Liechtensteiner', '+423')),
    CountryCode._('LK', _CountryMeta('Sri Lanka', 'Sri Lankan', '+94')),
    CountryCode._('LR', _CountryMeta('Liberia', 'Liberian', '+231')),
    CountryCode._('LS', _CountryMeta('Lesotho', 'Basotho', '+266')),
    CountryCode._('LT', _CountryMeta('Lithuania', 'Lithuanian', '+370')),
    CountryCode._('LU', _CountryMeta('Luxembourg', 'Luxembourgish', '+352')),
    CountryCode._('LV', _CountryMeta('Latvia', 'Latvian', '+371')),
    CountryCode._('LY', _CountryMeta('Libya', 'Libyan', '+218')),
    CountryCode._('MC', _CountryMeta('Monaco', 'Monégasque', '+377')),
    CountryCode._('MD', _CountryMeta('Moldova', 'Moldovan', '+373')),
    CountryCode._('ME', _CountryMeta('Montenegro', 'Montenegrin', '+382')),
    CountryCode._('MF', _CountryMeta('Saint Martin (French part)', 'Saint-Martinois', '+590')),
    CountryCode._('MG', _CountryMeta('Madagascar', 'Malagasy', '+261')),
    CountryCode._('MH', _CountryMeta('Marshall Islands', 'Marshallese', '+692')),
    CountryCode._('MK', _CountryMeta('North Macedonia', 'Macedonian', '+389')),
    CountryCode._('ML', _CountryMeta('Mali', 'Malian', '+223')),
    CountryCode._('MM', _CountryMeta('Myanmar', 'Burmese', '+95')),
    CountryCode._('MN', _CountryMeta('Mongolia', 'Mongolian', '+976')),
    CountryCode._('MO', _CountryMeta('Macao', 'Macanese', '+853')),
    CountryCode._('MP', _CountryMeta('Northern Mariana Islands', 'Northern Mariana Islander', '+1670')),
    CountryCode._('MQ', _CountryMeta('Martinique', 'Martinican', '+596')),
    CountryCode._('MR', _CountryMeta('Mauritania', 'Mauritanian', '+222')),
    CountryCode._('MS', _CountryMeta('Montserrat', 'Montserratian', '+1664')),
    CountryCode._('MT', _CountryMeta('Malta', 'Maltese', '+356')),
    CountryCode._('MU', _CountryMeta('Mauritius', 'Mauritian', '+230')),
    CountryCode._('MV', _CountryMeta('Maldives', 'Maldivian', '+960')),
    CountryCode._('MW', _CountryMeta('Malawi', 'Malawian', '+265')),
    CountryCode._('MX', _CountryMeta('Mexico', 'Mexican', '+52')),
    CountryCode._('MY', _CountryMeta('Malaysia', 'Malaysian', '+60')),
    CountryCode._('MZ', _CountryMeta('Mozambique', 'Mozambican', '+258')),
    CountryCode._('NA', _CountryMeta('Namibia', 'Namibian', '+264')),
    CountryCode._('NC', _CountryMeta('New Caledonia', 'New Caledonian', '+687')),
    CountryCode._('NE', _CountryMeta('Niger', 'Nigerien', '+227')),
    CountryCode._('NF', _CountryMeta('Norfolk Island', 'Norfolk Islander', '+672')),
    CountryCode._('NG', _CountryMeta('Nigeria', 'Nigerian', '+234')),
    CountryCode._('NI', _CountryMeta('Nicaragua', 'Nicaraguan', '+505')),
    CountryCode._('NL', _CountryMeta('Netherlands', 'Dutch', '+31')),
    CountryCode._('NO', _CountryMeta('Norway', 'Norwegian', '+47')),
    CountryCode._('NP', _CountryMeta('Nepal', 'Nepali', '+977')),
    CountryCode._('NR', _CountryMeta('Nauru', 'Nauruan', '+674')),
    CountryCode._('NU', _CountryMeta('Niue', 'Niuean', '+683')),
    CountryCode._('NZ', _CountryMeta('New Zealand', 'New Zealander', '+64')),
    CountryCode._('PA', _CountryMeta('Panama', 'Panamanian', '+507')),
    CountryCode._('PE', _CountryMeta('Peru', 'Peruvian', '+51')),
    CountryCode._('PF', _CountryMeta('French Polynesia', 'French Polynesian', '+689')),
    CountryCode._('PG', _CountryMeta('Papua New Guinea', 'Papua New Guinean', '+675')),
    CountryCode._('PH', _CountryMeta('Philippines', 'Filipino', '+63')),
    CountryCode._('PK', _CountryMeta('Pakistan', 'Pakistani', '+92')),
    CountryCode._('PL', _CountryMeta('Poland', 'Polish', '+48')),
    CountryCode._('PM', _CountryMeta('Saint Pierre and Miquelon', 'Saint-Pierrais and Miquelonnais', '+508')),
    CountryCode._('PN', _CountryMeta('Pitcairn', 'Pitcairn Islander', '+64')),
    CountryCode._('PR', _CountryMeta('Puerto Rico', 'Puerto Rican', '+1787')),
    CountryCode._('PS', _CountryMeta('Palestine, State of', 'Palestinian', '+970')),
    CountryCode._('PT', _CountryMeta('Portugal', 'Portuguese', '+351')),
    CountryCode._('PW', _CountryMeta('Palau', 'Palauan', '+680')),
    CountryCode._('PY', _CountryMeta('Paraguay', 'Paraguayan', '+595')),
    CountryCode._('RE', _CountryMeta('Réunion', 'Réunionese', '+262')),
    CountryCode._('RO', _CountryMeta('Romania', 'Romanian', '+40')),
    CountryCode._('RS', _CountryMeta('Serbia', 'Serbian', '+381')),
    CountryCode._('RU', _CountryMeta('Russian Federation', 'Russian', '+7')),
    CountryCode._('RW', _CountryMeta('Rwanda', 'Rwandan', '+250')),
    CountryCode._('SB', _CountryMeta('Solomon Islands', 'Solomon Islander', '+677')),
    CountryCode._('SC', _CountryMeta('Seychelles', 'Seychellois', '+248')),
    CountryCode._('SD', _CountryMeta('Sudan', 'Sudanese', '+249')),
    CountryCode._('SE', _CountryMeta('Sweden', 'Swedish', '+46')),
    CountryCode._('SG', _CountryMeta('Singapore', 'Singaporean', '+65')),
    CountryCode._('SH', _CountryMeta('Saint Helena, Ascension and Tristan da Cunha', 'Saint Helenian', '+290')),
    CountryCode._('SI', _CountryMeta('Slovenia', 'Slovenian', '+386')),
    CountryCode._('SJ', _CountryMeta('Svalbard and Jan Mayen', 'Svalbard and Jan Mayen', '+47')),
    CountryCode._('SK', _CountryMeta('Slovakia', 'Slovak', '+421')),
    CountryCode._('SL', _CountryMeta('Sierra Leone', 'Sierra Leonean', '+232')),
    CountryCode._('SM', _CountryMeta('San Marino', 'Sammarinese', '+378')),
    CountryCode._('SN', _CountryMeta('Senegal', 'Senegalese', '+221')),
    CountryCode._('SO', _CountryMeta('Somalia', 'Somali', '+252')),
    CountryCode._('SR', _CountryMeta('Suriname', 'Surinamese', '+597')),
    CountryCode._('SS', _CountryMeta('South Sudan', 'South Sudanese', '+211')),
    CountryCode._('ST', _CountryMeta('Sao Tome and Principe', 'São Toméan', '+239')),
    CountryCode._('SV', _CountryMeta('El Salvador', 'Salvadoran', '+503')),
    CountryCode._('SX', _CountryMeta('Sint Maarten (Dutch part)', 'Sint Maarten', '+1721')),
    CountryCode._('SY', _CountryMeta('Syrian Arab Republic', 'Syrian', '+963')),
    CountryCode._('SZ', _CountryMeta('Eswatini', 'Swazi', '+268')),
    CountryCode._('TC', _CountryMeta('Turks and Caicos Islands', 'Turks and Caicos Islander', '+1649')),
    CountryCode._('TD', _CountryMeta('Chad', 'Chadian', '+235')),
    CountryCode._('TF', _CountryMeta('French Southern Territories', 'French Southern Territories', '+262')),
    CountryCode._('TG', _CountryMeta('Togo', 'Togolese', '+228')),
    CountryCode._('TH', _CountryMeta('Thailand', 'Thai', '+66')),
    CountryCode._('TJ', _CountryMeta('Tajikistan', 'Tajikistani', '+992')),
    CountryCode._('TK', _CountryMeta('Tokelau', 'Tokelauan', '+690')),
    CountryCode._('TL', _CountryMeta('Timor-Leste', 'Timorese', '+670')),
    CountryCode._('TM', _CountryMeta('Turkmenistan', 'Turkmen', '+993')),
    CountryCode._('TN', _CountryMeta('Tunisia', 'Tunisian', '+216')),
    CountryCode._('TO', _CountryMeta('Tonga', 'Tongan', '+676')),
    CountryCode._('TR', _CountryMeta('Türkiye', 'Turkish', '+90')),
    CountryCode._('TT', _CountryMeta('Trinidad and Tobago', 'Trinidadian and Tobagonian', '+1868')),
    CountryCode._('TV', _CountryMeta('Tuvalu', 'Tuvaluan', '+688')),
    CountryCode._('TW', _CountryMeta('Taiwan', 'Taiwanese', '+886')),
    CountryCode._('TZ', _CountryMeta('Tanzania', 'Tanzanian', '+255')),
    CountryCode._('UA', _CountryMeta('Ukraine', 'Ukrainian', '+380')),
    CountryCode._('UG', _CountryMeta('Uganda', 'Ugandan', '+256')),
    CountryCode._('UM', _CountryMeta('United States Minor Outlying Islands', 'American', '+1')),
    CountryCode._('UY', _CountryMeta('Uruguay', 'Uruguayan', '+598')),
    CountryCode._('UZ', _CountryMeta('Uzbekistan', 'Uzbekistani', '+998')),
    CountryCode._('VA', _CountryMeta('Holy See', 'Vatican', '+379')),
    CountryCode._('VC', _CountryMeta('Saint Vincent and the Grenadines', 'Vincentian', '+1784')),
    CountryCode._('VE', _CountryMeta('Venezuela', 'Venezuelan', '+58')),
    CountryCode._('VG', _CountryMeta('Virgin Islands, British', 'British Virgin Islander', '+1284')),
    CountryCode._('VI', _CountryMeta('Virgin Islands, U.S.', 'U.S. Virgin Islander', '+1340')),
    CountryCode._('VN', _CountryMeta('Viet Nam', 'Vietnamese', '+84')),
    CountryCode._('VU', _CountryMeta('Vanuatu', 'Ni-Vanuatu', '+678')),
    CountryCode._('WF', _CountryMeta('Wallis and Futuna', 'Wallis and Futuna Islander', '+681')),
    CountryCode._('WS', _CountryMeta('Samoa', 'Samoan', '+685')),
    CountryCode._('YE', _CountryMeta('Yemen', 'Yemeni', '+967')),
    CountryCode._('YT', _CountryMeta('Mayotte', 'Mahoran', '+262')),
    CountryCode._('ZA', _CountryMeta('South Africa', 'South African', '+27')),
    CountryCode._('ZM', _CountryMeta('Zambia', 'Zambian', '+260')),
    CountryCode._('ZW', _CountryMeta('Zimbabwe', 'Zimbabwean', '+263')),
  ];

  /// Any citizenship is accepted for nationality selection — aliases [all].
  static const supportedNationalities = all;

  /// Derived string index for the [CountryCode.new] factory, keyed off [all].
  static final Map<String, CountryCode> _byCode = {
    for (final c in all) c.value: c,
  };

  static bool _isAlpha(String s) => s.codeUnits.every((u) => u >= 0x41 && u <= 0x5A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}

class _CountryMeta {
  const _CountryMeta(
    this.nameEn,
    this.demonymEn,
    this.dialCode, {
    this.currency = CurrencyCode.usd,
    this.timezone = 'UTC',
    this.emergency = '',
  });
  final String nameEn;
  final String demonymEn;
  final String dialCode;
  final CurrencyCode currency;
  final String timezone;
  final String emergency;
}
