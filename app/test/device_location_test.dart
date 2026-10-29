import 'package:app/balsm_app/care/care_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The map's "you are here" comes from [deviceLocationProvider], which must
/// never answer with the Cairo search fallback — a phone without location
/// permission was shown sitting in central Cairo.
class _FakeGeo extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  _FakeGeo({this.service = true, this.perm = LocationPermission.whileInUse, this.fix, this.last});
  final bool service;
  LocationPermission perm;
  final Position? fix;
  final Position? last;

  @override
  Future<bool> isLocationServiceEnabled() async => service;
  @override
  Future<LocationPermission> checkPermission() async => perm;
  @override
  Future<LocationPermission> requestPermission() async => perm;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      fix ?? (throw const LocationServiceDisabledException());
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => last;
}

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  Future<(DeviceLocation, LatLng)> read(_FakeGeo geo) async {
    GeolocatorPlatform.instance = geo;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(userLatLngProvider, (_, __) {});
    addTearDown(sub.close);
    return (await c.read(deviceLocationProvider.future), await c.read(userLatLngProvider.future));
  }

  test('a fix is both the position and the search center', () async {
    final (d, center) = await read(_FakeGeo(fix: _at(31.2, 29.9)));
    expect(d.position?.latitude, 31.2);
    expect(d.issue, isNull);
    expect(center.latitude, 31.2);
  });

  for (final (name, geo, issue) in [
    ('location switched off', _FakeGeo(service: false), DeviceLocationIssue.serviceOff),
    ('permission refused', _FakeGeo(perm: LocationPermission.denied), DeviceLocationIssue.denied),
    (
      'permission refused for good',
      _FakeGeo(perm: LocationPermission.deniedForever),
      DeviceLocationIssue.deniedForever
    ),
    ('no fix and none known', _FakeGeo(), DeviceLocationIssue.unavailable),
  ]) {
    test('$name: no position, says why; search falls back to Cairo', () async {
      final (d, center) = await read(geo);
      expect(d.position, isNull);
      expect(d.issue, issue);
      expect(center, kCareFallbackCenter);
    });
  }

  test('no fresh fix falls back to the last known position', () async {
    final (d, _) = await read(_FakeGeo(last: _at(30.5, 31.0)));
    expect(d.position?.latitude, 30.5);
  });
}
