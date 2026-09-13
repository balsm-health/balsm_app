/// Which artifact a downloaded row is. Matches the backend's own split — see
/// `MapPackArtifactKind` in Balsm-API-DotNet.
enum MapPackKind {
  basemap('basemap'),
  places('places');

  const MapPackKind(this.wire);

  final String wire;

  static MapPackKind fromWire(String wire) => switch (wire) {
        'basemap' => MapPackKind.basemap,
        'places' => MapPackKind.places,
        _ => throw ArgumentError('unknown map pack kind: $wire'),
      };
}

/// One verified, on-disk artifact — a row exists if and only if the file at
/// [localPath] is downloaded and SHA-256-verified. Terminal state only: this
/// is written once per successful download/update, never per progress tick.
class MapPackDownloadRow {
  const MapPackDownloadRow({
    required this.governorateId,
    required this.kind,
    required this.version,
    required this.sha256,
    required this.sizeBytes,
    required this.localPath,
    required this.downloadedAt,
  });

  final String governorateId;
  final MapPackKind kind;
  final String version;
  final String sha256;
  final int sizeBytes;
  final String localPath;
  final DateTime downloadedAt;
}
