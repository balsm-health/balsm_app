// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Health profile";
  String get bloodType => "Blood type";
  AllergiesMessages get allergies => AllergiesMessages(this);
  SeverityMessages get severity => SeverityMessages(this);
  String get conditions => "Conditions";
  String get contacts => "Emergency contacts";
  String get loadError => "Could not load profile";
  String get noAllergies => "No allergies added";
  String get controlled => "Controlled";
  String get remove => "Remove";
  String get chronicConditions => "Chronic Conditions";
  String get noConditions => "No conditions added";
  String get noContacts => "No emergency contacts added";
  String get primary => "Primary";
  String get addShort => "Add";
  String get selectBloodType => "Select blood type";
  String get unknown => "Unknown";
  String get allergen => "Allergen";
  String get severityLabel => "Severity";
  String get controlledSubstance => "Controlled substance";
  String get addCondition => "Add Condition";
  String get condition => "Condition";
  String get addContact => "Add Emergency Contact";
  String get name => "Name";
  String get phone => "Phone";
  String get relationOptional => "Relation (optional)";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AllergiesMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AllergiesMessages(this._parent);
  String get label => "Allergies";
  String get add => "Add allergy";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SeverityMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const SeverityMessages(this._parent);
  String get mild => "Mild";
  String get moderate => "Moderate";
  String get severe => "Severe";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
