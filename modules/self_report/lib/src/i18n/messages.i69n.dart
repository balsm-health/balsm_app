// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;

String get _languageCode => 'en';
String get _localeName => 'en';

class Messages implements i69n.I69nMessageBundle {
  const Messages();
  BodyMessages get body => BodyMessages(this);
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

class BodyMessages implements i69n.I69nMessageBundle {
  final Messages _parent;
  const BodyMessages(this._parent);
  String get head => "Head";
  String get neck => "Neck";
  String get l_shoulder => "L. Shoulder";
  String get r_shoulder => "R. Shoulder";
  String get chest => "Chest";
  String get l_upper_arm => "L. Upper arm";
  String get r_upper_arm => "R. Upper arm";
  String get abdomen => "Abdomen";
  String get l_elbow => "L. Elbow";
  String get r_elbow => "R. Elbow";
  String get l_forearm => "L. Forearm";
  String get r_forearm => "R. Forearm";
  String get pelvis => "Pelvis";
  String get l_hand => "L. Hand";
  String get r_hand => "R. Hand";
  String get l_thigh => "L. Thigh";
  String get r_thigh => "R. Thigh";
  String get l_knee => "L. Knee";
  String get r_knee => "R. Knee";
  String get l_shin => "L. Shin";
  String get r_shin => "R. Shin";
  String get l_foot => "L. Foot";
  String get r_foot => "R. Foot";
  String get bk_head => "Head";
  String get bk_neck => "Neck";
  String get bk_l_shoulder => "L. Shoulder";
  String get bk_r_shoulder => "R. Shoulder";
  String get bk_upper => "Upper back";
  String get bk_mid => "Mid back";
  String get bk_lower => "Lower back";
  String get bk_l_glute => "L. Glute";
  String get bk_r_glute => "R. Glute";
  String get bk_l_hamstr => "L. Hamstring";
  String get bk_r_hamstr => "R. Hamstring";
  String get bk_l_calf => "L. Calf";
  String get bk_r_calf => "R. Calf";
  String get bk_l_heel => "L. Heel";
  String get bk_r_heel => "R. Heel";
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
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
