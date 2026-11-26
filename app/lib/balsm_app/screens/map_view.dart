import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../care/care_entity.dart';

/// Where the care map was looking, kept for the session so switching tabs and
/// back returns to the same view. `placed` is true once the camera is somewhere
/// the patient chose — their own position, or wherever they panned — rather
/// than the fallback shown before the location resolved.
typedef MapView = ({LatLng center, double zoom, bool placed});

/// The map's last camera. Not auto-disposed: it is meant to outlive the route.
///
/// Updated on every camera move, so a widget watches it only through a
/// `select` that changes rarely (zoomed past the query floor or not).
class MapViewNotifier extends Notifier<MapView?> {
  @override
  MapView? build() => null;

  void remember(LatLng center, double zoom, {required bool placed}) =>
      state = (center: center, zoom: zoom, placed: placed);
}

final NotifierProvider<MapViewNotifier, MapView?> mapViewProvider =
    NotifierProvider<MapViewNotifier, MapView?>(MapViewNotifier.new);

/// An area the patient has panned to: what "Search this area" would search.
@immutable
class CareArea {
  const CareArea({required this.center, required this.radiusKm, required this.tooZoomedOut});

  final LatLng center;
  final double radiusKm;

  /// Zoomed out past [kCareMinQueryZoom].
  final bool tooZoomedOut;

  @override
  bool operator ==(Object other) =>
      other is CareArea && other.center == center && other.radiusKm == radiusKm && other.tooZoomedOut == tooZoomedOut;

  @override
  int get hashCode => Object.hash(center, radiusKm, tooZoomedOut);
}

/// Where the patient has panned since the last search, and whether the map
/// offers to search there.
@immutable
class MapPan {
  const MapPan({this.area, this.offered = false, this.zoomedOut = false});

  /// The last area panned to; null until a pan, and after a recenter.
  final CareArea? area;

  /// Shows "Search this area".
  final bool offered;

  /// Whether the last pan ended zoomed out past the query floor, so crossing
  /// the floor in either direction offers a new search.
  final bool zoomedOut;

  @override
  bool operator ==(Object other) =>
      other is MapPan && other.area == area && other.offered == offered && other.zoomedOut == zoomedOut;

  @override
  int get hashCode => Object.hash(area, offered, zoomedOut);
}

/// Panning does NOT re-query. It fired a request per settled gesture, which
/// spent bandwidth on areas the patient was only passing over and made results
/// shift under them mid-drag. Instead a pan arms "Search this area", so moving
/// the map is free and fetching is a decision — the behaviour people already
/// know from other map apps.
///
/// Not auto-disposed, like [mapViewProvider]: the map comes back to the same
/// view, so it comes back with the same offer.
class MapPanNotifier extends Notifier<MapPan> {
  /// How far the map must move before re-searching is worth offering. Roughly a
  /// city block at street zoom — below it the results on screen still describe
  /// what the patient is looking at.
  static const double researchThresholdMeters = 600;

  @override
  MapPan build() => const MapPan();

  /// The patient panned or zoomed to [area].
  void panned(CareArea area) {
    final searched = ref.read(careSearchProvider).focus;
    final movedFar =
        searched == null || const Distance().as(LengthUnit.Meter, searched, area.center) > researchThresholdMeters;
    state = MapPan(
      area: area,
      // A nudge is not a new area; only offer the search once the view has
      // actually moved somewhere else.
      offered: movedFar || area.tooZoomedOut != state.zoomedOut,
      zoomedOut: area.tooZoomedOut,
    );
  }

  /// Runs the search the button offers.
  void searchArea() {
    final area = state.area;
    if (area == null) return;
    state = MapPan(area: area, zoomedOut: state.zoomedOut);
    ref
        .read(careSearchProvider.notifier)
        .searchAround(area.center, radiusKm: area.radiusKm, tooZoomedOut: area.tooZoomedOut);
  }

  /// Searches around the patient's own position (the recenter button).
  void searchAroundMe(LatLng me) {
    state = MapPan(zoomedOut: state.zoomedOut);
    ref.read(careSearchProvider.notifier).searchAround(me, radiusKm: kCareDefaultRadiusKm, tooZoomedOut: false);
  }

  /// Withdraws the offer without searching.
  void dismissOffer() => state = MapPan(area: state.area, zoomedOut: state.zoomedOut);
}

final NotifierProvider<MapPanNotifier, MapPan> mapPanProvider =
    NotifierProvider<MapPanNotifier, MapPan>(MapPanNotifier.new);
