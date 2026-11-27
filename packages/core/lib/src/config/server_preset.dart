class ServerPreset {
  const ServerPreset({required this.label, required this.apiBaseUrl});
  final String label;
  final String apiBaseUrl;
  @override
  String toString() => label;
}
