import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the patient sent from the in-app feedback sheet.
///
/// [note] is free text, so it can hold anything a patient types — the sheet
/// asks them not to include health details, and nothing else in the payload
/// identifies them beyond the opaque user id already on every event.
class UserFeedback {
  const UserFeedback({required this.rating, this.topics = const [], this.note});

  /// 1–5.
  final int rating;

  /// Stable topic ids (`general`, `ease`, …), never display labels.
  final List<String> topics;

  final String? note;
}

/// Where in-app feedback goes. Like [AnalyticsLogger], a facade: the sheet
/// never imports a vendor SDK, and the composition root picks the backend.
abstract class FeedbackReporter {
  /// True when the feedback was accepted for delivery (it may still be queued
  /// offline by the backend).
  Future<bool> send(UserFeedback feedback);
}

/// Accepts and drops everything — the default binding and the test double.
class NoopFeedbackReporter implements FeedbackReporter {
  const NoopFeedbackReporter();

  @override
  Future<bool> send(UserFeedback feedback) async => false;
}

final feedbackReporterProvider = Provider<FeedbackReporter>((_) => const NoopFeedbackReporter());
