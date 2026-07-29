import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// A bilingual label carried by directory data (names/addresses come from the
/// care-directory source, not the i69n bundle). Resolve with [pick].
typedef L10nText = ({String en, String ar});

String pick(L10nText t, {required bool ar}) => ar ? t.ar : t.en;

/// Kind of nearby health place. Icon/colour/label are presentation config that
/// mirrors the design's `ENTITY_TYPES`.
enum CareEntityType {
  hospital(LucideIcons.building2, 0xFFD44A3C, 0xFFFAEAE8, (en: 'Hospitals', ar: 'مستشفيات')),
  clinic(LucideIcons.stethoscope, 0xFF1283FF, 0xFFE4F0FF, (en: 'Clinics', ar: 'عيادات')),
  pharmacy(LucideIcons.pill, 0xFF01C4A2, 0xFFE1F8F1, (en: 'Pharmacies', ar: 'صيدليات')),
  lab(LucideIcons.flaskConical, 0xFF724DD0, 0xFFECE6FA, (en: 'Labs', ar: 'مختبرات')),
  scan(LucideIcons.scanLine, 0xFF02BBB5, 0xFFE2F8F6, (en: 'Scan centers', ar: 'مراكز أشعة')),
  store(LucideIcons.shoppingBag, 0xFFD97A20, 0xFFFDF0E0, (en: 'Med. stores', ar: 'أدوات طبية'));

  const CareEntityType(this.icon, this._color, this._bg, this.label);

  final IconData icon;
  final int _color;
  final int _bg;
  final L10nText label;

  Color get color => Color(_color);
  Color get bg => Color(_bg);
}

/// A nearby health place shown on the care map. [x]/[y] are the design map's
/// SVG coordinate space ([mapWidth] x [mapHeight]); the real backend will
/// replace these with lat/lng projected to the rendered map.
class CareEntity {
  const CareEntity({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.name,
    required this.addr,
    required this.hours,
    required this.distance,
    required this.rating,
    required this.phone,
  });

  final String id;
  final CareEntityType type;
  final double x;
  final double y;
  final L10nText name;
  final L10nText addr;
  final String hours;
  final String distance;
  final String rating;
  final String phone;

  /// Design SVG viewport the [x]/[y] pin coordinates are expressed in.
  static const mapWidth = 390.0;
  static const mapHeight = 430.0;
}

/// Reads the nearby care directory.
///
/// TODO(care-directory): this is a placeholder backed by static sample data
/// (design `HEALTH_ENTITIES`). Replace with the Balsm-owned care-directory API
/// (Spec B) — a real query by the user's location + radius. The screen already
/// consumes it as an async list, so only this binding changes.
final careDirectoryProvider = FutureProvider.autoDispose<List<CareEntity>>((ref) async {
  return _sampleCareEntities;
});

const _sampleCareEntities = <CareEntity>[
  CareEntity(
      id: 'e1',
      type: CareEntityType.hospital,
      x: 72,
      y: 210,
      name: (en: 'Qasr Al-Aini Hospital', ar: 'مستشفى قصر العيني'),
      addr: (en: 'Al-Kasr Al-Aini St, Cairo', ar: 'شارع قصر العيني، القاهرة'),
      hours: '24/7',
      distance: '0.8 km',
      rating: '4.2',
      phone: '+20 2 2365 1234'),
  CareEntity(
      id: 'e2',
      type: CareEntityType.clinic,
      x: 210,
      y: 105,
      name: (en: 'Dr. Sara Kamal Clinic', ar: 'عيادة د. سارة كمال'),
      addr: (en: 'Zamalek, Cairo', ar: 'الزمالك، القاهرة'),
      hours: '9am – 5pm',
      distance: '1.2 km',
      rating: '4.9',
      phone: '+20 10 9876 5432'),
  CareEntity(
      id: 'e3',
      type: CareEntityType.pharmacy,
      x: 295,
      y: 230,
      name: (en: 'El-Ezaby Pharmacy', ar: 'صيدلية العزبي'),
      addr: (en: 'Tahrir Sq, Cairo', ar: 'ميدان التحرير، القاهرة'),
      hours: '8am – 12am',
      distance: '0.4 km',
      rating: '4.5',
      phone: '+20 2 2574 3210'),
  CareEntity(
      id: 'e4',
      type: CareEntityType.lab,
      x: 110,
      y: 310,
      name: (en: 'Alfa Scan Lab', ar: 'مختبر ألفا سكان'),
      addr: (en: 'Garden City, Cairo', ar: 'جاردن سيتي، القاهرة'),
      hours: '7am – 9pm',
      distance: '1.5 km',
      rating: '4.7',
      phone: '+20 2 2795 6789'),
  CareEntity(
      id: 'e5',
      type: CareEntityType.scan,
      x: 332,
      y: 148,
      name: (en: 'Cairo Radiology Center', ar: 'مركز القاهرة للأشعة'),
      addr: (en: 'Mohandiseen, Giza', ar: 'المهندسين، الجيزة'),
      hours: '8am – 10pm',
      distance: '2.1 km',
      rating: '4.6',
      phone: '+20 2 3304 5678'),
  CareEntity(
      id: 'e6',
      type: CareEntityType.store,
      x: 265,
      y: 358,
      name: (en: 'Al-Hayat Medical Supplies', ar: 'الحياة للمستلزمات الطبية'),
      addr: (en: 'Dokki, Giza', ar: 'الدقي، الجيزة'),
      hours: '9am – 8pm',
      distance: '1.8 km',
      rating: '4.3',
      phone: '+20 2 3761 2345'),
  CareEntity(
      id: 'e7',
      type: CareEntityType.pharmacy,
      x: 100,
      y: 148,
      name: (en: 'Seif Pharmacy', ar: 'صيدلية سيف'),
      addr: (en: 'Agouza, Giza', ar: 'العجوزة، الجيزة'),
      hours: '24/7',
      distance: '0.9 km',
      rating: '4.4',
      phone: '+20 2 3748 9012'),
  CareEntity(
      id: 'e8',
      type: CareEntityType.clinic,
      x: 342,
      y: 302,
      name: (en: 'Capital Clinic', ar: 'عيادة كابيتال'),
      addr: (en: 'Nasr City, Cairo', ar: 'مدينة نصر، القاهرة'),
      hours: '10am – 6pm',
      distance: '3.2 km',
      rating: '4.1',
      phone: '+20 2 2402 3456'),
  CareEntity(
      id: 'e9',
      type: CareEntityType.hospital,
      x: 180,
      y: 378,
      name: (en: 'Ain Shams Specialized Hospital', ar: 'مستشفى عين شمس التخصصي'),
      addr: (en: 'Ain Shams, Cairo', ar: 'عين شمس، القاهرة'),
      hours: '24/7',
      distance: '4.1 km',
      rating: '4.3',
      phone: '+20 2 2601 7890'),
  CareEntity(
      id: 'e10',
      type: CareEntityType.lab,
      x: 358,
      y: 80,
      name: (en: 'Cairo Lab', ar: 'كايرو لاب'),
      addr: (en: 'Heliopolis, Cairo', ar: 'مصر الجديدة، القاهرة'),
      hours: '7am – 11pm',
      distance: '5.0 km',
      rating: '4.8',
      phone: '+20 2 2690 1234'),
  CareEntity(
      id: 'e11',
      type: CareEntityType.scan,
      x: 52,
      y: 108,
      name: (en: 'Green Crescent Scan Center', ar: 'مركز الهلال الأخضر للأشعة'),
      addr: (en: 'Mohandeseen, Giza', ar: 'المهندسين، الجيزة'),
      hours: '8am – 8pm',
      distance: '2.8 km',
      rating: '4.5',
      phone: '+20 2 3303 1234'),
  CareEntity(
      id: 'e12',
      type: CareEntityType.store,
      x: 158,
      y: 62,
      name: (en: 'MedLine Medical Supplies', ar: 'ميدلاين للمستلزمات الطبية'),
      addr: (en: 'Zamalek, Cairo', ar: 'الزمالك، القاهرة'),
      hours: '9am – 7pm',
      distance: '1.4 km',
      rating: '4.2',
      phone: '+20 2 2736 5678'),
];
