// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

String _plural(int count, {String? zero, String? one, String? two, String? few, String? many, String? other}) =>
    i69n.plural(count, _languageCode, zero: zero, one: one, two: two, few: few, many: many, other: other);

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  ListMessages get list => ListMessages(this);
  String get add => "Add medication";
  TodayMessages get today => TodayMessages(this);
  OutcomeMessages get outcome => OutcomeMessages(this);
  NotificationMessages get notification => NotificationMessages(this);
  String get fieldName => "Name";
  String get fieldNameHint => "e.g. Amoxicillin";
  String get fieldDose => "Dose amount";
  String get fieldDoseHint => "e.g. 500 mg";
  String get schedule => "Schedule";
  String get scheduleDaily => "Daily";
  String get scheduleWeekly => "Weekly";
  String get scheduleCustom => "Custom";
  String get reminderTimes => "Reminder times";
  String get addTime => "Add time";
  String get startDate => "Start date";
  String get endDate => "End date";
  String get endDateOptional => "End date (optional)";
  String get controlledSubstance => "Controlled substance";
  String get saveMedication => "Save medication";
  String get nameRequired => "Name is required";
  String get selectDay => "Select at least one day";
  String get saveError => "Could not save medication";
  String get removeTime => "Remove time";
  String get dateNotSet => "Set";
  String get dayInitials => "M|T|W|T|F|S|S";
  String get weekdaysShort => "Mon|Tue|Wed|Thu|Fri|Sat|Sun";
  String get historyTitle => "Dose history";
  String get historyLoadError => "Could not load dose history.";
  String get historyEmpty => "No dose history yet.";
  String snoozedUntil(String time) => "Snoozed until $time";
  String get correction => "Correction";
  String get listTitle => "Medications";
  String get addShort => "Add";
  String get listLoadError => "Could not load medications.";
  String get controlled => "Controlled";
  String get inactive => "Inactive";
  String get active => "Active";
  String get listEmptyBody => "Add your first medication to start tracking doses.";
  String scheduleDailyAt(String times) => "Daily · $times";
  String scheduleOnceAt(String times) => "Once · $times";
  String scheduleEveryHours(int n, String times) => "Every ${n}h from $times";
  String scheduleEveryDays(int n, String times) => "Every ${_plural(n, one: 'day', other: '$n days')} · $times";
  String get todayLoadError => "Could not load today's doses.";
  String get todayEmpty => "No doses scheduled today.";
  String get recordError => "Could not record dose";
  String get snooze => "Snooze";
  String get skip => "Skip";
  String get take => "Take";
  String get missedBanner => "You have missed doses today. Review and update them below.";
  String get dedupBody => "Some dose entries appeared twice and were merged. Review your today list.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ListMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const ListMessages(this._parent);
  String get empty => "No medications yet";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'empty':
        return empty;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class TodayMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const TodayMessages(this._parent);
  String get title => "Today's medications";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class OutcomeMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const OutcomeMessages(this._parent);
  String get taken => "Taken";
  String get skipped => "Skipped";
  String get snoozed => "Snoozed";
  String get missed => "Missed";
  String get corrected => "Corrected";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NotificationMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const NotificationMessages(this._parent);
  String get body => "Time to check your medications";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
