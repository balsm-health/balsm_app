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
  ListMessages_ar get list => ListMessages_ar(this);
  String get add => "إضافة دواء";
  TodayMessages_ar get today => TodayMessages_ar(this);
  OutcomeMessages_ar get outcome => OutcomeMessages_ar(this);
  NotificationMessages_ar get notification => NotificationMessages_ar(this);
  String get fieldName => "الاسم";
  String get fieldNameHint => "مثال: أموكسيسيلين";
  String get fieldDose => "الجرعة";
  String get fieldDoseHint => "مثال: 500 ملغ";
  String get schedule => "الجدول";
  String get scheduleDaily => "يوميًا";
  String get scheduleWeekly => "أسبوعيًا";
  String get scheduleCustom => "مخصص";
  String get reminderTimes => "أوقات التذكير";
  String get addTime => "إضافة وقت";
  String get startDate => "تاريخ البدء";
  String get endDate => "تاريخ الانتهاء";
  String get endDateOptional => "تاريخ الانتهاء (اختياري)";
  String get controlledSubstance => "مادة خاضعة للرقابة";
  String get saveMedication => "حفظ الدواء";
  String get nameRequired => "الاسم مطلوب";
  String get selectDay => "اختر يومًا واحدًا على الأقل";
  String get saveError => "تعذّر حفظ الدواء";
  String get removeTime => "إزالة الوقت";
  String get dateNotSet => "تحديد";
  String get dayInitials => "ن|ث|ر|خ|ج|س|ح";
  String get weekdaysShort => "الإثنين|الثلاثاء|الأربعاء|الخميس|الجمعة|السبت|الأحد";
  String get historyTitle => "سجل الجرعات";
  String get historyLoadError => "تعذّر تحميل سجل الجرعات.";
  String get historyEmpty => "لا يوجد سجل جرعات بعد.";
  String snoozedUntil(String time) => "مؤجلة حتى $time";
  String get correction => "تصحيح";
  String get listTitle => "الأدوية";
  String get addShort => "إضافة";
  String get listLoadError => "تعذّر تحميل الأدوية.";
  String get controlled => "خاضع للرقابة";
  String get inactive => "غير نشط";
  String get active => "نشط";
  String get listEmptyBody => "أضف دواءك الأول لتبدأ بمتابعة الجرعات.";
  String scheduleDailyAt(String times) => "يوميًا · $times";
  String scheduleOnceAt(String times) => "مرة واحدة · $times";
  String scheduleEveryHours(int n, String times) =>
      "كل ${_plural(n, one: 'ساعة', two: 'ساعتين', few: '$n ساعات', many: '$n ساعة', other: '$n ساعة')} بدءًا من $times";
  String scheduleEveryDays(int n, String times) =>
      "كل ${_plural(n, one: 'يوم', two: 'يومين', few: '$n أيام', many: '$n يومًا', other: '$n يوم')} · $times";
  String get todayLoadError => "تعذّر تحميل جرعات اليوم.";
  String get todayEmpty => "لا توجد جرعات مجدولة اليوم.";
  String get recordError => "تعذّر تسجيل الجرعة";
  String get snooze => "تأجيل";
  String get skip => "تخطٍّ";
  String get take => "أخذ";
  String get missedBanner => "فاتتك جرعات اليوم. راجعها وحدّثها أدناه.";
  String get dedupBody => "ظهرت بعض الجرعات مرتين ودُمجت. راجع قائمة اليوم.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'fieldName':
        return fieldName;
      case 'fieldNameHint':
        return fieldNameHint;
      case 'fieldDose':
        return fieldDose;
      case 'fieldDoseHint':
        return fieldDoseHint;
      case 'schedule':
        return schedule;
      case 'scheduleDaily':
        return scheduleDaily;
      case 'scheduleWeekly':
        return scheduleWeekly;
      case 'scheduleCustom':
        return scheduleCustom;
      case 'reminderTimes':
        return reminderTimes;
      case 'addTime':
        return addTime;
      case 'startDate':
        return startDate;
      case 'endDate':
        return endDate;
      case 'endDateOptional':
        return endDateOptional;
      case 'controlledSubstance':
        return controlledSubstance;
      case 'saveMedication':
        return saveMedication;
      case 'nameRequired':
        return nameRequired;
      case 'selectDay':
        return selectDay;
      case 'saveError':
        return saveError;
      case 'removeTime':
        return removeTime;
      case 'dateNotSet':
        return dateNotSet;
      case 'dayInitials':
        return dayInitials;
      case 'weekdaysShort':
        return weekdaysShort;
      case 'historyTitle':
        return historyTitle;
      case 'historyLoadError':
        return historyLoadError;
      case 'historyEmpty':
        return historyEmpty;
      case 'snoozedUntil':
        return snoozedUntil;
      case 'correction':
        return correction;
      case 'listTitle':
        return listTitle;
      case 'addShort':
        return addShort;
      case 'listLoadError':
        return listLoadError;
      case 'controlled':
        return controlled;
      case 'inactive':
        return inactive;
      case 'active':
        return active;
      case 'listEmptyBody':
        return listEmptyBody;
      case 'scheduleDailyAt':
        return scheduleDailyAt;
      case 'scheduleOnceAt':
        return scheduleOnceAt;
      case 'scheduleEveryHours':
        return scheduleEveryHours;
      case 'scheduleEveryDays':
        return scheduleEveryDays;
      case 'todayLoadError':
        return todayLoadError;
      case 'todayEmpty':
        return todayEmpty;
      case 'recordError':
        return recordError;
      case 'snooze':
        return snooze;
      case 'skip':
        return skip;
      case 'take':
        return take;
      case 'missedBanner':
        return missedBanner;
      case 'dedupBody':
        return dedupBody;
      default:
        return super[key];
    }
  }
}

class ListMessages_ar extends ListMessages {
  final Messages_ar _parent;
  const ListMessages_ar(this._parent) : super(_parent);
  String get empty => "لا توجد أدوية بعد";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'empty':
        return empty;
      default:
        return super[key];
    }
  }
}

class TodayMessages_ar extends TodayMessages {
  final Messages_ar _parent;
  const TodayMessages_ar(this._parent) : super(_parent);
  String get title => "أدوية اليوم";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      default:
        return super[key];
    }
  }
}

class OutcomeMessages_ar extends OutcomeMessages {
  final Messages_ar _parent;
  const OutcomeMessages_ar(this._parent) : super(_parent);
  String get taken => "تم التناول";
  String get skipped => "تم التخطي";
  String get snoozed => "مؤجل";
  String get missed => "فائت";
  String get corrected => "مُصحَّح";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'corrected':
        return corrected;
      default:
        return super[key];
    }
  }
}

class NotificationMessages_ar extends NotificationMessages {
  final Messages_ar _parent;
  const NotificationMessages_ar(this._parent) : super(_parent);
  String get body => "حان وقت مراجعة أدويتك";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'body':
        return body;
      default:
        return super[key];
    }
  }
}
