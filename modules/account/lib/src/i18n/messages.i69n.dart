// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  AccountMessages get account => AccountMessages(this);
  HandleMessages get handle => HandleMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'account':
        return account;
      case 'handle':
        return handle;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AccountMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AccountMessages(this._parent);
  String get settings => "Settings";
  String get country => "Country";
  String get language => "Language";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'settings':
        return settings;
      case 'country':
        return country;
      case 'language':
        return language;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class HandleMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const HandleMessages(this._parent);
  String get title => "Choose your handle";
  String get available => "Available";
  String get taken => "Already taken";
  String get invalid => "Invalid handle";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'available':
        return available;
      case 'taken':
        return taken;
      case 'invalid':
        return invalid;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
