// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);

class Messages_ar extends Messages {
  const Messages_ar();
  String get title => "حذف الحساب";
  String get confirm => "تأكيد الحذف";
  String get cancelled => "تم إلغاء الحذف";
  String get publicTitle => "حذف حسابك";
  String get verifyHeading => "تأكيد هويتك";
  String get verifyBody => "نرسل رمزًا لمرة واحدة حتى لا يتمكن غيرك من حذف حسابك.";
  String get verifyContinue => "متابعة";
  String get sendCode => "أرسل لي رمزًا";
  String get sendCodeAgain => "أرسل رمزًا جديدًا";
  String get otpLabel => "الرمز لمرة واحدة";
  String get publicCancelTitle => "إلغاء حذف الحساب";
  String get publicCancelAction => "إلغاء الحذف";
  String get dataHeading => "ما الذي يحدث لبياناتك";
  String get dataIntro => "حذف حسابك نهائي. إليك بالضبط ما يُحتفظ به وما يُحذف وما يُمسح.";
  String get columnRetained => "يُحتفظ به";
  String get columnDeleted => "يُحذف";
  String get columnWiped => "يُمسح";
  String get itemDisclosureRecord => "سجل الإفصاح";
  String get itemDeletionLog => "سجل الحذف";
  String get itemAccount => "الحساب";
  String get itemHandle => "اسم المستخدم";
  String get itemSessions => "الجلسات";
  String get itemCareTeamCloud => "فريق الرعاية (النسخة السحابية)";
  String get itemPhiDevice => "كل البيانات الصحية على الجهاز";
  String get itemCareTeam => "فريق الرعاية";
  String get itemPhiServer => "كل البيانات الصحية على الخادم (بعد فترة السماح)";
  String get requestDeletion => "طلب حذف الحساب";
  String get safeBody => "حسابك بأمان. لم يُحذف أي شيء.";
  String get returnHome => "العودة إلى الرئيسية";
  String get scheduledTitle => "تمت جدولة الحذف";
  String get areYouSure => "هل أنت متأكد؟";
  String get scheduledBody => "لا يزال بإمكانك الإلغاء حتى تنتهي فترة السماح.";
  String get confirmBody => "سيؤدي هذا إلى جدولة حذف حسابك نهائيًا. يمكنك الإلغاء في أي وقت قبل انتهاء فترة السماح.";
  String get confirmAction => "نعم، احذف حسابي";
  String get scheduledFor => "موعد الحذف";
  String get graceEnded => "انتهت فترة السماح";
  String remainingDays(int days, int hours) =>
      "متبقٍ ${_plural(days, one: 'يوم واحد', two: 'يومان', few: '$days أيام', many: '$days يومًا', other: '$days يوم')} و${_plural(hours, zero: '0 ساعة', one: 'ساعة واحدة', two: 'ساعتان', few: '$hours ساعات', many: '$hours ساعة', other: '$hours ساعة')}";
  String remainingTime(int hours, int minutes, int seconds) => "متبقٍ $hours س $minutes د $seconds ث";
  String get welcomeBack => "مرحبًا بعودتك";
  String scheduledOn(String date) => "حسابك مجدول للحذف في $date.";
  String get changedMind => "غيّرت رأيك؟ يمكنك إلغاء الحذف والاحتفاظ بحسابك.";
  String get soon => "قريبًا";
  String get publicConfirmBody => "سيؤدي هذا إلى جدولة حذف حسابك نهائيًا. يمكنك الإلغاء خلال فترة السماح.";
  String deletedOn(String date) => "سيُحذف حسابك نهائيًا في $date.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'dataHeading':
        return dataHeading;
      case 'dataIntro':
        return dataIntro;
      case 'columnRetained':
        return columnRetained;
      case 'columnDeleted':
        return columnDeleted;
      case 'columnWiped':
        return columnWiped;
      case 'itemDisclosureRecord':
        return itemDisclosureRecord;
      case 'itemDeletionLog':
        return itemDeletionLog;
      case 'itemAccount':
        return itemAccount;
      case 'itemHandle':
        return itemHandle;
      case 'itemSessions':
        return itemSessions;
      case 'itemCareTeamCloud':
        return itemCareTeamCloud;
      case 'itemPhiDevice':
        return itemPhiDevice;
      case 'itemCareTeam':
        return itemCareTeam;
      case 'itemPhiServer':
        return itemPhiServer;
      case 'requestDeletion':
        return requestDeletion;
      case 'safeBody':
        return safeBody;
      case 'returnHome':
        return returnHome;
      case 'scheduledTitle':
        return scheduledTitle;
      case 'areYouSure':
        return areYouSure;
      case 'scheduledBody':
        return scheduledBody;
      case 'confirmBody':
        return confirmBody;
      case 'confirmAction':
        return confirmAction;
      case 'scheduledFor':
        return scheduledFor;
      case 'graceEnded':
        return graceEnded;
      case 'remainingDays':
        return remainingDays;
      case 'remainingTime':
        return remainingTime;
      case 'welcomeBack':
        return welcomeBack;
      case 'scheduledOn':
        return scheduledOn;
      case 'changedMind':
        return changedMind;
      case 'soon':
        return soon;
      case 'publicConfirmBody':
        return publicConfirmBody;
      case 'deletedOn':
        return deletedOn;
      default:
        return super[key];
    }
  }
}
