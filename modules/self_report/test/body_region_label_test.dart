import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  test('BodyRegion.label reads the module i69n catalog', () {
    expect(BodyRegion.head.label(const Messages()), 'Head');
    expect(BodyRegion.head.label(const Messages_ar()), 'الرأس');
    expect(BodyRegion.lShoulder.label(const Messages()), 'L. Shoulder');
    expect(BodyRegion.bkLower.labelForLang('en'), 'Lower back');
    expect(BodyRegion.bkLower.labelForLang('ar'), 'أسفل الظهر');
  });
}
