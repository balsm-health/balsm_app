// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  StatusMessages get status => StatusMessages(this);
  CommonMessages get common => CommonMessages(this);
  ErrorMessages get error => ErrorMessages(this);
  NotfoundMessages get notfound => NotfoundMessages(this);
  CountryMessages get country => CountryMessages(this);
  LanguageMessages get language => LanguageMessages(this);
  RelationMessages get relation => RelationMessages(this);
  String get nav_home => "Home";
  String get nav_card => "Card";
  String get nav_meds => "Meds";
  String get nav_sessions => "Sessions";
  String get nav_settings => "Settings";
  String get trust_on_device => "On-device";
  String get trust_private => "Private";
  String get trust_offline => "Offline-ready";
  String get backup_save_title => "Save your recovery code";
  String get backup_save_body =>
      "This is the only key that can restore your health data on a new device. Write it down and keep it safe — we can never recover it.";
  String get backup_saved => "I've saved it";
  String get restore_title => "Restore your data?";
  String get restore_body =>
      "We found a backup in your cloud. Enter your recovery code to restore your profile, medications, and history.";
  String get restore_code_label => "Recovery code";
  String get restore_error => "Wrong code or no backup found. Try again.";
  String get restore_action => "Restore";
  String get calendar_months => "January|February|March|April|May|June|July|August|September|October|November|December";
  String get calendar_weekdays => "Sun|Mon|Tue|Wed|Thu|Fri|Sat";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'status':
        return status;
      case 'common':
        return common;
      case 'error':
        return error;
      case 'notfound':
        return notfound;
      case 'country':
        return country;
      case 'language':
        return language;
      case 'relation':
        return relation;
      case 'nav_home':
        return nav_home;
      case 'nav_card':
        return nav_card;
      case 'nav_meds':
        return nav_meds;
      case 'nav_sessions':
        return nav_sessions;
      case 'nav_settings':
        return nav_settings;
      case 'trust_on_device':
        return trust_on_device;
      case 'trust_private':
        return trust_private;
      case 'trust_offline':
        return trust_offline;
      case 'backup_save_title':
        return backup_save_title;
      case 'backup_save_body':
        return backup_save_body;
      case 'backup_saved':
        return backup_saved;
      case 'restore_title':
        return restore_title;
      case 'restore_body':
        return restore_body;
      case 'restore_code_label':
        return restore_code_label;
      case 'restore_error':
        return restore_error;
      case 'restore_action':
        return restore_action;
      case 'calendar_months':
        return calendar_months;
      case 'calendar_weekdays':
        return calendar_weekdays;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class StatusMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const StatusMessages(this._parent);
  String get title => "Service status";
  String get operational => "All systems operational";
  String get degraded => "Degraded performance";
  String get down => "Service disruption";
  String get unknown => "Status unknown";
  String get incidents => "Incidents";
  String get no_incidents => "No incidents";
  String get incident => "Incident";
  String get unavailable => "Status unavailable";
  String get unavailable_body => "We could not reach the status service. If you need help, contact support below.";
  String get need_help => "Need help?";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'operational':
        return operational;
      case 'degraded':
        return degraded;
      case 'down':
        return down;
      case 'unknown':
        return unknown;
      case 'incidents':
        return incidents;
      case 'no_incidents':
        return no_incidents;
      case 'incident':
        return incident;
      case 'unavailable':
        return unavailable;
      case 'unavailable_body':
        return unavailable_body;
      case 'need_help':
        return need_help;
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
  String get close => "Close";
  String get copy => "Copy";
  String get skip => "Skip";
  String get clear => "Clear";
  String get dismiss => "Dismiss";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'close':
        return close;
      case 'copy':
        return copy;
      case 'skip':
        return skip;
      case 'clear':
        return clear;
      case 'dismiss':
        return dismiss;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ErrorMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const ErrorMessages(this._parent);
  String get unknown => "Something went wrong. Please try again.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'unknown':
        return unknown;
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
  String get go_home => "Go home";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      case 'go_home':
        return go_home;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CountryMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const CountryMessages(this._parent);
  EgCountryMessages get eg => EgCountryMessages(this);
  SaCountryMessages get sa => SaCountryMessages(this);
  AeCountryMessages get ae => AeCountryMessages(this);
  QaCountryMessages get qa => QaCountryMessages(this);
  KwCountryMessages get kw => KwCountryMessages(this);
  BhCountryMessages get bh => BhCountryMessages(this);
  OmCountryMessages get om => OmCountryMessages(this);
  JoCountryMessages get jo => JoCountryMessages(this);
  LbCountryMessages get lb => LbCountryMessages(this);
  MaCountryMessages get ma => MaCountryMessages(this);
  UsCountryMessages get us => UsCountryMessages(this);
  GbCountryMessages get gb => GbCountryMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'eg':
        return eg;
      case 'sa':
        return sa;
      case 'ae':
        return ae;
      case 'qa':
        return qa;
      case 'kw':
        return kw;
      case 'bh':
        return bh;
      case 'om':
        return om;
      case 'jo':
        return jo;
      case 'lb':
        return lb;
      case 'ma':
        return ma;
      case 'us':
        return us;
      case 'gb':
        return gb;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EgCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const EgCountryMessages(this._parent);
  String get name => "Egypt";
  String get demonym => "Egyptian";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SaCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const SaCountryMessages(this._parent);
  String get name => "Saudi Arabia";
  String get demonym => "Saudi";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AeCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const AeCountryMessages(this._parent);
  String get name => "United Arab Emirates";
  String get demonym => "Emirati";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class QaCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const QaCountryMessages(this._parent);
  String get name => "Qatar";
  String get demonym => "Qatari";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class KwCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const KwCountryMessages(this._parent);
  String get name => "Kuwait";
  String get demonym => "Kuwaiti";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class BhCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const BhCountryMessages(this._parent);
  String get name => "Bahrain";
  String get demonym => "Bahraini";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class OmCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const OmCountryMessages(this._parent);
  String get name => "Oman";
  String get demonym => "Omani";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class JoCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const JoCountryMessages(this._parent);
  String get name => "Jordan";
  String get demonym => "Jordanian";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class LbCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const LbCountryMessages(this._parent);
  String get name => "Lebanon";
  String get demonym => "Lebanese";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class MaCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const MaCountryMessages(this._parent);
  String get name => "Morocco";
  String get demonym => "Moroccan";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class UsCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const UsCountryMessages(this._parent);
  String get name => "United States";
  String get demonym => "American";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class GbCountryMessages implements i69n.I69nMessageBundle {
  final CountryMessages _parent;
  const GbCountryMessages(this._parent);
  String get name => "United Kingdom";
  String get demonym => "British";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      case 'demonym':
        return demonym;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class LanguageMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const LanguageMessages(this._parent);
  ArLanguageMessages get ar => ArLanguageMessages(this);
  EnLanguageMessages get en => EnLanguageMessages(this);
  FrLanguageMessages get fr => FrLanguageMessages(this);
  UrLanguageMessages get ur => UrLanguageMessages(this);
  FaLanguageMessages get fa => FaLanguageMessages(this);
  TrLanguageMessages get tr => TrLanguageMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'ar':
        return ar;
      case 'en':
        return en;
      case 'fr':
        return fr;
      case 'ur':
        return ur;
      case 'fa':
        return fa;
      case 'tr':
        return tr;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ArLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const ArLanguageMessages(this._parent);
  String get name => "Arabic";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EnLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const EnLanguageMessages(this._parent);
  String get name => "English";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class FrLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const FrLanguageMessages(this._parent);
  String get name => "French";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class UrLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const UrLanguageMessages(this._parent);
  String get name => "Urdu";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class FaLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const FaLanguageMessages(this._parent);
  String get name => "Persian";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class TrLanguageMessages implements i69n.I69nMessageBundle {
  final LanguageMessages _parent;
  const TrLanguageMessages(this._parent);
  String get name => "Turkish";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class RelationMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const RelationMessages(this._parent);
  String get spouse => "Spouse";
  String get partner => "Partner";
  String get parent => "Parent";
  String get child => "Child";
  String get sibling => "Sibling";
  String get grandparent => "Grandparent";
  String get relative => "Relative";
  String get friend => "Friend";
  String get guardian => "Guardian";
  String get caregiver => "Caregiver";
  String get neighbour => "Neighbour";
  String get other => "Other";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'spouse':
        return spouse;
      case 'partner':
        return partner;
      case 'parent':
        return parent;
      case 'child':
        return child;
      case 'sibling':
        return sibling;
      case 'grandparent':
        return grandparent;
      case 'relative':
        return relative;
      case 'friend':
        return friend;
      case 'guardian':
        return guardian;
      case 'caregiver':
        return caregiver;
      case 'neighbour':
        return neighbour;
      case 'other':
        return other;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
