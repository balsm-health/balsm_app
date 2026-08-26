import 'dart:math' show sqrt;
import 'dart:ui' show Path, PathFillType;

import 'package:flutter/material.dart' show Offset, Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_parsing/path_parsing.dart';
import 'package:xml/xml.dart';

/// Persist id encoded in a `region-{id}` or `region-{id}-{n}` element id.
///
/// The `-{n}` suffix exists because one region is often drawn as several
/// shapes (`region-r-shin-0` … `region-r-shin-8`); they all resolve to the
/// same [BodyRegion] id.
String? svgRegionId(String? id) {
  if (id == null || !id.startsWith('region-')) return null;
  final rest = id.substring('region-'.length);
  final last = rest.lastIndexOf('-');
  if (last <= 0) return rest;
  if (int.tryParse(rest.substring(last + 1)) == null) return rest;
  return rest.substring(0, last);
}

/// Exact tap targets for one body SVG — the artwork itself, not a box over it.
///
/// Shapes are kept in document order so [regionsAt] can report them topmost
/// first, matching what the user sees painted. Coordinates are viewBox units
/// (every body asset is `0 0 200 384`), which is the space [BodyMap] already
/// converts taps into.
class BodyHitMap {
  BodyHitMap._(this._shapes) : _regionBounds = _unionBounds(_shapes);

  /// Used before an asset finishes parsing, and for assets we decline to map.
  /// Reports no hits, so callers fall back to their own logic.
  static final empty = BodyHitMap._(const <_Shape>[]);

  final List<_Shape> _shapes;

  /// One box per region, spanning all of that region's shapes.
  final Map<String, Rect> _regionBounds;

  bool get isEmpty => _shapes.isEmpty;

  static Map<String, Rect> _unionBounds(List<_Shape> shapes) {
    final bounds = <String, Rect>{};
    for (final shape in shapes) {
      final seen = bounds[shape.regionId];
      bounds[shape.regionId] = seen == null ? shape.bounds : seen.expandToInclude(shape.bounds);
    }
    return bounds;
  }

  /// Region ids whose artwork contains [point], topmost first.
  ///
  /// A point can sit inside several regions — organ plates draw viscera over
  /// the body silhouette — so this yields all of them and lets the caller pick
  /// the first that is selectable on the current layer.
  Iterable<String> regionsAt(Offset point) sync* {
    for (var i = _shapes.length - 1; i >= 0; i--) {
      final shape = _shapes[i];
      if (!shape.bounds.contains(point)) continue;
      if (!shape.path.contains(point)) continue;
      yield shape.regionId;
    }
  }

  /// Region ids ordered by how close their artwork sits to [point], nearest
  /// first, limited to those within [within] viewBox units.
  ///
  /// Forgiveness for a near miss. Measured against each region's bounding box
  /// — cheap, and precise enough for a tap that already failed [regionsAt].
  /// Ties (a point inside several boxes) prefer the smaller region, so a hand
  /// wins over the arm enclosing it.
  Iterable<String> regionsNear(Offset point, {double within = 10}) {
    final scored = <({String id, double distance, double area})>[];
    for (final entry in _regionBounds.entries) {
      final distance = _distanceTo(entry.value, point);
      if (distance > within) continue;
      scored.add((id: entry.key, distance: distance, area: entry.value.width * entry.value.height));
    }
    scored.sort((a, b) {
      final byDistance = a.distance.compareTo(b.distance);
      return byDistance != 0 ? byDistance : a.area.compareTo(b.area);
    });
    return scored.map((s) => s.id);
  }

  /// Gap between [rect] and [p]; zero when [p] is inside.
  static double _distanceTo(Rect rect, Offset p) {
    final dx = (rect.left - p.dx).clamp(0.0, double.infinity) + (p.dx - rect.right).clamp(0.0, double.infinity);
    final dy = (rect.top - p.dy).clamp(0.0, double.infinity) + (p.dy - rect.bottom).clamp(0.0, double.infinity);
    return sqrt(dx * dx + dy * dy);
  }

  static final Map<String, Future<BodyHitMap>> _cache = {};

  /// Parsed map for [asset], built once per asset and cached for the session.
  static Future<BodyHitMap> forAsset(String asset) => _cache.putIfAbsent(asset, () => _parse(asset));

  static Future<BodyHitMap> _parse(String asset) async {
    final doc = XmlDocument.parse(await rootBundle.loadString(asset));
    final shapes = <_Shape>[];
    for (final el in doc.descendants.whereType<XmlElement>()) {
      final regionId = svgRegionId(el.getAttribute('id'));
      if (regionId == null) continue;
      // Body assets place tagged shapes at the top level, untransformed. If
      // that ever stops holding, skip the shape rather than hit-test it in the
      // wrong coordinate space — the caller's box fallback still covers it.
      if (_isTransformed(el)) continue;
      final path = _toPath(el);
      if (path != null) shapes.add(_Shape(regionId, path));
    }
    return BodyHitMap._(shapes);
  }

  static bool _isTransformed(XmlElement el) {
    for (XmlNode? n = el; n != null; n = n.parent) {
      if (n is XmlElement && n.getAttribute('transform') != null) return true;
    }
    return false;
  }

  static Path? _toPath(XmlElement el) => switch (el.name.local) {
        'path' => _fromPathData(el.getAttribute('d')),
        'ellipse' => _fromEllipse(el),
        'circle' => _fromCircle(el),
        'rect' => _fromRect(el),
        _ => null,
      };

  static Path? _fromPathData(String? d) {
    if (d == null || d.isEmpty) return null;
    final proxy = _PathBuilder();
    try {
      writeSvgPathDataToPath(d, proxy);
    } on Object {
      return null; // malformed `d` — fall back to the box for this shape
    }
    // SVG's default fill rule is nonzero; Flutter's Path default matches.
    return proxy.path..fillType = PathFillType.nonZero;
  }

  static Path? _fromEllipse(XmlElement el) {
    final cx = _num(el, 'cx'), cy = _num(el, 'cy');
    final rx = _num(el, 'rx'), ry = _num(el, 'ry');
    if (cx == null || cy == null || rx == null || ry == null) return null;
    return Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
  }

  static Path? _fromCircle(XmlElement el) {
    final cx = _num(el, 'cx'), cy = _num(el, 'cy'), r = _num(el, 'r');
    if (cx == null || cy == null || r == null) return null;
    return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  }

  static Path? _fromRect(XmlElement el) {
    final x = _num(el, 'x') ?? 0, y = _num(el, 'y') ?? 0;
    final w = _num(el, 'width'), h = _num(el, 'height');
    if (w == null || h == null) return null;
    return Path()..addRect(Rect.fromLTWH(x, y, w, h));
  }

  static double? _num(XmlElement el, String attr) {
    final raw = el.getAttribute(attr);
    return raw == null ? null : double.tryParse(raw);
  }
}

class _Shape {
  _Shape(this.regionId, this.path) : bounds = path.getBounds();

  final String regionId;
  final Path path;

  /// Cached so the common miss costs a rect test, not a path test.
  final Rect bounds;
}

/// Adapts `path_parsing`'s callback API onto a [Path].
class _PathBuilder extends PathProxy {
  final path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
