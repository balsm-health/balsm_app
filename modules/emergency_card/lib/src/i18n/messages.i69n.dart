// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Emergency card";
  String get generate => "Generate card";
  String get ttl => "Expires in";
  String get revoke => "Revoke card";
  String get expired => "This card has expired";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
