// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  AccountMessages_ar get account => AccountMessages_ar(this);
  HandleMessages_ar get handle => HandleMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'account':
        return account;
      case 'handle':
        return handle;
      default:
        return super[key];
    }
  }
}

class AccountMessages_ar extends AccountMessages {
  final Messages_ar _parent;
  const AccountMessages_ar(this._parent) : super(_parent);
  String get settings => "الإعدادات";
  String get country => "الدولة";
  String get language => "اللغة";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'settings':
        return settings;
      case 'country':
        return country;
      case 'language':
        return language;
      default:
        return super[key];
    }
  }
}

class HandleMessages_ar extends HandleMessages {
  final Messages_ar _parent;
  const HandleMessages_ar(this._parent) : super(_parent);
  String get title => "اختر المعرّف الخاص بك";
  String get available => "متاح";
  String get taken => "مستخدم بالفعل";
  String get invalid => "معرّف غير صالح";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
        return super[key];
    }
  }
}
