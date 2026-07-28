// ignore_for_file: unused_element, unused_field, camel_case_types, annotate_overrides, prefer_single_quotes
// GENERATED FILE, do not edit!
// dart format off
import 'package:i69n/i69n.dart' as i69n;
import 'package:core/core.dart';

String get _languageCode => 'en';
String get _localeName => 'en';

class Strings implements i69n.I69nMessageBundle {
  const Strings();
  AuthStrings get auth => AuthStrings(this);
  BootStrings get boot => BootStrings(this);
  CareStrings get care => CareStrings(this);
  CheckinStrings get checkin => CheckinStrings(this);
  CommonStrings get common => CommonStrings(this);
  EmergencyStrings get emergency => EmergencyStrings(this);
  HomeStrings get home => HomeStrings(this);
  MedsStrings get meds => MedsStrings(this);
  NavStrings get nav => NavStrings(this);
  OnboardingStrings get onboarding => OnboardingStrings(this);
  PrivacyStrings get privacy => PrivacyStrings(this);
  ProfileStrings get profile => ProfileStrings(this);
  RecordsStrings get records => RecordsStrings(this);
  SettingsStrings get settings => SettingsStrings(this);
  StorageStrings get storage => StorageStrings(this);
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class AuthStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const AuthStrings(this._parent);
  String get use_phone => "Use phone instead";
  String get use_email => "Use email instead";
  String get un_label => "Handle";
  String get un_ph => "e.g. layla_hassan";
  String get un_avail => "Available";
  String get un_taken => "Already taken";
  String get un_checking => "Checking…";
  String get un_invalid => "Only letters, numbers, and _ (3–20 chars)";
  String get ph_title => "What's your number?";
  String get ph_help => "We'll text you a code to confirm it's you.";
  String get ph_label => "Mobile number";
  String get ph_terms =>
      "By continuing you agree to Balsm's terms and privacy policy.";
  String get otp_title => "Enter your code";
  String get otp_help => "We sent a 6-digit code to";
  String get otp_resend => "Resend code";
  String get otp_in => "Resend in";
  String get otp_wrong => "Wrong number?";
  String get verify => "Verify";
  String get pw_label => "Password";
  String get pw_ph => "Enter your password";
  String get pw_show => "Show password";
  String get pw_hide => "Hide password";
  String get forgot_pw => "Forgot?";
  String get use_code => "Use a one-time code instead";
  String get use_password => "Use a password instead";
  String get pw_signin => "Sign in";
  String get pw_min => "At least 8 characters";
  String get pw_invalid_creds => "Invalid email or password.";
  String get fp_title => "Reset your password";
  String get fp_help =>
      "Enter your email — we'll send a code to reset your password.";
  String get fp_send => "Send reset code";
  String get fp_code_label => "Reset code";
  String get fp_new_pw => "New password";
  String get fp_reset => "Reset password";
  String get fp_sent_help => "We sent a reset code to";
  String get fp_done => "Done";
  String get fp_success => "Password updated. Sign in with your new password.";
  String get dial_title => "Country code";
  String get dial_search => "Search country";
  String auth_locked_retry(String secs) =>
      "Account temporarily locked. Try again in ${secs}s.";
  String get auth_phone_soon =>
      "Phone sign-in isn't available yet — please use email.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class BootStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const BootStrings(this._parent);
  String get boot_preparing => "Preparing your health record";
  String get boot_tagline => "On your device, by design.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CareStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const CareStrings(this._parent);
  String get to_doctor => "A copy reaches Dr. Sara at your next visit.";
  String get to_home => "Back to home";
  String get care_intro =>
      "The doctors following your condition and who can see your reports.";
  String get care_primary => "Primary";
  String get care_message => "Message";
  String get care_book => "Book";
  String get care_find => "Find a new doctor";
  String get appts => "Appointments";
  String get upcoming_appt => "Upcoming appointment";
  String get past_appts => "Past visits";
  String get book_appt => "Book";
  String get follow_up => "Follow-up";
  String get check_up => "Check-up";
  String get book_via_doctor =>
      "Your care team will schedule appointments for you.";
  String get map_nearby => "Nearby care";
  String get map_search_ph => "Search clinics, pharmacies…";
  String get map_all => "All";
  String get map_open_now => "Open now";
  String get map_distance => "away";
  String get map_call => "Call";
  String get map_directions => "Directions";
  String get map_list => "List";
  String get map_map => "Map";
  String get map_found => "places nearby";
  String get map_your_loc => "Your location";
  String get map_no_results => "No places found";
  String get care_empty => "No care team yet";
  String get care_add_help =>
      "Add a doctor from the map to build your care team.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CheckinStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const CheckinStrings(this._parent);
  String get latest => "Latest readings";
  String get unit_bp => "mmHg";
  String get unit_glu => "mg/dL";
  String get bp_normal => "In range";
  String get bp_high => "A little high";
  String get q_mood_h => "Pick the face that fits best.";
  String get mood_1 => "Rough";
  String get mood_2 => "Low";
  String get mood_3 => "Okay";
  String get mood_4 => "Good";
  String get mood_5 => "Great";
  String get q_bp_t => "What's your blood pressure?";
  String get q_bp_h => "Tap a number, then use the keypad.";
  String get sys => "Systolic";
  String get dia => "Diastolic";
  String get q_glu_t => "And your blood sugar?";
  String get q_glu_h => "Enter the reading from your glucometer.";
  String get glu_fast => "Fasting";
  String get glu_meal => "After a meal";
  String get glu_random => "Random";
  String get q_med_t => "Did you take your medications?";
  String get q_med_h => "Tap each one you've taken today.";
  String get q_sym_t => "Any pain or symptoms?";
  String get pain_0 => "No pain";
  String get pain_mild => "Mild";
  String get pain_mod => "Moderate";
  String get pain_sev => "Severe";
  String get pain_worst => "Worst";
  String get note_lbl => "Anything else? (optional)";
  String get note_ph => "Add a note for your doctor…";
  String get s_headache => "Headache";
  String get s_dizzy => "Dizziness";
  String get s_fatigue => "Fatigue";
  String get s_blurred => "Blurred vision";
  String get s_swelling => "Swelling";
  String get s_chest => "Chest tightness";
  String get s_nausea => "Nausea";
  String get s_thirst => "Excess thirst";
  String get s_none => "Nothing";
  String get view_trends => "View trends";
  String get trends => "Trends";
  String get range_w => "Week";
  String get range_m => "Month";
  String get range_3m => "3 months";
  String get avg => "avg";
  String get symptoms => "Symptoms";
  String get ql_title => "Let's check in";
  String get ql_add_records => "add to records";
  String get full_checkin => "Full check-in";
  String get quick_log_or => "or log just one";
  String get body_location => "Where does it hurt?";
  String get cond_icd10_hint => "ICD-10 (optional)";
  String get cond_onset_hint => "Onset yr";
  String get q_vitals_t => "Your vitals";
  String get q_vitals_h => "Enter any readings you took today — all optional.";
  String get vital_hr => "Heart rate";
  String get unit_hr => "bpm";
  String get vital_temp => "Temperature";
  String get unit_temp => "°C";
  String get vital_spo2 => "Oxygen (SpO₂)";
  String get unit_spo2 => "%";
  String get sym_headache => "Headache";
  String get sym_dizzy => "Dizziness";
  String get sym_fatigue => "Fatigue";
  String get sym_blurred_vision => "Blurred vision";
  String get sym_swelling => "Swelling";
  String get sym_chest_tightness => "Chest tightness";
  String get sym_nausea => "Nausea";
  String get sym_thirst => "Excess thirst";
  String get body_head => "Head";
  String get body_neck => "Neck";
  String get body_l_shoulder => "L. Shoulder";
  String get body_r_shoulder => "R. Shoulder";
  String get body_chest => "Chest";
  String get body_l_upper_arm => "L. Upper arm";
  String get body_r_upper_arm => "R. Upper arm";
  String get body_abdomen => "Abdomen";
  String get body_l_elbow => "L. Elbow";
  String get body_r_elbow => "R. Elbow";
  String get body_l_forearm => "L. Forearm";
  String get body_r_forearm => "R. Forearm";
  String get body_pelvis => "Pelvis";
  String get body_l_hand => "L. Hand";
  String get body_r_hand => "R. Hand";
  String get body_l_thigh => "L. Thigh";
  String get body_r_thigh => "R. Thigh";
  String get body_l_knee => "L. Knee";
  String get body_r_knee => "R. Knee";
  String get body_l_shin => "L. Shin";
  String get body_r_shin => "R. Shin";
  String get body_l_foot => "L. Foot";
  String get body_r_foot => "R. Foot";
  String get body_bk_head => "Head";
  String get body_bk_neck => "Neck";
  String get body_bk_l_shoulder => "L. Shoulder";
  String get body_bk_r_shoulder => "R. Shoulder";
  String get body_bk_upper => "Upper back";
  String get body_bk_mid => "Mid back";
  String get body_bk_lower => "Lower back";
  String get body_bk_l_glute => "L. Glute";
  String get body_bk_r_glute => "R. Glute";
  String get body_bk_l_hamstr => "L. Hamstring";
  String get body_bk_r_hamstr => "R. Hamstring";
  String get body_bk_l_calf => "L. Calf";
  String get body_bk_r_calf => "R. Calf";
  String get body_bk_l_heel => "L. Heel";
  String get body_bk_r_heel => "R. Heel";
  String q_mood_t(Gender gender) => "How are you feeling today?";
  String q_sym_h(Gender gender) =>
      "Slide to your pain level, then tap anything you feel.";
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
      case 'q_mood_t':
        return q_mood_t;
      case 'q_sym_h':
        return q_sym_h;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class CommonStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const CommonStrings(this._parent);
  String get continue_ => "Continue";
  String get today_lbl => "Today's check-in";
  String get done_lbl => "All done for today";
  String get done_q => "Check-in complete";
  String get recent => "Recent reports";
  String get see_all => "See all";
  String get yesterday => "vs yesterday";
  String get step_of => "of";
  String get back => "Back";
  String get finish => "Finish check-in";
  String get saved_t => "Check-in saved";
  String get saved_local => "Saved locally. Will sync when you reconnect.";
  String get no_symptoms => "No symptoms";
  String get profile => "Profile";
  String get since => "Balsm patient since";
  String get no_appts => "No upcoming appointments";
  String get your_accounts => "Your accounts";
  String get pages => "pages";
  String get cancel => "Cancel";
  String get acc_active => "Active account";
  String get acc_not_signed_in => "Not signed in";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EmergencyStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const EmergencyStrings(this._parent);
  String get em_title => "What's your email?";
  String get em_help => "We'll send you a code to verify it's you.";
  String get em_label => "Email address";
  String get em_ph => "you@example.com";
  String get em_otp_h => "We sent a 6-digit code to";
  String get em_eg => "Egypt";
  String get em_intro =>
      "Egypt's nationwide emergency lines. Tap any number to call right away.";
  String get em_tap_call => "Tap to call";
  String get em_ambulance => "Ambulance";
  String get em_police => "Police";
  String get em_fire => "Fire & rescue";
  String get em_tourist => "Tourist police";
  String get emergency => "Emergency";
  String get em_pw_title => "Welcome back";
  String get em_pw_help => "Sign in with your email and password.";
  String get eqr_title => "Emergency QR";
  String get eqr_ttl_1h => "1h";
  String get eqr_ttl_6h => "6h";
  String get eqr_ttl_24h => "24h";
  String get eqr_ttl_7d => "7d";
  String get eqr_help_active =>
      "Show this encrypted code to emergency staff. It expires automatically; the decryption key travels only inside the link.";
  String get eqr_help_signin => "Sign in to share your emergency health card.";
  String get eqr_help_incomplete =>
      "Add your blood type, allergies, conditions or an emergency contact to share an emergency card.";
  String get eqr_help_create =>
      "Generate a secure, encrypted QR of your emergency health profile. The decryption key stays on your device.";
  String get eqr_expired => "Expired";
  String eqr_expires_in(String t) => "Expires in $t";
  String get eqr_copy => "Copy";
  String get eqr_share => "Share";
  String get eqr_save => "Save";
  String get eqr_saved_toast => "Saved to Photos";
  String get eqr_link_copied => "Link copied";
  String get eqr_revoke => "Revoke code";
  String get eqr_revoked_toast => "QR revoked";
  String get eqr_generate => "Generate QR";
  String get eqr_generate_new => "Generate new code";
  String get eqr_valid_for => "Valid for";
  String get eqr_signin_required => "Sign in required";
  String get eqr_no_data => "No health data yet";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class HomeStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const HomeStrings(this._parent);
  String get nudge_handle => "Claim your handle";
  String get nudge_handle_sub => "Get set up";
  String get nudge_ec => "Add emergency card";
  String get nudge_ec_sub => "Be prepared";
  String get nudge_med => "Add a medication";
  String get nudge_med_sub => "Stay on track";
  String get greet => "Good morning";
  String get hero_time => "About 2 minutes";
  String get streak => "day streak";
  String get streak_help => "Checked in 6 of the last 7 days";
  String get on_track => "On track";
  String get experience => "experience";
  String get away_banner => "You're away from home";
  String hero_q(Gender gender) => "How are you feeling today?";
  String hero_cta(Gender gender) => "Start check-in";
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
      case 'hero_q':
        return hero_q;
      case 'hero_cta':
        return hero_cta;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class MedsStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const MedsStrings(this._parent);
  String get meds_today => "Today's medications";
  String get taken => "Taken";
  String get due => "Due";
  String get take => "Take";
  String get skip_q => "I didn't measure this today";
  String get skipped => "Skipped";
  String get mark_skip => "Didn't take";
  String get meds_taken => "taken";
  String get medications => "Medications";
  String get morning => "Morning";
  String get evening => "Evening";
  String get adherence => "this week";
  String get rx_active => "Active";
  String get rx_expired => "Expired";
  String get rx_valid_until => "Valid until";
  String get rx_show => "Show to pharmacist";
  String get rx_scan => "Scan to dispense";
  String get dose_skipped => "Skipped";
  String get dose_snoozed => "Snoozed";
  String get dose_missed => "Missed";
  String get med_scheduled => "Scheduled";
  String get med_snooze15 => "Snooze 15 min";
  String get med_skip => "Skip";
  String get tz_changed => "Time zone changed";
  String get tz_recompute => "Recompute reminders";
  String get tz_keep => "Keep as is";
  String get med_add_title => "Add medication";
  String get med_field_name => "Name";
  String get med_ph_name => "Medication name";
  String get med_field_dose => "Dose (optional)";
  String get med_ph_dose => "e.g. 500 mg";
  String get med_reminder_time => "Daily reminder time";
  String get med_add_btn => "Add medication";
  String get med_time_morning => "Morning";
  String get med_time_midday => "Midday";
  String get med_time_evening => "Evening";
  String get med_time_night => "Night";
  String get meds_signin_help => "Sign in to view your medications.";
  String get meds_empty_help => "No medications yet. Add one to get started.";
  String get meds_none_today => "Nothing scheduled today.";
  String meds_tz_moved(String from, String to) =>
      "You moved from $from to $to. Recompute your medication reminder times for the new local time?";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class NavStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const NavStrings(this._parent);
  String get tab_home => "Home";
  String get tab_map => "Nearby";
  String get tab_meds => "Meds";
  String get tab_profile => "Profile";
  String get gov_sessions => "Devices & sessions";
  String get gov_status => "Service status";
  String get gov_delete => "Delete account";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class OnboardingStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const OnboardingStrings(this._parent);
  String get w_title => "Your health, kept close.";
  String get w_sub =>
      "Daily check-ins, medication reminders, and trends — saved on your phone, synced when you're ready.";
  String get w_have => "I already have an account";
  String get w_signin => "Sign in";
  String get w_or => "or";
  String get w_apple => "Continue with Apple";
  String get w_google => "Continue with Google";
  String get pf_title => "Tell us about you";
  String get pf_help =>
      "This helps your care team read your reports correctly.";
  String get pf_fname => "First name";
  String get pf_lname => "Last name";
  String get pf_fname_ph => "e.g. Layla";
  String get pf_lname_ph => "e.g. Hassan";
  String get pf_dob => "Date of birth";
  String get pf_gender => "Gender";
  String get pf_female => "Female";
  String get pf_male => "Male";
  String get pf_gov => "Governorate";
  String get pf_create => "Create my profile";
  String get pf_secure => "Your details stay on this device.";
  String get dob_title => "Date of birth";
  String get dob_confirm => "Confirm";
  String get dob_select => "Select a date";
  String get age_gate_body =>
      "Balsm is currently available for ages 18 and older. We're working on a version for younger users with parental consent.";
  String w_start(Gender gender) => "Get started";
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
      case 'w_start':
        return w_start;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class PrivacyStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const PrivacyStrings(this._parent);
  String get pv_sharing => "Data sharing";
  String get pv_share_team => "Share reports with care team";
  String get pv_share_team_h => "Your doctors can see your daily readings";
  String get pv_analytics => "Anonymous analytics";
  String get pv_analytics_h => "Help us improve the app";
  String get pv_research => "Research contributions";
  String get pv_research_h => "De-identified data for medical studies";
  String get pv_security => "Security";
  String get pv_bio => "Biometric app lock";
  String get pv_bio_h => "Unlock with Face ID / fingerprint";
  String get pv_pin => "Require PIN on open";
  String get pv_pin_h => "An extra layer of protection";
  String get pv_yourdata => "Your data";
  String get pv_export => "Export my data";
  String get pv_export_h => "As a PDF or CSV file";
  String get pv_download => "Download health records";
  String get pv_download_h => "All labs and scans";
  String get pv_connected => "Connected apps";
  String get pv_connected_h => "Manage third-party access";
  String get pv_danger => "Danger zone";
  String get pv_delete => "Delete my account";
  String get pv_delete_h => "Permanently erase all your data";
  String get pv_encrypted => "Your data is encrypted and protected";
  String get pv_title => "Your privacy & data";
  String get pv_collect => "What we collect";
  String get pv_protect => "How we protect it";
  String get pv_rights => "Your rights";
  String get pv_authority => "Supervisory authority";
  String get pv_sharing2 => "Sharing";
  String get pv_deletion => "Deletion";
  String get pv_saving => "Saving…";
  String get pv_agree => "I agree & continue";
  String get pv_intro_body =>
      "Before you continue, please review how we handle your data. Your health data stays on your device.";
  String get pv_collect_body =>
      "A minimal non-health account (email, country, language). Health records stay encrypted on your device.";
  String get pv_protect_body =>
      "On-device encryption, secure transport, and least-privilege access.";
  String get pv_rights_body =>
      "Access, correct, or delete your data at any time from account settings.";
  String pv_authority_body(String authority) =>
      "The authority overseeing your data protection in your country: $authority.";
  String get pv_sharing_body =>
      "We never sell your data. Sharing happens only with your explicit consent or a legal obligation.";
  String get pv_deletion_body =>
      "Deleting your account removes your non-health cloud data and wipes on-device records.";
  String get pv_scroll_hint => "Scroll down to continue";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class ProfileStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const ProfileStrings(this._parent);
  String get m_bp => "Blood pressure";
  String get m_glucose => "Blood glucose";
  String get m_mood => "Mood";
  String get m_pain => "Pain";
  String get m_weight => "Weight";
  String get p_personal => "Account details";
  String get pd_account => "Account";
  String get pd_share_qr => "Share my QR code";
  String get pd_share_qr_h => "Let others scan to connect";
  String get pd_qr_scan => "Scan to connect on Balsm";
  String get pd_nationality => "Nationality";
  String get pd_blood => "Blood type";
  String get pd_weight => "Weight";
  String get pd_height => "Height";
  String get pd_phone => "Mobile number";
  String get pd_nid => "National ID";
  String get pd_emergency => "Emergency contact";
  String get pd_em_name => "Name";
  String get pd_em_rel => "Relationship";
  String get pd_em_phone => "Phone";
  String get pd_save => "Save changes";
  String get pd_saved => "Saved";
  String get conn_accounts => "Connected accounts";
  String get conn_apple => "Apple ID";
  String get conn_google => "Google account";
  String get conn_connect => "Connect";
  String get conn_remove => "Remove";
  String get p_cond => "Medical profile";
  String get p_care => "Care team";
  String get p_notif => "Reminders";
  String get p_lang => "Language";
  String get p_privacy => "Privacy & data";
  String get p_help => "Help & support";
  String get p_signout => "Sign out";
  String get p_emergency => "Emergency";
  String get pd_kg => "kg";
  String get pd_cm => "cm";
  String get pd_conditions => "Chronic conditions";
  String get pd_allergies => "Allergies";
  String get pd_measurements => "Measurements";
  String get pd_add_cond => "Add a condition…";
  String get pd_add_alg => "Add an allergy…";
  String get bmi_label => "BMI";
  String get bmi_under => "Underweight";
  String get bmi_normal => "Healthy";
  String get bmi_over => "Overweight";
  String get bmi_obese => "Obese";
  String get switch_account => "Switch account";
  String get p_country => "Country";
  String get pd_primary => "Primary";
  String get pd_basic_info => "Basic info";
  String get pd_contact_section => "Contact";
  String get pd_add_contact => "Add contact";
  String get pd_change_photo => "Change photo";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class RecordsStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const RecordsStrings(this._parent);
  String get reports => "Past reports";
  String get rec_search_ph => "Search records, tags, results…";
  String get rec_search_clear => "Clear search";
  String get rec_tags => "Tags";
  String get rec_tags_ph => "Add a tag and press Enter";
  String get rec_date => "Date";
  String get rec_no_results => "No matching records";
  String get rec_no_results_h => "No records match";
  String get rec_no_results_h2 => "Nothing in this category yet.";
  String get rec_clear_filters => "Clear filters";
  String get prescriptions => "Prescriptions";
  String get records => "Health records";
  String get records_short => "Records";
  String get all_records => "All";
  String get rec_lab => "Lab tests";
  String get rec_scan => "Scans";
  String get rec_report => "Reports";
  String get rec_lab_one => "Lab test";
  String get rec_scan_one => "Scan";
  String get rec_report_one => "Report";
  String get rec_self => "You uploaded";
  String get rec_empty => "No records yet";
  String get rec_source => "Source";
  String get rec_view => "View document";
  String get rec_share => "Share with doctor";
  String get rec_empty_h =>
      "Add a lab test, scan, or report to keep your whole history in one place.";
  String get rec_pick_type => "What are you adding?";
  String get rec_title => "Title";
  String get rec_title_ph => "e.g. HbA1c blood test";
  String get rec_attach => "Attach file or photo";
  String get rec_attach_h => "PDF, photo of a paper report, or a scan image.";
  String get rec_take_photo => "Take a photo";
  String get rec_from_files => "Choose a file";
  String get rec_added => "Record added";
  String get rec_added_h => "Stored on your device. Yours by design.";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class SettingsStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const SettingsStrings(this._parent);
  String get trust_private => "Private by default";
  String get trust_offline => "Works offline";
  String get trust_device => "Yours, always";
  String get add_photo => "Add a photo";
  String get nat_egyptian => "Egyptian";
  String get add_member => "Add family member";
  String get choose_lang => "Choose language";
  String get choose_country => "Where are you now?";
  String get travel_help =>
      "Set your location so Balsm shows local emergency numbers and care info while you travel.";
  String get lang_full => "Full support";
  String get lang_beta => "Beta";
  String get home_country => "Home";
  String get add_record => "Add record";
  String get add_calendar => "Add to calendar";
  String get na_not_available => "Not available yet";
  String get na_notify_me => "Notify me when available";
  String get na_status_support => "Service status & support";
  String get cal_months =>
      "January|February|March|April|May|June|July|August|September|October|November|December";
  String get cal_weekdays => "Su|Mo|Tu|We|Th|Fr|Sa";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class StorageStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const StorageStrings(this._parent);
  String get store_backup_to => "Back up to";
  String get store_move_to => "Move to";
  String get store_remove_cloud => "Remove from cloud";
  String get store_remove_dev => "Remove from device";
  String get store_delete_all => "Delete everywhere";
  String get store_delete_rec => "Delete record";
  String get store_manage => "Manage storage";
  String get storage => "Storage & sync";
  String get storage_short => "Storage";
  String get storage_icloud => "iCloud";
  String get storage_gdrive => "Google Drive";
  String get storage_device => "On this device";
  String get store_local => "On this device";
  String get store_icloud => "iCloud";
  String get store_gdrive => "Google Drive";
  String get store_synced => "Synced";
  String get store_local_only => "Local only";
  String get store_backed => "Backed up";
  String get store_step_prepare => "Preparing…";
  String get store_step_checkins => "Transferring check-ins…";
  String get store_step_records => "Transferring records…";
  String get store_step_rx => "Transferring prescriptions…";
  String get store_step_verify => "Verifying & finishing…";
  String get store_choose_help => "Choose where to keep a backup of your data.";
  String get store_always_on => "Always on";
  String get store_no_backup => "No backup";
  String get store_tap_connect => "Tap to connect";
  String store_connecting(String target) => "Connecting to $target…";
  String get store_auto_start => "Backup will start automatically.";
  String get store_migrating => "Migrating";
  String get store_removed_done => "Cloud backup removed";
  String get store_synced_done => "All synced";
  String get store_device_only => "Saved on this device only";
  String store_synced_with(String target) => "Synced with $target";
  String get store_done => "Done";
  String get store_remove_q => "Remove cloud backup?";
  String store_remove_help(String target) =>
      "Your data will be removed from $target and kept on this device only.";
  String get store_remove_cta => "Remove cloud backup";
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
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}
