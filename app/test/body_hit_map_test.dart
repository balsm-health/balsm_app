import 'package:app/balsm_app/widgets/body_hit_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Every layer asset paired with the catalog it is meant to expose.
const _layers = <(String, BodyTissue, BodyView)>[
  ('assets/body/male_front.svg', BodyTissue.skin, BodyView.front),
  ('assets/body/male_back.svg', BodyTissue.skin, BodyView.back),
  ('assets/body/female_front.svg', BodyTissue.skin, BodyView.front),
  ('assets/body/female_back.svg', BodyTissue.skin, BodyView.back),
  ('assets/body/muscles_front.svg', BodyTissue.muscle, BodyView.front),
  ('assets/body/muscles_back.svg', BodyTissue.muscle, BodyView.back),
  ('assets/body/bones_front.svg', BodyTissue.bone, BodyView.front),
  ('assets/body/bones_back.svg', BodyTissue.bone, BodyView.back),
  ('assets/body/joints_front.svg', BodyTissue.joint, BodyView.front),
  ('assets/body/joints_back.svg', BodyTissue.joint, BodyView.back),
  ('assets/body/tendons_front.svg', BodyTissue.tendon, BodyView.front),
  ('assets/body/tendons_back.svg', BodyTissue.tendon, BodyView.back),
  ('assets/body/nerves_front.svg', BodyTissue.nerve, BodyView.front),
  ('assets/body/nerves_back.svg', BodyTissue.nerve, BodyView.back),
  ('assets/body/organs_front.svg', BodyTissue.organ, BodyView.front),
  ('assets/body/organs_back.svg', BodyTissue.organ, BodyView.back),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('svgRegionId', () {
    test('strips the shape index, keeps hyphenated ids', () {
      expect(svgRegionId('region-chest'), 'chest');
      expect(svgRegionId('region-r-shin-7'), 'r-shin');
      expect(svgRegionId('region-bk-l-shoulder'), 'bk-l-shoulder');
      expect(svgRegionId('region-l-eye-0'), 'l-eye');
    });

    test('ignores anything not tagged as a region', () {
      expect(svgRegionId(null), isNull);
      expect(svgRegionId('shadow'), isNull);
      expect(svgRegionId('regionish-chest'), isNull);
    });
  });

  group('parsing', () {
    test('every layer asset yields shapes', () async {
      for (final (asset, _, _) in _layers) {
        final map = await BodyHitMap.forAsset(asset);
        expect(map.isEmpty, isFalse, reason: '$asset parsed to nothing');
      }
    });

    test('every tagged shape names a real catalog location', () async {
      final known = BodyRegion.all.map((r) => r.id).toSet();
      for (final (asset, _, _) in _layers) {
        final map = await BodyHitMap.forAsset(asset);
        // Sweep the viewBox to collect the ids the map can actually report.
        final seen = <String>{};
        for (var x = 0.0; x < 200; x += 2) {
          for (var y = 0.0; y < 384; y += 2) {
            seen.addAll(map.regionsAt(Offset(x, y)));
          }
        }
        expect(seen.difference(known), isEmpty, reason: '$asset tags unknown region ids');
      }
    });

    test('assets are cached, not reparsed', () async {
      final a = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      final b = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      expect(identical(a, b), isTrue);
    });
  });

  group('hit testing', () {
    test('a point on the artwork reports its region', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      expect(map.regionsAt(const Offset(100, 106)).first, 'chest');
      expect(map.regionsAt(const Offset(100, 30)).first, 'head');
    });

    test('a point off the body reports nothing', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      expect(map.regionsAt(const Offset(2, 2)), isEmpty);
      expect(map.regionsAt(const Offset(198, 382)), isEmpty);
    });

    test('overlapping shapes come back topmost first', () async {
      final map = await BodyHitMap.forAsset('assets/body/organs_front.svg');
      // The organ plate paints viscera over the body silhouette.
      final stack = map.regionsAt(const Offset(92, 108)).toList();
      expect(stack.first, 'heart');
      expect(stack, contains('chest'), reason: 'silhouette should sit underneath');
      expect(stack.indexOf('heart'), lessThan(stack.indexOf('chest')));
    });

    test('ellipse hit targets are honoured, not just paths', () async {
      // `head` is an invisible <ellipse cx=100 cy=30 rx=19 ry=22>.
      final map = await BodyHitMap.forAsset('assets/body/nerves_front.svg');
      expect(map.regionsAt(const Offset(100, 30)), contains('head'));
      expect(map.regionsAt(const Offset(100, 30 - 21)), contains('head')); // inside ry
      expect(map.regionsAt(const Offset(100, 30 - 30)), isNot(contains('head'))); // beyond ry
    });
  });

  group('near misses', () {
    test('a point just off the artwork still finds it', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      // Just outside the left arm, inside the forgiveness radius.
      expect(map.regionsNear(const Offset(2, 200)), contains('l-forearm'));
    });

    test('a point nowhere near the body finds nothing', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      expect(map.regionsNear(const Offset(2, 2)), isEmpty);
    });

    test('results are ordered nearest first', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      final near = map.regionsNear(const Offset(100, 106), within: 40).toList();
      expect(near.first, 'chest', reason: 'the tap is inside the chest');
      expect(near.length, greaterThan(1), reason: 'neighbours should follow');
    });

    test('the radius is honoured', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      expect(map.regionsNear(const Offset(2, 200), within: 0), isEmpty);
      expect(map.regionsNear(const Offset(2, 200), within: 40), isNotEmpty);
    });

    test('a point inside the artwork is also near it', () async {
      final map = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      const inside = Offset(100, 106);
      expect(map.regionsAt(inside).first, 'chest');
      expect(map.regionsNear(inside).first, 'chest');
    });
  });

  group('layer filtering', () {
    test('scenery drawn on a layer is not selectable there', () async {
      // organs_front draws the whole silhouette; only viscera and head extras
      // are on the organ catalog, so an arm tap must not resolve to a region.
      final map = await BodyHitMap.forAsset('assets/body/organs_front.svg');
      final stack = map.regionsAt(const Offset(56, 196)).toList();
      expect(stack, isNotEmpty, reason: 'the forearm is painted here');
      expect(
        stack.map((id) => BodyRegion.fromId(id, BodyTissue.organ)).nonNulls,
        isEmpty,
        reason: 'nothing under this point belongs to the organ layer',
      );
    });

    test('viscera resolve on the organ layer', () async {
      final map = await BodyHitMap.forAsset('assets/body/organs_front.svg');
      final region =
          map.regionsAt(const Offset(92, 108)).map((id) => BodyRegion.fromId(id, BodyTissue.organ)).nonNulls.first;
      expect(region, Organ.heart);
    });

    test('a location shared by layers resolves to that layer subclass', () async {
      final muscles = await BodyHitMap.forAsset('assets/body/muscles_front.svg');
      final bones = await BodyHitMap.forAsset('assets/body/bones_front.svg');
      const p = Offset(100, 106);
      expect(
        muscles.regionsAt(p).map((id) => BodyRegion.fromId(id, BodyTissue.muscle)).nonNulls.first,
        Muscle.chest,
      );
      expect(
        bones.regionsAt(p).map((id) => BodyRegion.fromId(id, BodyTissue.bone)).nonNulls.first,
        Bone.chest,
      );
    });
  });
}
