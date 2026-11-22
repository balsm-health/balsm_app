// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  AccountMessages_ar get account => AccountMessages_ar(this);
  HandleMessages_ar get handle => HandleMessages_ar(this);
  String get backupTitle => "النسخ الاحتياطي والمزامنة";
  String get backupStatus => "الحالة";
  String get backupNow => "نسخ احتياطي الآن";
  String get viewRecoveryCode => "عرض رمز الاسترداد";
  String get rotateRecoveryCode => "تغيير رمز الاسترداد";
  String get backupExplainer =>
      "بياناتك الصحية مشفّرة من طرف إلى طرف ومخزّنة في حسابك السحابي. لا يفتحها إلا رمز الاسترداد، ولا يمكن لبلسم قراءتها أو استعادتها أبدًا. احتفظ برمزك في مكان آمن.";
  String get backingUp => "جارٍ النسخ الاحتياطي…";
  String get backupComplete => "اكتمل النسخ الاحتياطي";
  String get noBackupYet => "لم يتم إعداد نسخة احتياطية بعد. اضغط \"نسخ احتياطي الآن\".";
  String get rotateTitle => "تغيير رمز الاسترداد؟";
  String get rotateBody =>
      "سيُنشأ رمز جديد ويُعاد تشفير نسختك الاحتياطية. سيتوقف الرمز القديم عن العمل فورًا. احفظ الرمز الجديد.";
  String get rotateAction => "تغيير";
  String get confirmIdentityTitle => "تأكيد هويتك";
  String get confirmIdentityBody => "يتطلب تغيير بلدك تأكيد هويتك. سيُطلب منك تسجيل الدخول مجددًا.";
  String get privacyDisclosureTitle => "إفصاح الخصوصية";
  String privacyDisclosureBody(String authority) =>
      "تخضع بياناتك الآن لإشراف $authority. يرجى مراجعة شروط الخصوصية المحدّثة.";
  String get iUnderstand => "فهمت";
  String get loadError => "تعذّر تحميل الحساب.";
  String get noAccount => "لا يوجد حساب.";
  String get countryWarning => "يتطلب تغيير البلد تأكيد الهوية.";
  String get languageIntro => "اختر لغتك المفضلة.";
  String get handleFormatHint => "من 3 إلى 30 حرفًا: a-z و0-9 و_ أو .";
  String get handleCheckFailed => "تعذّر التحقق من التوفر";
  String get claimTitle => "احجز اسم المستخدم";
  String get claimIntro => "اختر @اسم مستخدم فريدًا. يمكن للآخرين العثور عليك به.";
  String get suggestions => "اقتراحات";
  String get claimAction => "حجز الاسم";
  String get sectionAccount => "الحساب";
  String get sectionBackup => "النسخ الاحتياطي";
  String get sectionPrivacy => "الخصوصية";
  String get sectionEmergency => "الطوارئ";
  String get rowHandle => "اسم المستخدم";
  String get notSet => "غير محدد";
  String get rowSessions => "الجلسات";
  String get rowDeleteAccount => "حذف الحساب";
  String get rowEmergencyCard => "بطاقة الطوارئ";
  String get notAvailableYet => "غير متاح بعد.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'account':
        return account;
      case 'handle':
        return handle;
      case 'backupTitle':
        return backupTitle;
      case 'backupStatus':
        return backupStatus;
      case 'backupNow':
        return backupNow;
      case 'viewRecoveryCode':
        return viewRecoveryCode;
      case 'rotateRecoveryCode':
        return rotateRecoveryCode;
      case 'backupExplainer':
        return backupExplainer;
      case 'backingUp':
        return backingUp;
      case 'backupComplete':
        return backupComplete;
      case 'noBackupYet':
        return noBackupYet;
      case 'rotateTitle':
        return rotateTitle;
      case 'rotateBody':
        return rotateBody;
      case 'rotateAction':
        return rotateAction;
      case 'confirmIdentityTitle':
        return confirmIdentityTitle;
      case 'confirmIdentityBody':
        return confirmIdentityBody;
      case 'privacyDisclosureTitle':
        return privacyDisclosureTitle;
      case 'privacyDisclosureBody':
        return privacyDisclosureBody;
      case 'iUnderstand':
        return iUnderstand;
      case 'loadError':
        return loadError;
      case 'noAccount':
        return noAccount;
      case 'countryWarning':
        return countryWarning;
      case 'languageIntro':
        return languageIntro;
      case 'handleFormatHint':
        return handleFormatHint;
      case 'handleCheckFailed':
        return handleCheckFailed;
      case 'claimTitle':
        return claimTitle;
      case 'claimIntro':
        return claimIntro;
      case 'suggestions':
        return suggestions;
      case 'claimAction':
        return claimAction;
      case 'sectionAccount':
        return sectionAccount;
      case 'sectionBackup':
        return sectionBackup;
      case 'sectionPrivacy':
        return sectionPrivacy;
      case 'sectionEmergency':
        return sectionEmergency;
      case 'rowHandle':
        return rowHandle;
      case 'notSet':
        return notSet;
      case 'rowSessions':
        return rowSessions;
      case 'rowDeleteAccount':
        return rowDeleteAccount;
      case 'rowEmergencyCard':
        return rowEmergencyCard;
      case 'notAvailableYet':
        return notAvailableYet;
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
  String get offline => "لا يوجد اتصال. هذا يحتاج إلى إنترنت.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'settings':
        return settings;
      case 'country':
        return country;
      case 'language':
        return language;
      case 'offline':
        return offline;
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
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
