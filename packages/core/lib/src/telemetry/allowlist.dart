/// The canonical set of **non-PHI** keys allowed to leave the device in
/// telemetry (breadcrumbs, event contexts, Sentry and PostHog payloads).
/// Deny-by-default: any key NOT in this set is redacted before egress (see
/// `scrubTelemetry`).
///
/// This is an **alias, not a copy**. The one list lives in `balsm_api`
/// (`non_phi_allowlist.dart`) because `core` depends on `balsm_api` and not the
/// reverse, so that is the lowest package both egress paths can reach — the
/// telemetry scrubbers here and `PhiLeakInterceptor.scrubForTelemetry` there.
///
/// It was previously duplicated in four places that had drifted apart, with a
/// comment claiming a test guarded them; no such test existed. Add new keys to
/// `non_phi_allowlist.dart`, never here.
library;

import 'package:balsm_api/balsm_api.dart';

/// See `kNonPhiAllowlist` in `balsm_api` — the single source of truth.
const Set<String> kTelemetryAllowlist = kNonPhiAllowlist;
