// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Active sessions";
  String get current => "Current session";
  String get revoke => "Sign out";
  String get signOutAll => "Sign out of all devices";
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
      case 'signOutAll':
        return signOutAll;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
