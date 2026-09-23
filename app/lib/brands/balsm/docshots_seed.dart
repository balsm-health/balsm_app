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

  // Each collection guards itself, so a re-run tops up whatever is missing
  // instead of skipping everything because one of them is already there.
  await _seedCareTeam(container, userId);

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
  if ((await dao.listProviders(profile.id)).isNotEmpty) return;

  final add = container.read(addCareProviderUseCaseProvider);
  final team = <({CareProviderType type, String name, String specialty, String phone, String clinic})>[
    (
      type: CareProviderType.doctor,
      name: DocshotsPersona.doctorCardiologyEn,
      specialty: 'Cardiology',
      phone: '+20 100 555 0180',
      clinic: 'Balsm Medical Centre, Maadi',
    ),
    (
      type: CareProviderType.doctor,
      name: DocshotsPersona.doctorEndocrineEn,
      specialty: 'Endocrinology',
      phone: '+20 100 555 0194',
      clinic: 'Nile Clinic, Zamalek',
    ),
    (
      type: CareProviderType.pharmacy,
      name: 'El Ezaby Pharmacy',
      specialty: 'Delivery, blood pressure checks',
      phone: '19600',
      clinic: 'Maadi branch',
    ),
    (
      type: CareProviderType.lab,
      name: 'Alfa Laboratories',
      specialty: 'Blood work, HbA1c',
      phone: '19014',
      clinic: 'Degla branch',
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
    );
  }
  debugPrint('[docshots] seeded ${team.length} care providers');
}
