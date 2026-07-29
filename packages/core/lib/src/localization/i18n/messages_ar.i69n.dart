// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  CommonMessages_ar get common => CommonMessages_ar(this);
  ErrorMessages_ar get error => ErrorMessages_ar(this);
  NotfoundMessages_ar get notfound => NotfoundMessages_ar(this);
  CountryMessages_ar get country => CountryMessages_ar(this);
  LanguageMessages_ar get language => LanguageMessages_ar(this);
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
      default:
        return super[key];
    }
  }
}

class CommonMessages_ar extends CommonMessages {
  final Messages_ar _parent;
  const CommonMessages_ar(this._parent) : super(_parent);
  String get continue_ => "متابعة";
  String get back => "رجوع";
  String get cancel => "إلغاء";
  String get confirm => "تأكيد";
  String get next => "التالي";
  String get done => "تم";
  String get retry => "إعادة المحاولة";
  String get save => "حفظ";
  String get delete => "حذف";
  String get edit => "تعديل";
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
      case 'edit':
        return edit;
      default:
        return super[key];
    }
  }
}

class ErrorMessages_ar extends ErrorMessages {
  final Messages_ar _parent;
  const ErrorMessages_ar(this._parent) : super(_parent);
  String get network => "خطأ في الشبكة. تحقق من اتصالك.";
  String get unknown => "حدث خطأ ما. حاول مرة أخرى.";
  String get validation => "يرجى التحقق من المعلومات التي أدخلتها.";
  String get geofence => "هذه الخدمة غير متاحة في منطقتك.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
        return super[key];
    }
  }
}

class NotfoundMessages_ar extends NotfoundMessages {
  final Messages_ar _parent;
  const NotfoundMessages_ar(this._parent) : super(_parent);
  String get title => "الصفحة غير موجودة";
  String get body => "الصفحة التي تبحث عنها غير موجودة.";
  String get cta => "العودة للرئيسية";
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
      case 'cta':
        return cta;
      default:
        return super[key];
    }
  }
}

class CountryMessages_ar extends CountryMessages {
  final Messages_ar _parent;
  const CountryMessages_ar(this._parent) : super(_parent);
  EgCountryMessages_ar get eg => EgCountryMessages_ar(this);
  SaCountryMessages_ar get sa => SaCountryMessages_ar(this);
  AeCountryMessages_ar get ae => AeCountryMessages_ar(this);
  QaCountryMessages_ar get qa => QaCountryMessages_ar(this);
  KwCountryMessages_ar get kw => KwCountryMessages_ar(this);
  BhCountryMessages_ar get bh => BhCountryMessages_ar(this);
  OmCountryMessages_ar get om => OmCountryMessages_ar(this);
  JoCountryMessages_ar get jo => JoCountryMessages_ar(this);
  LbCountryMessages_ar get lb => LbCountryMessages_ar(this);
  MaCountryMessages_ar get ma => MaCountryMessages_ar(this);
  UsCountryMessages_ar get us => UsCountryMessages_ar(this);
  GbCountryMessages_ar get gb => GbCountryMessages_ar(this);
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
        return super[key];
    }
  }
}

class EgCountryMessages_ar extends EgCountryMessages {
  final CountryMessages_ar _parent;
  const EgCountryMessages_ar(this._parent) : super(_parent);
  String get name => "مصر";
  String get demonym => "مصري";
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
        return super[key];
    }
  }
}

class SaCountryMessages_ar extends SaCountryMessages {
  final CountryMessages_ar _parent;
  const SaCountryMessages_ar(this._parent) : super(_parent);
  String get name => "السعودية";
  String get demonym => "سعودي";
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
        return super[key];
    }
  }
}

class AeCountryMessages_ar extends AeCountryMessages {
  final CountryMessages_ar _parent;
  const AeCountryMessages_ar(this._parent) : super(_parent);
  String get name => "الإمارات";
  String get demonym => "إماراتي";
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
        return super[key];
    }
  }
}

class QaCountryMessages_ar extends QaCountryMessages {
  final CountryMessages_ar _parent;
  const QaCountryMessages_ar(this._parent) : super(_parent);
  String get name => "قطر";
  String get demonym => "قطري";
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
        return super[key];
    }
  }
}

class KwCountryMessages_ar extends KwCountryMessages {
  final CountryMessages_ar _parent;
  const KwCountryMessages_ar(this._parent) : super(_parent);
  String get name => "الكويت";
  String get demonym => "كويتي";
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
        return super[key];
    }
  }
}

class BhCountryMessages_ar extends BhCountryMessages {
  final CountryMessages_ar _parent;
  const BhCountryMessages_ar(this._parent) : super(_parent);
  String get name => "البحرين";
  String get demonym => "بحريني";
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
        return super[key];
    }
  }
}

class OmCountryMessages_ar extends OmCountryMessages {
  final CountryMessages_ar _parent;
  const OmCountryMessages_ar(this._parent) : super(_parent);
  String get name => "عُمان";
  String get demonym => "عُماني";
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
        return super[key];
    }
  }
}

class JoCountryMessages_ar extends JoCountryMessages {
  final CountryMessages_ar _parent;
  const JoCountryMessages_ar(this._parent) : super(_parent);
  String get name => "الأردن";
  String get demonym => "أردني";
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
        return super[key];
    }
  }
}

class LbCountryMessages_ar extends LbCountryMessages {
  final CountryMessages_ar _parent;
  const LbCountryMessages_ar(this._parent) : super(_parent);
  String get name => "لبنان";
  String get demonym => "لبناني";
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
        return super[key];
    }
  }
}

class MaCountryMessages_ar extends MaCountryMessages {
  final CountryMessages_ar _parent;
  const MaCountryMessages_ar(this._parent) : super(_parent);
  String get name => "المغرب";
  String get demonym => "مغربي";
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
        return super[key];
    }
  }
}

class UsCountryMessages_ar extends UsCountryMessages {
  final CountryMessages_ar _parent;
  const UsCountryMessages_ar(this._parent) : super(_parent);
  String get name => "الولايات المتحدة";
  String get demonym => "أمريكي";
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
        return super[key];
    }
  }
}

class GbCountryMessages_ar extends GbCountryMessages {
  final CountryMessages_ar _parent;
  const GbCountryMessages_ar(this._parent) : super(_parent);
  String get name => "المملكة المتحدة";
  String get demonym => "بريطاني";
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
        return super[key];
    }
  }
}

class LanguageMessages_ar extends LanguageMessages {
  final Messages_ar _parent;
  const LanguageMessages_ar(this._parent) : super(_parent);
  ArLanguageMessages_ar get ar => ArLanguageMessages_ar(this);
  EnLanguageMessages_ar get en => EnLanguageMessages_ar(this);
  FrLanguageMessages_ar get fr => FrLanguageMessages_ar(this);
  UrLanguageMessages_ar get ur => UrLanguageMessages_ar(this);
  FaLanguageMessages_ar get fa => FaLanguageMessages_ar(this);
  TrLanguageMessages_ar get tr => TrLanguageMessages_ar(this);
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
        return super[key];
    }
  }
}

class ArLanguageMessages_ar extends ArLanguageMessages {
  final LanguageMessages_ar _parent;
  const ArLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "العربية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}

class EnLanguageMessages_ar extends EnLanguageMessages {
  final LanguageMessages_ar _parent;
  const EnLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "الإنجليزية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}

class FrLanguageMessages_ar extends FrLanguageMessages {
  final LanguageMessages_ar _parent;
  const FrLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "الفرنسية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}

class UrLanguageMessages_ar extends UrLanguageMessages {
  final LanguageMessages_ar _parent;
  const UrLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "الأردية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}

class FaLanguageMessages_ar extends FaLanguageMessages {
  final LanguageMessages_ar _parent;
  const FaLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "الفارسية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}

class TrLanguageMessages_ar extends TrLanguageMessages {
  final LanguageMessages_ar _parent;
  const TrLanguageMessages_ar(this._parent) : super(_parent);
  String get name => "التركية";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'name':
        return name;
      default:
        return super[key];
    }
  }
}
