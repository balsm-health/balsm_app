// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "بطاقة الطوارئ";
  String get generate => "إنشاء البطاقة";
  String get revoke => "إلغاء البطاقة";
  String get unavailable => "بطاقة الطوارئ هذه غير متاحة";
  String get qrUnavailable => "رمز الطوارئ هذا لم يعد متاحًا.";
  String get profileHeading => "ملف بلسم";
  String get fieldName => "الاسم";
  String get fieldDateOfBirth => "تاريخ الميلاد";
  String get fieldGender => "الجنس";
  String get needsRefresh => "هذا الرمز يحتاج إلى تحديث";
  String get needsRefreshBody => "اطلب من صاحب البطاقة فتح تطبيق بلسم مرة واحدة، وسيتحدّث الرمز تلقائيًا.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'generate':
        return generate;
      case 'revoke':
        return revoke;
      case 'unavailable':
        return unavailable;
      case 'qrUnavailable':
        return qrUnavailable;
      case 'profileHeading':
        return profileHeading;
      case 'fieldName':
        return fieldName;
      case 'fieldDateOfBirth':
        return fieldDateOfBirth;
      case 'fieldGender':
        return fieldGender;
      case 'needsRefresh':
        return needsRefresh;
      case 'needsRefreshBody':
        return needsRefreshBody;
      default:
        return super[key];
    }
  }
}
