// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "إشعار هام";
  String get subtitle => "كيف يتعامل بلسم مع بياناتك الصحية";
  String get scroll => "مرّر للاطلاع على الإشعار كاملاً";
  String get scrollToContinue => "مرّر إلى النهاية للمتابعة";
  String get accept => "قرأتُ وأوافق";
  SectionMessages_ar get section => SectionMessages_ar(this);
  AuthorityMessages_ar get authority => AuthorityMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'subtitle':
        return subtitle;
      case 'scroll':
        return scroll;
      case 'scrollToContinue':
        return scrollToContinue;
      case 'accept':
        return accept;
      case 'section':
        return section;
      case 'authority':
        return authority;
      default:
        return super[key];
    }
  }
}

class SectionMessages_ar extends SectionMessages {
  final Messages_ar _parent;
  const SectionMessages_ar(this._parent) : super(_parent);
  DataCollectedSectionMessages_ar get dataCollected => DataCollectedSectionMessages_ar(this);
  HowProtectedSectionMessages_ar get howProtected => HowProtectedSectionMessages_ar(this);
  YourRightsSectionMessages_ar get yourRights => YourRightsSectionMessages_ar(this);
  SupervisorySectionMessages_ar get supervisory => SupervisorySectionMessages_ar(this);
  SharingSectionMessages_ar get sharing => SharingSectionMessages_ar(this);
  DeletionSectionMessages_ar get deletion => DeletionSectionMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'dataCollected':
        return dataCollected;
      case 'howProtected':
        return howProtected;
      case 'yourRights':
        return yourRights;
      case 'supervisory':
        return supervisory;
      case 'sharing':
        return sharing;
      case 'deletion':
        return deletion;
      default:
        return super[key];
    }
  }
}

class DataCollectedSectionMessages_ar extends DataCollectedSectionMessages {
  final SectionMessages_ar _parent;
  const DataCollectedSectionMessages_ar(this._parent) : super(_parent);
  String get title => "ما الذي نجمعه";
  String get body =>
      "يبقى ملفك الصحي وأدويتك وسجل الجرعات على هذا الجهاز. لا تخزّن سحابة بلسم سوى هوية حسابك — وليس بياناتك الطبية أبداً.";
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
        return super[key];
    }
  }
}

class HowProtectedSectionMessages_ar extends HowProtectedSectionMessages {
  final SectionMessages_ar _parent;
  const HowProtectedSectionMessages_ar(this._parent) : super(_parent);
  String get title => "كيف نحميها";
  String get body => "كل ما على هذا الجهاز مشفّر. والنسخ الاحتياطية مشفّرة بمفتاح تملكه أنت وحدك.";
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
        return super[key];
    }
  }
}

class YourRightsSectionMessages_ar extends YourRightsSectionMessages {
  final SectionMessages_ar _parent;
  const YourRightsSectionMessages_ar(this._parent) : super(_parent);
  String get title => "حقوقك";
  String get body => "يمكنك تصدير بياناتك أو نسخها احتياطياً أو حذفها نهائياً في أي وقت من الإعدادات.";
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
        return super[key];
    }
  }
}

class SupervisorySectionMessages_ar extends SupervisorySectionMessages {
  final SectionMessages_ar _parent;
  const SupervisorySectionMessages_ar(this._parent) : super(_parent);
  String get title => "الجهة الرقابية";
  String body(String authority) => "يمكن رفع شكاوى حماية البيانات إلى $authority.";
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
        return super[key];
    }
  }
}

class SharingSectionMessages_ar extends SharingSectionMessages {
  final SectionMessages_ar _parent;
  const SharingSectionMessages_ar(this._parent) : super(_parent);
  String get title => "المشاركة";
  String get body =>
      "لا تتم مشاركة أي شيء دون إجراء صريح منك. تُشارك بيانات بطاقة الطوارئ فقط عبر روابط QR تنشئها ويمكنك إلغاؤها.";
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
        return super[key];
    }
  }
}

class DeletionSectionMessages_ar extends DeletionSectionMessages {
  final SectionMessages_ar _parent;
  const DeletionSectionMessages_ar(this._parent) : super(_parent);
  String get title => "الحذف";
  String get body => "طلب حذف الحساب يزيل حسابك السحابي بعد فترة سماح؛ وتُمحى بيانات هذا الجهاز عند تسجيل الخروج.";
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
        return super[key];
    }
  }
}

class AuthorityMessages_ar extends AuthorityMessages {
  final Messages_ar _parent;
  const AuthorityMessages_ar(this._parent) : super(_parent);
  String get eg => "وزارة الصحة والسكان المصرية";
  String get sa => "وزارة الصحة السعودية";
  String get ae => "وزارة الصحة ووقاية المجتمع الإماراتية";
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
      default:
        return super[key];
    }
  }
}
