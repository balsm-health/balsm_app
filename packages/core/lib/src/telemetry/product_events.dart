/// Product-analytics events: what a patient does, never what they recorded.
///
/// One place for every event name, so PostHog funnels, retention and
/// dashboards can rely on them not drifting. Each event's properties use only
/// keys already on `kNonPhiAllowlist` (`category`, `source`, `action`,
/// `result`, `step`, `count`, `duration_ms`, `type`); the scrubber redacts
/// anything else.
///
/// PHI rule: a value says which *kind* of thing happened, never which
/// reading, symptom or condition. `category` is the quick-log group
/// ([ProductCategory]) — "a vital was saved", not "glucose was saved", since
/// which metric a patient tracks can suggest their condition. Check-in steps
/// are positions (`step` index of `count`), not metric ids.
library;

/// Every property key a [ProductEvent] may carry. A test holds this to
/// `kNonPhiAllowlist`, so a new key cannot ship unreviewed: the scrubber would
/// otherwise redact it silently.
const Set<String> kProductEventPropKeys = {
  'category',
  'source',
  'action',
  'result',
  'step',
  'count',
  'duration_ms',
  'type',
};

/// Event names. Snake case, `<area>_<what happened>`.
abstract final class ProductEvent {
  // ── Quick-log sheet ──────────────────────────────────────────────
  /// The sheet opened. `source`: where from ([ProductSource]).
  static const quickLogOpened = 'quick_log_opened';

  /// A row was opened. `category`.
  static const quickLogItemOpened = 'quick_log_item_opened';

  /// An entry was saved. `category`, `duration_ms` from opening the row.
  static const quickLogSaved = 'quick_log_saved';

  /// Unsaved input was thrown away at the discard prompt. `category`,
  /// `action`: `back` (out of the entry) or `close` (the whole sheet).
  static const quickLogDiscarded = 'quick_log_discarded';

  /// A search finished typing. `result`: `hits` or `empty`; `count`: rows
  /// shown. The query itself is never sent.
  static const quickLogSearched = 'quick_log_searched';

  /// A document shortcut was tapped. `type`: `lab`, `scan` or `report`.
  static const quickLogDocumentTapped = 'quick_log_document_tapped';

  /// The full check-in card was tapped from the sheet.
  static const quickLogFullCheckInTapped = 'quick_log_full_checkin_tapped';

  // ── Full check-in ────────────────────────────────────────────────
  /// The wizard opened. `count`: steps in it.
  static const checkInStarted = 'check_in_started';

  /// A step came on screen. `step`: its index from 0; `count`: steps.
  static const checkInStepViewed = 'check_in_step_viewed';

  /// The check-in was saved. `count`: steps; `duration_ms` from opening.
  static const checkInCompleted = 'check_in_completed';

  /// The wizard closed unsaved. `step`: where it was left; `count`: steps.
  static const checkInAbandoned = 'check_in_abandoned';

  // ── Nearby care ──────────────────────────────────────────────────
  /// The locate button was pressed. `result` ([ProductLocateResult]).
  static const nearbyLocate = 'nearby_locate';
}

/// Quick-log groups, as the `category` property.
abstract final class ProductCategory {
  static const vital = 'vital';
  static const wellbeing = 'wellbeing';
  static const symptom = 'symptom';
}

/// Where a flow was opened from, as the `source` property.
abstract final class ProductSource {
  static const tabBar = 'tab_bar';
  static const home = 'home';
  static const quickLog = 'quick_log';

  /// The desktop menu bar or a keyboard command.
  static const menu = 'menu';
}

/// Outcomes of [ProductEvent.nearbyLocate].
abstract final class ProductLocateResult {
  static const found = 'found';
  static const serviceOff = 'service_off';
  static const denied = 'denied';
  static const deniedForever = 'denied_forever';
  static const unavailable = 'unavailable';
}
