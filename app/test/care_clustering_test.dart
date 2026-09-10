import 'package:app/balsm_app/care/care_clustering.dart';
import 'package:app/balsm_app/care/care_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

CareEntity _place(String id, double lat, double lng) => CareEntity(
      id: id,
      type: CareEntityType.pharmacy,
      position: LatLng(lat, lng),
      name: (en: 'Fixture $id', ar: ''),
      addr: (en: 'Fixture Street', ar: ''),
      hours: '',
      distance: '',
      rating: '',
      phone: '',
    );

void main() {
  // Twenty places packed into ~200m of Cairo — the density the real directory
  // actually has downtown, where ~19k places nationally would otherwise render
  // as an unreadable mass of overlapping pins.
  final dense = List.generate(20, (i) => _place('p$i', 30.0444 + i * 0.0001, 31.2357 + i * 0.0001));

  test('dense points collapse into fewer markers when zoomed out', () {
    final index = buildCareClusters(dense);

    final points = careClustersFor(index, const LatLng(29.9, 31.1), const LatLng(30.2, 31.4), 11);

    expect(points.length, lessThan(dense.length), reason: 'clustering must reduce the marker count');
    expect(points.any((p) => p.isCluster == true), isTrue);
  });

  test('a cluster reports how many places it stands for', () {
    final index = buildCareClusters(dense);

    final clusters = careClustersFor(index, const LatLng(29.9, 31.1), const LatLng(30.2, 31.4), 11)
        .where((p) => p.isCluster == true);

    expect(clusters, isNotEmpty);
    expect(clusters.map((c) => c.count).reduce((a, b) => a + b), lessThanOrEqualTo(dense.length));
    expect(clusters.every((c) => c.count > 1), isTrue, reason: 'a cluster of one should be a plain pin');
  });

  test('zooming in past the cluster ceiling yields individual places', () {
    final index = buildCareClusters(dense);

    // The map's own maxZoom is 18, one above the cluster ceiling — that is the
    // level at which every place must have its own pin.
    final points =
        careClustersFor(index, const LatLng(30.043, 31.234), const LatLng(30.047, 31.238), kCareClusterMaxZoom + 1.0);

    expect(points.every((p) => p.isCluster != true), isTrue,
        reason: 'above the cluster ceiling every place gets its own pin');
    expect(points.first.entity, isNotNull);
  });

  test('a single place is never wrapped in a cluster', () {
    final index = buildCareClusters([_place('solo', 30.0444, 31.2357)]);

    final points = careClustersFor(index, const LatLng(29.0, 30.0), const LatLng(31.0, 32.0), 10);

    expect(points, hasLength(1));
    expect(points.single.isCluster, isNot(true));
    expect(points.single.count, 1);
  });

  test('points outside the viewport are not returned', () {
    final index = buildCareClusters([
      _place('cairo', 30.0444, 31.2357),
      _place('aswan', 24.0889, 32.8998),
    ]);

    final points = careClustersFor(index, const LatLng(29.9, 31.1), const LatLng(30.2, 31.4), 11);

    expect(points, hasLength(1), reason: 'only the Cairo place is in view');
  });
}
