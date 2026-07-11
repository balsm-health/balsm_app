// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  CountryMessages_ar get country => CountryMessages_ar(this);
  EmailMessages_ar get email => EmailMessages_ar(this);
  OtpMessages_ar get otp => OtpMessages_ar(this);
  SocialMessages_ar get social => SocialMessages_ar(this);
  LockoutMessages_ar get lockout => LockoutMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'country':
        return country;
      case 'email':
        return email;
      case 'otp':
        return otp;
      case 'social':
        return social;
      case 'lockout':
        return lockout;
      default:
        return super[key];
    }
  }
}

class CountryMessages_ar extends CountryMessages {
  final Messages_ar _parent;
  const CountryMessages_ar(this._parent) : super(_parent);
  String get title => "اختر دولتك";
  String get search => "ابحث عن الدول";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'search':
        return search;
      default:
        return super[key];
    }
  }
}

class EmailMessages_ar extends EmailMessages {
  final Messages_ar _parent;
  const EmailMessages_ar(this._parent) : super(_parent);
  String get title => "أدخل بريدك الإلكتروني";
  String get label => "البريد الإلكتروني";
  String get cta => "إرسال الرمز";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'label':
        return label;
      case 'cta':
        return cta;
      default:
        return super[key];
    }
  }
}

class OtpMessages_ar extends OtpMessages {
  final Messages_ar _parent;
  const OtpMessages_ar(this._parent) : super(_parent);
  String get title => "أدخل رمز التحقق";
  String get subtitle => "أرسلنا رمزًا إلى بريدك الإلكتروني";
  String get resend => "إعادة إرسال الرمز";
  ErrorOtpMessages_ar get error => ErrorOtpMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'subtitle':
        return subtitle;
      case 'resend':
        return resend;
      case 'error':
        return error;
      default:
        return super[key];
    }
  }
}

class ErrorOtpMessages_ar extends ErrorOtpMessages {
  final OtpMessages_ar _parent;
  const ErrorOtpMessages_ar(this._parent) : super(_parent);
  String get invalid => "رمز غير صحيح. حاول مرة أخرى.";
  String get expired => "انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'invalid':
        return invalid;
      case 'expired':
        return expired;
      default:
        return super[key];
    }
  }
}

class SocialMessages_ar extends SocialMessages {
  final Messages_ar _parent;
  const SocialMessages_ar(this._parent) : super(_parent);
  String get google => "المتابعة باستخدام Google";
  String get apple => "المتابعة باستخدام Apple";
  String get divider => "أو";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'google':
        return google;
      case 'apple':
        return apple;
      case 'divider':
        return divider;
      default:
        return super[key];
    }
  }
}

class LockoutMessages_ar extends LockoutMessages {
  final Messages_ar _parent;
  const LockoutMessages_ar(this._parent) : super(_parent);
  String get title => "محاولات كثيرة جدًا";
  String get body => "تم قفل حسابك مؤقتًا. حاول مرة أخرى لاحقًا.";
  String get support => "تواصل مع الدعم";
  String get retry => "حاول مرة أخرى";
  String get needHelp => "تحتاج مساعدة؟";
  String contactSupport(String email) => "راسل $email";
  String get serviceStatus => "تحقق من حالة الخدمة";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      case 'support':
        return support;
      case 'retry':
        return retry;
      case 'needHelp':
        return needHelp;
      case 'contactSupport':
        return contactSupport;
      case 'serviceStatus':
        return serviceStatus;
      default:
        return super[key];
    }
  }
}
