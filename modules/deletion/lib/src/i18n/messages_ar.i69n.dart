// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "حذف الحساب";
  String get confirm => "تأكيد الحذف";
  String get cancelled => "تم إلغاء الحذف";
  String get grace => "سيتم حذف حسابك بعد انتهاء فترة السماح";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'confirm':
        return confirm;
      case 'cancelled':
        return cancelled;
      case 'grace':
        return grace;
      default:
        return super[key];
    }
  }
}
