import 'package:app/balsm_app/strings.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arabic addresses women and men with different forms. Copy aimed at the
/// patient follows their gender; `other` (unknown) reads masculine, the app
/// convention (see [Gender]).
void main() {
  final ar = stringsFor('ar');
  final en = stringsFor('en');

  test('mood words agree with the patient', () {
    expect(ar.checkin.mood_1(Gender.female), 'متعبة');
    expect(ar.checkin.mood_1(Gender.male), 'متعب');
    expect(ar.checkin.mood_1(Gender.other), 'متعب');
    expect(ar.checkin.mood_5(Gender.female), 'ممتازة');
    expect(ar.checkin.mood_5(Gender.male), 'ممتاز');
  });

  test('instructions address the patient in their gender', () {
    expect(ar.checkin.q_mood_h(Gender.female), startsWith('اختاري'));
    expect(ar.checkin.q_mood_h(Gender.male), startsWith('اختر '));
    expect(ar.offline.go_done_title(Gender.female), 'أنتِ متصلة الآن');
    expect(ar.offline.go_done_title(Gender.other), 'أنت متصل الآن');
  });

  test('a parameter still interpolates inside a gendered message', () {
    expect(ar.care.care_import_banner('3', Gender.female), contains('أُضيف 3'));
    expect(ar.care.care_import_banner('3', Gender.female), contains('اضغطي'));
  });

  test('English ignores gender', () {
    expect(en.checkin.mood_1(Gender.female), en.checkin.mood_1(Gender.male));
  });
}
