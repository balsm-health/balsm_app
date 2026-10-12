// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Delete account";
  String get confirm => "Confirm deletion";
  String get cancelled => "Deletion cancelled";
  String get publicTitle => "Delete your account";
  String get verifyHeading => "Verify it is you";
  String get verifyBody => "We send a one-time code so nobody else can delete your account.";
  String get verifyContinue => "Continue";
  String get sendCode => "Send me a code";
  String get sendCodeAgain => "Send a new code";
  String get otpLabel => "One-time code";
  String get publicCancelTitle => "Cancel account deletion";
  String get publicCancelAction => "Cancel deletion";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'confirm':
        return confirm;
      case 'cancelled':
        return cancelled;
      case 'publicTitle':
        return publicTitle;
      case 'verifyHeading':
        return verifyHeading;
      case 'verifyBody':
        return verifyBody;
      case 'verifyContinue':
        return verifyContinue;
      case 'sendCode':
        return sendCode;
      case 'sendCodeAgain':
        return sendCodeAgain;
      case 'otpLabel':
        return otpLabel;
      case 'publicCancelTitle':
        return publicCancelTitle;
      case 'publicCancelAction':
        return publicCancelAction;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
