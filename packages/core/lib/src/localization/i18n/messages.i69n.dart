// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  CommonMessages get common => CommonMessages(this);
  ErrorMessages get error => ErrorMessages(this);
  NotfoundMessages get notfound => NotfoundMessages(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'common':
        return common;
      case 'error':
        return error;
      case 'notfound':
        return notfound;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CommonMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const CommonMessages(this._parent);
  String get continue_ => "Continue";
  String get back => "Back";
  String get cancel => "Cancel";
  String get confirm => "Confirm";
  String get next => "Next";
  String get done => "Done";
  String get retry => "Retry";
  String get save => "Save";
  String get delete => "Delete";
  String get edit => "Edit";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'continue_':
        return continue_;
      case 'back':
        return back;
      case 'cancel':
        return cancel;
      case 'confirm':
        return confirm;
      case 'next':
        return next;
      case 'done':
        return done;
      case 'retry':
        return retry;
      case 'save':
        return save;
      case 'delete':
        return delete;
      case 'edit':
        return edit;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ErrorMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const ErrorMessages(this._parent);
  String get network => "Network error. Please check your connection.";
  String get unknown => "Something went wrong. Please try again.";
  String get validation => "Please check the information you entered.";
  String get geofence => "This service is not available in your region.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'network':
        return network;
      case 'unknown':
        return unknown;
      case 'validation':
        return validation;
      case 'geofence':
        return geofence;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NotfoundMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const NotfoundMessages(this._parent);
  String get title => "Page not found";
  String get body => "The page you are looking for does not exist.";
  String get cta => "Go home";
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
      case 'cta':
        return cta;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
