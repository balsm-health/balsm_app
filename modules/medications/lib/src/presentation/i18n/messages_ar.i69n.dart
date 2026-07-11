// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  ListMessages_ar get list => ListMessages_ar(this);
  String get add => "إضافة دواء";
  TodayMessages_ar get today => TodayMessages_ar(this);
  OutcomeMessages_ar get outcome => OutcomeMessages_ar(this);
  NotificationMessages_ar get notification => NotificationMessages_ar(this);
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

class ListMessages_ar extends ListMessages {
  final Messages_ar _parent;
  const ListMessages_ar(this._parent) : super(_parent);
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

class TodayMessages_ar extends TodayMessages {
  final Messages_ar _parent;
  const TodayMessages_ar(this._parent) : super(_parent);
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

class OutcomeMessages_ar extends OutcomeMessages {
  final Messages_ar _parent;
  const OutcomeMessages_ar(this._parent) : super(_parent);
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

class NotificationMessages_ar extends NotificationMessages {
  final Messages_ar _parent;
  const NotificationMessages_ar(this._parent) : super(_parent);
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
