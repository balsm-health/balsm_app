// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "الجلسات النشطة";
  String get current => "الجلسة الحالية";
  String get revoke => "تسجيل الخروج";
  String get offline => "يحتاج نشاط تسجيل الدخول إلى اتصال بالإنترنت.";
  String get loadError => "تعذّر تحميل الجلسات.";
  String get signOutAll => "تسجيل الخروج من كل الأجهزة";
  String get signOutAllTitle => "تسجيل الخروج من كل الأجهزة؟";
  String get signOutAllBody =>
      "سيُنهي هذا كل الجلسات على جميع الأجهزة، بما فيها هذا الجهاز. ستحتاج إلى تسجيل الدخول مجددًا.";
  String signedOutCount(int n) =>
      "تم تسجيل الخروج من ${_plural(n, one: 'جلسة واحدة', two: 'جلستين', few: '$n جلسات', many: '$n جلسة', other: '$n جلسة')}.";
  String get empty => "لا توجد جلسات نشطة.";
  String get thisDevice => "هذا الجهاز";
  String get revokeTitle => "إنهاء الجلسة؟";
  String revokeBody(String device) => "تسجيل الخروج من \"$device\"؟ سيحتاج ذلك الجهاز إلى تسجيل الدخول مجددًا.";
  String get revokeAction => "إنهاء";
  String get revoked => "تم إنهاء الجلسة.";
  String firstSeen(String date) => "أول ظهور $date";
  String lastActive(String time) => "آخر نشاط $time";
  String get deviceGeneric => "جهاز";
  String get deviceWeb => "الويب";
  String get deviceDesktop => "سطح المكتب";
  String get justNow => "الآن";
  String minutesAgo(int n) =>
      "قبل ${_plural(n, one: 'دقيقة', two: 'دقيقتين', few: '$n دقائق', many: '$n دقيقة', other: '$n دقيقة')}";
  String hoursAgo(int n) =>
      "قبل ${_plural(n, one: 'ساعة', two: 'ساعتين', few: '$n ساعات', many: '$n ساعة', other: '$n ساعة')}";
  String daysAgo(int n) =>
      "قبل ${_plural(n, one: 'يوم', two: 'يومين', few: '$n أيام', many: '$n يومًا', other: '$n يوم')}";
  String weeksAgo(int n) =>
      "قبل ${_plural(n, one: 'أسبوع', two: 'أسبوعين', few: '$n أسابيع', many: '$n أسبوعًا', other: '$n أسبوع')}";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'current':
        return current;
      case 'revoke':
        return revoke;
      case 'offline':
        return offline;
      case 'loadError':
        return loadError;
      case 'signOutAll':
        return signOutAll;
      case 'signOutAllTitle':
        return signOutAllTitle;
      case 'signOutAllBody':
        return signOutAllBody;
      case 'signedOutCount':
        return signedOutCount;
      case 'empty':
        return empty;
      case 'thisDevice':
        return thisDevice;
      case 'revokeTitle':
        return revokeTitle;
      case 'revokeBody':
        return revokeBody;
      case 'revokeAction':
        return revokeAction;
      case 'revoked':
        return revoked;
      case 'firstSeen':
        return firstSeen;
      case 'lastActive':
        return lastActive;
      case 'deviceGeneric':
        return deviceGeneric;
      case 'deviceWeb':
        return deviceWeb;
      case 'deviceDesktop':
        return deviceDesktop;
      case 'justNow':
        return justNow;
      case 'minutesAgo':
        return minutesAgo;
      case 'hoursAgo':
        return hoursAgo;
      case 'daysAgo':
        return daysAgo;
      case 'weeksAgo':
        return weeksAgo;
      default:
        return super[key];
    }
  }
}
