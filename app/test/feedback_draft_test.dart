import 'package:app/balsm_app/screens/feedback_draft.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReporter implements FeedbackReporter {
  _FakeReporter({required this.ok});
  final bool ok;
  final sent = <UserFeedback>[];

  @override
  Future<bool> send(UserFeedback feedback) async {
    sent.add(feedback);
    return ok;
  }
}

/// The feedback sheet's rating and topics live in one notifier, which the
/// send reads.
void main() {
  ProviderContainer containerWith(FeedbackReporter reporter) {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [feedbackReporterProvider.overrideWithValue(reporter)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sends the rating and the topics in the sheet order', () async {
    final reporter = _FakeReporter(ok: true);
    final c = containerWith(reporter);
    final provider = feedbackDraftProvider(null);
    final sub = c.listen(provider, (_, __) {});
    addTearDown(sub.close);
    await c.read(provider.future);

    c.read(provider.notifier)
      ..rate(4)
      ..toggleTopic('meds')
      ..toggleTopic('general')
      ..toggleTopic('ease')
      ..toggleTopic('ease');
    expect(c.read(provider).value?.rating, 4);

    final ok = await c.read(provider.notifier).submit(note: '', topicOrder: const ['general', 'ease', 'meds']);
    expect(ok, isTrue);
    expect(reporter.sent.single.rating, 4);
    expect(reporter.sent.single.topics, ['general', 'meds']);
  });

  test('nothing is sent without a rating', () async {
    final reporter = _FakeReporter(ok: true);
    final c = containerWith(reporter);
    final provider = feedbackDraftProvider(null);
    final sub = c.listen(provider, (_, __) {});
    addTearDown(sub.close);
    await c.read(provider.future);

    expect(await c.read(provider.notifier).submit(note: '', topicOrder: const []), isFalse);
    expect(reporter.sent, isEmpty);
  });

  test('a failed send reports false', () async {
    final c = containerWith(_FakeReporter(ok: false));
    final provider = feedbackDraftProvider(null);
    final sub = c.listen(provider, (_, __) {});
    addTearDown(sub.close);
    await c.read(provider.future);
    c.read(provider.notifier).rate(2);
    expect(await c.read(provider.notifier).submit(note: '', topicOrder: const []), isFalse);
  });
}
