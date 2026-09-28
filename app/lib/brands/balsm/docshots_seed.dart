/// Synthetic on-device data for documentation and store screenshots.
///
/// ─────────────────────────────────────────────────────────────────────────
/// FABRICATED CLINICAL DATA. Read this before copying anything here.
///
/// The repo rule is that PHI is never invented (see CLAUDE.md and the comment
/// on `E2eFixture`), because plausible-looking fake health data has a habit of
/// escaping into fixtures, tests and eventually screenshots that get read as
/// real. This file is the one sanctioned exception, added deliberately so the
/// store listing can show populated screens instead of empty states.
///
/// It is contained on purpose:
///   * referenced ONLY from `main_docshots.dart`, so it is tree-shaken out of
///     `main_balsm.dart` — it cannot reach a shipped build;
///   * writes through the module PORTS, so domain invariants still apply and
///     nothing here needs knowledge of drift;
///   * writes to the on-device database only. Nothing is uploaded.
///
/// Do not import this from app code, tests, or any other entrypoint.
/// ─────────────────────────────────────────────────────────────────────────
library;

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medications/medications.dart';
import 'package:profile/profile.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';

import '../../balsm_app/app_state.dart';
import 'docshots_persona.dart';

/// Seeds the synthetic record. Idempotent: re-running leaves one copy of each
/// medication, so a repeated `flutter run` does not stack duplicates.
Future<void> seedDocshotsData(ProviderContainer container) async {
  final profileId = await container.read(activeProfileProvider.future);
  if (profileId == null) {
    debugPrint('[docshots] no active profile — skipping seed');
    return;
  }

  final userId = container.read(currentUserIdProvider);
  if (userId == null) {
    debugPrint('[docshots] no user id — skipping seed');
    return;
  }

  // Arabic is grammatically gendered, and the i69n `_select` messages read
  // `state.gender` — which nothing sets at boot, so it sits on `Gender.other`
  // (masculine) until the patient opens Personal Details. The persona is a
  // woman, so an Arabic capture greeting her in the masculine is simply wrong.
  container.read(patientAppStateProvider).setGender(Gender.female);

  // Each collection guards itself, so a re-run tops up whatever is missing
  // instead of skipping everything because one of them is already there.
  await _seedCareTeam(container, userId);
  await _seedHealthProfile(container, userId);
  await _seedRecords(container, userId);
  await _seedCheckIns(container, profileId);

  final meds = container.read(medicationsDataSourceProvider);
  if ((await meds.findAll()).isNotEmpty) {
    debugPrint('[docshots] medications already seeded — skipping');
    return;
  }

  // Midnight today, so scheduled times land on predictable clock positions
  // regardless of when the capture runs.
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);

  final regimen = <(String name, String dose, ScheduleType type, ScheduleConfig config)>[
    ('Metformin', '500 mg', ScheduleType.daily, const ScheduleConfig(times: ['08:00', '20:00'])),
    ('Amlodipine', '5 mg', ScheduleType.daily, const ScheduleConfig(times: ['09:00'])),
    ('Vitamin D3', '1000 IU', ScheduleType.weekly, const ScheduleConfig(times: ['10:00'], days: [1])),
  ];

  for (final (name, dose, type, config) in regimen) {
    final id = MedicationId.uuid();
    await meds.put(
      id,
      Medication(
        id: id,
        userId: userId,
        name: name,
        doseAmount: dose,
        scheduleType: type,
        scheduleConfig: config,
        startDate: midnight.subtract(const Duration(days: 90)),
      ),
      scope: profileId,
    );

    // Seven days of history so the adherence ring reads as a real number
    // rather than 0%. One deliberate miss keeps it honest-looking (~93%)
    // instead of a suspicious flat 100%.
    if (type != ScheduleType.daily) continue;
    for (var day = 7; day >= 1; day--) {
      for (final time in config.times) {
        final parts = time.split(':');
        final scheduledAt = midnight
            .subtract(Duration(days: day))
            .add(Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1])));
        final missed = day == 3 && time == '20:00' && name == 'Metformin';
        await meds.insertDoseEvent(DoseEvent(
          id: DoseEventId.uuid(),
          medicationId: id,
          scheduledAt: scheduledAt,
          recordedAt: scheduledAt.add(const Duration(minutes: 4)),
          outcome: missed ? DoseOutcome.missed : DoseOutcome.taken,
        ));
      }
    }
  }

  debugPrint('[docshots] seeded ${regimen.length} medications for ${DocshotsPersona.nameEn}');
}

/// A care team with more than one provider type, so the capture shows the type
/// chips and the badge rather than a single unfiltered list.
///
/// Names are the persona's English ones even for the Arabic capture, matching
/// how the medication regimen above is seeded — the layout is what is being
/// photographed, and a provider's name is not translated in real use either.
Future<void> _seedCareTeam(ProviderContainer container, UserId userId) async {
  final dao = container.read(profileDataSourceProvider);
  final profile = await dao.getProfile(userId);
  if (profile == null) return;
  if ((await container.read(careProvidersDataSourceProvider).findAll(scope: profile.id)).isNotEmpty) return;

  final add = container.read(addCareProviderUseCaseProvider);
  final team = <({
    CareProviderType type,
    String name,
    String specialty,
    String phone,
    String clinic,
    String? mapUrl,
  })>[
    (
      type: CareProviderType.doctor,
      name: DocshotsPersona.doctorCardiologyEn,
      specialty: 'Cardiology',
      phone: '+20 100 555 0180',
      clinic: 'Balsm Medical Centre, Maadi',
      // One provider carries a map link so the card's Directions action is
      // visible in captures. A public maps search URL, not a real address.
      mapUrl: 'https://maps.google.com/?q=Maadi+Cairo',
    ),
    (
      type: CareProviderType.doctor,
      name: DocshotsPersona.doctorEndocrineEn,
      specialty: 'Endocrinology',
      phone: '+20 100 555 0194',
      clinic: 'Nile Clinic, Zamalek',
      mapUrl: null,
    ),
    (
      type: CareProviderType.pharmacy,
      name: 'El Ezaby Pharmacy',
      specialty: 'Delivery, blood pressure checks',
      phone: '19600',
      clinic: 'Maadi branch',
      mapUrl: null,
    ),
    (
      type: CareProviderType.lab,
      name: 'Alfa Laboratories',
      specialty: 'Blood work, HbA1c',
      phone: '19014',
      clinic: 'Degla branch',
      mapUrl: null,
    ),
  ];

  for (final p in team) {
    await add.execute(
      userId: userId,
      type: p.type,
      name: p.name,
      specialty: p.specialty,
      phone: p.phone,
      clinic: p.clinic,
      mapUrl: p.mapUrl,
    );
  }
  debugPrint('[docshots] seeded ${team.length} care providers');
}

/// Blood type, measurements, allergies, conditions and a next of kin — the
/// fields the emergency card and the medical profile screens read. Without
/// them those screens capture as a column of "Not set" rows.
Future<void> _seedHealthProfile(ProviderContainer container, UserId userId) async {
  final dao = container.read(profileDataSourceProvider);
  final profile = await dao.getProfile(userId);
  if (profile == null) return;

  if (profile.bloodType == null) {
    await container.read(updateHealthProfileUseCaseProvider).execute(
          userId: userId,
          bloodType: BloodType.oPositive,
          weightKg: 63,
          heightCm: 164,
        );
  }

  if (profile.allergies.isEmpty) {
    final add = container.read(addAllergyUseCaseProvider);
    for (final (name, severity) in const [
      ('Penicillin', 'severe'),
      ('Dust mites', 'mild'),
    ]) {
      await add.execute(userId: userId, name: name, severity: severity);
    }
  }

  if (profile.conditions.isEmpty) {
    final add = container.read(addChronicConditionUseCaseProvider);
    for (final name in const ['Type 2 diabetes', 'Hypertension']) {
      await add.execute(userId: userId, name: name);
    }
  }

  if (profile.emergencyContacts.isEmpty) {
    await container.read(addEmergencyContactUseCaseProvider).execute(
          userId: userId,
          name: DocshotsPersona.sonEn,
          phone: '+20 100 555 0112',
          relation: 'Son',
        );
  }

  debugPrint('[docshots] seeded health profile for ${DocshotsPersona.nameEn}');
}

/// A small record vault, so the home shortcut reads "5 documents" and the
/// records screen captures with a list and its type filters rather than the
/// empty state.
///
/// No `filePath`: these rows carry no attachment, because a fabricated scan
/// image is exactly the kind of thing that escapes into places it should not.
/// The list, the type chips and the counts are what a screenshot needs.
Future<void> _seedRecords(ProviderContainer container, UserId userId) async {
  final records = container.read(recordsDataSourceProvider);
  if ((await records.findAll(scope: userId)).isNotEmpty) return;

  final today = DateTime.now();
  final vault = <(RecordType type, String title, String note, int daysAgo)>[
    (RecordType.lab, 'HbA1c panel', '6.8% — down from 7.4%', 12),
    (RecordType.lab, 'Lipid profile', 'LDL 118 mg/dL', 40),
    (RecordType.scan, 'Chest X-ray', 'No acute findings', 96),
    (RecordType.report, 'Cardiology consult', 'Continue current regimen', 21),
    (RecordType.report, 'Annual check-up', 'Routine follow-up in 6 months', 150),
  ];

  for (final (type, title, note, daysAgo) in vault) {
    final id = RecordDocumentId.uuid();
    final takenAt = today.subtract(Duration(days: daysAgo));
    await records.put(
      id,
      RecordDocument(
        id: id,
        userId: userId,
        type: type,
        title: title,
        tags: const [],
        source: RecordSource.self,
        resultNote: note,
        takenAt: takenAt,
        createdAt: takenAt,
      ),
      scope: userId,
    );
  }

  debugPrint('[docshots] seeded ${vault.length} records');
}

/// Fourteen days of self-reported check-ins: mood, pain, symptoms and vitals.
///
/// This is what the trends charts, the body map and the home streak all read.
/// Without it those screens capture as empty axes — the single least
/// convincing thing a health app can show a store reviewer.
///
/// The numbers wander rather than sitting on a flat line, and the series is
/// deliberately unremarkable: blood pressure hovering just above normal and
/// fasting glucose in the 120s-140s mg/dL is consistent with the seeded conditions
/// (type 2 diabetes, hypertension) under a working regimen. Nothing here is a
/// real measurement of anybody.
Future<void> _seedCheckIns(ProviderContainer container, HealthProfileId profileId) async {
  final dao = container.read(checkInsDataSourceProvider);
  if ((await dao.findAll(scope: profileId)).isNotEmpty) return;

  final now = DateTime.now();
  // One entry a day, walked backwards, each in the evening so the timestamps
  // are plausible and ordered.
  final days = <(int mood, int pain, List<SymptomId> symptoms, int sys, int dia, int hr, int glucoseMgDl)>[
    (4, 0, [], 124, 79, 72, 128),
    (4, 1, [SymptomId.fatigue], 128, 82, 76, 133),
    (3, 2, [SymptomId.headache], 133, 85, 79, 142),
    (3, 0, [], 126, 80, 74, 130),
    (5, 0, [], 119, 76, 68, 122),
    (4, 0, [], 122, 78, 71, 124),
    (3, 3, [SymptomId.headache, SymptomId.dizzy], 136, 88, 81, 148),
    (4, 1, [SymptomId.fatigue], 129, 83, 75, 135),
    (4, 0, [], 125, 80, 73, 126),
    (5, 0, [], 118, 75, 69, 121),
    (4, 2, [SymptomId.swelling], 131, 84, 77, 137),
    (3, 1, [SymptomId.fatigue], 127, 81, 74, 131),
    (4, 0, [], 123, 78, 70, 126),
    (5, 0, [], 120, 77, 69, 124),
  ];

  for (var i = 0; i < days.length; i++) {
    final (mood, pain, symptoms, sys, dia, hr, glucoseMgDl) = days[i];
    // From YESTERDAY backwards, never today: a check-in recorded today flips
    // the home hero from "How are you feeling today?" to the completed state,
    // and that hero is the whole point of the first store screenshot.
    final day = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: i + 1))
        .add(const Duration(hours: 20, minutes: 30));
    final id = CheckInId.uuid();
    await dao.put(
      id,
      CheckIn(
        id: id,
        healthProfileId: profileId,
        recordedAt: day,
        mood: Mood(mood),
        painLevel: PainLevel(pain),
        painSites: const {},
        symptoms: symptoms.toSet(),
        vitals: Vitals(
          systolic: sys,
          diastolic: dia,
          heartRate: hr,
          glucoseFasting: glucoseMgDl,
          // A slow ~0.9 kg drift down over the fortnight with a little noise.
          // Alternating +0.2/-0.1 drew a perfect sawtooth, which reads as
          // generated data the moment anyone looks at the chart.
          weightKg: double.parse(
            (64.0 - (days.length - 1 - i) * 0.07 + ((i % 3) - 1) * 0.06).toStringAsFixed(1),
          ),
        ),
      ),
      scope: profileId,
    );
  }

  debugPrint('[docshots] seeded ${days.length} check-ins');
}
