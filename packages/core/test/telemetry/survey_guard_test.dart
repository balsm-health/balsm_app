import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> survey(List<Map<String, dynamic>> questions) =>
    {'id': 's1', 'presentationId': 'p1', 'name': 'n', 'questions': questions};

Map<String, dynamic> q(String type, {bool openChoice = false}) => {
      'type': type,
      'question': 'q',
      'isOptional': false,
      if (type.endsWith('choice')) ...{
        'choices': ['a', 'b'],
        'hasOpenChoice': openChoice
      },
      if (type == 'rating') ...{
        'ratingType': 1,
        'scaleLowerBound': 1,
        'scaleUpperBound': 5,
        'lowerBoundLabel': 'low',
        'upperBoundLabel': 'high',
      },
    };

/// PostHog surveys are choice-only and consent-gated: typed answers can carry
/// health details and are captured natively, past the Dart scrubber.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isChoiceOnlySurvey', () {
    test('ratings and fixed choices pass', () {
      expect(isChoiceOnlySurvey(survey([q('rating'), q('single_choice'), q('multiple_choice')])), isTrue);
    });

    for (final (name, s) in [
      ('an open-text question', survey([q('rating'), q('open')])),
      ('a choice with "Other: ___"', survey([q('single_choice', openChoice: true)])),
      ('a link out of the app', survey([q('link')])),
      ('an unknown type', survey([q('emoji_text')])),
      ('no questions', survey([])),
      ('a malformed shape', {'questions': 'x'}),
    ]) {
      test('$name is refused', () => expect(isChoiceOnlySurvey(s), isFalse));
    }
  });

  group('ChoiceOnlySurveyPlatform', () {
    late List<MethodCall> calls;
    late List<String> refused;

    setUp(() {
      calls = [];
      refused = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
        calls.add(call);
        return null;
      });
    });

    test('a free-text survey is closed back to the SDK and reported, not shown', () async {
      final guard = ChoiceOnlySurveyPlatform(onRefused: refused.add)..setAnalyticsEnabled(true);
      await guard.showSurvey(survey([q('open')]));
      expect(refused, ['free_text']);
      expect(calls.single.method, 'surveyAction');
      expect(calls.single.arguments, {'type': 'closed', 'presentationId': 'p1'});
    });

    test('with analytics switched off even a choice survey is refused', () async {
      final guard = ChoiceOnlySurveyPlatform(onRefused: refused.add)..setAnalyticsEnabled(false);
      await guard.showSurvey(survey([q('rating')]));
      expect(refused, ['consent_off']);
    });

    test('a choice survey with consent is handed to the SDK', () async {
      final guard = ChoiceOnlySurveyPlatform(onRefused: refused.add)..setAnalyticsEnabled(true);
      await guard.showSurvey(survey([q('rating')]));
      expect(refused, isEmpty);
      expect(calls.where((c) => c.arguments is Map && (c.arguments as Map)['type'] == 'closed'), isEmpty);
    });
  });
}
