// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "حذف الحساب";
  String get confirm => "تأكيد الحذف";
  String get cancelled => "تم إلغاء الحذف";
  String get publicTitle => "حذف حسابك";
  String get verifyHeading => "تأكيد هويتك";
  String get verifyBody =>
      "نرسل رمزًا لمرة واحدة حتى لا يتمكن غيرك من حذف حسابك.";
  String get verifyContinue => "متابعة";
  String get sendCode => "أرسل لي رمزًا";
  String get sendCodeAgain => "أرسل رمزًا جديدًا";
  String get otpLabel => "الرمز لمرة واحدة";
  String get publicCancelTitle => "إلغاء حذف الحساب";
  String get publicCancelAction => "إلغاء الحذف";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
        return super[key];
    }
  }
}
