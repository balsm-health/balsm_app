// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  AccountMessages get account => AccountMessages(this);
  HandleMessages get handle => HandleMessages(this);
  String get backupTitle => "Backup & sync";
  String get backupStatus => "Status";
  String get backupNow => "Back up now";
  String get viewRecoveryCode => "View recovery code";
  String get rotateRecoveryCode => "Rotate recovery code";
  String get backupExplainer =>
      "Your health data is end-to-end encrypted and stored in your own cloud. Only your recovery code can unlock it — Balsm can never read or recover it. Keep your code safe.";
  String get backingUp => "Backing up…";
  String get backupComplete => "Backup complete";
  String get noBackupYet => "No backup set up yet — tap \"Back up now\".";
  String get rotateTitle => "Rotate recovery code?";
  String get rotateBody =>
      "A new code will be generated and your backup re-encrypted. Your old code stops working immediately. Save the new one.";
  String get rotateAction => "Rotate";
  String get confirmIdentityTitle => "Confirm your identity";
  String get confirmIdentityBody =>
      "Changing your country requires confirming your identity. You will be asked to re-authenticate.";
  String get privacyDisclosureTitle => "Privacy disclosure";
  String privacyDisclosureBody(String authority) =>
      "Your data is now governed under $authority. Please review the updated privacy terms.";
  String get iUnderstand => "I understand";
  String get loadError => "Could not load account.";
  String get noAccount => "No account.";
  String get countryWarning => "Changing country requires confirming identity.";
  String get languageIntro => "Choose your preferred language.";
  String get handleFormatHint => "3-30 characters: a-z, 0-9, _ or .";
  String get handleCheckFailed => "Could not check availability";
  String get claimTitle => "Claim your handle";
  String get claimIntro => "Pick a unique @handle. People can find you with it.";
  String get suggestions => "Suggestions";
  String get claimAction => "Claim handle";
  String get sectionAccount => "Account";
  String get sectionBackup => "Backup";
  String get sectionPrivacy => "Privacy";
  String get sectionEmergency => "Emergency";
  String get rowHandle => "Handle";
  String get notSet => "Not set";
  String get rowSessions => "Sessions";
  String get rowDeleteAccount => "Delete Account";
  String get rowEmergencyCard => "Emergency Card";
  String get notAvailableYet => "Not available yet.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AccountMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AccountMessages(this._parent);
  String get settings => "Settings";
  String get country => "Country";
  String get language => "Language";
  String get offline => "You're offline. This needs a connection.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class HandleMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const HandleMessages(this._parent);
  String get title => "Choose your handle";
  String get available => "Available";
  String get taken => "Already taken";
  String get invalid => "Invalid handle";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
