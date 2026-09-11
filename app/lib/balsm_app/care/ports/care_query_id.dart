import 'package:core/core.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';

/// Typed id of one directory query — the key a retained result set is stored
/// under.
///
/// Not a record id in the usual sense: it identifies a *question* (this centre,
/// this radius, this filter) rather than a row. Core's data-source contract
/// requires a typed key rather than a bare String, and this is the honest type
/// for one.
///
/// Built from a ROUNDED centre. Three decimals is ~110m, far below the radius
/// being searched, so no user-visible result changes — but without it every
/// pixel of pan drift is a distinct key and nothing is ever reused, here or in
/// the server's vary-by-query cache.
class CareQueryId extends UniqueId {
  const CareQueryId.value(super.value) : super.value();
  const CareQueryId.empty() : super.empty();

  /// Composes the id from everything that changes the response. A field left
  /// out here would serve one query's results in answer to another.
  factory CareQueryId.of(LatLng center, CareSearch search) => CareQueryId.value([
        center.latitude.toStringAsFixed(kCareCenterPrecision),
        center.longitude.toStringAsFixed(kCareCenterPrecision),
        search.radiusKm.toStringAsFixed(1),
        // Null when several types are ticked: the narrowing happens on-device,
        // so the SERVER response is identical and may be reused across them.
        search.wireType ?? '',
        search.text.trim().toLowerCase(),
        kCareResultLimit,
      ].join('|'));
}
