import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

import '../prefs.dart';

/// What the feedback sheet holds: the rating and topics being given, and when
/// feedback was last sent. No PHI — the free-text note stays in its field and
/// is never stored.
@immutable
class FeedbackDraft {
  FeedbackDraft({this.rating = 0, Set<String> topics = const {}, this.lastSentAt}) : topics = Set.unmodifiable(topics);

  /// 1–5; 0 until the patient picks one.
  final int rating;

  /// Selected topic ids. Unmodifiable.
  final Set<String> topics;
  final DateTime? lastSentAt;

  FeedbackDraft withRating(int n) => FeedbackDraft(rating: n, topics: topics, lastSentAt: lastSentAt);

  FeedbackDraft toggleTopic(String id) => FeedbackDraft(
        rating: rating,
        topics: topics.contains(id) ? topics.difference({id}) : {...topics, id},
        lastSentAt: lastSentAt,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedbackDraft &&
      other.rating == rating &&
      setEquals(other.topics, topics) &&
      other.lastSentAt == lastSentAt;

  @override
  int get hashCode => Object.hash(rating, Object.hashAllUnordered(topics), lastSentAt);
}

/// One feedback sheet's draft, keyed by the prefs it reads the last rating
/// from (null in tests or before storage is up: nothing is loaded or kept).
class FeedbackDraftNotifier extends AsyncNotifier<FeedbackDraft> {
  FeedbackDraftNotifier(this.prefs);
  final PatientAppPrefs? prefs;

  @override
  Future<FeedbackDraft> build() async {
    final prefs = this.prefs;
    if (prefs == null) return FeedbackDraft();
    final rating = await prefs.feedbackRating();
    final at = await prefs.feedbackSentAt();
    return FeedbackDraft(rating: rating ?? 0, lastSentAt: at);
  }

  void _edit(FeedbackDraft Function(FeedbackDraft) change) {
    final draft = state.value;
    if (draft != null) state = AsyncData(change(draft));
  }

  void rate(int n) => _edit((d) => d.withRating(n));

  void toggleTopic(String id) => _edit((d) => d.toggleTopic(id));

  /// Sends the rating, the topics (in [topicOrder]) and [note], then keeps the
  /// rating and the send date. False when nothing was sent.
  Future<bool> submit({required String note, required List<String> topicOrder}) async {
    final draft = state.value;
    if (draft == null || draft.rating == 0) return false;
    final ok = await ref.read(feedbackReporterProvider).send(
          UserFeedback(
            rating: draft.rating,
            topics: topicOrder.where(draft.topics.contains).toList(),
            note: note,
          ),
        );
    if (!ok) return false;
    await prefs?.setFeedbackRating(draft.rating);
    await prefs?.setFeedbackSentAt(DateTime.now());
    return true;
  }
}

final AsyncNotifierProviderFamily<FeedbackDraftNotifier, FeedbackDraft, PatientAppPrefs?> feedbackDraftProvider =
    AsyncNotifierProvider.autoDispose.family<FeedbackDraftNotifier, FeedbackDraft, PatientAppPrefs?>(
  FeedbackDraftNotifier.new,
);
