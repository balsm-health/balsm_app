import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart' show PosthogObserver;
// The survey hand-off from the native SDK has no public hook, so the guard
// subclasses the SDK's own platform class. Pinned by survey_guard_test: if a
// posthog_flutter upgrade moves it, the build or that test breaks first.
// ignore: implementation_imports
import 'package:posthog_flutter/src/posthog_flutter_io.dart';
// ignore: implementation_imports
import 'package:posthog_flutter/src/posthog_flutter_platform_interface.dart';

import 'analytics_consent.dart';

/// The navigator observer surveys need to know where to open their sheet.
///
/// Its own `$screen` capture is switched off (every name maps to null): screen
/// views go only through the scrubbed `AnalyticsRouteObserver`.
NavigatorObserver surveyContextObserver() => PosthogObserver(nameExtractor: (_) => null);

/// Question types a survey may ask: a tap on a scale or on a fixed answer.
///
/// Anything that takes typed text — `open`, a choice question's "Other: ___"
/// (`hasOpenChoice`), or a `link` out of the app — is refused. Typed answers
/// can carry health details, and a survey response is captured by the native
/// SDK, past the Dart scrubber.
const Set<String> kAllowedSurveyQuestionTypes = {'rating', 'single_choice', 'multiple_choice'};

/// Whether [survey] (the native SDK's survey dict) asks only choice
/// questions. Unknown or malformed shapes are refused.
bool isChoiceOnlySurvey(Map<String, dynamic> survey) {
  final questions = survey['questions'];
  if (questions is! List || questions.isEmpty) return false;
  for (final q in questions) {
    if (q is! Map) return false;
    if (!kAllowedSurveyQuestionTypes.contains(q['type'])) return false;
    if (q['hasOpenChoice'] == true) return false;
  }
  return true;
}

/// Shows PostHog surveys only when the patient allows analytics and the
/// survey is choice-only ([isChoiceOnlySurvey]). A refused survey is closed
/// back to the SDK so it does not stay pending, and reported through
/// [onRefused] so a misconfigured survey is noticed rather than silently lost.
class ChoiceOnlySurveyPlatform extends PosthogFlutterIO implements AnalyticsConsentSink {
  ChoiceOnlySurveyPlatform({this.onRefused});

  /// Called with the reason a survey was not shown. The reason is a fixed
  /// word, never survey content.
  final void Function(String reason)? onRefused;

  static const _channel = MethodChannel('posthog_flutter');

  bool _enabled = kAnalyticsConsentDefault;

  @override
  void setAnalyticsEnabled(bool enabled) => _enabled = enabled;

  @override
  Future<void> showSurvey(Map<String, dynamic> survey) async {
    final reason = !_enabled ? 'consent_off' : (isChoiceOnlySurvey(survey) ? null : 'free_text');
    if (reason == null) return super.showSurvey(survey);
    onRefused?.call(reason);
    final id = survey['presentationId'];
    if (id == null) return;
    try {
      await _channel.invokeMethod('surveyAction', {'type': 'closed', 'presentationId': id});
    } on PlatformException catch (e) {
      debugPrint('[survey_guard] close refused survey: ${e.code}');
    }
  }

  /// Puts the guard between the native SDK and the survey UI. Call before
  /// `Posthog().setup`; Android and iOS only (other platforms render no
  /// native-triggered surveys).
  static ChoiceOnlySurveyPlatform install({void Function(String reason)? onRefused}) {
    final guard = ChoiceOnlySurveyPlatform(onRefused: onRefused);
    PosthogFlutterPlatformInterface.instance = guard;
    return guard;
  }
}
