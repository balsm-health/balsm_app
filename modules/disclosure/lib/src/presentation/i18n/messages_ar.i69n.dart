// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "إشعار مهم";
  String get scroll => "مرّر لقراءة الإشعار كاملًا";
  String get accept => "لقد قرأت وأوافق";
  AuthorityMessages_ar get authority => AuthorityMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'scroll':
        return scroll;
      case 'accept':
        return accept;
      case 'authority':
        return authority;
      default:
        return super[key];
    }
  }
}

class AuthorityMessages_ar extends AuthorityMessages {
  final Messages_ar _parent;
  const AuthorityMessages_ar(this._parent) : super(_parent);
  String get eg => "وزارة الصحة والسكان المصرية";
  String get sa => "وزارة الصحة السعودية";
  String get ae => "وزارة الصحة ووقاية المجتمع الإماراتية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'eg':
        return eg;
      case 'sa':
        return sa;
      case 'ae':
        return ae;
      default:
        return super[key];
    }
  }
}
