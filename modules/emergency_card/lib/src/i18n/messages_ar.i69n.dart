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
  String get ttl => "تنتهي خلال";
  String get revoke => "إلغاء البطاقة";
  String get expired => "انتهت صلاحية هذه البطاقة";
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
      case 'ttl':
        return ttl;
      case 'revoke':
        return revoke;
      case 'expired':
        return expired;
      default:
        return super[key];
    }
  }
}
