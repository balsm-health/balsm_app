// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Important notice";
  String get scroll => "Scroll to read the full notice";
  String get accept => "I have read and accept";
  AuthorityMessages get authority => AuthorityMessages(this);
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AuthorityMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AuthorityMessages(this._parent);
  String get eg => "Egyptian Ministry of Health and Population";
  String get sa => "Saudi Ministry of Health";
  String get ae => "UAE Ministry of Health and Prevention";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
