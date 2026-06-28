class ServerPreset {
  final String label;
  final String apiBaseUrl;
  const ServerPreset({required this.label, required this.apiBaseUrl});
  @override String toString() => label;
}
