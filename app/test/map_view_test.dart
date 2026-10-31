import 'dart:async';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/care/ports/care_directory_repository.dart';
import 'package:app/balsm_app/screens/map_screen.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:material_ui/material_ui.dart';

/// The map opens on the patient's own position, returns to where it was after
/// a tab switch, and does not refetch what it already has.
class _CountingRepository implements CareDirectoryRepository {
  int pinCalls = 0;
  int nearbyCalls = 0;

  @override
  Future<CarePinResults> pins(LatLng center, CareSearch search,
      {bool noFloor = false, CancelToken? cancelToken}) async {
    pinCalls++;
    return const CarePinResults.fresh([]);
  }

  @override
  Future<CareResults> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken}) async {
    nearbyCalls++;
    return const CareResults.fresh([]);
  }

  @override
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken}) async => null;
}

void main() {
  // Tests have no network, so every map tile fails to load. Those failures are
  // the tile images, not the map under test. testWidgets installs its own
  // handler per test, so this wraps the body and restores it before the end.
  void mapTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      final report = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.library != 'image resource service') report?.call(d);
      };
      try {
        await body(tester);
      } finally {
        FlutterError.onError = report;
      }
    });
  }

  // Alexandria: inside coverage, and not the Cairo fallback.
  const me = LatLng(31.2001, 29.9187);

  LatLng cameraCenter(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera.center;

  Future<ProviderContainer> pump(WidgetTester tester,
      {required Future<DeviceLocation> location, MapView? saved}) async {
    final container = ProviderContainer(overrides: [
      careDirectoryRepositoryProvider.overrideWithValue(_CountingRepository()),
      deviceLocationProvider.overrideWith((ref) => location),
      if (saved != null) mapViewProvider.overrideWith((ref) => saved),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppScope(state: PatientAppState(), child: const MaterialApp(home: MapScreen())),
    ));
    await tester.pump();
    await tester.pump();
    return container;
  }

  mapTest('opens on the patient\'s position', (tester) async {
    final container = await pump(tester, location: Future.value((position: me, issue: null)));
    expect(cameraCenter(tester).latitude, closeTo(me.latitude, 1e-4));
    expect(container.read(mapViewProvider)?.placed, isTrue);
  });

  mapTest('moves to the position when it arrives after the map', (tester) async {
    final fix = Completer<DeviceLocation>();
    await pump(tester, location: fix.future);
    expect(cameraCenter(tester).latitude, isNot(closeTo(me.latitude, 1e-4)));

    fix.complete((position: me, issue: null));
    await tester.pump();
    await tester.pump();
    expect(cameraCenter(tester).latitude, closeTo(me.latitude, 1e-4));
  });

  mapTest('returns to the view it had, not the patient\'s position', (tester) async {
    const there = LatLng(30.5852, 31.5035);
    await pump(tester,
        location: Future.value((position: me, issue: null)), saved: (center: there, zoom: 12, placed: true));
    expect(cameraCenter(tester).latitude, closeTo(there.latitude, 1e-4));
  });

  test('pins are not refetched when the map comes back', () async {
    final repo = _CountingRepository();
    final container = ProviderContainer(overrides: [
      careDirectoryRepositoryProvider.overrideWithValue(repo),
      deviceLocationProvider.overrideWith((ref) async => (position: me, issue: null)),
    ]);
    addTearDown(container.dispose);

    var sub = container.listen(carePinsProvider, (prev, next) {});
    await container.read(carePinsProvider.future);
    sub.close();
    await Future<void>.delayed(Duration.zero);

    sub = container.listen(carePinsProvider, (prev, next) {});
    await container.read(carePinsProvider.future);
    sub.close();
    expect(repo.pinCalls, 1);
  });
}
