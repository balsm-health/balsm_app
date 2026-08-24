// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'messages.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Messages_ar extends Messages {
  const Messages_ar();
  BodyMessages_ar get body => BodyMessages_ar(this);
  TissueMessages_ar get tissue => TissueMessages_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'body':
        return body;
      case 'tissue':
        return tissue;
      default:
        return super[key];
    }
  }
}

class BodyMessages_ar extends BodyMessages {
  final Messages_ar _parent;
  const BodyMessages_ar(this._parent) : super(_parent);
  String get head => "الرأس";
  String get neck => "الرقبة";
  String get l_shoulder => "كتف أيسر";
  String get r_shoulder => "كتف أيمن";
  String get chest => "الصدر";
  String get l_upper_arm => "عضد أيسر";
  String get r_upper_arm => "عضد أيمن";
  String get abdomen => "البطن";
  String get l_elbow => "مرفق أيسر";
  String get r_elbow => "مرفق أيمن";
  String get l_forearm => "ساعد أيسر";
  String get r_forearm => "ساعد أيمن";
  String get pelvis => "الحوض";
  String get l_hand => "يد يسرى";
  String get r_hand => "يد يمنى";
  String get l_thigh => "فخذ أيسر";
  String get r_thigh => "فخذ أيمن";
  String get l_knee => "ركبة يسرى";
  String get r_knee => "ركبة يمنى";
  String get l_shin => "ساق يسرى";
  String get r_shin => "ساق يمنى";
  String get l_foot => "قدم يسرى";
  String get r_foot => "قدم يمنى";
  String get bk_head => "الرأس";
  String get bk_neck => "الرقبة";
  String get bk_l_shoulder => "كتف أيسر";
  String get bk_r_shoulder => "كتف أيمن";
  String get bk_upper => "أعلى الظهر";
  String get bk_mid => "وسط الظهر";
  String get bk_lower => "أسفل الظهر";
  String get bk_l_glute => "أرداف أيسر";
  String get bk_r_glute => "أرداف أيمن";
  String get bk_l_hamstr => "أوتار ركبة يسرى";
  String get bk_r_hamstr => "أوتار ركبة يمنى";
  String get bk_l_calf => "بطة ساق يسرى";
  String get bk_r_calf => "بطة ساق يمنى";
  String get bk_l_heel => "كعب أيسر";
  String get bk_r_heel => "كعب أيمن";
  String get sinuses => "الجيوب الأنفية";
  String get l_eye => "عين يسرى";
  String get r_eye => "عين يمنى";
  String get l_ear => "أذن يسرى";
  String get r_ear => "أذن يمنى";
  String get jaw => "الفك";
  String get bk_l_ear => "أذن يسرى";
  String get bk_r_ear => "أذن يمنى";
  String get heart => "القلب";
  String get l_lung => "رئة يسرى";
  String get r_lung => "رئة يمنى";
  String get stomach => "المعدة";
  String get liver => "الكبد";
  String get intestines => "الأمعاء";
  String get bladder => "المثانة";
  String get l_kidney => "كلية يسرى";
  String get r_kidney => "كلية يمنى";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'head':
        return head;
      case 'neck':
        return neck;
      case 'l_shoulder':
        return l_shoulder;
      case 'r_shoulder':
        return r_shoulder;
      case 'chest':
        return chest;
      case 'l_upper_arm':
        return l_upper_arm;
      case 'r_upper_arm':
        return r_upper_arm;
      case 'abdomen':
        return abdomen;
      case 'l_elbow':
        return l_elbow;
      case 'r_elbow':
        return r_elbow;
      case 'l_forearm':
        return l_forearm;
      case 'r_forearm':
        return r_forearm;
      case 'pelvis':
        return pelvis;
      case 'l_hand':
        return l_hand;
      case 'r_hand':
        return r_hand;
      case 'l_thigh':
        return l_thigh;
      case 'r_thigh':
        return r_thigh;
      case 'l_knee':
        return l_knee;
      case 'r_knee':
        return r_knee;
      case 'l_shin':
        return l_shin;
      case 'r_shin':
        return r_shin;
      case 'l_foot':
        return l_foot;
      case 'r_foot':
        return r_foot;
      case 'bk_head':
        return bk_head;
      case 'bk_neck':
        return bk_neck;
      case 'bk_l_shoulder':
        return bk_l_shoulder;
      case 'bk_r_shoulder':
        return bk_r_shoulder;
      case 'bk_upper':
        return bk_upper;
      case 'bk_mid':
        return bk_mid;
      case 'bk_lower':
        return bk_lower;
      case 'bk_l_glute':
        return bk_l_glute;
      case 'bk_r_glute':
        return bk_r_glute;
      case 'bk_l_hamstr':
        return bk_l_hamstr;
      case 'bk_r_hamstr':
        return bk_r_hamstr;
      case 'bk_l_calf':
        return bk_l_calf;
      case 'bk_r_calf':
        return bk_r_calf;
      case 'bk_l_heel':
        return bk_l_heel;
      case 'bk_r_heel':
        return bk_r_heel;
      case 'sinuses':
        return sinuses;
      case 'l_eye':
        return l_eye;
      case 'r_eye':
        return r_eye;
      case 'l_ear':
        return l_ear;
      case 'r_ear':
        return r_ear;
      case 'jaw':
        return jaw;
      case 'bk_l_ear':
        return bk_l_ear;
      case 'bk_r_ear':
        return bk_r_ear;
      case 'heart':
        return heart;
      case 'l_lung':
        return l_lung;
      case 'r_lung':
        return r_lung;
      case 'stomach':
        return stomach;
      case 'liver':
        return liver;
      case 'intestines':
        return intestines;
      case 'bladder':
        return bladder;
      case 'l_kidney':
        return l_kidney;
      case 'r_kidney':
        return r_kidney;
      default:
        return super[key];
    }
  }
}

class TissueMessages_ar extends TissueMessages {
  final Messages_ar _parent;
  const TissueMessages_ar(this._parent) : super(_parent);
  String get skin => "الجلد";
  String get muscle => "العضل";
  String get bone => "العظم";
  String get joint => "المفصل";
  String get tendon => "الوتر";
  String get nerve => "العصب";
  String get organ => "العضو";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'skin':
        return skin;
      case 'muscle':
        return muscle;
      case 'bone':
        return bone;
      case 'joint':
        return joint;
      case 'tendon':
        return tendon;
      case 'nerve':
        return nerve;
      case 'organ':
        return organ;
      default:
        return super[key];
    }
  }
}
