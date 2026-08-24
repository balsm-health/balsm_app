import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  test('BodyRegion.label reads the module i69n catalog', () {
    expect(BodyRegion.head.label(const Messages()), 'Head');
    expect(BodyRegion.head.label(const Messages_ar()), 'الرأس');
    expect(BodyRegion.l_shoulder.label(const Messages()), 'L. Shoulder');
    expect(BodyRegion.bk_lower.labelForLang('en'), 'Lower back');
    expect(BodyRegion.bk_lower.labelForLang('ar'), 'أسفل الظهر');
    expect(BodyRegion.jaw.label(const Messages()), 'Jaw');
    expect(BodyRegion.heart.label(const Messages_ar()), 'القلب');
  });

  test('BodyTissue.label reads the module i69n catalog', () {
    expect(BodyTissue.muscle.label(const Messages()), 'Muscle');
    expect(BodyTissue.organ.label(const Messages_ar()), 'العضو');
  });

  test('PainSite equality is region × tissue', () {
    const a = PainSite(region: BodyRegion.chest, tissue: BodyTissue.muscle);
    const b = PainSite(region: BodyRegion.chest, tissue: BodyTissue.joint);
    expect(a, isNot(b));
    expect(a, const PainSite(region: BodyRegion.chest, tissue: BodyTissue.muscle));
    expect({a, b}.length, 2);
  });

  test('organ layer exposes viscera; joint layer does not', () {
    expect(BodyTissue.organ.regions(BodyView.front), contains(BodyRegion.heart));
    expect(BodyTissue.joint.regions(BodyView.front), isNot(contains(BodyRegion.chest)));
    expect(BodyTissue.joint.regions(BodyView.front), contains(BodyRegion.l_knee));
    expect(BodyTissue.bone.allows(BodyRegion.l_eye), isFalse);
    expect(BodyTissue.skin.allows(BodyRegion.l_eye), isTrue);
  });
}
