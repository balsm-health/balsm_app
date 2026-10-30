import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/flavor.dart';
import 'campaign_attribution.dart';
import 'posthog_analytics_logger.dart';
import 'session_replay.dart';

/// Initialises the PostHog SDK for product analytics. No-op when no project
/// token is configured (`POSTHOG_API_KEY`), so dev builds and tests emit nothing.
///
/// Manual setup, not the SDK's automatic init: the native side is told
/// `AUTO_INIT: false` (AndroidManifest + Info.plist) so the config below — and
/// in particular [PostHogConfig.optOut] and the PHI scrub — is the ONLY way the
/// SDK ever starts. Automatic init would begin collecting before the patient's
/// consent had been read off disk.
///
/// [analyticsEnabled] is the patient's persisted consent; passing it here means
/// a patient who opted out never emits a single event on this launch, not even
/// the native `$application_opened`.
///
/// Flutter web: `Posthog().setup()` is a no-op there (the web SDK expects a
/// `posthog-js` snippet in `index.html`). The snippet is deliberately absent
/// from `app/web/index.html` — the web build of a PHI app must not carry
/// `posthog-js` autocapture, which reads on-screen text. Product analytics is
/// mobile-only by design.
/// [campaign] is the first-touch campaign attribution from
/// `CampaignAttribution.resolve`, registered as super properties so every event
/// carries which ad produced the install. Empty for an organic launch.
Future<void> initPostHog({
  required bool analyticsEnabled,
  Map<String, String> campaign = const {},
}) async {
  final token = FlavorConfig.current.posthogApiKey;
  if (token == null || token.isEmpty) return;

  final config = PostHogConfig(token)
    ..host = FlavorConfig.current.posthogHost
    ..optOut = !analyticsEnabled
    // Sessions / DAU / retention come from these; non-PHI and captured
    // natively, which is why the consent flag has to reach the SDK itself.
    ..captureApplicationLifecycleEvents = true
    // Screen recording is configured but held stopped: it is stopped right
    // after setup, before the first frame, and only SessionReplayGate starts
    // it — with analytics consent, screen-recording consent (opt-in), and on
    // an allowed, health-free screen. Everything is masked regardless, and
    // touches are not captured: on a known keypad they spell out what was
    // typed, masks or not.
    ..sessionReplay = true
    ..sessionReplayConfig = (PostHogSessionReplayConfig()
      ..maskAllTexts = true
      ..maskAllImages = true
      ..maskCustomPaint = true
      ..captureTouches = false)
    // Choice-only surveys (thumbs, ratings, fixed answers) for "how did this
    // feel" feedback. ChoiceOnlySurveyPlatform refuses any survey with typed
    // answers and any survey while analytics consent is off; PosthogObserver
    // is installed with screen capture switched off, so screen views still
    // go only through the scrubbed AnalyticsRouteObserver.
    ..surveys = true
    // Balsm has no PostHog-delivered push; leaving these on would register the
    // device's notification subscription with PostHog for nothing.
    ..capturePushNotificationSubscriptions = false
    ..capturePushNotificationOpened = false
    // Feature flags are not in use. Off keeps a network round-trip and a
    // person-properties evaluation out of every cold start.
    ..preloadFeatureFlags = false
    ..sendFeatureFlagEvents = false
    ..debug = kDebugMode
    // Defence-in-depth, mirroring `sentry_init`'s `beforeSend`: a second scrub
    // of every Dart-captured event, so a call site that reaches the SDK without
    // going through PostHogAnalyticsLogger still cannot carry PHI. Natively
    // captured events (lifecycle, `$rageclick`) do not run these callbacks —
    // they carry SDK-generated `$` properties only and no app data at all.
    // Super properties (registered below) are merged natively after this runs.
    ..beforeSend = [
      (event) {
        event.properties = scrubPostHogProperties(event.properties);
        // Person properties are never set from the app. They are attached to
        // the identified patient and outlive the event, so they are dropped
        // whole rather than scrubbed key by key.
        event.userProperties = null;
        event.userPropertiesSetOnce = null;
        return event;
      },
    ];

  await Posthog().setup(config);
  // Deny by default: nothing records until SessionReplayGate says so.
  await Posthog().stopSessionRecording();

  // Register AFTER setup — super properties need an initialised SDK.
  final superProperties = <String, Object>{
    ...postHogBuildProperties(FlavorConfig.current),
    // `initial_utm_*`, not `utm_*` — see initialCampaignSuperProperties.
    ...initialCampaignSuperProperties(campaign),
  };
  for (final entry in superProperties.entries) {
    await Posthog().register(entry.key, entry.value);
  }
}

/// The build a session came from: which brand (`balsm` / `balsm_pro`) and which
/// environment (`dev` / `staging` / `prod`).
///
/// Registered as PostHog **super properties**, not passed per call, for two
/// reasons. They then ride on *every* event including the natively captured ones
/// (`$application_opened`, `$rageclick`) that never pass through
/// `AnalyticsLogger` — so a dashboard filtered to `flavor = prod` does not
/// silently lose the lifecycle events every retention chart is built on. And the
/// native SDK merges them after `beforeSend`, so they cannot be scrubbed away by
/// mistake.
///
/// Both are build metadata resolved from `--dart-define`s. Neither can carry PHI.
/// The names are the codebase's own (`FlavorConfig.brand` / `.flavor`), not
/// invented dashboard synonyms.
///
/// Web and mobile are already told apart by PostHog's own `$lib`
/// (`posthog-flutter` vs `posthog-js`), so nothing here needs to repeat it.
Map<String, Object> postHogBuildProperties(FlavorConfig config) => {
      'brand': config.brand.name,
      'flavor': config.flavor.name,
    };

/// [ReplayRecorder] over PostHog's session recording; driven by
/// [SessionReplayGate].
class PostHogReplayRecorder implements ReplayRecorder {
  const PostHogReplayRecorder();

  @override
  Future<void> start() => Posthog().startSessionRecording();

  @override
  Future<void> stop() => Posthog().stopSessionRecording();
}

/// The root PostHog takes replay screenshots from. Capture still only runs
/// while [SessionReplayGate] has the recorder started.
Widget sessionReplayRoot(Widget child) => PostHogWidget(child: child);
