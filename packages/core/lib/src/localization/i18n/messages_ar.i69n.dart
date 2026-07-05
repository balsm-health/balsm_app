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
  AuthMessages_ar get auth => AuthMessages_ar(this);
  DisclosureMessages_ar get disclosure => DisclosureMessages_ar(this);
  HomeMessages_ar get home => HomeMessages_ar(this);
  ProfileMessages_ar get profile => ProfileMessages_ar(this);
  HandleMessages_ar get handle => HandleMessages_ar(this);
  EmergencyMessages_ar get emergency => EmergencyMessages_ar(this);
  MedsMessages_ar get meds => MedsMessages_ar(this);
  DeletionMessages_ar get deletion => DeletionMessages_ar(this);
  SessionsMessages_ar get sessions => SessionsMessages_ar(this);
  AccountMessages_ar get account => AccountMessages_ar(this);
  ErrorMessages_ar get error => ErrorMessages_ar(this);
  NotfoundMessages_ar get notfound => NotfoundMessages_ar(this);
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
        return super[key];
    }
  }
}

class AuthMessages_ar extends AuthMessages {
  final Messages_ar _parent;
  const AuthMessages_ar(this._parent) : super(_parent);
  CountryAuthMessages_ar get country => CountryAuthMessages_ar(this);
  EmailAuthMessages_ar get email => EmailAuthMessages_ar(this);
  OtpAuthMessages_ar get otp => OtpAuthMessages_ar(this);
  SocialAuthMessages_ar get social => SocialAuthMessages_ar(this);
  LockoutAuthMessages_ar get lockout => LockoutAuthMessages_ar(this);
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

class CountryAuthMessages_ar extends CountryAuthMessages {
  final AuthMessages_ar _parent;
  const CountryAuthMessages_ar(this._parent) : super(_parent);
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

class EmailAuthMessages_ar extends EmailAuthMessages {
  final AuthMessages_ar _parent;
  const EmailAuthMessages_ar(this._parent) : super(_parent);
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

class OtpAuthMessages_ar extends OtpAuthMessages {
  final AuthMessages_ar _parent;
  const OtpAuthMessages_ar(this._parent) : super(_parent);
  String get title => "أدخل رمز التحقق";
  String get subtitle => "أرسلنا رمزًا إلى بريدك الإلكتروني";
  String get resend => "إعادة إرسال الرمز";
  ErrorOtpAuthMessages_ar get error => ErrorOtpAuthMessages_ar(this);
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

class ErrorOtpAuthMessages_ar extends ErrorOtpAuthMessages {
  final OtpAuthMessages_ar _parent;
  const ErrorOtpAuthMessages_ar(this._parent) : super(_parent);
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

class SocialAuthMessages_ar extends SocialAuthMessages {
  final AuthMessages_ar _parent;
  const SocialAuthMessages_ar(this._parent) : super(_parent);
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

class LockoutAuthMessages_ar extends LockoutAuthMessages {
  final AuthMessages_ar _parent;
  const LockoutAuthMessages_ar(this._parent) : super(_parent);
  String get title => "محاولات كثيرة جدًا";
  String get body => "تم قفل حسابك مؤقتًا. حاول مرة أخرى لاحقًا.";
  String get support => "تواصل مع الدعم";
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
        return super[key];
    }
  }
}

class DisclosureMessages_ar extends DisclosureMessages {
  final Messages_ar _parent;
  const DisclosureMessages_ar(this._parent) : super(_parent);
  String get title => "إشعار مهم";
  String get scroll => "مرّر لقراءة الإشعار كاملًا";
  String get accept => "لقد قرأت وأوافق";
  AuthorityDisclosureMessages_ar get authority =>
      AuthorityDisclosureMessages_ar(this);
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
        return super[key];
    }
  }
}

class AuthorityDisclosureMessages_ar extends AuthorityDisclosureMessages {
  final DisclosureMessages_ar _parent;
  const AuthorityDisclosureMessages_ar(this._parent) : super(_parent);
  String get eg => "وزارة الصحة والسكان المصرية";
  String get sa => "وزارة الصحة السعودية";
  String get ae => "وزارة الصحة ووقاية المجتمع الإماراتية";
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
        return super[key];
    }
  }
}

class HomeMessages_ar extends HomeMessages {
  final Messages_ar _parent;
  const HomeMessages_ar(this._parent) : super(_parent);
  GreetingHomeMessages_ar get greeting => GreetingHomeMessages_ar(this);
  NudgeHomeMessages_ar get nudge => NudgeHomeMessages_ar(this);
  TodayHomeMessages_ar get today => TodayHomeMessages_ar(this);
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
        return super[key];
    }
  }
}

class GreetingHomeMessages_ar extends GreetingHomeMessages {
  final HomeMessages_ar _parent;
  const GreetingHomeMessages_ar(this._parent) : super(_parent);
  String get morning => "صباح الخير";
  String get afternoon => "مساء الخير";
  String get evening => "مساء الخير";
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
        return super[key];
    }
  }
}

class NudgeHomeMessages_ar extends NudgeHomeMessages {
  final HomeMessages_ar _parent;
  const NudgeHomeMessages_ar(this._parent) : super(_parent);
  String get handle => "أنشئ المعرّف الخاص بك";
  String get emergency => "أنشئ بطاقة الطوارئ";
  String get medications => "أضف أدويتك";
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
        return super[key];
    }
  }
}

class TodayHomeMessages_ar extends TodayHomeMessages {
  final HomeMessages_ar _parent;
  const TodayHomeMessages_ar(this._parent) : super(_parent);
  String get title => "اليوم";
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
        return super[key];
    }
  }
}

class ProfileMessages_ar extends ProfileMessages {
  final Messages_ar _parent;
  const ProfileMessages_ar(this._parent) : super(_parent);
  String get title => "الملف الصحي";
  String get bloodType => "فصيلة الدم";
  AllergiesProfileMessages_ar get allergies =>
      AllergiesProfileMessages_ar(this);
  String get conditions => "الحالات الصحية";
  String get contacts => "جهات اتصال الطوارئ";
  SeverityProfileMessages_ar get severity => SeverityProfileMessages_ar(this);
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
        return super[key];
    }
  }
}

class AllergiesProfileMessages_ar extends AllergiesProfileMessages {
  final ProfileMessages_ar _parent;
  const AllergiesProfileMessages_ar(this._parent) : super(_parent);
  String get label => "الحساسية";
  String get add => "إضافة حساسية";
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
        return super[key];
    }
  }
}

class SeverityProfileMessages_ar extends SeverityProfileMessages {
  final ProfileMessages_ar _parent;
  const SeverityProfileMessages_ar(this._parent) : super(_parent);
  String get mild => "خفيفة";
  String get moderate => "متوسطة";
  String get severe => "شديدة";
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
        return super[key];
    }
  }
}

class HandleMessages_ar extends HandleMessages {
  final Messages_ar _parent;
  const HandleMessages_ar(this._parent) : super(_parent);
  String get title => "اختر المعرّف الخاص بك";
  String get available => "متاح";
  String get taken => "مستخدم بالفعل";
  String get invalid => "معرّف غير صالح";
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
        return super[key];
    }
  }
}

class EmergencyMessages_ar extends EmergencyMessages {
  final Messages_ar _parent;
  const EmergencyMessages_ar(this._parent) : super(_parent);
  String get title => "بطاقة الطوارئ";
  String get generate => "إنشاء البطاقة";
  String get ttl => "تنتهي خلال";
  String get revoke => "إلغاء البطاقة";
  String get expired => "انتهت صلاحية هذه البطاقة";
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
        return super[key];
    }
  }
}

class MedsMessages_ar extends MedsMessages {
  final Messages_ar _parent;
  const MedsMessages_ar(this._parent) : super(_parent);
  ListMedsMessages_ar get list => ListMedsMessages_ar(this);
  String get add => "إضافة دواء";
  TodayMedsMessages_ar get today => TodayMedsMessages_ar(this);
  OutcomeMedsMessages_ar get outcome => OutcomeMedsMessages_ar(this);
  NotificationMedsMessages_ar get notification =>
      NotificationMedsMessages_ar(this);
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
        return super[key];
    }
  }
}

class ListMedsMessages_ar extends ListMedsMessages {
  final MedsMessages_ar _parent;
  const ListMedsMessages_ar(this._parent) : super(_parent);
  String get empty => "لا توجد أدوية بعد";
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
        return super[key];
    }
  }
}

class TodayMedsMessages_ar extends TodayMedsMessages {
  final MedsMessages_ar _parent;
  const TodayMedsMessages_ar(this._parent) : super(_parent);
  String get title => "أدوية اليوم";
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
        return super[key];
    }
  }
}

class OutcomeMedsMessages_ar extends OutcomeMedsMessages {
  final MedsMessages_ar _parent;
  const OutcomeMedsMessages_ar(this._parent) : super(_parent);
  String get taken => "تم التناول";
  String get skipped => "تم التخطي";
  String get snoozed => "مؤجل";
  String get missed => "فائت";
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
        return super[key];
    }
  }
}

class NotificationMedsMessages_ar extends NotificationMedsMessages {
  final MedsMessages_ar _parent;
  const NotificationMedsMessages_ar(this._parent) : super(_parent);
  String get body => "حان وقت مراجعة أدويتك";
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
        return super[key];
    }
  }
}

class DeletionMessages_ar extends DeletionMessages {
  final Messages_ar _parent;
  const DeletionMessages_ar(this._parent) : super(_parent);
  String get title => "حذف الحساب";
  String get confirm => "تأكيد الحذف";
  String get cancelled => "تم إلغاء الحذف";
  String get grace => "سيتم حذف حسابك بعد انتهاء فترة السماح";
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
        return super[key];
    }
  }
}

class SessionsMessages_ar extends SessionsMessages {
  final Messages_ar _parent;
  const SessionsMessages_ar(this._parent) : super(_parent);
  String get title => "الجلسات النشطة";
  String get current => "الجلسة الحالية";
  String get revoke => "تسجيل الخروج";
  String get signOutAll => "تسجيل الخروج من جميع الأجهزة";
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
        return super[key];
    }
  }
}

class AccountMessages_ar extends AccountMessages {
  final Messages_ar _parent;
  const AccountMessages_ar(this._parent) : super(_parent);
  String get settings => "الإعدادات";
  String get country => "الدولة";
  String get language => "اللغة";
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
        return super[key];
    }
  }
}
