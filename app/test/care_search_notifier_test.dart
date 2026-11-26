import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/screens/map_view.dart';
import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// The care map's search is one provider: typing, ticking types, deep links
/// and "Search this area" all land in [careSearchProvider], with no copy of
/// it kept in the screen.
void main() {
  ProviderContainer container() {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    return c;
  }

  const cairo = LatLng(30.0444, 31.2357);
  const giza = LatLng(30.0131, 31.2089);

  group('CareSearch', () {
    test('equal searches are equal, whatever set instance holds the types', () {
      expect(
        const CareSearch(types: {CareEntityType.lab, CareEntityType.dentist}),
        const CareSearch().copyWith(types: {CareEntityType.dentist, CareEntityType.lab}),
      );
      expect(const CareSearch(text: 'a'), isNot(const CareSearch(text: 'b')));
    });

    test('types copied in cannot be changed afterwards', () {
      final search = const CareSearch().copyWith(types: {CareEntityType.lab});
      expect(() => search.types.add(CareEntityType.dentist), throwsUnsupportedError);
    });
  });

  group('CareSearchNotifier', () {
    test('typed text is searched once typing pauses', () async {
      final c = container();
      c.read(careSearchProvider.notifier).typeText('lab');
      expect(c.read(careSearchProvider).text, '');
      await Future<void>.delayed(CareSearchNotifier.typingPause + const Duration(milliseconds: 50));
      expect(c.read(careSearchProvider).text, 'lab');
    });

    test('ticking a type also applies text still waiting for the pause', () {
      final c = container();
      c.read(careSearchProvider.notifier)
        ..typeText('lab')
        ..toggleType(CareEntityType.lab);
      expect(c.read(careSearchProvider).text, 'lab');
      expect(c.read(careSearchProvider).types, {CareEntityType.lab});
    });

    test('toggling a type twice, or "All", leaves no filter', () {
      final c = container();
      final n = c.read(careSearchProvider.notifier)
        ..toggleType(CareEntityType.lab)
        ..toggleType(CareEntityType.lab);
      expect(c.read(careSearchProvider).types, isEmpty);
      n
        ..toggleType(CareEntityType.dentist)
        ..toggleType(null);
      expect(c.read(careSearchProvider).types, isEmpty);
    });

    test('a deep-link request applies once per serial', () {
      final c = container();
      final n = c.read(careSearchProvider.notifier)
        ..applyFilterRequest(types: {CareEntityType.pharmacy}, serial: 1)
        ..toggleType(CareEntityType.lab)
        ..applyFilterRequest(types: {CareEntityType.pharmacy}, serial: 1);
      expect(c.read(careSearchProvider).types, {CareEntityType.pharmacy, CareEntityType.lab});
      n.applyFilterRequest(types: {CareEntityType.pharmacy}, serial: 2);
      expect(c.read(careSearchProvider).types, {CareEntityType.pharmacy});
    });

    test('clearing filters keeps the area', () {
      final c = container();
      c.read(careSearchProvider.notifier)
        ..searchAround(cairo, radiusKm: 5, tooZoomedOut: false)
        ..toggleType(CareEntityType.lab)
        ..clearFilters();
      final search = c.read(careSearchProvider);
      expect(search.types, isEmpty);
      expect(search.focus, cairo);
    });
  });

  group('MapPanNotifier', () {
    test('the first pan offers a search, which then searches that area', () {
      final c = container();
      c.read(mapPanProvider.notifier).panned(const CareArea(center: giza, radiusKm: 4, tooZoomedOut: false));
      expect(c.read(mapPanProvider).offered, isTrue);

      c.read(mapPanProvider.notifier).searchArea();
      expect(c.read(mapPanProvider).offered, isFalse);
      final search = c.read(careSearchProvider);
      expect(search.focus, giza);
      expect(search.radiusKm, 4);
    });

    test('a nudge near the searched area is not offered', () {
      final c = container();
      c.read(careSearchProvider.notifier).searchAround(cairo, radiusKm: 5, tooZoomedOut: false);
      c.read(mapPanProvider.notifier).panned(const CareArea(center: cairo, radiusKm: 5, tooZoomedOut: false));
      expect(c.read(mapPanProvider).offered, isFalse);
    });

    test('recentering searches around the patient and withdraws the offer', () {
      final c = container();
      c.read(mapPanProvider.notifier)
        ..panned(const CareArea(center: giza, radiusKm: 4, tooZoomedOut: false))
        ..searchAroundMe(cairo);
      expect(c.read(mapPanProvider), const MapPan());
      expect(c.read(careSearchProvider).focus, cairo);
      expect(c.read(careSearchProvider).radiusKm, kCareDefaultRadiusKm);
    });
  });

  test('the map view survives having no listener', () async {
    final c = container();
    c.read(mapViewProvider.notifier).remember(cairo, 12, placed: true);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(mapViewProvider), (center: cairo, zoom: 12.0, placed: true));
  });
}
