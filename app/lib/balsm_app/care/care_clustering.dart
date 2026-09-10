import 'package:fluster/fluster.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'care_entity.dart';

/// One point on the care map: either a single place, or a cluster standing in
/// for several.
///
/// The Egyptian directory holds ~19k places. Plotting them as individual markers
/// is unusable — pins pile into an unreadable mass at city zoom and the frame
/// budget goes with them — so points are clustered per zoom level and only
/// expand as the user zooms in.
class CarePoint extends Clusterable {
  /// A real place. Null when this point is a cluster.
  final CareEntity? entity;

  CarePoint.of(CareEntity place)
      : entity = place,
        super(
          latitude: place.position.latitude,
          longitude: place.position.longitude,
          isCluster: false,
          markerId: place.id,
        );

  CarePoint.cluster({
    required int id,
    required double lat,
    required double lng,
    required int size,
  })  : entity = null,
        super(
          latitude: lat,
          longitude: lng,
          isCluster: true,
          clusterId: id,
          pointsSize: size,
        );

  LatLng get position => LatLng(latitude ?? 0, longitude ?? 0);

  /// How many places this point stands for — 1 for a single place.
  int get count => isCluster == true ? (pointsSize ?? 0) : 1;
}

/// Cluster radius in pixels. Tuned so dense Cairo streets collapse at city zoom
/// while neighbouring buildings still separate once you are close in.
const int kCareClusterRadiusPx = 120;

/// Highest zoom at which points are still clustered. Fluster clusters *at* this
/// level and only returns individual points ABOVE it, so a query must be allowed
/// to reach maxZoom + 1 — clamping to this value would leave pins permanently
/// clustered even at full zoom.
const int kCareClusterMaxZoom = 17;

/// Builds the cluster index for [entities]. Rebuild only when the entity list
/// changes — indexing is the expensive part, querying it is cheap.
Fluster<CarePoint> buildCareClusters(List<CareEntity> entities) => Fluster<CarePoint>(
      minZoom: 0,
      maxZoom: kCareClusterMaxZoom,
      radius: kCareClusterRadiusPx,
      extent: 512,
      nodeSize: 64,
      points: entities.map(CarePoint.of).toList(growable: false),
      createCluster: (cluster, lng, lat) => CarePoint.cluster(
        id: cluster?.id ?? 0,
        lat: lat ?? 0,
        lng: lng ?? 0,
        size: cluster?.pointsSize ?? 0,
      ),
    );

/// Points to draw for the visible area at [zoom] — a mix of clusters and
/// individual places.
List<CarePoint> careClustersFor(
  Fluster<CarePoint> index,
  LatLng southWest,
  LatLng northEast,
  double zoom,
) =>
    index.clusters(
      [southWest.longitude, southWest.latitude, northEast.longitude, northEast.latitude],
      zoom.round().clamp(0, kCareClusterMaxZoom + 1),
    );
