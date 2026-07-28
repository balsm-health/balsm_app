// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'strings.i69n.dart';

String get _languageCode => 'ar';
String get _localeName => 'ar';

class Strings_ar extends Strings {
  const Strings_ar();
  AuthStrings_ar get auth => AuthStrings_ar(this);
  BootStrings_ar get boot => BootStrings_ar(this);
  CareStrings_ar get care => CareStrings_ar(this);
  CheckinStrings_ar get checkin => CheckinStrings_ar(this);
  CommonStrings_ar get common => CommonStrings_ar(this);
  EmergencyStrings_ar get emergency => EmergencyStrings_ar(this);
  HomeStrings_ar get home => HomeStrings_ar(this);
  MedsStrings_ar get meds => MedsStrings_ar(this);
  NavStrings_ar get nav => NavStrings_ar(this);
  OnboardingStrings_ar get onboarding => OnboardingStrings_ar(this);
  PrivacyStrings_ar get privacy => PrivacyStrings_ar(this);
  ProfileStrings_ar get profile => ProfileStrings_ar(this);
  RecordsStrings_ar get records => RecordsStrings_ar(this);
  SettingsStrings_ar get settings => SettingsStrings_ar(this);
  StorageStrings_ar get storage => StorageStrings_ar(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'auth':
        return auth;
      case 'boot':
        return boot;
      case 'care':
        return care;
      case 'checkin':
        return checkin;
      case 'common':
        return common;
      case 'emergency':
        return emergency;
      case 'home':
        return home;
      case 'meds':
        return meds;
      case 'nav':
        return nav;
      case 'onboarding':
        return onboarding;
      case 'privacy':
        return privacy;
      case 'profile':
        return profile;
      case 'records':
        return records;
      case 'settings':
        return settings;
      case 'storage':
        return storage;
      default:
        return super[key];
    }
  }
}

class AuthStrings_ar extends AuthStrings {
  final Strings_ar _parent;
  const AuthStrings_ar(this._parent) : super(_parent);
  String get use_phone => "استخدم رقم الهاتف";
  String get use_email => "استخدم البريد الإلكتروني";
  String get un_label => "المعرّف";
  String get un_ph => "مثال: layla_hassan";
  String get un_avail => "متاح";
  String get un_taken => "مأخوذ بالفعل";
  String get un_checking => "جارٍ التحقق…";
  String get un_invalid => "أحرف وأرقام و_ فقط (3–20 حرفاً)";
  String get ph_title => "ما رقم هاتفك؟";
  String get ph_help => "سنرسل لك رمزاً عبر رسالة للتأكد من هويتك.";
  String get ph_label => "رقم الموبايل";
  String get ph_terms =>
      "بالمتابعة فإنك توافق على شروط بَلسَم وسياسة الخصوصية.";
  String get otp_title => "أدخل رمز التحقق";
  String get otp_help => "أرسلنا رمزاً من 6 أرقام إلى";
  String get otp_resend => "إعادة إرسال الرمز";
  String get otp_in => "إعادة الإرسال خلال";
  String get otp_wrong => "الرقم غير صحيح؟";
  String get verify => "تأكيد";
  String get pw_label => "كلمة المرور";
  String get pw_ph => "أدخل كلمة المرور";
  String get pw_show => "إظهار كلمة المرور";
  String get pw_hide => "إخفاء كلمة المرور";
  String get forgot_pw => "نسيت؟";
  String get use_code => "استخدم رمزًا لمرة واحدة بدلاً من ذلك";
  String get use_password => "استخدم كلمة مرور بدلاً من ذلك";
  String get pw_signin => "تسجيل الدخول";
  String get pw_min => "٨ أحرف على الأقل";
  String get pw_invalid_creds => "البريد الإلكتروني أو كلمة المرور غير صحيحة.";
  String get fp_title => "إعادة تعيين كلمة المرور";
  String get fp_help =>
      "أدخل بريدك الإلكتروني — سنرسل رمزًا لإعادة تعيين كلمة المرور.";
  String get fp_send => "إرسال رمز إعادة التعيين";
  String get fp_code_label => "رمز إعادة التعيين";
  String get fp_new_pw => "كلمة المرور الجديدة";
  String get fp_reset => "إعادة تعيين كلمة المرور";
  String get fp_sent_help => "أرسلنا رمز إعادة التعيين إلى";
  String get fp_done => "تم";
  String get fp_success =>
      "تم تحديث كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.";
  String get dial_title => "رمز الدولة";
  String get dial_search => "ابحث عن دولة";
  String auth_locked_retry(String secs) =>
      "الحساب مقفل مؤقتًا. حاول بعد $secs ثانية.";
  String get auth_phone_soon =>
      "تسجيل الدخول عبر الهاتف غير متاح بعد — استخدم البريد الإلكتروني.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'use_phone':
        return use_phone;
      case 'use_email':
        return use_email;
      case 'un_label':
        return un_label;
      case 'un_ph':
        return un_ph;
      case 'un_avail':
        return un_avail;
      case 'un_taken':
        return un_taken;
      case 'un_checking':
        return un_checking;
      case 'un_invalid':
        return un_invalid;
      case 'ph_title':
        return ph_title;
      case 'ph_help':
        return ph_help;
      case 'ph_label':
        return ph_label;
      case 'ph_terms':
        return ph_terms;
      case 'otp_title':
        return otp_title;
      case 'otp_help':
        return otp_help;
      case 'otp_resend':
        return otp_resend;
      case 'otp_in':
        return otp_in;
      case 'otp_wrong':
        return otp_wrong;
      case 'verify':
        return verify;
      case 'pw_label':
        return pw_label;
      case 'pw_ph':
        return pw_ph;
      case 'pw_show':
        return pw_show;
      case 'pw_hide':
        return pw_hide;
      case 'forgot_pw':
        return forgot_pw;
      case 'use_code':
        return use_code;
      case 'use_password':
        return use_password;
      case 'pw_signin':
        return pw_signin;
      case 'pw_min':
        return pw_min;
      case 'pw_invalid_creds':
        return pw_invalid_creds;
      case 'fp_title':
        return fp_title;
      case 'fp_help':
        return fp_help;
      case 'fp_send':
        return fp_send;
      case 'fp_code_label':
        return fp_code_label;
      case 'fp_new_pw':
        return fp_new_pw;
      case 'fp_reset':
        return fp_reset;
      case 'fp_sent_help':
        return fp_sent_help;
      case 'fp_done':
        return fp_done;
      case 'fp_success':
        return fp_success;
      case 'dial_title':
        return dial_title;
      case 'dial_search':
        return dial_search;
      case 'auth_locked_retry':
        return auth_locked_retry;
      case 'auth_phone_soon':
        return auth_phone_soon;
      default:
        return super[key];
    }
  }
}

class BootStrings_ar extends BootStrings {
  final Strings_ar _parent;
  const BootStrings_ar(this._parent) : super(_parent);
  String get boot_preparing => "نُجهّز سجلّك الصحي";
  String get boot_tagline => "على جهازك، بالتصميم.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'boot_preparing':
        return boot_preparing;
      case 'boot_tagline':
        return boot_tagline;
      default:
        return super[key];
    }
  }
}

class CareStrings_ar extends CareStrings {
  final Strings_ar _parent;
  const CareStrings_ar(this._parent) : super(_parent);
  String get to_doctor => "ستصل نسخة إلى د. سارة في زيارتك القادمة.";
  String get to_home => "العودة للرئيسية";
  String get care_intro => "الأطباء الذين يتابعون حالتك ويرون تقاريرك.";
  String get care_primary => "الطبيب الأساسي";
  String get care_message => "رسالة";
  String get care_book => "حجز";
  String get care_find => "ابحث عن طبيب جديد";
  String get appts => "المواعيد";
  String get upcoming_appt => "الموعد القادم";
  String get past_appts => "الزيارات السابقة";
  String get book_appt => "حجز";
  String get follow_up => "متابعة";
  String get check_up => "فحص دوري";
  String get book_via_doctor => "سيقوم فريق رعايتك بجدولة المواعيد لك.";
  String get map_nearby => "رعاية قريبة";
  String get map_search_ph => "ابحث عن عيادة أو صيدلية…";
  String get map_all => "الكل";
  String get map_open_now => "مفتوح الآن";
  String get map_distance => "بُعد";
  String get map_call => "اتصال";
  String get map_directions => "اتجاهات";
  String get map_list => "قائمة";
  String get map_map => "خريطة";
  String get map_found => "مكان بالقرب منك";
  String get map_your_loc => "موقعك";
  String get map_no_results => "لا توجد أماكن";
  String get care_empty => "لا يوجد فريق رعاية بعد";
  String get care_add_help => "أضف طبيبك من الخريطة لبناء فريق الرعاية.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'to_doctor':
        return to_doctor;
      case 'to_home':
        return to_home;
      case 'care_intro':
        return care_intro;
      case 'care_primary':
        return care_primary;
      case 'care_message':
        return care_message;
      case 'care_book':
        return care_book;
      case 'care_find':
        return care_find;
      case 'appts':
        return appts;
      case 'upcoming_appt':
        return upcoming_appt;
      case 'past_appts':
        return past_appts;
      case 'book_appt':
        return book_appt;
      case 'follow_up':
        return follow_up;
      case 'check_up':
        return check_up;
      case 'book_via_doctor':
        return book_via_doctor;
      case 'map_nearby':
        return map_nearby;
      case 'map_search_ph':
        return map_search_ph;
      case 'map_all':
        return map_all;
      case 'map_open_now':
        return map_open_now;
      case 'map_distance':
        return map_distance;
      case 'map_call':
        return map_call;
      case 'map_directions':
        return map_directions;
      case 'map_list':
        return map_list;
      case 'map_map':
        return map_map;
      case 'map_found':
        return map_found;
      case 'map_your_loc':
        return map_your_loc;
      case 'map_no_results':
        return map_no_results;
      case 'care_empty':
        return care_empty;
      case 'care_add_help':
        return care_add_help;
      default:
        return super[key];
    }
  }
}

class CheckinStrings_ar extends CheckinStrings {
  final Strings_ar _parent;
  const CheckinStrings_ar(this._parent) : super(_parent);
  String get latest => "آخر القياسات";
  String get unit_bp => "ملم زئبق";
  String get unit_glu => "مجم/دل";
  String get bp_normal => "ضمن المعدل";
  String get bp_high => "أعلى قليلاً";
  String get q_mood_t => "كيف تشعرين اليوم؟";
  String get q_mood_h => "اختاري الوجه الأقرب لحالتك.";
  String get mood_1 => "متعبة";
  String get mood_2 => "ضعيفة";
  String get mood_3 => "عادية";
  String get mood_4 => "جيدة";
  String get mood_5 => "ممتازة";
  String get q_bp_t => "كم ضغط دمك؟";
  String get q_bp_h => "اضغطي على الرقم ثم استخدمي لوحة الأرقام.";
  String get sys => "الانقباضي";
  String get dia => "الانبساطي";
  String get q_glu_t => "وكم نسبة السكر؟";
  String get q_glu_h => "أدخلي القراءة من جهاز قياس السكر.";
  String get glu_fast => "صائمة";
  String get glu_meal => "بعد الأكل";
  String get glu_random => "عشوائي";
  String get q_med_t => "هل أخذتِ أدويتك؟";
  String get q_med_h => "اضغطي على كل دواء أخذتِه اليوم.";
  String get q_sym_t => "هل لديك ألم أو أعراض؟";
  String get q_sym_h => "حرّكي المؤشر لمستوى الألم، ثم اختاري ما تشعرين به.";
  String get pain_0 => "لا ألم";
  String get pain_mild => "خفيف";
  String get pain_mod => "متوسط";
  String get pain_sev => "شديد";
  String get pain_worst => "الأسوأ";
  String get note_lbl => "أي شيء آخر؟ (اختياري)";
  String get note_ph => "اكتبي ملاحظة لطبيبك…";
  String get s_headache => "صداع";
  String get s_dizzy => "دوخة";
  String get s_fatigue => "إرهاق";
  String get s_blurred => "تشوش الرؤية";
  String get s_swelling => "تورّم";
  String get s_chest => "ضيق بالصدر";
  String get s_nausea => "غثيان";
  String get s_thirst => "عطش زائد";
  String get s_none => "لا شيء";
  String get view_trends => "عرض الرسوم";
  String get trends => "الرسوم البيانية";
  String get range_w => "أسبوع";
  String get range_m => "شهر";
  String get range_3m => "3 أشهر";
  String get avg => "متوسط";
  String get symptoms => "الأعراض";
  String get ql_title => "لنسجّل متابعتك";
  String get ql_add_records => "أضف إلى السجلات";
  String get full_checkin => "المتابعة الكاملة";
  String get quick_log_or => "أو سجّل قراءة واحدة";
  String get body_location => "أين يؤلمك؟";
  String get cond_icd10_hint => "رمز ICD-10 (اختياري)";
  String get cond_onset_hint => "سنة البدء";
  String get q_vitals_t => "مؤشراتك الحيوية";
  String get q_vitals_h => "أدخل أي قياسات أخذتها اليوم — كلها اختيارية.";
  String get vital_hr => "معدل النبض";
  String get unit_hr => "نبضة/د";
  String get vital_temp => "درجة الحرارة";
  String get unit_temp => "°م";
  String get vital_spo2 => "الأكسجين (SpO₂)";
  String get unit_spo2 => "%";
  String get sym_headache => "صداع";
  String get sym_dizzy => "دوخة";
  String get sym_fatigue => "إرهاق";
  String get sym_blurred_vision => "تشوش الرؤية";
  String get sym_swelling => "تورّم";
  String get sym_chest_tightness => "ضيق بالصدر";
  String get sym_nausea => "غثيان";
  String get sym_thirst => "عطش زائد";
  String get body_head => "الرأس";
  String get body_neck => "الرقبة";
  String get body_l_shoulder => "كتف أيسر";
  String get body_r_shoulder => "كتف أيمن";
  String get body_chest => "الصدر";
  String get body_l_upper_arm => "عضد أيسر";
  String get body_r_upper_arm => "عضد أيمن";
  String get body_abdomen => "البطن";
  String get body_l_elbow => "مرفق أيسر";
  String get body_r_elbow => "مرفق أيمن";
  String get body_l_forearm => "ساعد أيسر";
  String get body_r_forearm => "ساعد أيمن";
  String get body_pelvis => "الحوض";
  String get body_l_hand => "يد يسرى";
  String get body_r_hand => "يد يمنى";
  String get body_l_thigh => "فخذ أيسر";
  String get body_r_thigh => "فخذ أيمن";
  String get body_l_knee => "ركبة يسرى";
  String get body_r_knee => "ركبة يمنى";
  String get body_l_shin => "ساق يسرى";
  String get body_r_shin => "ساق يمنى";
  String get body_l_foot => "قدم يسرى";
  String get body_r_foot => "قدم يمنى";
  String get body_bk_head => "الرأس";
  String get body_bk_neck => "الرقبة";
  String get body_bk_l_shoulder => "كتف أيسر";
  String get body_bk_r_shoulder => "كتف أيمن";
  String get body_bk_upper => "أعلى الظهر";
  String get body_bk_mid => "وسط الظهر";
  String get body_bk_lower => "أسفل الظهر";
  String get body_bk_l_glute => "أرداف أيسر";
  String get body_bk_r_glute => "أرداف أيمن";
  String get body_bk_l_hamstr => "أوتار ركبة يسرى";
  String get body_bk_r_hamstr => "أوتار ركبة يمنى";
  String get body_bk_l_calf => "بطة ساق يسرى";
  String get body_bk_r_calf => "بطة ساق يمنى";
  String get body_bk_l_heel => "كعب أيسر";
  String get body_bk_r_heel => "كعب أيمن";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'latest':
        return latest;
      case 'unit_bp':
        return unit_bp;
      case 'unit_glu':
        return unit_glu;
      case 'bp_normal':
        return bp_normal;
      case 'bp_high':
        return bp_high;
      case 'q_mood_t':
        return q_mood_t;
      case 'q_mood_h':
        return q_mood_h;
      case 'mood_1':
        return mood_1;
      case 'mood_2':
        return mood_2;
      case 'mood_3':
        return mood_3;
      case 'mood_4':
        return mood_4;
      case 'mood_5':
        return mood_5;
      case 'q_bp_t':
        return q_bp_t;
      case 'q_bp_h':
        return q_bp_h;
      case 'sys':
        return sys;
      case 'dia':
        return dia;
      case 'q_glu_t':
        return q_glu_t;
      case 'q_glu_h':
        return q_glu_h;
      case 'glu_fast':
        return glu_fast;
      case 'glu_meal':
        return glu_meal;
      case 'glu_random':
        return glu_random;
      case 'q_med_t':
        return q_med_t;
      case 'q_med_h':
        return q_med_h;
      case 'q_sym_t':
        return q_sym_t;
      case 'q_sym_h':
        return q_sym_h;
      case 'pain_0':
        return pain_0;
      case 'pain_mild':
        return pain_mild;
      case 'pain_mod':
        return pain_mod;
      case 'pain_sev':
        return pain_sev;
      case 'pain_worst':
        return pain_worst;
      case 'note_lbl':
        return note_lbl;
      case 'note_ph':
        return note_ph;
      case 's_headache':
        return s_headache;
      case 's_dizzy':
        return s_dizzy;
      case 's_fatigue':
        return s_fatigue;
      case 's_blurred':
        return s_blurred;
      case 's_swelling':
        return s_swelling;
      case 's_chest':
        return s_chest;
      case 's_nausea':
        return s_nausea;
      case 's_thirst':
        return s_thirst;
      case 's_none':
        return s_none;
      case 'view_trends':
        return view_trends;
      case 'trends':
        return trends;
      case 'range_w':
        return range_w;
      case 'range_m':
        return range_m;
      case 'range_3m':
        return range_3m;
      case 'avg':
        return avg;
      case 'symptoms':
        return symptoms;
      case 'ql_title':
        return ql_title;
      case 'ql_add_records':
        return ql_add_records;
      case 'full_checkin':
        return full_checkin;
      case 'quick_log_or':
        return quick_log_or;
      case 'body_location':
        return body_location;
      case 'cond_icd10_hint':
        return cond_icd10_hint;
      case 'cond_onset_hint':
        return cond_onset_hint;
      case 'q_vitals_t':
        return q_vitals_t;
      case 'q_vitals_h':
        return q_vitals_h;
      case 'vital_hr':
        return vital_hr;
      case 'unit_hr':
        return unit_hr;
      case 'vital_temp':
        return vital_temp;
      case 'unit_temp':
        return unit_temp;
      case 'vital_spo2':
        return vital_spo2;
      case 'unit_spo2':
        return unit_spo2;
      case 'sym_headache':
        return sym_headache;
      case 'sym_dizzy':
        return sym_dizzy;
      case 'sym_fatigue':
        return sym_fatigue;
      case 'sym_blurred_vision':
        return sym_blurred_vision;
      case 'sym_swelling':
        return sym_swelling;
      case 'sym_chest_tightness':
        return sym_chest_tightness;
      case 'sym_nausea':
        return sym_nausea;
      case 'sym_thirst':
        return sym_thirst;
      case 'body_head':
        return body_head;
      case 'body_neck':
        return body_neck;
      case 'body_l_shoulder':
        return body_l_shoulder;
      case 'body_r_shoulder':
        return body_r_shoulder;
      case 'body_chest':
        return body_chest;
      case 'body_l_upper_arm':
        return body_l_upper_arm;
      case 'body_r_upper_arm':
        return body_r_upper_arm;
      case 'body_abdomen':
        return body_abdomen;
      case 'body_l_elbow':
        return body_l_elbow;
      case 'body_r_elbow':
        return body_r_elbow;
      case 'body_l_forearm':
        return body_l_forearm;
      case 'body_r_forearm':
        return body_r_forearm;
      case 'body_pelvis':
        return body_pelvis;
      case 'body_l_hand':
        return body_l_hand;
      case 'body_r_hand':
        return body_r_hand;
      case 'body_l_thigh':
        return body_l_thigh;
      case 'body_r_thigh':
        return body_r_thigh;
      case 'body_l_knee':
        return body_l_knee;
      case 'body_r_knee':
        return body_r_knee;
      case 'body_l_shin':
        return body_l_shin;
      case 'body_r_shin':
        return body_r_shin;
      case 'body_l_foot':
        return body_l_foot;
      case 'body_r_foot':
        return body_r_foot;
      case 'body_bk_head':
        return body_bk_head;
      case 'body_bk_neck':
        return body_bk_neck;
      case 'body_bk_l_shoulder':
        return body_bk_l_shoulder;
      case 'body_bk_r_shoulder':
        return body_bk_r_shoulder;
      case 'body_bk_upper':
        return body_bk_upper;
      case 'body_bk_mid':
        return body_bk_mid;
      case 'body_bk_lower':
        return body_bk_lower;
      case 'body_bk_l_glute':
        return body_bk_l_glute;
      case 'body_bk_r_glute':
        return body_bk_r_glute;
      case 'body_bk_l_hamstr':
        return body_bk_l_hamstr;
      case 'body_bk_r_hamstr':
        return body_bk_r_hamstr;
      case 'body_bk_l_calf':
        return body_bk_l_calf;
      case 'body_bk_r_calf':
        return body_bk_r_calf;
      case 'body_bk_l_heel':
        return body_bk_l_heel;
      case 'body_bk_r_heel':
        return body_bk_r_heel;
      default:
        return super[key];
    }
  }
}

class CommonStrings_ar extends CommonStrings {
  final Strings_ar _parent;
  const CommonStrings_ar(this._parent) : super(_parent);
  String get continue_ => "متابعة";
  String get today_lbl => "متابعة اليوم";
  String get done_lbl => "انتهيتِ لليوم";
  String get done_q => "اكتملت المتابعة";
  String get recent => "آخر التقارير";
  String get see_all => "عرض الكل";
  String get yesterday => "عن أمس";
  String get step_of => "من";
  String get back => "رجوع";
  String get finish => "إنهاء المتابعة";
  String get saved_t => "تم حفظ المتابعة";
  String get saved_local => "حُفظ محلياً — ستتم المزامنة عند الاتصال.";
  String get no_symptoms => "لا أعراض";
  String get profile => "الملف الشخصي";
  String get since => "مريضة بَلسَم منذ";
  String get no_appts => "لا مواعيد قادمة";
  String get your_accounts => "حساباتك";
  String get pages => "صفحات";
  String get cancel => "إلغاء";
  String get acc_active => "الحساب النشط";
  String get acc_not_signed_in => "لم يتم تسجيل الدخول";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'continue_':
        return continue_;
      case 'today_lbl':
        return today_lbl;
      case 'done_lbl':
        return done_lbl;
      case 'done_q':
        return done_q;
      case 'recent':
        return recent;
      case 'see_all':
        return see_all;
      case 'yesterday':
        return yesterday;
      case 'step_of':
        return step_of;
      case 'back':
        return back;
      case 'finish':
        return finish;
      case 'saved_t':
        return saved_t;
      case 'saved_local':
        return saved_local;
      case 'no_symptoms':
        return no_symptoms;
      case 'profile':
        return profile;
      case 'since':
        return since;
      case 'no_appts':
        return no_appts;
      case 'your_accounts':
        return your_accounts;
      case 'pages':
        return pages;
      case 'cancel':
        return cancel;
      case 'acc_active':
        return acc_active;
      case 'acc_not_signed_in':
        return acc_not_signed_in;
      default:
        return super[key];
    }
  }
}

class EmergencyStrings_ar extends EmergencyStrings {
  final Strings_ar _parent;
  const EmergencyStrings_ar(this._parent) : super(_parent);
  String get em_title => "ما هو بريدك الإلكتروني؟";
  String get em_help => "سنرسل لك رمزاً للتحقق من هويتك.";
  String get em_label => "البريد الإلكتروني";
  String get em_ph => "you@example.com";
  String get em_otp_h => "أرسلنا رمزاً من 6 أرقام إلى";
  String get em_eg => "مصر";
  String get em_intro =>
      "خطوط الطوارئ على مستوى مصر. اضغط أي رقم للاتصال فوراً.";
  String get em_tap_call => "اضغط للاتصال";
  String get em_ambulance => "إسعاف";
  String get em_police => "شرطة";
  String get em_fire => "الإطفاء والإنقاذ";
  String get em_tourist => "شرطة السياحة";
  String get emergency => "الطوارئ";
  String get em_pw_title => "مرحبًا بعودتك";
  String get em_pw_help => "سجّل الدخول ببريدك الإلكتروني وكلمة المرور.";
  String get eqr_title => "رمز الطوارئ";
  String get eqr_ttl_1h => "ساعة";
  String get eqr_ttl_6h => "٦ س";
  String get eqr_ttl_24h => "٢٤ س";
  String get eqr_ttl_7d => "٧ أيام";
  String get eqr_help_active =>
      "اعرض هذا الرمز المشفّر لطاقم الطوارئ. ينتهي تلقائيًا ولا يحتوي على مفتاح فك التشفير إلا داخل الرابط نفسه.";
  String get eqr_help_signin =>
      "سجّل الدخول لمشاركة بطاقة الطوارئ الصحية الخاصة بك.";
  String get eqr_help_incomplete =>
      "أضف فصيلة دمك أو الحساسية أو الحالات أو جهة اتصال للطوارئ لمشاركة بطاقة الطوارئ.";
  String get eqr_help_create =>
      "أنشئ رمز QR مشفّرًا لملفك الصحي للطوارئ. يبقى مفتاح فك التشفير على جهازك.";
  String get eqr_expired => "منتهي";
  String eqr_expires_in(String t) => "ينتهي خلال $t";
  String get eqr_copy => "نسخ";
  String get eqr_share => "مشاركة";
  String get eqr_save => "حفظ";
  String get eqr_saved_toast => "تم حفظ الصورة";
  String get eqr_link_copied => "تم نسخ الرابط";
  String get eqr_revoke => "إلغاء الرمز";
  String get eqr_revoked_toast => "تم إلغاء الرمز";
  String get eqr_generate => "إنشاء رمز QR";
  String get eqr_generate_new => "إنشاء رمز جديد";
  String get eqr_valid_for => "مدة الصلاحية";
  String get eqr_signin_required => "يلزم تسجيل الدخول";
  String get eqr_no_data => "لا توجد بيانات صحية بعد";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'em_title':
        return em_title;
      case 'em_help':
        return em_help;
      case 'em_label':
        return em_label;
      case 'em_ph':
        return em_ph;
      case 'em_otp_h':
        return em_otp_h;
      case 'em_eg':
        return em_eg;
      case 'em_intro':
        return em_intro;
      case 'em_tap_call':
        return em_tap_call;
      case 'em_ambulance':
        return em_ambulance;
      case 'em_police':
        return em_police;
      case 'em_fire':
        return em_fire;
      case 'em_tourist':
        return em_tourist;
      case 'emergency':
        return emergency;
      case 'em_pw_title':
        return em_pw_title;
      case 'em_pw_help':
        return em_pw_help;
      case 'eqr_title':
        return eqr_title;
      case 'eqr_ttl_1h':
        return eqr_ttl_1h;
      case 'eqr_ttl_6h':
        return eqr_ttl_6h;
      case 'eqr_ttl_24h':
        return eqr_ttl_24h;
      case 'eqr_ttl_7d':
        return eqr_ttl_7d;
      case 'eqr_help_active':
        return eqr_help_active;
      case 'eqr_help_signin':
        return eqr_help_signin;
      case 'eqr_help_incomplete':
        return eqr_help_incomplete;
      case 'eqr_help_create':
        return eqr_help_create;
      case 'eqr_expired':
        return eqr_expired;
      case 'eqr_expires_in':
        return eqr_expires_in;
      case 'eqr_copy':
        return eqr_copy;
      case 'eqr_share':
        return eqr_share;
      case 'eqr_save':
        return eqr_save;
      case 'eqr_saved_toast':
        return eqr_saved_toast;
      case 'eqr_link_copied':
        return eqr_link_copied;
      case 'eqr_revoke':
        return eqr_revoke;
      case 'eqr_revoked_toast':
        return eqr_revoked_toast;
      case 'eqr_generate':
        return eqr_generate;
      case 'eqr_generate_new':
        return eqr_generate_new;
      case 'eqr_valid_for':
        return eqr_valid_for;
      case 'eqr_signin_required':
        return eqr_signin_required;
      case 'eqr_no_data':
        return eqr_no_data;
      default:
        return super[key];
    }
  }
}

class HomeStrings_ar extends HomeStrings {
  final Strings_ar _parent;
  const HomeStrings_ar(this._parent) : super(_parent);
  String get nudge_handle => "احجز معرّفك";
  String get nudge_handle_sub => "ابدأ الإعداد";
  String get nudge_ec => "أضف بطاقة الطوارئ";
  String get nudge_ec_sub => "كن مستعداً";
  String get nudge_med => "أضف دواءً";
  String get nudge_med_sub => "واظب على المتابعة";
  String get greet => "صباح الخير";
  String get hero_q => "كيف تشعرين اليوم؟";
  String get hero_cta => "ابدأ المتابعة";
  String get hero_time => "حوالي دقيقتين";
  String get streak => "يوم متتالٍ";
  String get streak_help => "تابعتِ 6 من آخر 7 أيام";
  String get on_track => "ملتزمة";
  String get experience => "خبرة";
  String get away_banner => "أنت خارج بلدك";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'nudge_handle':
        return nudge_handle;
      case 'nudge_handle_sub':
        return nudge_handle_sub;
      case 'nudge_ec':
        return nudge_ec;
      case 'nudge_ec_sub':
        return nudge_ec_sub;
      case 'nudge_med':
        return nudge_med;
      case 'nudge_med_sub':
        return nudge_med_sub;
      case 'greet':
        return greet;
      case 'hero_q':
        return hero_q;
      case 'hero_cta':
        return hero_cta;
      case 'hero_time':
        return hero_time;
      case 'streak':
        return streak;
      case 'streak_help':
        return streak_help;
      case 'on_track':
        return on_track;
      case 'experience':
        return experience;
      case 'away_banner':
        return away_banner;
      default:
        return super[key];
    }
  }
}

class MedsStrings_ar extends MedsStrings {
  final Strings_ar _parent;
  const MedsStrings_ar(this._parent) : super(_parent);
  String get meds_today => "أدوية اليوم";
  String get taken => "مأخوذ";
  String get due => "مستحق";
  String get take => "أخذ";
  String get skip_q => "لم أقِس هذا اليوم";
  String get skipped => "لم يُؤخذ";
  String get mark_skip => "لم آخذه";
  String get meds_taken => "مأخوذة";
  String get medications => "الأدوية";
  String get morning => "الصباح";
  String get evening => "المساء";
  String get adherence => "هذا الأسبوع";
  String get rx_active => "فعّالة";
  String get rx_expired => "منتهية";
  String get rx_valid_until => "صالحة حتى";
  String get rx_show => "أظهر للصيدلاني";
  String get rx_scan => "امسح للصرف";
  String get dose_skipped => "تم التخطي";
  String get dose_snoozed => "مؤجل";
  String get dose_missed => "فائت";
  String get med_scheduled => "الموعد";
  String get med_snooze15 => "تأجيل 15 دقيقة";
  String get med_skip => "تخطّي";
  String get tz_changed => "تغيّرت المنطقة الزمنية";
  String get tz_recompute => "إعادة الحساب";
  String get tz_keep => "الإبقاء كما هي";
  String get med_add_title => "إضافة دواء";
  String get med_field_name => "الاسم";
  String get med_ph_name => "اسم الدواء";
  String get med_field_dose => "الجرعة (اختياري)";
  String get med_ph_dose => "مثال: 500 ملجم";
  String get med_reminder_time => "وقت التذكير اليومي";
  String get med_add_btn => "إضافة الدواء";
  String get med_time_morning => "صباحاً";
  String get med_time_midday => "ظهراً";
  String get med_time_evening => "مساءً";
  String get med_time_night => "ليلاً";
  String get meds_signin_help => "سجّل الدخول لعرض أدويتك.";
  String get meds_empty_help => "لا توجد أدوية بعد. أضف دواءً للبدء.";
  String get meds_none_today => "لا جرعات مجدولة اليوم.";
  String meds_tz_moved(String from, String to) =>
      "انتقلت من $from إلى $to. هل نعيد حساب مواعيد تذكير الأدوية لتوقيتك المحلي الجديد؟";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'meds_today':
        return meds_today;
      case 'taken':
        return taken;
      case 'due':
        return due;
      case 'take':
        return take;
      case 'skip_q':
        return skip_q;
      case 'skipped':
        return skipped;
      case 'mark_skip':
        return mark_skip;
      case 'meds_taken':
        return meds_taken;
      case 'medications':
        return medications;
      case 'morning':
        return morning;
      case 'evening':
        return evening;
      case 'adherence':
        return adherence;
      case 'rx_active':
        return rx_active;
      case 'rx_expired':
        return rx_expired;
      case 'rx_valid_until':
        return rx_valid_until;
      case 'rx_show':
        return rx_show;
      case 'rx_scan':
        return rx_scan;
      case 'dose_skipped':
        return dose_skipped;
      case 'dose_snoozed':
        return dose_snoozed;
      case 'dose_missed':
        return dose_missed;
      case 'med_scheduled':
        return med_scheduled;
      case 'med_snooze15':
        return med_snooze15;
      case 'med_skip':
        return med_skip;
      case 'tz_changed':
        return tz_changed;
      case 'tz_recompute':
        return tz_recompute;
      case 'tz_keep':
        return tz_keep;
      case 'med_add_title':
        return med_add_title;
      case 'med_field_name':
        return med_field_name;
      case 'med_ph_name':
        return med_ph_name;
      case 'med_field_dose':
        return med_field_dose;
      case 'med_ph_dose':
        return med_ph_dose;
      case 'med_reminder_time':
        return med_reminder_time;
      case 'med_add_btn':
        return med_add_btn;
      case 'med_time_morning':
        return med_time_morning;
      case 'med_time_midday':
        return med_time_midday;
      case 'med_time_evening':
        return med_time_evening;
      case 'med_time_night':
        return med_time_night;
      case 'meds_signin_help':
        return meds_signin_help;
      case 'meds_empty_help':
        return meds_empty_help;
      case 'meds_none_today':
        return meds_none_today;
      case 'meds_tz_moved':
        return meds_tz_moved;
      default:
        return super[key];
    }
  }
}

class NavStrings_ar extends NavStrings {
  final Strings_ar _parent;
  const NavStrings_ar(this._parent) : super(_parent);
  String get tab_home => "الرئيسية";
  String get tab_map => "قريب منك";
  String get tab_meds => "الأدوية";
  String get tab_profile => "الملف";
  String get gov_sessions => "الأجهزة والجلسات";
  String get gov_status => "حالة الخدمة";
  String get gov_delete => "حذف الحساب";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'tab_home':
        return tab_home;
      case 'tab_map':
        return tab_map;
      case 'tab_meds':
        return tab_meds;
      case 'tab_profile':
        return tab_profile;
      case 'gov_sessions':
        return gov_sessions;
      case 'gov_status':
        return gov_status;
      case 'gov_delete':
        return gov_delete;
      default:
        return super[key];
    }
  }
}

class OnboardingStrings_ar extends OnboardingStrings {
  final Strings_ar _parent;
  const OnboardingStrings_ar(this._parent) : super(_parent);
  String get w_title => "صحتك، دائماً قريبة.";
  String get w_sub =>
      "متابعة يومية، تذكير بالدواء، ورسوم بيانية — محفوظة على هاتفك، وتُزامَن عند رغبتك.";
  String get w_start => "ابدأ الآن";
  String get w_have => "لديّ حساب بالفعل";
  String get w_signin => "تسجيل الدخول";
  String get w_or => "أو";
  String get w_apple => "المتابعة مع Apple";
  String get w_google => "المتابعة مع Google";
  String get pf_title => "عرّفنا بنفسك";
  String get pf_help => "هذا يساعد فريق الرعاية على قراءة تقاريرك بدقة.";
  String get pf_fname => "الاسم الأول";
  String get pf_lname => "اسم العائلة";
  String get pf_fname_ph => "مثال: ليلى";
  String get pf_lname_ph => "مثال: حسن";
  String get pf_dob => "تاريخ الميلاد";
  String get pf_gender => "النوع";
  String get pf_female => "أنثى";
  String get pf_male => "ذكر";
  String get pf_gov => "المحافظة";
  String get pf_create => "إنشاء ملفّي";
  String get pf_secure => "تبقى بياناتك على هذا الجهاز.";
  String get dob_title => "تاريخ الميلاد";
  String get dob_confirm => "تأكيد";
  String get dob_select => "اختر تاريخاً";
  String get age_gate_body =>
      "بلسم متاح حاليًا لمن هم في سن 18 وأكثر. نعمل على إصدار للمستخدمين الأصغر سنًا بموافقة ولي الأمر.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'w_title':
        return w_title;
      case 'w_sub':
        return w_sub;
      case 'w_start':
        return w_start;
      case 'w_have':
        return w_have;
      case 'w_signin':
        return w_signin;
      case 'w_or':
        return w_or;
      case 'w_apple':
        return w_apple;
      case 'w_google':
        return w_google;
      case 'pf_title':
        return pf_title;
      case 'pf_help':
        return pf_help;
      case 'pf_fname':
        return pf_fname;
      case 'pf_lname':
        return pf_lname;
      case 'pf_fname_ph':
        return pf_fname_ph;
      case 'pf_lname_ph':
        return pf_lname_ph;
      case 'pf_dob':
        return pf_dob;
      case 'pf_gender':
        return pf_gender;
      case 'pf_female':
        return pf_female;
      case 'pf_male':
        return pf_male;
      case 'pf_gov':
        return pf_gov;
      case 'pf_create':
        return pf_create;
      case 'pf_secure':
        return pf_secure;
      case 'dob_title':
        return dob_title;
      case 'dob_confirm':
        return dob_confirm;
      case 'dob_select':
        return dob_select;
      case 'age_gate_body':
        return age_gate_body;
      default:
        return super[key];
    }
  }
}

class PrivacyStrings_ar extends PrivacyStrings {
  final Strings_ar _parent;
  const PrivacyStrings_ar(this._parent) : super(_parent);
  String get pv_sharing => "مشاركة البيانات";
  String get pv_share_team => "مشاركة التقارير مع فريق الرعاية";
  String get pv_share_team_h => "يرى أطباؤك قراءاتك اليومية";
  String get pv_analytics => "تحليلات مجهولة";
  String get pv_analytics_h => "ساعدنا على تحسين التطبيق";
  String get pv_research => "المساهمة في الأبحاث";
  String get pv_research_h => "بيانات مجهولة للأبحاث الطبية";
  String get pv_security => "الأمان";
  String get pv_bio => "قفل بالبصمة / الوجه";
  String get pv_bio_h => "افتح التطبيق ببصمتك";
  String get pv_pin => "طلب رمز PIN عند الفتح";
  String get pv_pin_h => "طبقة حماية إضافية";
  String get pv_yourdata => "بياناتك";
  String get pv_export => "تصدير بياناتي";
  String get pv_export_h => "ملف PDF أو CSV";
  String get pv_download => "تحميل السجلات الصحية";
  String get pv_download_h => "جميع التحاليل والأشعة";
  String get pv_connected => "التطبيقات المتصلة";
  String get pv_connected_h => "إدارة الوصول للطرف الثالث";
  String get pv_danger => "منطقة الخطر";
  String get pv_delete => "حذف حسابي";
  String get pv_delete_h => "حذف دائم لكل بياناتك";
  String get pv_encrypted => "بياناتك مشفّرة ومحمية";
  String get pv_title => "خصوصيتك وبياناتك";
  String get pv_collect => "ما الذي نجمعه";
  String get pv_protect => "كيف نحميها";
  String get pv_rights => "حقوقك";
  String get pv_authority => "الجهة الرقابية";
  String get pv_sharing2 => "المشاركة";
  String get pv_deletion => "الحذف";
  String get pv_saving => "جارٍ الحفظ…";
  String get pv_agree => "أوافق وأتابع";
  String get pv_intro_body =>
      "قبل المتابعة، يرجى مراجعة كيفية تعاملنا مع بياناتك. تبقى بياناتك الصحية على جهازك.";
  String get pv_collect_body =>
      "حساب أساسي غير صحي (البريد، البلد، اللغة). تبقى السجلات الصحية مشفّرة على جهازك.";
  String get pv_protect_body =>
      "تشفير على مستوى الجهاز، ونقل عبر قنوات آمنة، ووصول محدود بأقل قدر ممكن.";
  String get pv_rights_body =>
      "يمكنك الوصول إلى بياناتك أو تصحيحها أو حذفها في أي وقت من إعدادات الحساب.";
  String pv_authority_body(String authority) =>
      "الجهة المشرفة على حماية بياناتك في بلدك: $authority.";
  String get pv_sharing_body =>
      "لا نبيع بياناتك. لا تتم المشاركة إلا بموافقتك الصريحة أو عند وجود إلزام قانوني.";
  String get pv_deletion_body =>
      "يؤدي حذف حسابك إلى إزالة بياناتك السحابية غير الصحية ومسح السجلات من جهازك.";
  String get pv_scroll_hint => "مرّر للأسفل للمتابعة";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'pv_sharing':
        return pv_sharing;
      case 'pv_share_team':
        return pv_share_team;
      case 'pv_share_team_h':
        return pv_share_team_h;
      case 'pv_analytics':
        return pv_analytics;
      case 'pv_analytics_h':
        return pv_analytics_h;
      case 'pv_research':
        return pv_research;
      case 'pv_research_h':
        return pv_research_h;
      case 'pv_security':
        return pv_security;
      case 'pv_bio':
        return pv_bio;
      case 'pv_bio_h':
        return pv_bio_h;
      case 'pv_pin':
        return pv_pin;
      case 'pv_pin_h':
        return pv_pin_h;
      case 'pv_yourdata':
        return pv_yourdata;
      case 'pv_export':
        return pv_export;
      case 'pv_export_h':
        return pv_export_h;
      case 'pv_download':
        return pv_download;
      case 'pv_download_h':
        return pv_download_h;
      case 'pv_connected':
        return pv_connected;
      case 'pv_connected_h':
        return pv_connected_h;
      case 'pv_danger':
        return pv_danger;
      case 'pv_delete':
        return pv_delete;
      case 'pv_delete_h':
        return pv_delete_h;
      case 'pv_encrypted':
        return pv_encrypted;
      case 'pv_title':
        return pv_title;
      case 'pv_collect':
        return pv_collect;
      case 'pv_protect':
        return pv_protect;
      case 'pv_rights':
        return pv_rights;
      case 'pv_authority':
        return pv_authority;
      case 'pv_sharing2':
        return pv_sharing2;
      case 'pv_deletion':
        return pv_deletion;
      case 'pv_saving':
        return pv_saving;
      case 'pv_agree':
        return pv_agree;
      case 'pv_intro_body':
        return pv_intro_body;
      case 'pv_collect_body':
        return pv_collect_body;
      case 'pv_protect_body':
        return pv_protect_body;
      case 'pv_rights_body':
        return pv_rights_body;
      case 'pv_authority_body':
        return pv_authority_body;
      case 'pv_sharing_body':
        return pv_sharing_body;
      case 'pv_deletion_body':
        return pv_deletion_body;
      case 'pv_scroll_hint':
        return pv_scroll_hint;
      default:
        return super[key];
    }
  }
}

class ProfileStrings_ar extends ProfileStrings {
  final Strings_ar _parent;
  const ProfileStrings_ar(this._parent) : super(_parent);
  String get m_bp => "ضغط الدم";
  String get m_glucose => "سكر الدم";
  String get m_mood => "الحالة";
  String get m_pain => "الألم";
  String get m_weight => "الوزن";
  String get p_personal => "تفاصيل الحساب";
  String get pd_account => "الحساب";
  String get pd_share_qr => "شارك رمز QR الخاص بي";
  String get pd_share_qr_h => "ليتمكن الآخرون من المسح والتواصل";
  String get pd_qr_scan => "امسح للتواصل عبر بَلسَم";
  String get pd_nationality => "الجنسية";
  String get pd_blood => "فصيلة الدم";
  String get pd_weight => "الوزن";
  String get pd_height => "الطول";
  String get pd_phone => "رقم الهاتف";
  String get pd_nid => "الرقم القومي";
  String get pd_emergency => "جهة اتصال الطوارئ";
  String get pd_em_name => "الاسم";
  String get pd_em_rel => "صلة القرابة";
  String get pd_em_phone => "الهاتف";
  String get pd_save => "حفظ التغييرات";
  String get pd_saved => "تم الحفظ";
  String get conn_accounts => "الحسابات المرتبطة";
  String get conn_apple => "Apple ID";
  String get conn_google => "حساب Google";
  String get conn_connect => "ربط";
  String get conn_remove => "إلغاء الربط";
  String get p_cond => "الملف الطبي";
  String get p_care => "فريق الرعاية";
  String get p_notif => "التذكيرات";
  String get p_lang => "اللغة";
  String get p_privacy => "الخصوصية والبيانات";
  String get p_help => "المساعدة والدعم";
  String get p_signout => "تسجيل الخروج";
  String get p_emergency => "الطوارئ";
  String get pd_kg => "كجم";
  String get pd_cm => "سم";
  String get pd_conditions => "الحالات المزمنة";
  String get pd_allergies => "الحساسية";
  String get pd_measurements => "القياسات";
  String get pd_add_cond => "أضف حالة…";
  String get pd_add_alg => "أضف حساسية…";
  String get bmi_label => "كتلة الجسم";
  String get bmi_under => "نقص وزن";
  String get bmi_normal => "صحي";
  String get bmi_over => "زيادة وزن";
  String get bmi_obese => "سمنة";
  String get switch_account => "تبديل الحساب";
  String get p_country => "الدولة";
  String get pd_primary => "أساسي";
  String get pd_basic_info => "المعلومات الأساسية";
  String get pd_contact_section => "معلومات الاتصال";
  String get pd_add_contact => "إضافة جهة اتصال";
  String get pd_change_photo => "تغيير الصورة";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'm_bp':
        return m_bp;
      case 'm_glucose':
        return m_glucose;
      case 'm_mood':
        return m_mood;
      case 'm_pain':
        return m_pain;
      case 'm_weight':
        return m_weight;
      case 'p_personal':
        return p_personal;
      case 'pd_account':
        return pd_account;
      case 'pd_share_qr':
        return pd_share_qr;
      case 'pd_share_qr_h':
        return pd_share_qr_h;
      case 'pd_qr_scan':
        return pd_qr_scan;
      case 'pd_nationality':
        return pd_nationality;
      case 'pd_blood':
        return pd_blood;
      case 'pd_weight':
        return pd_weight;
      case 'pd_height':
        return pd_height;
      case 'pd_phone':
        return pd_phone;
      case 'pd_nid':
        return pd_nid;
      case 'pd_emergency':
        return pd_emergency;
      case 'pd_em_name':
        return pd_em_name;
      case 'pd_em_rel':
        return pd_em_rel;
      case 'pd_em_phone':
        return pd_em_phone;
      case 'pd_save':
        return pd_save;
      case 'pd_saved':
        return pd_saved;
      case 'conn_accounts':
        return conn_accounts;
      case 'conn_apple':
        return conn_apple;
      case 'conn_google':
        return conn_google;
      case 'conn_connect':
        return conn_connect;
      case 'conn_remove':
        return conn_remove;
      case 'p_cond':
        return p_cond;
      case 'p_care':
        return p_care;
      case 'p_notif':
        return p_notif;
      case 'p_lang':
        return p_lang;
      case 'p_privacy':
        return p_privacy;
      case 'p_help':
        return p_help;
      case 'p_signout':
        return p_signout;
      case 'p_emergency':
        return p_emergency;
      case 'pd_kg':
        return pd_kg;
      case 'pd_cm':
        return pd_cm;
      case 'pd_conditions':
        return pd_conditions;
      case 'pd_allergies':
        return pd_allergies;
      case 'pd_measurements':
        return pd_measurements;
      case 'pd_add_cond':
        return pd_add_cond;
      case 'pd_add_alg':
        return pd_add_alg;
      case 'bmi_label':
        return bmi_label;
      case 'bmi_under':
        return bmi_under;
      case 'bmi_normal':
        return bmi_normal;
      case 'bmi_over':
        return bmi_over;
      case 'bmi_obese':
        return bmi_obese;
      case 'switch_account':
        return switch_account;
      case 'p_country':
        return p_country;
      case 'pd_primary':
        return pd_primary;
      case 'pd_basic_info':
        return pd_basic_info;
      case 'pd_contact_section':
        return pd_contact_section;
      case 'pd_add_contact':
        return pd_add_contact;
      case 'pd_change_photo':
        return pd_change_photo;
      default:
        return super[key];
    }
  }
}

class RecordsStrings_ar extends RecordsStrings {
  final Strings_ar _parent;
  const RecordsStrings_ar(this._parent) : super(_parent);
  String get reports => "التقارير السابقة";
  String get rec_search_ph => "ابحث في السجلات والوسوم والنتائج…";
  String get rec_search_clear => "مسح البحث";
  String get rec_tags => "الوسوم";
  String get rec_tags_ph => "أضف وسماً واضغط Enter";
  String get rec_date => "التاريخ";
  String get rec_no_results => "لا سجلات مطابقة";
  String get rec_no_results_h => "لا سجلات تطابق";
  String get rec_no_results_h2 => "لا شيء في هذه الفئة بعد.";
  String get rec_clear_filters => "مسح عوامل التصفية";
  String get prescriptions => "الوصفات الطبية";
  String get records => "السجلات الصحية";
  String get records_short => "السجلات";
  String get all_records => "الكل";
  String get rec_lab => "تحاليل";
  String get rec_scan => "أشعة";
  String get rec_report => "تقارير";
  String get rec_lab_one => "تحليل";
  String get rec_scan_one => "أشعة";
  String get rec_report_one => "تقرير";
  String get rec_self => "رفعتَه بنفسك";
  String get rec_empty => "لا توجد سجلات بعد";
  String get rec_source => "المصدر";
  String get rec_view => "عرض المستند";
  String get rec_share => "مشاركة مع الطبيب";
  String get rec_empty_h =>
      "أضف تحليلاً أو أشعة أو تقريراً لتحتفظ بتاريخك كاملاً في مكان واحد.";
  String get rec_pick_type => "ما الذي تضيفه؟";
  String get rec_title => "العنوان";
  String get rec_title_ph => "مثال: تحليل السكر التراكمي";
  String get rec_attach => "إرفاق ملف أو صورة";
  String get rec_attach_h => "ملف PDF أو صورة لتقرير ورقي أو صورة أشعة.";
  String get rec_take_photo => "التقاط صورة";
  String get rec_from_files => "اختيار ملف";
  String get rec_added => "تمت إضافة السجل";
  String get rec_added_h => "محفوظ على جهازك. ملكك بالتصميم.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'reports':
        return reports;
      case 'rec_search_ph':
        return rec_search_ph;
      case 'rec_search_clear':
        return rec_search_clear;
      case 'rec_tags':
        return rec_tags;
      case 'rec_tags_ph':
        return rec_tags_ph;
      case 'rec_date':
        return rec_date;
      case 'rec_no_results':
        return rec_no_results;
      case 'rec_no_results_h':
        return rec_no_results_h;
      case 'rec_no_results_h2':
        return rec_no_results_h2;
      case 'rec_clear_filters':
        return rec_clear_filters;
      case 'prescriptions':
        return prescriptions;
      case 'records':
        return records;
      case 'records_short':
        return records_short;
      case 'all_records':
        return all_records;
      case 'rec_lab':
        return rec_lab;
      case 'rec_scan':
        return rec_scan;
      case 'rec_report':
        return rec_report;
      case 'rec_lab_one':
        return rec_lab_one;
      case 'rec_scan_one':
        return rec_scan_one;
      case 'rec_report_one':
        return rec_report_one;
      case 'rec_self':
        return rec_self;
      case 'rec_empty':
        return rec_empty;
      case 'rec_source':
        return rec_source;
      case 'rec_view':
        return rec_view;
      case 'rec_share':
        return rec_share;
      case 'rec_empty_h':
        return rec_empty_h;
      case 'rec_pick_type':
        return rec_pick_type;
      case 'rec_title':
        return rec_title;
      case 'rec_title_ph':
        return rec_title_ph;
      case 'rec_attach':
        return rec_attach;
      case 'rec_attach_h':
        return rec_attach_h;
      case 'rec_take_photo':
        return rec_take_photo;
      case 'rec_from_files':
        return rec_from_files;
      case 'rec_added':
        return rec_added;
      case 'rec_added_h':
        return rec_added_h;
      default:
        return super[key];
    }
  }
}

class SettingsStrings_ar extends SettingsStrings {
  final Strings_ar _parent;
  const SettingsStrings_ar(this._parent) : super(_parent);
  String get trust_private => "خصوصية افتراضية";
  String get trust_offline => "يعمل دون إنترنت";
  String get trust_device => "ملكك دائماً";
  String get add_photo => "إضافة صورة";
  String get nat_egyptian => "مصري";
  String get add_member => "إضافة فرد من الأسرة";
  String get choose_lang => "اختر اللغة";
  String get choose_country => "أين أنت الآن؟";
  String get travel_help =>
      "حدّد موقعك ليعرض بَلسَم أرقام الطوارئ ومعلومات الرعاية المحلية أثناء سفرك.";
  String get lang_full => "دعم كامل";
  String get lang_beta => "تجريبي";
  String get home_country => "بلدك";
  String get add_record => "إضافة سجل";
  String get add_calendar => "أضف للتقويم";
  String get na_not_available => "غير متاح بعد";
  String get na_notify_me => "أبلغني عند التوفر";
  String get na_status_support => "حالة الخدمة والدعم";
  String get cal_months =>
      "يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر";
  String get cal_weekdays => "أحد|إثن|ثلا|أرب|خمي|جمع|سبت";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'trust_private':
        return trust_private;
      case 'trust_offline':
        return trust_offline;
      case 'trust_device':
        return trust_device;
      case 'add_photo':
        return add_photo;
      case 'nat_egyptian':
        return nat_egyptian;
      case 'add_member':
        return add_member;
      case 'choose_lang':
        return choose_lang;
      case 'choose_country':
        return choose_country;
      case 'travel_help':
        return travel_help;
      case 'lang_full':
        return lang_full;
      case 'lang_beta':
        return lang_beta;
      case 'home_country':
        return home_country;
      case 'add_record':
        return add_record;
      case 'add_calendar':
        return add_calendar;
      case 'na_not_available':
        return na_not_available;
      case 'na_notify_me':
        return na_notify_me;
      case 'na_status_support':
        return na_status_support;
      case 'cal_months':
        return cal_months;
      case 'cal_weekdays':
        return cal_weekdays;
      default:
        return super[key];
    }
  }
}

class StorageStrings_ar extends StorageStrings {
  final Strings_ar _parent;
  const StorageStrings_ar(this._parent) : super(_parent);
  String get store_backup_to => "نسخ إلى";
  String get store_move_to => "نقل إلى";
  String get store_remove_cloud => "حذف من السحابة";
  String get store_remove_dev => "حذف من الجهاز";
  String get store_delete_all => "حذف من كل مكان";
  String get store_delete_rec => "حذف السجل";
  String get store_manage => "إدارة التخزين";
  String get storage => "التخزين والمزامنة";
  String get storage_short => "التخزين";
  String get storage_icloud => "آي كلاود";
  String get storage_gdrive => "جوجل درايف";
  String get storage_device => "على هذا الجهاز";
  String get store_local => "على هذا الجهاز";
  String get store_icloud => "آي كلاود";
  String get store_gdrive => "جوجل درايف";
  String get store_synced => "تمت المزامنة";
  String get store_local_only => "محلي فقط";
  String get store_backed => "محفوظ احتياطياً";
  String get store_step_prepare => "جارٍ التحضير…";
  String get store_step_checkins => "نقل المتابعات…";
  String get store_step_records => "نقل السجلات…";
  String get store_step_rx => "نقل الوصفات…";
  String get store_step_verify => "التحقق والإنهاء…";
  String get store_choose_help => "اختر مكان حفظ نسخة احتياطية من بياناتك.";
  String get store_always_on => "دائمًا";
  String get store_no_backup => "لا نسخة احتياطية";
  String get store_tap_connect => "اضغط للربط";
  String store_connecting(String target) => "جارٍ الربط بـ $target…";
  String get store_auto_start => "سيبدأ النسخ الاحتياطي تلقائياً.";
  String get store_migrating => "جارٍ النقل";
  String get store_removed_done => "تم إيقاف النسخ الاحتياطي";
  String get store_synced_done => "تمت المزامنة بنجاح";
  String get store_device_only => "محفوظ على هذا الجهاز فقط";
  String store_synced_with(String target) => "مزامن مع $target";
  String get store_done => "تم";
  String get store_remove_q => "إيقاف النسخ الاحتياطي؟";
  String store_remove_help(String target) =>
      "ستُحذف بياناتك من $target وتبقى على جهازك فقط.";
  String get store_remove_cta => "إيقاف النسخ الاحتياطي";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)]
          as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'store_backup_to':
        return store_backup_to;
      case 'store_move_to':
        return store_move_to;
      case 'store_remove_cloud':
        return store_remove_cloud;
      case 'store_remove_dev':
        return store_remove_dev;
      case 'store_delete_all':
        return store_delete_all;
      case 'store_delete_rec':
        return store_delete_rec;
      case 'store_manage':
        return store_manage;
      case 'storage':
        return storage;
      case 'storage_short':
        return storage_short;
      case 'storage_icloud':
        return storage_icloud;
      case 'storage_gdrive':
        return storage_gdrive;
      case 'storage_device':
        return storage_device;
      case 'store_local':
        return store_local;
      case 'store_icloud':
        return store_icloud;
      case 'store_gdrive':
        return store_gdrive;
      case 'store_synced':
        return store_synced;
      case 'store_local_only':
        return store_local_only;
      case 'store_backed':
        return store_backed;
      case 'store_step_prepare':
        return store_step_prepare;
      case 'store_step_checkins':
        return store_step_checkins;
      case 'store_step_records':
        return store_step_records;
      case 'store_step_rx':
        return store_step_rx;
      case 'store_step_verify':
        return store_step_verify;
      case 'store_choose_help':
        return store_choose_help;
      case 'store_always_on':
        return store_always_on;
      case 'store_no_backup':
        return store_no_backup;
      case 'store_tap_connect':
        return store_tap_connect;
      case 'store_connecting':
        return store_connecting;
      case 'store_auto_start':
        return store_auto_start;
      case 'store_migrating':
        return store_migrating;
      case 'store_removed_done':
        return store_removed_done;
      case 'store_synced_done':
        return store_synced_done;
      case 'store_device_only':
        return store_device_only;
      case 'store_synced_with':
        return store_synced_with;
      case 'store_done':
        return store_done;
      case 'store_remove_q':
        return store_remove_q;
      case 'store_remove_help':
        return store_remove_help;
      case 'store_remove_cta':
        return store_remove_cta;
      default:
        return super[key];
    }
  }
}
