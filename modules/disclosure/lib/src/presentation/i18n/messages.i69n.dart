// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  String get title => "Important notice";
  String get subtitle => "How Balsm handles your health data";
  String get scroll => "Scroll to read the full notice";
  String get scrollToContinue => "Scroll to the end to continue";
  String get accept => "I have read and accept";
  SectionMessages get section => SectionMessages(this);
  AuthorityMessages get authority => AuthorityMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SectionMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const SectionMessages(this._parent);
  DataCollectedSectionMessages get dataCollected =>
      DataCollectedSectionMessages(this);
  HowProtectedSectionMessages get howProtected =>
      HowProtectedSectionMessages(this);
  YourRightsSectionMessages get yourRights => YourRightsSectionMessages(this);
  SupervisorySectionMessages get supervisory =>
      SupervisorySectionMessages(this);
  SharingSectionMessages get sharing => SharingSectionMessages(this);
  DeletionSectionMessages get deletion => DeletionSectionMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class DataCollectedSectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const DataCollectedSectionMessages(this._parent);
  String get title => "What we collect";
  String get body =>
      "Your health profile, medications, and dose history stay on this device. Balsm's cloud stores only your account identity — never your medical data.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class HowProtectedSectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const HowProtectedSectionMessages(this._parent);
  String get title => "How it's protected";
  String get body =>
      "Everything on this device is encrypted. Backups are encrypted with a key that only you hold.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class YourRightsSectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const YourRightsSectionMessages(this._parent);
  String get title => "Your rights";
  String get body =>
      "You can export, back up, or permanently delete your data at any time from Settings.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SupervisorySectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const SupervisorySectionMessages(this._parent);
  String get title => "Supervisory authority";
  String body(String authority) =>
      "Data protection complaints may be raised with $authority.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SharingSectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const SharingSectionMessages(this._parent);
  String get title => "Sharing";
  String get body =>
      "Nothing is shared without your explicit action. Emergency-card data is shared only through QR links you create and can revoke.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class DeletionSectionMessages implements i69n.I69nMessageBundle {
  final SectionMessages _parent;
  const DeletionSectionMessages(this._parent);
  String get title => "Deletion";
  String get body =>
      "Requesting account deletion removes your cloud account after a grace period; data on this device is wiped at sign-out.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'title':
        return title;
      case 'body':
        return body;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AuthorityMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const AuthorityMessages(this._parent);
  String get eg => "Egyptian Ministry of Health and Population";
  String get sa => "Saudi Ministry of Health";
  String get ae => "UAE Ministry of Health and Prevention";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'eg':
        return eg;
      case 'sa':
        return sa;
      case 'ae':
        return ae;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
