/// The `retry` policy for every Balsm `ProviderScope` / `ProviderContainer`: never retry.
///
/// Riverpod 3 re-runs a provider that throws, up to ten times with backoff. Balsm keeps the 2.x behaviour on
/// purpose: a failed provider shows its error (an offline banner, a retry button) at once, and a background
/// loop of repeated API calls is not something a patient asked for. To let one provider retry, pass it its
/// own `retry:`; do not change this default.
///
/// A top-level function rather than a closure so it can sit in a `const ProviderScope(...)`.
Duration? noProviderRetry(int retryCount, Object error) => null;
