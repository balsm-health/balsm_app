// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  CountryMessages get country => CountryMessages(this);
  EmailMessages get email => EmailMessages(this);
  OtpMessages get otp => OtpMessages(this);
  SocialMessages get social => SocialMessages(this);
  LockoutMessages get lockout => LockoutMessages(this);
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CountryMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const CountryMessages(this._parent);
  String get title => "Select your country";
  String get search => "Search countries";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EmailMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const EmailMessages(this._parent);
  String get title => "Enter your email";
  String get label => "Email address";
  String get cta => "Send code";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class OtpMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const OtpMessages(this._parent);
  String get title => "Enter verification code";
  String get subtitle => "We sent a code to your email";
  String get resend => "Resend code";
  ErrorOtpMessages get error => ErrorOtpMessages(this);
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ErrorOtpMessages implements i69n.I69nMessageBundle {
  final OtpMessages _parent;
  const ErrorOtpMessages(this._parent);
  String get invalid => "Invalid code. Please try again.";
  String get expired => "This code has expired. Request a new one.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SocialMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const SocialMessages(this._parent);
  String get google => "Continue with Google";
  String get apple => "Continue with Apple";
  String get divider => "or";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class LockoutMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const LockoutMessages(this._parent);
  String get title => "Too many attempts";
  String get body =>
      "Your account is temporarily locked. Please try again later.";
  String get support => "Contact support";
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
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
