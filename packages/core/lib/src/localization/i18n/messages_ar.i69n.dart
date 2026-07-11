// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  CommonMessages_ar get common => CommonMessages_ar(this);
  ErrorMessages_ar get error => ErrorMessages_ar(this);
  NotfoundMessages_ar get notfound => NotfoundMessages_ar(this);
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
        return super[key];
    }
  }
}

class CommonMessages_ar extends CommonMessages {
  final Messages_ar _parent;
  const CommonMessages_ar(this._parent) : super(_parent);
  String get continue_ => "متابعة";
  String get back => "رجوع";
  String get cancel => "إلغاء";
  String get confirm => "تأكيد";
  String get next => "التالي";
  String get done => "تم";
  String get retry => "إعادة المحاولة";
  String get save => "حفظ";
  String get delete => "حذف";
  String get edit => "تعديل";
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
        return super[key];
    }
  }
}

class ErrorMessages_ar extends ErrorMessages {
  final Messages_ar _parent;
  const ErrorMessages_ar(this._parent) : super(_parent);
  String get network => "خطأ في الشبكة. تحقق من اتصالك.";
  String get unknown => "حدث خطأ ما. حاول مرة أخرى.";
  String get validation => "يرجى التحقق من المعلومات التي أدخلتها.";
  String get geofence => "هذه الخدمة غير متاحة في منطقتك.";
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
        return super[key];
    }
  }
}

class NotfoundMessages_ar extends NotfoundMessages {
  final Messages_ar _parent;
  const NotfoundMessages_ar(this._parent) : super(_parent);
  String get title => "الصفحة غير موجودة";
  String get body => "الصفحة التي تبحث عنها غير موجودة.";
  String get cta => "العودة للرئيسية";
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
        return super[key];
    }
  }
}
