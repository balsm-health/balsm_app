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
  String get revoke => "Revoke card";
  String get unavailable => "This emergency card is unavailable";
  String get qrUnavailable => "This emergency QR is no longer available.";
  String get profileHeading => "Balsm Profile";
  String get fieldName => "Name";
  String get fieldDateOfBirth => "Date of birth";
  String get fieldGender => "Gender";
  String get needsRefresh => "This code needs a refresh";
  String get needsRefreshBody => "Ask the owner to open their Balsm app once — the code updates itself.";
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
      case 'revoke':
        return revoke;
      case 'unavailable':
        return unavailable;
      case 'qrUnavailable':
        return qrUnavailable;
      case 'profileHeading':
        return profileHeading;
      case 'fieldName':
        return fieldName;
      case 'fieldDateOfBirth':
        return fieldDateOfBirth;
      case 'fieldGender':
        return fieldGender;
      case 'needsRefresh':
        return needsRefresh;
      case 'needsRefreshBody':
        return needsRefreshBody;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
