// SYNTHETIC PHI corpus for PHI-leak fuzz testing.
//
// IMPORTANT: Every value in this file is fabricated for test purposes only.
// No real patient data, no real names, no real national IDs, no real phone
// numbers. These payloads exist solely to verify that PHI never escapes via
// Sentry crash reports or Dio request bodies (FR-018, FR-047/FR-048).
//
// Generators below intentionally include denied PHI field names
// (email, dob, national_id, blood_type, allergy, condition, medication,
// handle, display_name, bio, emergency_contact, name, phone, date_of_birth)
// so the scrubbers can be proven to remove them.

class PhiCorpus {
  /// Returns 50+ synthetic payloads mixing PHI fields with allowed
  /// telemetry fields. Names/phones/IDs span Egypt, Saudi Arabia, and the UAE
  /// in both Arabic and English transliteration.
  static List<Map<String, dynamic>> generate() {
    final payloads = <Map<String, dynamic>>[];

    // --- Egyptian synthetic identities (ar + en) ---
    final egNames = <String>[
      'أحمد محمود السيد',
      'فاطمة عبد الرحمن',
      'محمد علي حسن',
      'منى إبراهيم فؤاد',
      'يوسف خالد عبد الله',
      'Ahmed Mahmoud Elsayed',
      'Fatma Abdelrahman',
      'Mohamed Aly Hassan',
    ];
    final egPhones = <String>[
      '+201001234567',
      '+201112223334',
      '+201234567890',
      '01098765432',
    ];
    // Synthetic Egyptian national ID shape (14 digits) — NOT a real ID.
    final egNationalIds = <String>[
      '29001011234567',
      '30005156789012',
      '28812319876543',
    ];

    // --- Saudi synthetic identities (ar + en) ---
    final saNames = <String>[
      'عبد العزيز بن سعود',
      'نورة الفهد',
      'خالد المطيري',
      'سارة العتيبي',
      'Abdulaziz Al Saud',
      'Noura Alfahad',
      'Khalid Almutairi',
    ];
    final saPhones = <String>[
      '+966500000001',
      '+966551234567',
      '0509876543',
    ];
    // Synthetic Saudi Iqama/national ID shape (10 digits) — NOT real.
    final saNationalIds = <String>[
      '1012345678',
      '2098765432',
      '1055667788',
    ];

    // --- UAE synthetic identities (ar + en) ---
    final aeNames = <String>[
      'راشد بن محمد آل مكتوم',
      'مريم الكعبي',
      'سلطان النعيمي',
      'عائشة الزعابي',
      'Rashid Al Maktoum',
      'Maryam Alkaabi',
      'Sultan Alnuaimi',
    ];
    final aePhones = <String>[
      '+971500000002',
      '+971561234567',
      '0521234567',
    ];
    // Synthetic Emirates ID shape (784-YYYY-NNNNNNN-N) — NOT real.
    final aeNationalIds = <String>[
      '784-1990-1234567-1',
      '784-1985-7654321-2',
      '784-2000-1112223-3',
    ];

    final dobs = <String>[
      '1990-01-01',
      '1985-12-31',
      '2000-06-15',
      '1978-03-22',
      '1995-09-09',
    ];

    final bloodTypes = <String>['A+', 'O-', 'B+', 'AB-', 'O+'];

    final allergiesAr = <String>['حساسية البنسلين', 'حساسية الفول السوداني', 'حساسية اللاكتوز'];
    final allergiesEn = <String>['Penicillin allergy', 'Peanut allergy', 'Lactose intolerance'];

    final conditionsAr = <String>['داء السكري', 'ارتفاع ضغط الدم', 'الربو'];
    final conditionsEn = <String>['Diabetes', 'Hypertension', 'Asthma'];

    final medicationsAr = <String>['ميتفورمين', 'إنسولين', 'فينتولين'];
    final medicationsEn = <String>['Metformin', 'Insulin', 'Ventolin'];

    final handles = <String>['ahmed_eg', 'noura.sa', 'rashid_ae', 'maryam2026'];
    final displayNames = <String>['Ahmed', 'نورة', 'Rashid', 'مريم'];
    final bios = <String>['Diabetic patient since 2010', 'مريض ضغط دم'];

    final allCountrySets = <Map<String, List<String>>>[
      {'names': egNames, 'phones': egPhones, 'ids': egNationalIds},
      {'names': saNames, 'phones': saPhones, 'ids': saNationalIds},
      {'names': aeNames, 'phones': aePhones, 'ids': aeNationalIds},
    ];

    var counter = 0;
    for (final set in allCountrySets) {
      final names = set['names']!;
      final phones = set['phones']!;
      final ids = set['ids']!;
      for (var i = 0; i < names.length; i++) {
        payloads.add(<String, dynamic>{
          // allowed telemetry fields
          'event_id': 'evt-${counter.toString().padLeft(4, '0')}',
          'timestamp': '2026-06-18T10:${i.toString().padLeft(2, '0')}:00Z',
          'level': 'error',
          'status_code': 500,
          'method': 'POST',
          'url': 'https://api.balsm.test/v1/profile',
          // denied PHI fields
          'name': names[i],
          'phone': phones[i % phones.length],
          'national_id': ids[i % ids.length],
          'dob': dobs[i % dobs.length],
          'date_of_birth': dobs[(i + 1) % dobs.length],
          'blood_type': bloodTypes[i % bloodTypes.length],
          'allergy': (i.isEven ? allergiesAr : allergiesEn)[i % 3],
          'condition': (i.isEven ? conditionsAr : conditionsEn)[i % 3],
          'medication': (i.isEven ? medicationsAr : medicationsEn)[i % 3],
          'handle': handles[i % handles.length],
          'display_name': displayNames[i % displayNames.length],
          'bio': bios[i % bios.length],
          'email': 'synthetic${counter}@example.test',
          'emergency_contact': phones[(i + 1) % phones.length],
        });
        counter++;
      }
    }

    // Additional edge payloads to push count >= 50 and cover nested shapes.
    for (var i = 0; i < 30; i++) {
      payloads.add(<String, dynamic>{
        'event_id': 'edge-${i.toString().padLeft(4, '0')}',
        'timestamp': '2026-06-18T12:${i.toString().padLeft(2, '0')}:00Z',
        'environment': 'test',
        'release': 'balsm@0.0.1-test',
        'transaction': '/v1/medications',
        'email': 'patient.$i@synthetic.test',
        'dob': dobs[i % dobs.length],
        'name': '${egNames[i % egNames.length]} #$i',
        'phone': saPhones[i % saPhones.length],
        'national_id': aeNationalIds[i % aeNationalIds.length],
        'blood_type': bloodTypes[i % bloodTypes.length],
        'allergy': allergiesEn[i % allergiesEn.length],
        'condition': conditionsAr[i % conditionsAr.length],
        'medication': medicationsEn[i % medicationsEn.length],
        'handle': handles[i % handles.length],
        'display_name': displayNames[i % displayNames.length],
        'bio': bios[i % bios.length],
        'emergency_contact': egPhones[i % egPhones.length],
      });
    }

    assert(payloads.length >= 50, 'corpus must contain >= 50 payloads');
    return payloads;
  }

  /// Field names that must NEVER appear in outbound telemetry.
  static const Set<String> deniedFields = {
    'email',
    'dob',
    'date_of_birth',
    'name',
    'phone',
    'national_id',
    'blood_type',
    'allergy',
    'condition',
    'medication',
    'handle',
    'display_name',
    'bio',
    'emergency_contact',
  };

  /// Field names that are permitted in outbound telemetry.
  static const Set<String> allowedFields = {
    'event_id',
    'timestamp',
    'platform',
    'level',
    'logger',
    'transaction',
    'environment',
    'release',
    'dist',
    'type',
    'value',
    'stacktrace',
    'module',
    'function',
    'filename',
    'lineno',
    'colno',
    'abs_path',
    'status_code',
    'method',
    'url',
    'reason',
  };
}
