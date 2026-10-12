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
