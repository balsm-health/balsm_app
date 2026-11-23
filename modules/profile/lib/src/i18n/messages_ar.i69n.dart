// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "الملف الصحي";
  String get bloodType => "فصيلة الدم";
  AllergiesMessages_ar get allergies => AllergiesMessages_ar(this);
  SeverityMessages_ar get severity => SeverityMessages_ar(this);
  String get conditions => "الحالات الصحية";
  String get contacts => "جهات اتصال الطوارئ";
  String get loadError => "تعذّر تحميل الملف الصحي";
  String get noAllergies => "لم تُضف أي حساسية";
  String get controlled => "خاضع للرقابة";
  String get remove => "إزالة";
  String get chronicConditions => "الأمراض المزمنة";
  String get noConditions => "لم تُضف أي حالات";
  String get noContacts => "لم تُضف جهات اتصال للطوارئ";
  String get primary => "أساسي";
  String get addShort => "إضافة";
  String get selectBloodType => "اختر فصيلة الدم";
  String get unknown => "غير معروف";
  String get allergen => "مسبّب الحساسية";
  String get severityLabel => "الشدة";
  String get controlledSubstance => "مادة خاضعة للرقابة";
  String get addCondition => "إضافة حالة";
  String get condition => "الحالة";
  String get addContact => "إضافة جهة اتصال للطوارئ";
  String get name => "الاسم";
  String get phone => "الهاتف";
  String get relationOptional => "صلة القرابة (اختياري)";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'bloodType':
        return bloodType;
      case 'allergies':
        return allergies;
      case 'severity':
        return severity;
      case 'conditions':
        return conditions;
      case 'contacts':
        return contacts;
      case 'loadError':
        return loadError;
      case 'noAllergies':
        return noAllergies;
      case 'controlled':
        return controlled;
      case 'remove':
        return remove;
      case 'chronicConditions':
        return chronicConditions;
      case 'noConditions':
        return noConditions;
      case 'noContacts':
        return noContacts;
      case 'primary':
        return primary;
      case 'addShort':
        return addShort;
      case 'selectBloodType':
        return selectBloodType;
      case 'unknown':
        return unknown;
      case 'allergen':
        return allergen;
      case 'severityLabel':
        return severityLabel;
      case 'controlledSubstance':
        return controlledSubstance;
      case 'addCondition':
        return addCondition;
      case 'condition':
        return condition;
      case 'addContact':
        return addContact;
      case 'name':
        return name;
      case 'phone':
        return phone;
      case 'relationOptional':
        return relationOptional;
      default:
        return super[key];
    }
  }
}

class AllergiesMessages_ar extends AllergiesMessages {
  final Messages_ar _parent;
  const AllergiesMessages_ar(this._parent) : super(_parent);
  String get label => "الحساسية";
  String get add => "إضافة حساسية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'label':
        return label;
      case 'add':
        return add;
      default:
        return super[key];
    }
  }
}

class SeverityMessages_ar extends SeverityMessages {
  final Messages_ar _parent;
  const SeverityMessages_ar(this._parent) : super(_parent);
  String get mild => "خفيفة";
  String get moderate => "متوسطة";
  String get severe => "شديدة";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'mild':
        return mild;
      case 'moderate':
        return moderate;
      case 'severe':
        return severe;
      default:
        return super[key];
    }
  }
}
