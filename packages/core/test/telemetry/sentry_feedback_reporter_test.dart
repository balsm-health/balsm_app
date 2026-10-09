import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentryFeedbackReporter.build', () {
    test('an online account is named by its opaque id', () {
      final f = SentryFeedbackReporter.build(
        const UserFeedback(rating: 4, note: ' slow map '),
        userId: '7b1d6c1e-0000-4000-8000-000000000001',
      );
      expect(f.name, '7b1d6c1e-0000-4000-8000-000000000001');
      expect(f.message, 'slow map');
      // Identity stops at the opaque id.
      expect(f.contactEmail, isNull);
    });

    test('no id — device-only or signed out — stays anonymous', () {
      final f = SentryFeedbackReporter.build(const UserFeedback(rating: 5));
      expect(f.name, isNull);
      expect(f.message, SentryFeedbackReporter.ratingOnly);
    });
  });
}
