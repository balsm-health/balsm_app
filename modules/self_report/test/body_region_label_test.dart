import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  test('BodyRegion.label reads the module i69n catalog', () {
    expect(BodyRegion.head.label(const Messages()), 'Head');
    expect(BodyRegion.head.label(const Messages_ar()), 'الرأس');
    expect(BodyRegion.l_shoulder.label(const Messages()), 'L. Shoulder');
    expect(BodyRegion.bk_lower.labelForLang('en'), 'Lower back');
    expect(BodyRegion.bk_lower.labelForLang('ar'), 'أسفل الظهر');
  });
}
