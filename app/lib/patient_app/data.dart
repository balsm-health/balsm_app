import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'tokens.dart';

/// Bilingual string. `s.of('ar')` picks the locale, falling back to en.
typedef L = Map<String, String>;

extension LocalizedMap on L {
  String of(String lang) => this[lang] ?? this['en'] ?? '';
}

// ── Sample patient ───────────────────────────────────────────
const L kPatientName = {'en': 'Layla Hassan', 'ar': 'ليلى حسن'};

class FamilyAccount {
  const FamilyAccount(this.id, this.name, this.initials, this.color,
      this.relation, this.age, this.since, this.conditions);
  final String id;
  final L name;
  final String initials;
  final Color color;
  final L relation;
  final int age;
  final L since;
  final List<L> conditions;
}

const List<FamilyAccount> kFamilyAccounts = [
  FamilyAccount('layla', {'en': 'Layla Hassan', 'ar': 'ليلى حسن'}, 'LH',
      T.petalAqua, {'en': 'You', 'ar': 'أنتِ'}, 58,
      {'en': 'Mar 2025', 'ar': 'مارس 2025'}, [
    {'en': 'Type 2 diabetes', 'ar': 'السكري من النوع الثاني'},
    {'en': 'Hypertension', 'ar': 'ارتفاع ضغط الدم'},
  ]),
  FamilyAccount('karim', {'en': 'Karim Hassan', 'ar': 'كريم حسن'}, 'KH',
      T.petalBlue, {'en': 'Husband', 'ar': 'الزوج'}, 63,
      {'en': 'Mar 2025', 'ar': 'مارس 2025'}, [
    {'en': 'Hypertension', 'ar': 'ارتفاع ضغط الدم'},
  ]),
  FamilyAccount('nadia', {'en': 'Nadia Hassan', 'ar': 'ناديا حسن'}, 'NH',
      T.petalViolet, {'en': 'Daughter', 'ar': 'الابنة'}, 28,
      {'en': 'Apr 2025', 'ar': 'أبريل 2025'}, []),
];

// ── Medications (chronic regimen) ────────────────────────────
class Med {
  const Med(this.id, this.name, this.dose, this.when, this.tone, this.icon);
  final String id;
  final L name;
  final L dose;
  final String when; // morning | evening
  final String tone; // info | violet | success
  final IconData icon;
}

const List<Med> kMeds = [
  Med('metformin', {'en': 'Metformin', 'ar': 'ميتفورمين'},
      {'en': '500 mg · with breakfast', 'ar': '500 ملجم · مع الإفطار'},
      'morning', 'info', LucideIcons.pill),
  Med('amlodipine', {'en': 'Amlodipine', 'ar': 'أملوديبين'},
      {'en': '5 mg · once daily', 'ar': '5 ملجم · مرة يومياً'},
      'morning', 'violet', LucideIcons.heartPulse),
  Med('atorvastatin', {'en': 'Atorvastatin', 'ar': 'أتورفاستاتين'},
      {'en': '20 mg · after dinner', 'ar': '20 ملجم · بعد العشاء'},
      'evening', 'success', LucideIcons.pill),
];

/// (bg, fg) wash + icon color for a med tone.
({Color bg, Color fg}) medTone(String tone) => switch (tone) {
      'violet' => (bg: T.petalViolet50, fg: T.petalViolet),
      'success' => (bg: T.petalMint50, fg: T.petalMint600),
      _ => (bg: T.petalBlue50, fg: T.petalBlue),
    };

// ── Mood colors (rough → great) ──────────────────────────────
const List<Color> kMoodColors = [
  Color(0xFFD44A3C),
  Color(0xFFD97A20),
  Color(0xFFE5B428),
  Color(0xFF55D77F),
  Color(0xFF01C4A2),
];

// ── History (most recent first) ──────────────────────────────
class HistoryDay {
  const HistoryDay(this.d, this.m, this.bp, this.glu, this.mood, this.pain, this.sym);
  final int d;
  final L m;
  final String bp;
  final int glu;
  final int mood;
  final int pain;
  final int sym;
}

const List<HistoryDay> kHistory = [
  HistoryDay(28, {'en': 'MAY', 'ar': 'مايو'}, '128/82', 142, 4, 1, 0),
  HistoryDay(27, {'en': 'MAY', 'ar': 'مايو'}, '134/86', 156, 3, 3, 1),
  HistoryDay(26, {'en': 'MAY', 'ar': 'مايو'}, '131/84', 138, 4, 0, 0),
  HistoryDay(25, {'en': 'MAY', 'ar': 'مايو'}, '126/80', 129, 5, 0, 0),
  HistoryDay(24, {'en': 'MAY', 'ar': 'مايو'}, '139/88', 167, 2, 4, 2),
  HistoryDay(23, {'en': 'MAY', 'ar': 'مايو'}, '130/83', 145, 3, 2, 0),
];

// ── Trend series ─────────────────────────────────────────────
const List<double> kTrendBpSys = [126, 139, 130, 134, 131, 128, 127];
const List<double> kTrendBpDia = [80, 88, 83, 86, 84, 82, 81];
const List<double> kTrendGlu = [129, 167, 145, 156, 138, 142, 134];

// ── Doctors ──────────────────────────────────────────────────
class Doctor {
  const Doctor(this.id, this.name, this.specialty, this.initials, this.color,
      this.rating, this.experience);
  final String id;
  final L name;
  final L specialty;
  final String initials;
  final Color color;
  final String rating;
  final L experience;
}

const List<Doctor> kDoctors = [
  Doctor('sara', {'en': 'Dr. Sara Kamal', 'ar': 'د. سارة كمال'},
      {'en': 'Internal Medicine', 'ar': 'الباطنة'}, 'SK', T.petalAqua, '4.9',
      {'en': '12 yrs', 'ar': '١٢ سنة'}),
  Doctor('ahmed', {'en': 'Dr. Ahmed Nour', 'ar': 'د. أحمد نور'},
      {'en': 'Cardiology', 'ar': 'أمراض القلب'}, 'AN', T.petalBlue, '4.8',
      {'en': '9 yrs', 'ar': '٩ سنوات'}),
  Doctor('mona', {'en': 'Dr. Mona Saad', 'ar': 'د. منى سعد'},
      {'en': 'Endocrinology', 'ar': 'الغدد الصماء'}, 'MS', T.petalEmerald, '4.9',
      {'en': '15 yrs', 'ar': '١٥ سنة'}),
];

Doctor? doctorById(String id) =>
    kDoctors.where((d) => d.id == id).cast<Doctor?>().firstWhere((_) => true, orElse: () => null);

// ── Appointments ─────────────────────────────────────────────
class Appointment {
  const Appointment(this.id, this.doctorId, this.type, this.date, this.time,
      this.location, this.status, this.ref);
  final String id;
  final String doctorId;
  final String type; // follow-up | check-up
  final L date;
  final String time;
  final L location;
  final String status; // upcoming | past
  final String ref;
}

const List<Appointment> kAppointments = [
  Appointment('a1', 'sara', 'follow-up', {'en': 'Sun, 8 Jun', 'ar': 'الأحد، 8 يونيو'},
      '10:30', {'en': 'Cairo Medical Center · Rm 204', 'ar': 'المركز الطبي القاهرة · غرفة 204'}, 'upcoming', 'BL-24819'),
  Appointment('a2', 'ahmed', 'check-up', {'en': 'Mon, 26 May', 'ar': 'الإثنين، 26 مايو'},
      '09:00', {'en': 'Heart Care Clinic', 'ar': 'عيادة القلب'}, 'past', 'BL-24102'),
  Appointment('a3', 'sara', 'follow-up', {'en': 'Wed, 12 Mar', 'ar': 'الأربعاء، 12 مارس'},
      '11:00', {'en': 'Cairo Medical Center · Rm 204', 'ar': 'المركز الطبي القاهرة · غرفة 204'}, 'past', 'BL-23658'),
];

// ── Prescriptions ────────────────────────────────────────────
class RxMed {
  const RxMed(this.name, this.dose);
  final L name;
  final L dose;
}

class Prescription {
  const Prescription(this.id, this.doctorId, this.date, this.validUntil,
      this.status, this.ref, this.meds);
  final String id;
  final String doctorId;
  final L date;
  final L validUntil;
  final String status; // active | expired
  final String ref;
  final List<RxMed> meds;
}

const List<Prescription> kPrescriptions = [
  Prescription('rx1', 'sara', {'en': '26 May 2025', 'ar': '26 مايو 2025'},
      {'en': '26 Aug 2025', 'ar': '26 أغسطس 2025'}, 'active', 'RX-20250526-001', [
    RxMed({'en': 'Metformin', 'ar': 'ميتفورمين'}, {'en': '500 mg · twice daily', 'ar': '500 ملجم · مرتين يومياً'}),
    RxMed({'en': 'Amlodipine', 'ar': 'أملوديبين'}, {'en': '5 mg · once daily', 'ar': '5 ملجم · مرة يومياً'}),
    RxMed({'en': 'Atorvastatin', 'ar': 'أتورفاستاتين'}, {'en': '20 mg · at night', 'ar': '20 ملجم · ليلاً'}),
  ]),
  Prescription('rx2', 'ahmed', {'en': '26 May 2025', 'ar': '26 مايو 2025'},
      {'en': '26 Jun 2025', 'ar': '26 يونيو 2025'}, 'active', 'RX-20250526-002', [
    RxMed({'en': 'Aspirin', 'ar': 'أسبرين'}, {'en': '100 mg · once daily', 'ar': '100 ملجم · مرة يومياً'}),
    RxMed({'en': 'Bisoprolol', 'ar': 'بيسوبرولول'}, {'en': '5 mg · once daily', 'ar': '5 ملجم · مرة يومياً'}),
  ]),
  Prescription('rx3', 'sara', {'en': '12 Mar 2025', 'ar': '12 مارس 2025'},
      {'en': '12 Jun 2025', 'ar': '12 يونيو 2025'}, 'expired', 'RX-20250312-001', [
    RxMed({'en': 'Metformin', 'ar': 'ميتفورمين'}, {'en': '500 mg · once daily', 'ar': '500 ملجم · مرة يومياً'}),
  ]),
];

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

// ── Health records ───────────────────────────────────────────
class RecordType {
  const RecordType(this.icon, this.color, this.bg, this.labelKey, this.oneKey);
  final IconData icon;
  final Color color;
  final Color bg;
  final String labelKey;
  final String oneKey;
}

const Map<String, RecordType> kRecordTypes = {
  'lab': RecordType(LucideIcons.flaskConical, T.petalMint600, T.petalMint50, 'rec_lab', 'rec_lab_one'),
  'scan': RecordType(LucideIcons.scanLine, T.petalBlue, T.petalBlue50, 'rec_scan', 'rec_scan_one'),
  'report': RecordType(LucideIcons.fileText, T.petalViolet, T.petalViolet50, 'rec_report', 'rec_report_one'),
};

class HealthRecord {
  const HealthRecord(this.id, this.type, this.storage, this.title, this.date,
      this.sourceId, this.fileType, this.pages, this.result, {this.tags = const []});
  final String id;
  final String type;
  final String storage; // local | icloud | gdrive
  final L title;
  final L date;
  final String sourceId;
  final String fileType;
  final int pages;
  final L? result;
  final List<L> tags;

  HealthRecord copyWith({String? storage}) => HealthRecord(
      id, type, storage ?? this.storage, title, date, sourceId, fileType, pages, result, tags: tags);
}

const L _tagDiabetes = {'en': 'Diabetes', 'ar': 'السكري'};
const L _tagFollowUp = {'en': 'Follow-up', 'ar': 'متابعة'};
const L _tagCholesterol = {'en': 'Cholesterol', 'ar': 'الكوليسترول'};
const L _tagHeart = {'en': 'Heart', 'ar': 'القلب'};
const L _tagChest = {'en': 'Chest', 'ar': 'الصدر'};

const List<HealthRecord> kHealthRecords = [
  HealthRecord('r1', 'lab', 'icloud', {'en': 'HbA1c — glycated hemoglobin', 'ar': 'تحليل السكر التراكمي'},
      {'en': '26 May 2025', 'ar': '26 مايو 2025'}, 'sara', 'PDF', 2,
      {'en': '6.8% · slightly above target', 'ar': '6.8% · أعلى قليلاً من الهدف'},
      tags: [_tagDiabetes, _tagFollowUp]),
  HealthRecord('r2', 'lab', 'icloud', {'en': 'Lipid panel', 'ar': 'تحليل الدهون'},
      {'en': '26 May 2025', 'ar': '26 مايو 2025'}, 'sara', 'PDF', 1,
      {'en': 'LDL 128 · within range', 'ar': 'الكوليسترول الضار 128 · ضمن المعدل'},
      tags: [_tagCholesterol, _tagHeart]),
  HealthRecord('r3', 'scan', 'gdrive', {'en': 'Chest X-ray', 'ar': 'أشعة الصدر'},
      {'en': '12 Mar 2025', 'ar': '12 مارس 2025'}, 'ahmed', 'Image', 1,
      {'en': 'No acute findings', 'ar': 'لا توجد ملاحظات حادة'},
      tags: [_tagChest]),
  HealthRecord('r4', 'report', 'gdrive', {'en': 'Cardiology consultation', 'ar': 'استشارة القلب'},
      {'en': '12 Mar 2025', 'ar': '12 مارس 2025'}, 'ahmed', 'PDF', 3, null,
      tags: [_tagHeart, _tagFollowUp]),
  HealthRecord('r5', 'lab', 'local', {'en': 'Fasting blood glucose', 'ar': 'سكر الدم الصائم'},
      {'en': '02 Feb 2025', 'ar': '2 فبراير 2025'}, 'self', 'Image', 1,
      {'en': '132 mg/dL', 'ar': '132 مجم/دل'},
      tags: [_tagDiabetes]),
];

// ── Nearby care entities ─────────────────────────────────────
class EntityType {
  const EntityType(this.icon, this.color, this.bg, this.border, this.label);
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;
  final L label;
}

const Map<String, EntityType> kEntityTypes = {
  'hospital': EntityType(LucideIcons.building2, Color(0xFFD44A3C), Color(0xFFFAEAE8), Color(0xFFF0C4C0), {'en': 'Hospitals', 'ar': 'مستشفيات'}),
  'clinic': EntityType(LucideIcons.stethoscope, T.petalBlue, T.petalBlue50, Color(0xFFB8D4FF), {'en': 'Clinics', 'ar': 'عيادات'}),
  'pharmacy': EntityType(LucideIcons.pill, T.petalEmerald, T.petalEmerald50, Color(0xFFA8ECD8), {'en': 'Pharmacies', 'ar': 'صيدليات'}),
  'lab': EntityType(LucideIcons.flaskConical, T.petalViolet, T.petalViolet50, Color(0xFFC8B8F0), {'en': 'Labs', 'ar': 'مختبرات'}),
  'scan': EntityType(LucideIcons.scanLine, T.petalAqua, T.petalAqua50, Color(0xFFA0E8E4), {'en': 'Scan centers', 'ar': 'مراكز أشعة'}),
  'store': EntityType(LucideIcons.shoppingBag, Color(0xFFD97A20), Color(0xFFFDF0E0), Color(0xFFF0CCAA), {'en': 'Med. stores', 'ar': 'أدوات طبية'}),
};

class HealthEntity {
  const HealthEntity(this.id, this.type, this.lat, this.lng, this.name, this.addr,
      this.hours, this.distance, this.rating, this.phone);
  final String id;
  final String type;
  final double lat;
  final double lng;
  final L name;
  final L addr;
  final String hours;
  final String distance;
  final String rating;
  final String phone;
}

/// Approximate Greater Cairo centre — fallback when GPS is unavailable.
const double kCairoLat = 30.0444;
const double kCairoLng = 31.2357;

const List<HealthEntity> kHealthEntities = [
  HealthEntity('e1', 'hospital', 30.0286, 31.2294, {'en': 'Qasr Al-Aini Hospital', 'ar': 'مستشفى قصر العيني'}, {'en': 'Al-Kasr Al-Aini St, Cairo', 'ar': 'شارع قصر العيني، القاهرة'}, '24/7', '0.8 km', '4.2', '+20 2 2365 1234'),
  HealthEntity('e2', 'clinic', 30.0614, 31.2197, {'en': 'Dr. Sara Kamal Clinic', 'ar': 'عيادة د. سارة كمال'}, {'en': 'Zamalek, Cairo', 'ar': 'الزمالك، القاهرة'}, '9am – 5pm', '1.2 km', '4.9', '+20 10 9876 5432'),
  HealthEntity('e3', 'pharmacy', 30.0444, 31.2357, {'en': 'El-Ezaby Pharmacy', 'ar': 'صيدلية العزبي'}, {'en': 'Tahrir Sq, Cairo', 'ar': 'ميدان التحرير، القاهرة'}, '8am – 12am', '0.4 km', '4.5', '+20 2 2574 3210'),
  HealthEntity('e4', 'lab', 30.0360, 31.2310, {'en': 'Alfa Scan Lab', 'ar': 'مختبر ألفا سكان'}, {'en': 'Garden City, Cairo', 'ar': 'جاردن سيتي، القاهرة'}, '7am – 9pm', '1.5 km', '4.7', '+20 2 2795 6789'),
  HealthEntity('e5', 'scan', 30.0560, 31.2000, {'en': 'Cairo Radiology Center', 'ar': 'مركز القاهرة للأشعة'}, {'en': 'Mohandiseen, Giza', 'ar': 'المهندسين، الجيزة'}, '8am – 10pm', '2.1 km', '4.6', '+20 2 3304 5678'),
  HealthEntity('e6', 'store', 30.0380, 31.2120, {'en': 'Al-Hayat Medical Supplies', 'ar': 'الحياة للمستلزمات الطبية'}, {'en': 'Dokki, Giza', 'ar': 'الدقي، الجيزة'}, '9am – 8pm', '1.8 km', '4.3', '+20 2 3761 2345'),
  HealthEntity('e7', 'pharmacy', 30.0560, 31.2080, {'en': 'Seif Pharmacy', 'ar': 'صيدلية سيف'}, {'en': 'Agouza, Giza', 'ar': 'العجوزة، الجيزة'}, '24/7', '0.9 km', '4.4', '+20 2 3748 9012'),
  HealthEntity('e8', 'clinic', 30.0540, 31.3400, {'en': 'Capital Clinic', 'ar': 'عيادة كابيتال'}, {'en': 'Nasr City, Cairo', 'ar': 'مدينة نصر، القاهرة'}, '10am – 6pm', '3.2 km', '4.1', '+20 2 2402 3456'),
  HealthEntity('e9', 'hospital', 30.0900, 31.3240, {'en': 'Cleopatra Hospital', 'ar': 'مستشفى كليوباترا'}, {'en': 'Heliopolis, Cairo', 'ar': 'مصر الجديدة، القاهرة'}, '24/7', '4.6 km', '4.5', '+20 2 2414 7890'),
  HealthEntity('e10', 'pharmacy', 29.9602, 31.2569, {'en': 'Roshdy Pharmacy', 'ar': 'صيدلية رشدي'}, {'en': 'Maadi, Cairo', 'ar': 'المعادي، القاهرة'}, '24/7', '5.4 km', '4.6', '+20 2 2358 1122'),
  HealthEntity('e11', 'lab', 30.0875, 31.3280, {'en': 'Mokhtabar Labs', 'ar': 'المختبر'}, {'en': 'Heliopolis, Cairo', 'ar': 'مصر الجديدة، القاهرة'}, '7am – 10pm', '4.8 km', '4.8', '+20 2 2690 3344'),
  HealthEntity('e12', 'clinic', 29.9650, 31.2700, {'en': 'Maadi Family Clinic', 'ar': 'عيادة المعادي للأسرة'}, {'en': 'Maadi, Cairo', 'ar': 'المعادي، القاهرة'}, '9am – 9pm', '5.7 km', '4.4', '+20 2 2380 5566'),
];
