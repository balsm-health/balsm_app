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
  String get title => "Active sessions";
  String get current => "Current session";
  String get revoke => "Sign out";
  String get offline => "Sign-in activity needs a connection.";
  String get loadError => "Could not load sessions.";
  String get signOutAll => "Sign out everywhere";
  String get signOutAllTitle => "Sign out everywhere?";
  String get signOutAllBody =>
      "This revokes every session on all devices, including this one. You will need to sign in again.";
  String signedOutCount(int n) => "Signed out of ${_plural(n, one: '1 session', other: '$n sessions')}.";
  String get empty => "No active sessions.";
  String get thisDevice => "This device";
  String get revokeTitle => "Revoke session?";
  String revokeBody(String device) => "Sign out \"$device\"? That device will need to sign in again.";
  String get revokeAction => "Revoke";
  String get revoked => "Session revoked.";
  String firstSeen(String date) => "First seen $date";
  String lastActive(String time) => "Active $time";
  String get deviceGeneric => "Device";
  String get deviceWeb => "Web";
  String get deviceDesktop => "Desktop";
  String get justNow => "just now";
  String minutesAgo(int n) => "${_plural(n, one: '1 minute ago', other: '$n minutes ago')}";
  String hoursAgo(int n) => "${_plural(n, one: '1 hour ago', other: '$n hours ago')}";
  String daysAgo(int n) => "${_plural(n, one: '1 day ago', other: '$n days ago')}";
  String weeksAgo(int n) => "${_plural(n, one: '1 week ago', other: '$n weeks ago')}";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'current':
        return current;
      case 'revoke':
        return revoke;
      case 'offline':
        return offline;
      case 'loadError':
        return loadError;
      case 'signOutAll':
        return signOutAll;
      case 'signOutAllTitle':
        return signOutAllTitle;
      case 'signOutAllBody':
        return signOutAllBody;
      case 'signedOutCount':
        return signedOutCount;
      case 'empty':
        return empty;
      case 'thisDevice':
        return thisDevice;
      case 'revokeTitle':
        return revokeTitle;
      case 'revokeBody':
        return revokeBody;
      case 'revokeAction':
        return revokeAction;
      case 'revoked':
        return revoked;
      case 'firstSeen':
        return firstSeen;
      case 'lastActive':
        return lastActive;
      case 'deviceGeneric':
        return deviceGeneric;
      case 'deviceWeb':
        return deviceWeb;
      case 'deviceDesktop':
        return deviceDesktop;
      case 'justNow':
        return justNow;
      case 'minutesAgo':
        return minutesAgo;
      case 'hoursAgo':
        return hoursAgo;
      case 'daysAgo':
        return daysAgo;
      case 'weeksAgo':
        return weeksAgo;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
