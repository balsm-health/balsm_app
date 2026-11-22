import 'dart:async';

/// Drops the result of a call that returns `FutureOr<void>` (Sentry scope setters
/// do), where `unawaited` — which wants a `Future` — does not apply. The call has
/// already run; this only keeps a pending future from being flagged as discarded.
void fireAndForget(FutureOr<void> result) {
  if (result is Future<void>) unawaited(result);
}
