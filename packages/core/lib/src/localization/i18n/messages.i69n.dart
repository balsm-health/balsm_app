// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  CommonMessages get common => CommonMessages(this);
  AuthMessages get auth => AuthMessages(this);
  DisclosureMessages get disclosure => DisclosureMessages(this);
  HomeMessages get home => HomeMessages(this);
  ProfileMessages get profile => ProfileMessages(this);
  HandleMessages get handle => HandleMessages(this);
  EmergencyMessages get emergency => EmergencyMessages(this);
  MedsMessages get meds => MedsMessages(this);
  DeletionMessages get deletion => DeletionMessages(this);
  SessionsMessages get sessions => SessionsMessages(this);
  AccountMessages get account => AccountMessages(this);
  ErrorMessages get error => ErrorMessages(this);
  NotfoundMessages get notfound => NotfoundMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'common':
        return common;
      case 'auth':
        return auth;
      case 'disclosure':
        return disclosure;
      case 'home':
        return home;
      case 'profile':
        return profile;
      case 'handle':
        return handle;
      case 'emergency':
        return emergency;
      case 'meds':
        return meds;
      case 'deletion':
        return deletion;
      case 'sessions':
        return sessions;
      case 'account':
        return account;
      case 'error':
        return error;
      case 'notfound':
        return notfound;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CommonMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const CommonMessages(this._parent);
  String get continue_ => "Continue";
  String get back => "Back";
  String get cancel => "Cancel";
  String get confirm => "Confirm";
  String get next => "Next";
  String get done => "Done";
  String get retry => "Retry";
  String get save => "Save";
  String get delete => "Delete";
  String get edit => "Edit";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'continue_':
        return continue_;
      case 'back':
        return back;
      case 'cancel':
        return cancel;
      case 'confirm':
        return confirm;
      case 'next':
        return next;
      case 'done':
        return done;
      case 'retry':
        return retry;
      case 'save':
        return save;
      case 'delete':
        return delete;
      case 'edit':
        return edit;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AuthMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AuthMessages(this._parent);
  CountryAuthMessages get country => CountryAuthMessages(this);
  EmailAuthMessages get email => EmailAuthMessages(this);
  OtpAuthMessages get otp => OtpAuthMessages(this);
  SocialAuthMessages get social => SocialAuthMessages(this);
  LockoutAuthMessages get lockout => LockoutAuthMessages(this);
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

class CountryAuthMessages implements i69n.I69nMessageBundle {
  final AuthMessages _parent;
  const CountryAuthMessages(this._parent);
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

class EmailAuthMessages implements i69n.I69nMessageBundle {
  final AuthMessages _parent;
  const EmailAuthMessages(this._parent);
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

class OtpAuthMessages implements i69n.I69nMessageBundle {
  final AuthMessages _parent;
  const OtpAuthMessages(this._parent);
  String get title => "Enter verification code";
  String get subtitle => "We sent a code to your email";
  String get resend => "Resend code";
  ErrorOtpAuthMessages get error => ErrorOtpAuthMessages(this);
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

class ErrorOtpAuthMessages implements i69n.I69nMessageBundle {
  final OtpAuthMessages _parent;
  const ErrorOtpAuthMessages(this._parent);
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

class SocialAuthMessages implements i69n.I69nMessageBundle {
  final AuthMessages _parent;
  const SocialAuthMessages(this._parent);
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

class LockoutAuthMessages implements i69n.I69nMessageBundle {
  final AuthMessages _parent;
  const LockoutAuthMessages(this._parent);
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

class DisclosureMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const DisclosureMessages(this._parent);
  String get title => "Important notice";
  String get scroll => "Scroll to read the full notice";
  String get accept => "I have read and accept";
  AuthorityDisclosureMessages get authority =>
      AuthorityDisclosureMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'scroll':
        return scroll;
      case 'accept':
        return accept;
      case 'authority':
        return authority;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AuthorityDisclosureMessages implements i69n.I69nMessageBundle {
  final DisclosureMessages _parent;
  const AuthorityDisclosureMessages(this._parent);
  String get eg => "Egyptian Ministry of Health and Population";
  String get sa => "Saudi Ministry of Health";
  String get ae => "UAE Ministry of Health and Prevention";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'eg':
        return eg;
      case 'sa':
        return sa;
      case 'ae':
        return ae;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class HomeMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const HomeMessages(this._parent);
  GreetingHomeMessages get greeting => GreetingHomeMessages(this);
  NudgeHomeMessages get nudge => NudgeHomeMessages(this);
  TodayHomeMessages get today => TodayHomeMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'greeting':
        return greeting;
      case 'nudge':
        return nudge;
      case 'today':
        return today;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class GreetingHomeMessages implements i69n.I69nMessageBundle {
  final HomeMessages _parent;
  const GreetingHomeMessages(this._parent);
  String get morning => "Good morning";
  String get afternoon => "Good afternoon";
  String get evening => "Good evening";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'morning':
        return morning;
      case 'afternoon':
        return afternoon;
      case 'evening':
        return evening;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NudgeHomeMessages implements i69n.I69nMessageBundle {
  final HomeMessages _parent;
  const NudgeHomeMessages(this._parent);
  String get handle => "Set up your handle";
  String get emergency => "Create your emergency card";
  String get medications => "Add your medications";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'handle':
        return handle;
      case 'emergency':
        return emergency;
      case 'medications':
        return medications;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class TodayHomeMessages implements i69n.I69nMessageBundle {
  final HomeMessages _parent;
  const TodayHomeMessages(this._parent);
  String get title => "Today";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ProfileMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const ProfileMessages(this._parent);
  String get title => "Health profile";
  String get bloodType => "Blood type";
  AllergiesProfileMessages get allergies => AllergiesProfileMessages(this);
  String get conditions => "Conditions";
  String get contacts => "Emergency contacts";
  SeverityProfileMessages get severity => SeverityProfileMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'bloodType':
        return bloodType;
      case 'allergies':
        return allergies;
      case 'conditions':
        return conditions;
      case 'contacts':
        return contacts;
      case 'severity':
        return severity;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AllergiesProfileMessages implements i69n.I69nMessageBundle {
  final ProfileMessages _parent;
  const AllergiesProfileMessages(this._parent);
  String get label => "Allergies";
  String get add => "Add allergy";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
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

class SeverityProfileMessages implements i69n.I69nMessageBundle {
  final ProfileMessages _parent;
  const SeverityProfileMessages(this._parent);
  String get mild => "Mild";
  String get moderate => "Moderate";
  String get severe => "Severe";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
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

class EmergencyMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const EmergencyMessages(this._parent);
  String get title => "Emergency card";
  String get generate => "Generate card";
  String get ttl => "Expires in";
  String get revoke => "Revoke card";
  String get expired => "This card has expired";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'generate':
        return generate;
      case 'ttl':
        return ttl;
      case 'revoke':
        return revoke;
      case 'expired':
        return expired;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class MedsMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const MedsMessages(this._parent);
  ListMedsMessages get list => ListMedsMessages(this);
  String get add => "Add medication";
  TodayMedsMessages get today => TodayMedsMessages(this);
  OutcomeMedsMessages get outcome => OutcomeMedsMessages(this);
  NotificationMedsMessages get notification => NotificationMedsMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'list':
        return list;
      case 'add':
        return add;
      case 'today':
        return today;
      case 'outcome':
        return outcome;
      case 'notification':
        return notification;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ListMedsMessages implements i69n.I69nMessageBundle {
  final MedsMessages _parent;
  const ListMedsMessages(this._parent);
  String get empty => "No medications yet";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'empty':
        return empty;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class TodayMedsMessages implements i69n.I69nMessageBundle {
  final MedsMessages _parent;
  const TodayMedsMessages(this._parent);
  String get title => "Today's medications";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class OutcomeMedsMessages implements i69n.I69nMessageBundle {
  final MedsMessages _parent;
  const OutcomeMedsMessages(this._parent);
  String get taken => "Taken";
  String get skipped => "Skipped";
  String get snoozed => "Snoozed";
  String get missed => "Missed";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'taken':
        return taken;
      case 'skipped':
        return skipped;
      case 'snoozed':
        return snoozed;
      case 'missed':
        return missed;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NotificationMedsMessages implements i69n.I69nMessageBundle {
  final MedsMessages _parent;
  const NotificationMedsMessages(this._parent);
  String get body => "Time to check your medications";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class DeletionMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const DeletionMessages(this._parent);
  String get title => "Delete account";
  String get confirm => "Confirm deletion";
  String get cancelled => "Deletion cancelled";
  String get grace => "Your account will be deleted after the grace period";
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
      case 'grace':
        return grace;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SessionsMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const SessionsMessages(this._parent);
  String get title => "Active sessions";
  String get current => "Current session";
  String get revoke => "Sign out";
  String get signOutAll => "Sign out of all devices";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'current':
        return current;
      case 'revoke':
        return revoke;
      case 'signOutAll':
        return signOutAll;
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

class ErrorMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const ErrorMessages(this._parent);
  String get network => "Network error. Please check your connection.";
  String get unknown => "Something went wrong. Please try again.";
  String get validation => "Please check the information you entered.";
  String get geofence => "This service is not available in your region.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'network':
        return network;
      case 'unknown':
        return unknown;
      case 'validation':
        return validation;
      case 'geofence':
        return geofence;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NotfoundMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const NotfoundMessages(this._parent);
  String get title => "Page not found";
  String get body => "The page you are looking for does not exist.";
  String get cta => "Go home";
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
      case 'cta':
        return cta;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
