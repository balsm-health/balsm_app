final _kSchemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

/// Adds a scheme to a bare `host[:port]` typed into Dev Config's custom-server
/// field, so it survives `dio`'s `Uri.parse` instead of throwing at save/select
/// time (`FormatException: Scheme not starting with alphabetic character`).
///
/// Returns null when the result still cannot be parsed as an absolute URI
/// (empty input, or something `Uri.tryParse` rejects even once schemed), so
/// the caller can reject the input instead of crashing later.
String? normalizeServerUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final candidate = _kSchemePattern.hasMatch(trimmed) ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.isEmpty) return null;
  return candidate;
}
