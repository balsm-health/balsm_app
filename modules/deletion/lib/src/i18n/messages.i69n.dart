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
  String get title => "Delete account";
  String get confirm => "Confirm deletion";
  String get cancelled => "Deletion cancelled";
  String get publicTitle => "Delete your account";
  String get verifyHeading => "Verify it is you";
  String get verifyBody => "We send a one-time code so nobody else can delete your account.";
  String get verifyContinue => "Continue";
  String get sendCode => "Send me a code";
  String get sendCodeAgain => "Send a new code";
  String get otpLabel => "One-time code";
  String get publicCancelTitle => "Cancel account deletion";
  String get publicCancelAction => "Cancel deletion";
  String get dataHeading => "What happens to your data";
  String get dataIntro => "Deleting your account is permanent. Here is exactly what is kept, removed, and wiped.";
  String get columnRetained => "Retained";
  String get columnDeleted => "Deleted";
  String get columnWiped => "Wiped";
  String get itemDisclosureRecord => "Disclosure record";
  String get itemDeletionLog => "Deletion log";
  String get itemAccount => "Account";
  String get itemHandle => "Handle";
  String get itemSessions => "Sessions";
  String get itemCareTeamCloud => "Care team (cloud copy)";
  String get itemPhiDevice => "All PHI on device";
  String get itemCareTeam => "Care team";
  String get itemPhiServer => "All PHI on server (after grace)";
  String get requestDeletion => "Request account deletion";
  String get safeBody => "Your account is safe. Nothing was deleted.";
  String get returnHome => "Return to home";
  String get scheduledTitle => "Deletion scheduled";
  String get areYouSure => "Are you sure?";
  String get scheduledBody => "You can still cancel until the grace period ends.";
  String get confirmBody =>
      "This schedules your account for permanent deletion. You can cancel any time before the grace period ends.";
  String get confirmAction => "Yes, delete my account";
  String get scheduledFor => "Deletion scheduled for";
  String get graceEnded => "Grace period has ended";
  String remainingDays(int days, int hours) =>
      "${_plural(days, one: '1 day', other: '$days days')}, ${_plural(hours, one: '1 hour', other: '$hours hours')} remaining";
  String remainingTime(int hours, int minutes, int seconds) => "${hours}h ${minutes}m ${seconds}s remaining";
  String get welcomeBack => "Welcome back";
  String scheduledOn(String date) => "Your account is scheduled for deletion on $date.";
  String get changedMind => "Changed your mind? You can cancel the deletion and keep your account.";
  String get soon => "soon";
  String get publicConfirmBody =>
      "This permanently schedules your account for deletion. You can cancel during the grace period.";
  String deletedOn(String date) => "Your account will be permanently deleted on $date.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
