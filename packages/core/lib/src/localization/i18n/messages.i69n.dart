// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  CommonMessages get common => CommonMessages(this);
  ErrorMessages get error => ErrorMessages(this);
  NotfoundMessages get notfound => NotfoundMessages(this);
  CountryMessages get country => CountryMessages(this);
  LanguageMessages get language => LanguageMessages(this);
  RelationMessages get relation => RelationMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
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
      case 'other':
        return other;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
