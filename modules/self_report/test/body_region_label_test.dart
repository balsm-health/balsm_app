import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  test('BodyRegion.label reads the module i69n catalog', () {
    expect(Muscle.head.label(const Messages()), 'Head');
    expect(Muscle.head.label(const Messages_ar()), 'الرأس');
    expect(Muscle.l_shoulder.label(const Messages()), 'L. Shoulder');
    expect(Muscle.bk_lower.labelForLang('en'), 'Lower back');
    expect(Muscle.bk_lower.labelForLang('ar'), 'أسفل الظهر');
    expect(Muscle.jaw.label(const Messages()), 'Jaw');
    expect(Organ.heart.label(const Messages_ar()), 'القلب');
  });

  test('the same location labels the same on every layer', () {
    expect(Bone.chest.label(const Messages()), Skin.chest.label(const Messages()));
    expect(Bone.chest.id, Skin.chest.id);
  });

  test('BodyTissue.label reads the module i69n catalog', () {
    expect(BodyTissue.muscle.label(const Messages()), 'Muscle');
    expect(BodyTissue.organ.label(const Messages_ar()), 'العضو');
  });

  test('tissue rides on the subclass', () {
    expect(Muscle.chest.tissue, BodyTissue.muscle);
    expect(Bone.chest.tissue, BodyTissue.bone);
    expect(Organ.liver.tissue, BodyTissue.organ);
    expect(Muscle.chest, isA<Muscle>());
    expect(Organ.liver, isA<Organ>());
  });

  test('identity is location × tissue, so one spot spans layers', () {
    expect(Muscle.chest, isNot(Bone.chest));
    expect(Muscle.chest, Muscle.chest);
    expect({Muscle.chest, Bone.chest}.length, 2);
    expect(<BodyRegion>[Muscle.chest, Muscle.chest].toSet().length, 1);
  });

  test('PainSite equality follows its region', () {
    const a = PainSite(Muscle.l_knee);
    const b = PainSite(Joint.l_knee);
    expect(a.tissue, BodyTissue.muscle);
    expect(b.tissue, BodyTissue.joint);
    expect(a, isNot(b));
    expect(a, const PainSite(Muscle.l_knee));
    expect({a, b}.length, 2);
  });

  test('on() hops a location to another layer', () {
    expect(Skin.chest.on(BodyTissue.bone), Bone.chest);
    expect(Muscle.l_knee.on(BodyTissue.joint), Joint.l_knee);
    expect(Skin.abdomen.on(BodyTissue.bone), isNull);
    expect(Skin.chest.on(BodyTissue.joint), isNull);
  });

  test('organ layer exposes viscera; joint layer does not', () {
    expect(BodyTissue.organ.regions(BodyView.front), contains(Organ.heart));
    expect(BodyTissue.joint.regions(BodyView.front), isNot(contains(Joint.l_foot.on(BodyTissue.skin))));
    expect(BodyTissue.joint.regions(BodyView.front), contains(Joint.l_knee));
    expect(BodyTissue.bone.allows(Skin.l_eye), isFalse);
    expect(BodyTissue.bone.allows(Skin.abdomen), isFalse);
    expect(BodyTissue.skin.allows(Skin.l_eye), isTrue);
    expect(BodyTissue.joint.allows(Skin.chest), isFalse);
  });

  test('regions(view) is filtered by view and cached', () {
    final front = BodyTissue.muscle.regions(BodyView.front);
    expect(front, contains(Muscle.chest));
    expect(front, isNot(contains(Muscle.bk_lower)));
    expect(front.every((r) => r.view == BodyView.front), isTrue);
    expect(front.every((r) => r.tissue == BodyTissue.muscle), isTrue);
    expect(identical(front, BodyTissue.muscle.regions(BodyView.front)), isTrue);
  });

  test('fromId resolves a (region_id, tissue_id) pair', () {
    expect(BodyRegion.fromId('chest', BodyTissue.muscle), Muscle.chest);
    expect(BodyRegion.fromId('chest', BodyTissue.bone), Bone.chest);
    expect(BodyRegion.fromId('bk-lower', BodyTissue.muscle), Muscle.bk_lower);
    expect(BodyRegion.fromId('l-eye', BodyTissue.skin), Skin.l_eye);
    expect(BodyRegion.fromId('liver', BodyTissue.organ), Organ.liver);
    // Location exists, but is not a hotspot on that layer.
    expect(BodyRegion.fromId('chest', BodyTissue.joint), isNull);
    expect(BodyRegion.fromId('abdomen', BodyTissue.bone), isNull);
    expect(BodyRegion.fromId('nope', BodyTissue.skin), isNull);
  });

  test('every (id, tissue) pair is unique', () {
    final keys = BodyRegion.all.map((r) => '${r.id}/${r.tissue.id}').toSet();
    expect(keys.length, BodyRegion.all.length);
  });

  test('Organ.liver is a compile-time constant', () {
    const site = PainSite(Organ.liver);
    expect(site.region.isOrgan, isTrue);
    expect(site.region.id, 'liver');
    expect(site.tissue, BodyTissue.organ);
  });
}
