// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  ListMessages get list => ListMessages(this);
  String get add => "Add medication";
  TodayMessages get today => TodayMessages(this);
  OutcomeMessages get outcome => OutcomeMessages(this);
  NotificationMessages get notification => NotificationMessages(this);
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
