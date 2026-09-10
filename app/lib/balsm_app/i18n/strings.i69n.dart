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
  WalkthroughStrings get walkthrough => WalkthroughStrings(this);
  PrivacyStrings get privacy => PrivacyStrings(this);
  ProfileStrings get profile => ProfileStrings(this);
  EcosystemStrings get ecosystem => EcosystemStrings(this);
  FeedbackStrings get feedback => FeedbackStrings(this);
  RecordsStrings get records => RecordsStrings(this);
  SettingsStrings get settings => SettingsStrings(this);
  StorageStrings get storage => StorageStrings(this);
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'walkthrough':
        return walkthrough;
      case 'privacy':
        return privacy;
      case 'profile':
        return profile;
      case 'ecosystem':
        return ecosystem;
      case 'feedback':
        return feedback;
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
  String get un_label => "Handle";
  String get un_ph => "e.g. layla_hassan";
  String get un_avail => "Available";
  String get un_taken => "Already taken";
  String get un_checking => "Checking…";
  String get un_invalid => "Only letters, numbers, and _ (3–20 chars)";
  String get ph_terms_pre => "By continuing you agree to Balsm's";
  String get ph_terms_link => "terms";
  String get ph_terms_and => "and";
  String get ph_priv_link => "privacy policy";
  String get legal_terms_t => "Terms of use";
  String get legal_priv_t => "Privacy policy";
  String get legal_updated => "Notice version";
  String get otp_title => "Enter your code";
  String get otp_resend => "Resend code";
  String get otp_in => "Resend in";
  String get verify => "Verify";
  String get pw_label => "Password";
  String get pw_ph => "Enter your password";
  String get forgot_pw => "Forgot password?";
  String get pw_signin => "Sign in";
  String get pw_signup => "Sign up";
  String get pw_signing_in => "Signing in…";
  String get otp_verifying => "Verifying…";
  String get pw_invalid_creds => "Invalid email or password.";
  String get fp_title => "Reset your password";
  String get fp_help => "Enter your email — we'll send a code to reset your password.";
  String get fp_send => "Send reset code";
  String get fp_code_label => "Reset code";
  String get fp_new_pw => "New password";
  String get fp_reset => "Reset password";
  String get fp_sent_help => "We sent a reset code to";
  String get fp_done => "Done";
  String get fp_success => "Password updated. Sign in with your new password.";
  String auth_locked_retry(String secs) => "Account temporarily locked. Try again in ${secs}s.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
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
      case 'ph_terms_pre':
        return ph_terms_pre;
      case 'ph_terms_link':
        return ph_terms_link;
      case 'ph_terms_and':
        return ph_terms_and;
      case 'ph_priv_link':
        return ph_priv_link;
      case 'legal_terms_t':
        return legal_terms_t;
      case 'legal_priv_t':
        return legal_priv_t;
      case 'legal_updated':
        return legal_updated;
      case 'otp_title':
        return otp_title;
      case 'otp_resend':
        return otp_resend;
      case 'otp_in':
        return otp_in;
      case 'verify':
        return verify;
      case 'pw_label':
        return pw_label;
      case 'pw_ph':
        return pw_ph;
      case 'forgot_pw':
        return forgot_pw;
      case 'pw_signin':
        return pw_signin;
      case 'pw_signup':
        return pw_signup;
      case 'pw_signing_in':
        return pw_signing_in;
      case 'otp_verifying':
        return otp_verifying;
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
      case 'auth_locked_retry':
        return auth_locked_retry;
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
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
  String get map_sub => "places mapped nearby";
  String get to_doctor => "A copy reaches Dr. Sara at your next visit.";
  String get to_home => "Back to home";
  String get care_intro => "The doctors following your condition and who can see your reports.";
  String get care_find => "Find a new doctor";
  String get follow_up => "Follow-up";
  String get check_up => "Check-up";
  String get map_nearby => "Nearby care";
  String get map_search_ph => "Search clinics, pharmacies…";
  String get map_all => "All";
  String get map_distance => "away";
  String get map_call => "Call";
  String get map_directions => "Directions";
  String get map_list => "List";
  String get map_map => "Map";
  String get map_found => "places nearby";
  String get map_no_results => "No places found";
  String get map_no_res_h => "Try a different search or filter.";
  String map_n_types(String n) => "$n types";
  String get map_clear => "Clear search";
  String get care_empty => "No care team yet";
  String get care_add_help => "Add a doctor from the map to build your care team.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'map_sub':
        return map_sub;
      case 'to_doctor':
        return to_doctor;
      case 'to_home':
        return to_home;
      case 'care_intro':
        return care_intro;
      case 'care_find':
        return care_find;
      case 'follow_up':
        return follow_up;
      case 'check_up':
        return check_up;
      case 'map_nearby':
        return map_nearby;
      case 'map_search_ph':
        return map_search_ph;
      case 'map_all':
        return map_all;
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
      case 'map_no_results':
        return map_no_results;
      case 'map_no_res_h':
        return map_no_res_h;
      case 'map_n_types':
        return map_n_types;
      case 'map_clear':
        return map_clear;
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
  String get unit_kg => "kg";
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
  String get s_none => "Nothing";
  String get view_trends => "View trends";
  String get trends => "Trends";
  String get range_w => "Week";
  String get range_m => "Month";
  String get range_3m => "3 months";
  String get trend_all_metrics => "All metrics";
  String trend_n_metrics(String n) => "$n metrics";
  String get avg => "avg";
  String get no_checkins => "No check-ins yet";
  String get no_readings => "No readings in this range";
  String get symptoms => "Symptoms";
  String symptoms_n(String n) => "$n symptoms";
  String get ql_title => "Let's check in";
  String get ql_search => "Search";
  String get ql_no_results => "No matches";
  String get ql_vitals => "Vitals";
  String get ql_wellbeing => "Wellbeing";
  String get ql_add_records => "add to records";
  String get full_checkin => "Full check-in";
  String get ql_full_sub => "Mood · BP · glucose · meds";
  String get quick_log_or => "or log just one";
  String get ql_save => "Save";
  String get ql_saved => "Saved";
  String get body_location => "Where does it hurt?";
  String get body_view_front => "Front";
  String get body_view_back => "Back";
  String get body_tap => "Tap to mark location";
  String get list_sep => ", ";
  String get list_mid => " · ";
  String pain_n(String n) => "$n/10";
  String pain_n_where(String n, String where) => "$n/10 · $where";
  String labeled_where(String label, String where) => "$label · $where";
  String reading_unit(String n, String unit) => "$n $unit";
  String reading_unit_ctx(String n, String unit, String ctx) => "$n $unit · $ctx";
  String bp_pair(String sys, String dia) => "$sys/$dia";
  String get cond_icd10_hint => "ICD-10 (optional)";
  String get cond_onset_hint => "Onset yr";
  String get q_vitals_t => "Your vitals";
  String get q_vitals_h => "Enter any readings you took today — all optional.";
  String get unit_spo2 => "%";
  String get sym_headache => "Headache";
  String get sym_dizzy => "Dizziness";
  String get sym_fatigue => "Fatigue";
  String get sym_blurred_vision => "Blurred vision";
  String get sym_swelling => "Swelling";
  String get sym_chest_tightness => "Chest tightness";
  String get sym_nausea => "Nausea";
  String get sym_thirst => "Excess thirst";
  String q_mood_t(Gender gender) => "How are you feeling today?";
  String q_sym_h(Gender gender) => "Slide to your pain level, then tap anything you feel.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'latest':
        return latest;
      case 'unit_bp':
        return unit_bp;
      case 'unit_glu':
        return unit_glu;
      case 'unit_kg':
        return unit_kg;
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
      case 'trend_all_metrics':
        return trend_all_metrics;
      case 'trend_n_metrics':
        return trend_n_metrics;
      case 'avg':
        return avg;
      case 'no_checkins':
        return no_checkins;
      case 'no_readings':
        return no_readings;
      case 'symptoms':
        return symptoms;
      case 'symptoms_n':
        return symptoms_n;
      case 'ql_title':
        return ql_title;
      case 'ql_search':
        return ql_search;
      case 'ql_no_results':
        return ql_no_results;
      case 'ql_vitals':
        return ql_vitals;
      case 'ql_wellbeing':
        return ql_wellbeing;
      case 'ql_add_records':
        return ql_add_records;
      case 'full_checkin':
        return full_checkin;
      case 'ql_full_sub':
        return ql_full_sub;
      case 'quick_log_or':
        return quick_log_or;
      case 'ql_save':
        return ql_save;
      case 'ql_saved':
        return ql_saved;
      case 'body_location':
        return body_location;
      case 'body_view_front':
        return body_view_front;
      case 'body_view_back':
        return body_view_back;
      case 'body_tap':
        return body_tap;
      case 'list_sep':
        return list_sep;
      case 'list_mid':
        return list_mid;
      case 'pain_n':
        return pain_n;
      case 'pain_n_where':
        return pain_n_where;
      case 'labeled_where':
        return labeled_where;
      case 'reading_unit':
        return reading_unit;
      case 'reading_unit_ctx':
        return reading_unit_ctx;
      case 'bp_pair':
        return bp_pair;
      case 'cond_icd10_hint':
        return cond_icd10_hint;
      case 'cond_onset_hint':
        return cond_onset_hint;
      case 'q_vitals_t':
        return q_vitals_t;
      case 'q_vitals_h':
        return q_vitals_h;
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
  String get step_of => "of";
  String get back => "Back";
  String get finish => "Finish check-in";
  String get saved_t => "Check-in saved";
  String get saved_local => "Saved locally. Will sync when you reconnect.";
  String get profile => "Profile";
  String get your_accounts => "Your accounts";
  String get pages => "pages";
  String get cancel => "Cancel";
  String get acc_active => "Active account";
  String get acc_not_signed_in => "Not signed in";
  String get loading => "Loading";
  String get today => "Today";
  String get date => "Date";
  String get time => "Time";
  String get details => "Details";
  String get select_date => "Select a date";
  String get roadmap => "Roadmap";
  String get member_name => "Name";
  String get member_name_ph => "Family member's name";
  String get relation => "Relation";
  String get select_relation => "Select a relation";
  String get rel_default => "Family member";
  String get member_dob => "Date of birth";
  String get member_dob_ph => "DD / MM / YYYY";
  String get yrs => "yrs";
  String get add_member_cta => "Add member";
  String get rel_spouse => "Spouse";
  String get rel_son => "Son";
  String get rel_daughter => "Daughter";
  String get rel_father => "Father";
  String get rel_mother => "Mother";
  String get rel_sibling => "Sibling";
  String get rel_grandparent => "Grandparent";
  String get rel_other => "Other";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'profile':
        return profile;
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
      case 'loading':
        return loading;
      case 'today':
        return today;
      case 'date':
        return date;
      case 'time':
        return time;
      case 'details':
        return details;
      case 'select_date':
        return select_date;
      case 'roadmap':
        return roadmap;
      case 'member_name':
        return member_name;
      case 'member_name_ph':
        return member_name_ph;
      case 'relation':
        return relation;
      case 'select_relation':
        return select_relation;
      case 'rel_default':
        return rel_default;
      case 'member_dob':
        return member_dob;
      case 'member_dob_ph':
        return member_dob_ph;
      case 'yrs':
        return yrs;
      case 'add_member_cta':
        return add_member_cta;
      case 'rel_spouse':
        return rel_spouse;
      case 'rel_son':
        return rel_son;
      case 'rel_daughter':
        return rel_daughter;
      case 'rel_father':
        return rel_father;
      case 'rel_mother':
        return rel_mother;
      case 'rel_sibling':
        return rel_sibling;
      case 'rel_grandparent':
        return rel_grandparent;
      case 'rel_other':
        return rel_other;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EmergencyStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const EmergencyStrings(this._parent);
  String get em_label => "Email address";
  String get em_ph => "you@example.com";
  String get em_otp_h => "We sent a 6-digit code to";
  String get em_eg => "Egypt";
  String get em_intro => "Egypt's nationwide emergency lines. Tap any number to call right away.";
  String get em_tap_call => "Tap to call";
  String get em_ambulance => "Ambulance";
  String get em_police => "Police";
  String get em_fire => "Fire & rescue";
  String get em_tourist => "Tourist police";
  String get emergency => "Emergency";
  String get em_pw_title => "Welcome back";
  String get em_pw_help => "Enter your password to sign in.";
  String get em_pw_signup_title => "Create your account";
  String get em_pw_signup_help => "Set a password to get started.";
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
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
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
      case 'em_pw_signup_title':
        return em_pw_signup_title;
      case 'em_pw_signup_help':
        return em_pw_signup_help;
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
  String streak_help(Gender gender, int checked) => "Checked in ${checked} of the last 7 days";
  String get on_track => "On track";
  String get away_banner => "You're away from home";
  String hero_q(Gender gender) => "How are you feeling today?";
  String hero_cta(Gender gender) => "Start check-in";
  String get hero_disclaimer => "Your own self-report — not a clinical measurement";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'away_banner':
        return away_banner;
      case 'hero_q':
        return hero_q;
      case 'hero_cta':
        return hero_cta;
      case 'hero_disclaimer':
        return hero_disclaimer;
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
  String get adherence => "Adherence";
  String get regimen => "Your daily regimen";
  String get last_7d => "Last 7 days";
  String get rx_manage => "Manage your scripts";
  String get rx_empty => "No prescriptions yet";
  String get rx_empty_h => "Add a prescription to keep your scripts in one place.";
  String get rx_active => "Active";
  String get rx_expired => "Expired";
  String get rx_valid_until => "Valid until";
  String get rx_issued => "Issued";
  String get rx_med_one => "1 medication";
  String rx_meds_n(String n) => "$n medications";
  String get rx_show => "Show to pharmacist";
  String get rx_scan => "Scan to dispense";
  String get rx_add => "Add prescription";
  String get rx_name => "Name";
  String get rx_name_ph => "e.g. Dr. Sara's prescription";
  String get rx_doctor_name => "Doctor's name";
  String get rx_doctor_name_ph => "Optional";
  String get rx_date => "Date issued";
  String get rx_expiry => "Expiration";
  String get rx_added => "Prescription added";
  String get rx_upload => "Upload a file";
  String get rx_manual => "Type it in";
  String get rx_or_paste_url => "or paste a link";
  String get rx_url_ph => "https://…";
  String get rx_med_name_ph => "Medication name";
  String get rx_med_dose_ph => "Dose (e.g. 500 mg)";
  String get rx_med_desc_ph => "Notes (optional)";
  String get rx_frequency => "Frequency";
  String get freq_once => "One time";
  String get freq_per_day => "Times per day";
  String get freq_every_x => "Every X";
  String get freq_other => "Other";
  String get freq_every => "Every";
  String get unit_hours => "hours";
  String get unit_days => "days";
  String get freq_other_ph => "Describe frequency";
  String freq_n_per_day(String n) => "$n×/day";
  String get rx_duration => "Duration";
  String get dur_days => "For X days";
  String get dur_weeks => "For X weeks";
  String get dur_months => "For X months";
  String get unit_weeks => "weeks";
  String get unit_months => "months";
  String get dur_until_empty => "Until package finishes";
  String get dur_ongoing => "Ongoing";
  String get dur_other => "Other";
  String get dur_other_ph => "Describe duration";
  String get rx_add_med => "Add another medication";
  String get rx_self_added => "Self-added";
  String get rx_self_note => "Added by you — not verified by a pharmacy.";
  String get rx_my_prescriptions => "My prescriptions";
  String get rx_take_photo => "Take photo";
  String get rx_from_files => "Choose file";
  String get rx_prescribed_by => "Prescribed by";
  String get rx_default_title => "Prescription";
  String get dose_skipped => "Skipped";
  String get dose_snoozed => "Snoozed";
  String get dose_missed => "Missed";
  String get med_scheduled => "Scheduled";
  String get med_snooze15 => "Snooze 15 min";
  String get med_skip => "Skip";
  String get tz_changed => "Time zone changed";
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
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'regimen':
        return regimen;
      case 'last_7d':
        return last_7d;
      case 'rx_manage':
        return rx_manage;
      case 'rx_empty':
        return rx_empty;
      case 'rx_empty_h':
        return rx_empty_h;
      case 'rx_active':
        return rx_active;
      case 'rx_expired':
        return rx_expired;
      case 'rx_valid_until':
        return rx_valid_until;
      case 'rx_issued':
        return rx_issued;
      case 'rx_med_one':
        return rx_med_one;
      case 'rx_meds_n':
        return rx_meds_n;
      case 'rx_show':
        return rx_show;
      case 'rx_scan':
        return rx_scan;
      case 'rx_add':
        return rx_add;
      case 'rx_name':
        return rx_name;
      case 'rx_name_ph':
        return rx_name_ph;
      case 'rx_doctor_name':
        return rx_doctor_name;
      case 'rx_doctor_name_ph':
        return rx_doctor_name_ph;
      case 'rx_date':
        return rx_date;
      case 'rx_expiry':
        return rx_expiry;
      case 'rx_added':
        return rx_added;
      case 'rx_upload':
        return rx_upload;
      case 'rx_manual':
        return rx_manual;
      case 'rx_or_paste_url':
        return rx_or_paste_url;
      case 'rx_url_ph':
        return rx_url_ph;
      case 'rx_med_name_ph':
        return rx_med_name_ph;
      case 'rx_med_dose_ph':
        return rx_med_dose_ph;
      case 'rx_med_desc_ph':
        return rx_med_desc_ph;
      case 'rx_frequency':
        return rx_frequency;
      case 'freq_once':
        return freq_once;
      case 'freq_per_day':
        return freq_per_day;
      case 'freq_every_x':
        return freq_every_x;
      case 'freq_other':
        return freq_other;
      case 'freq_every':
        return freq_every;
      case 'unit_hours':
        return unit_hours;
      case 'unit_days':
        return unit_days;
      case 'freq_other_ph':
        return freq_other_ph;
      case 'freq_n_per_day':
        return freq_n_per_day;
      case 'rx_duration':
        return rx_duration;
      case 'dur_days':
        return dur_days;
      case 'dur_weeks':
        return dur_weeks;
      case 'dur_months':
        return dur_months;
      case 'unit_weeks':
        return unit_weeks;
      case 'unit_months':
        return unit_months;
      case 'dur_until_empty':
        return dur_until_empty;
      case 'dur_ongoing':
        return dur_ongoing;
      case 'dur_other':
        return dur_other;
      case 'dur_other_ph':
        return dur_other_ph;
      case 'rx_add_med':
        return rx_add_med;
      case 'rx_self_added':
        return rx_self_added;
      case 'rx_self_note':
        return rx_self_note;
      case 'rx_my_prescriptions':
        return rx_my_prescriptions;
      case 'rx_take_photo':
        return rx_take_photo;
      case 'rx_from_files':
        return rx_from_files;
      case 'rx_prescribed_by':
        return rx_prescribed_by;
      case 'rx_default_title':
        return rx_default_title;
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
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
  String get lang_to_en => "Switch to English";
  String get lang_to_ar => "Switch to Arabic";
  String get pf_title => "Tell us about you";
  String get pf_help => "This helps your care team read your reports correctly.";
  String get pf_fname => "First name";
  String get pf_lname => "Last name";
  String get pf_fname_ph => "e.g. Layla";
  String get pf_lname_ph => "e.g. Hassan";
  String get pf_dob => "Date of birth";
  String get pf_gender => "Gender";
  String get pf_female => "Female";
  String get pf_male => "Male";
  String get pf_create => "Create my profile";
  String get pf_creating => "Creating your account…";
  String get pf_secure => "Your details stay on this device.";
  String get dob_title => "Date of birth";
  String get dob_confirm => "Confirm";
  String get age_gate_body =>
      "Balsm is currently available for ages 18 and older. We're working on a version for younger users with parental consent.";
  String w_start(Gender gender) => "Get started";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'lang_to_en':
        return lang_to_en;
      case 'lang_to_ar':
        return lang_to_ar;
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
      case 'pf_create':
        return pf_create;
      case 'pf_creating':
        return pf_creating;
      case 'pf_secure':
        return pf_secure;
      case 'dob_title':
        return dob_title;
      case 'dob_confirm':
        return dob_confirm;
      case 'age_gate_body':
        return age_gate_body;
      case 'w_start':
        return w_start;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class WalkthroughStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const WalkthroughStrings(this._parent);
  String get wt_eyebrow_1 => "Open · Arab · Trusted";
  String get wt_title_1 => "Healthcare that finally belongs to us.";
  String get wt_body_1 =>
      "Balsm is the first and largest open-source health platform built in Egypt and the Arab world — Arabic-first, and owned by the people who use it.";
  String get wt_eyebrow_2 => "A day with Balsm";
  String get wt_title_2 => "From this morning's reading to tonight's pharmacy run.";
  String get wt_body_2 =>
      "One record, one daily check-in, one map of care nearby — try them below, right where they live in the app.";
  String get wt_eyebrow_3 => "Yours, always";
  String get wt_title_3 => "Your data stays yours.";
  String get wt_body_3 =>
      "Saved on your phone by design, and it works offline. You choose what is shared — and with whom.";
  String get wt_skip => "Skip";
  String get wt_next => "Next";
  String get wt_start => "Get started";
  String get wt_demo_record => "Record";
  String get wt_demo_checkin => "Check-in";
  String get wt_demo_nearby => "Nearby";
  String get wt_demo_rec1_t => "CBC blood panel";
  String get wt_demo_rec1_d => "2 days ago";
  String get wt_demo_rec2_t => "Cardiology referral";
  String get wt_demo_rec2_d => "2 weeks ago";
  String get wt_demo_mood_low => "Low";
  String get wt_demo_mood_okay => "Okay";
  String get wt_demo_mood_good => "Good";
  String get wt_demo_mood_great => "Great";
  String get wt_demo_pin1 => "Zahran Pharmacy";
  String get wt_demo_pin2 => "Nour Clinic";
  String get wt_demo_pin3 => "City Lab";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'wt_eyebrow_1':
        return wt_eyebrow_1;
      case 'wt_title_1':
        return wt_title_1;
      case 'wt_body_1':
        return wt_body_1;
      case 'wt_eyebrow_2':
        return wt_eyebrow_2;
      case 'wt_title_2':
        return wt_title_2;
      case 'wt_body_2':
        return wt_body_2;
      case 'wt_eyebrow_3':
        return wt_eyebrow_3;
      case 'wt_title_3':
        return wt_title_3;
      case 'wt_body_3':
        return wt_body_3;
      case 'wt_skip':
        return wt_skip;
      case 'wt_next':
        return wt_next;
      case 'wt_start':
        return wt_start;
      case 'wt_demo_record':
        return wt_demo_record;
      case 'wt_demo_checkin':
        return wt_demo_checkin;
      case 'wt_demo_nearby':
        return wt_demo_nearby;
      case 'wt_demo_rec1_t':
        return wt_demo_rec1_t;
      case 'wt_demo_rec1_d':
        return wt_demo_rec1_d;
      case 'wt_demo_rec2_t':
        return wt_demo_rec2_t;
      case 'wt_demo_rec2_d':
        return wt_demo_rec2_d;
      case 'wt_demo_mood_low':
        return wt_demo_mood_low;
      case 'wt_demo_mood_okay':
        return wt_demo_mood_okay;
      case 'wt_demo_mood_good':
        return wt_demo_mood_good;
      case 'wt_demo_mood_great':
        return wt_demo_mood_great;
      case 'wt_demo_pin1':
        return wt_demo_pin1;
      case 'wt_demo_pin2':
        return wt_demo_pin2;
      case 'wt_demo_pin3':
        return wt_demo_pin3;
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
  String get pv_protect_body => "On-device encryption, secure transport, and least-privilege access.";
  String get pv_rights_body => "Access, correct, or delete your data at any time from account settings.";
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
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
  String get m_o2 => "Oxygen";
  String get p_personal => "Account details";
  String get pd_account => "Account";
  String get pd_handle_hint => "Your unique handle on Balsm";
  String get pd_share_qr => "Emergency QR";
  String get pd_share_qr_h => "Show an encrypted code to staff";
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
  String get pd_saving => "Saving…";
  String get pd_number_invalid => "Enter a valid number";
  String get hc_title => "Change your username?";
  String get hc_body =>
      "Your old link stops working right away. Anyone holding it — a clinician, a family member — will need the new one.";
  String get hc_from => "From";
  String get hc_to => "To";
  String get hc_confirm => "Change username";
  String get hc_cancel => "Keep current username";
  String get conn_accounts => "Connected accounts";
  String get conn_apple => "Apple ID";
  String get conn_google => "Google account";
  String get conn_connect => "Connect";
  String get p_cond => "Medical profile";
  String get p_care => "Care team";
  String get p_notif => "Reminders";
  String get p_lang => "Language";
  String get p_privacy => "Privacy & data";
  String get p_help => "Help & support";
  String get acct_load_failed => "Couldn't load your account.";
  String get acct_retry => "Retry";
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
  String get p_country => "Country";
  String get pd_primary => "Primary";
  String get pd_basic_info => "Basic info";
  String get pd_contact_section => "Contact";
  String get pd_add_contact => "Add contact";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'm_o2':
        return m_o2;
      case 'p_personal':
        return p_personal;
      case 'pd_account':
        return pd_account;
      case 'pd_handle_hint':
        return pd_handle_hint;
      case 'pd_share_qr':
        return pd_share_qr;
      case 'pd_share_qr_h':
        return pd_share_qr_h;
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
      case 'pd_saving':
        return pd_saving;
      case 'pd_number_invalid':
        return pd_number_invalid;
      case 'hc_title':
        return hc_title;
      case 'hc_body':
        return hc_body;
      case 'hc_from':
        return hc_from;
      case 'hc_to':
        return hc_to;
      case 'hc_confirm':
        return hc_confirm;
      case 'hc_cancel':
        return hc_cancel;
      case 'conn_accounts':
        return conn_accounts;
      case 'conn_apple':
        return conn_apple;
      case 'conn_google':
        return conn_google;
      case 'conn_connect':
        return conn_connect;
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
      case 'acct_load_failed':
        return acct_load_failed;
      case 'acct_retry':
        return acct_retry;
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
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class EcosystemStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const EcosystemStrings(this._parent);
  String get eco_row => "About Balsm & community";
  String get eco_title => "The Balsm ecosystem";
  String get eco_hero => "Balsm is bigger than this app";
  String get eco_sub =>
      "A community-owned healthcare system for the Arab world. Open code, your data, no vendor in between.";
  String get eco_p1h => "This app — for you";
  String get eco_p1b => "Your records, medications and appointments, whole and in your language.";
  String get eco_p2h => "Balsm Pro — for pharmacies & clinics";
  String get eco_p2b => "Dispensing, inventory and encounters on the same open system — offline-first, on the roadmap.";
  String get eco_help_t => "Help Balsm grow";
  String get eco_help_sub => "Balsm belongs to the people who use it. Every one of these makes it stronger.";
  String get eco_tagline => "Open · Arab · Trusted";
  String get eco_a1h => "Tell someone you trust";
  String get eco_a1b => "Family and neighbours are how Balsm travels — one recommendation at a time.";
  String get eco_a2h => "Share your feedback";
  String get eco_a2b => "Rate the app and tell us what to fix. The team reads every note.";
  String get eco_a3h => "Ask your pharmacy or clinic";
  String get eco_a3b =>
      "Providers join when patients ask. Mention Balsm on your next visit — it's free for them to own.";
  String get eco_a4h => "Contribute to the project";
  String get eco_a4b => "Developers, translators, clinicians — the code and roadmap are open to everyone.";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'eco_row':
        return eco_row;
      case 'eco_title':
        return eco_title;
      case 'eco_hero':
        return eco_hero;
      case 'eco_sub':
        return eco_sub;
      case 'eco_p1h':
        return eco_p1h;
      case 'eco_p1b':
        return eco_p1b;
      case 'eco_p2h':
        return eco_p2h;
      case 'eco_p2b':
        return eco_p2b;
      case 'eco_help_t':
        return eco_help_t;
      case 'eco_help_sub':
        return eco_help_sub;
      case 'eco_tagline':
        return eco_tagline;
      case 'eco_a1h':
        return eco_a1h;
      case 'eco_a1b':
        return eco_a1b;
      case 'eco_a2h':
        return eco_a2h;
      case 'eco_a2b':
        return eco_a2b;
      case 'eco_a3h':
        return eco_a3h;
      case 'eco_a3b':
        return eco_a3b;
      case 'eco_a4h':
        return eco_a4h;
      case 'eco_a4b':
        return eco_a4b;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class FeedbackStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const FeedbackStrings(this._parent);
  String get fb_row => "Rate & feedback";
  String get fb_title => "How is Balsm doing?";
  String get fb_rate_q => "Tap a flower to rate";
  String get fb_r1 => "Needs work";
  String get fb_r2 => "Could be better";
  String get fb_r3 => "Okay";
  String get fb_r4 => "Good";
  String get fb_r5 => "Excellent";
  String get fb_last => "Last shared";
  String get fb_about => "What is it about?";
  String get fb_note_lbl => "Tell us more";
  String get fb_optional => "optional";
  String get fb_ph => "What worked well? What didn't?";
  String get fb_privacy =>
      "Reviewed by the Balsm team, inside Balsm — never an app store. Your health data stays on your device.";
  String get fb_send => "Send feedback";
  String get fb_thanks => "Received. Thank you.";
  String get fb_thanks_sub => "The Balsm team reads every note. Yours helps Balsm work better for everyone.";
  String get fb_done => "Done";
  String get fb_t_general => "General";
  String get fb_t_ease => "Ease of use";
  String get fb_t_records => "Records";
  String get fb_t_meds => "Medications";
  String get fb_t_arabic => "Arabic & language";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'fb_row':
        return fb_row;
      case 'fb_title':
        return fb_title;
      case 'fb_rate_q':
        return fb_rate_q;
      case 'fb_r1':
        return fb_r1;
      case 'fb_r2':
        return fb_r2;
      case 'fb_r3':
        return fb_r3;
      case 'fb_r4':
        return fb_r4;
      case 'fb_r5':
        return fb_r5;
      case 'fb_last':
        return fb_last;
      case 'fb_about':
        return fb_about;
      case 'fb_note_lbl':
        return fb_note_lbl;
      case 'fb_optional':
        return fb_optional;
      case 'fb_ph':
        return fb_ph;
      case 'fb_privacy':
        return fb_privacy;
      case 'fb_send':
        return fb_send;
      case 'fb_thanks':
        return fb_thanks;
      case 'fb_thanks_sub':
        return fb_thanks_sub;
      case 'fb_done':
        return fb_done;
      case 'fb_t_general':
        return fb_t_general;
      case 'fb_t_ease':
        return fb_t_ease;
      case 'fb_t_records':
        return fb_t_records;
      case 'fb_t_meds':
        return fb_t_meds;
      case 'fb_t_arabic':
        return fb_t_arabic;
      default:
        throw Exception('Message $key doesn\'t exist in $this');
    }
  }
}

class RecordsStrings implements i69n.I69nMessageBundle {
  final Strings _parent;
  const RecordsStrings(this._parent);
  String get rec_documents => "documents";
  String get reports => "Past reports";
  String get rec_search_ph => "Search records, tags, results…";
  String get rec_tags => "Tags";
  String get rec_tags_ph => "Add a tag and press Enter";
  String get rec_no_results => "No matching records";
  String get rec_no_results_h => "No records match";
  String get rec_no_results_h2 => "Nothing in this category yet.";
  String get rec_clear_filters => "Clear filters";
  String get prescriptions => "Prescriptions";
  String get records => "Health records";
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
  String get rec_preview => "Document preview";
  String get rec_share => "Share with doctor";
  String get rec_empty_h => "Add a lab test, scan, or report to keep your whole history in one place.";
  String get rec_pick_type => "What are you adding?";
  String get rec_title => "Title";
  String get rec_title_ph => "e.g. HbA1c blood test";
  String get rec_attach => "Attach file or photo";
  String get rec_attach_h => "PDF, photo of a paper report, or a scan image.";
  String get rec_take_photo => "Take a photo";
  String get rec_from_files => "Choose a file";
  String get rec_added => "Record added";
  String get rec_added_h => "Stored on your device. Yours by design.";
  String get tag_diabetes => "Diabetes";
  String get tag_cholesterol => "Cholesterol";
  String get tag_kidney => "Kidney";
  String get tag_thyroid => "Thyroid";
  String get tag_chest => "Chest";
  String get tag_abdomen => "Abdomen";
  String get tag_bone => "Bone";
  String get tag_follow_up => "Follow-up";
  String get tag_cardiology => "Cardiology";
  String get tag_surgery => "Surgery";
  String get tag_referral => "Referral";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'rec_documents':
        return rec_documents;
      case 'reports':
        return reports;
      case 'rec_search_ph':
        return rec_search_ph;
      case 'rec_tags':
        return rec_tags;
      case 'rec_tags_ph':
        return rec_tags_ph;
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
      case 'rec_preview':
        return rec_preview;
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
      case 'tag_diabetes':
        return tag_diabetes;
      case 'tag_cholesterol':
        return tag_cholesterol;
      case 'tag_kidney':
        return tag_kidney;
      case 'tag_thyroid':
        return tag_thyroid;
      case 'tag_chest':
        return tag_chest;
      case 'tag_abdomen':
        return tag_abdomen;
      case 'tag_bone':
        return tag_bone;
      case 'tag_follow_up':
        return tag_follow_up;
      case 'tag_cardiology':
        return tag_cardiology;
      case 'tag_surgery':
        return tag_surgery;
      case 'tag_referral':
        return tag_referral;
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
  String get add_member => "Add family member";
  String get choose_lang => "Choose language";
  String get choose_country => "Where are you now?";
  String get travel_help => "Set your location so Balsm shows local emergency numbers and care info while you travel.";
  String get lang_full => "Full support";
  String get lang_beta => "Beta";
  String get home_country => "Home";
  String get add_record => "Add record";
  String get add_calendar => "Add to calendar";
  String get na_not_available => "Not available yet";
  String get na_notify_me => "Notify me when available";
  String get na_status_support => "Service status & support";
  String get cal_months => "January|February|March|April|May|June|July|August|September|October|November|December";
  String get cal_months_short => "JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC";
  String get cal_weekdays => "Su|Mo|Tu|We|Th|Fr|Sa";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
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
      case 'cal_months_short':
        return cal_months_short;
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
  String get store_delete_rec => "Delete record";
  String get store_delete_rec_h =>
      "This permanently deletes the record and its attachment from this device. It cannot be undone.";
  String get store_deleted_rec => "Record deleted";
  String get store_manage => "Manage storage";
  String get storage => "Storage & sync";
  String get store_local => "On this device";
  String get store_icloud => "iCloud";
  String get store_gdrive => "Google Drive";
  String get store_balsm_cloud => "Balsm Cloud";
  String get store_local_only => "Local only";
  String get store_backed => "Backed up";
  String get store_step_prepare => "Preparing…";
  String get store_step_checkins => "Transferring check-ins…";
  String get store_step_records => "Transferring records…";
  String get store_step_rx => "Transferring prescriptions…";
  String get store_step_verify => "Verifying & finishing…";
  String get store_choose_help =>
      "Only local storage is available right now. iCloud, Google Drive, and Balsm Cloud are all coming later.";
  String get store_coming_soon => "Coming soon";
  String get store_available_soon => "Available soon";
  String get store_always_on => "Always on";
  String get store_no_backup => "No backup";
  String store_connecting(String target) => "Connecting to $target…";
  String get store_auto_start => "Backup will start automatically.";
  String get store_migrating => "Migrating";
  String get store_removed_done => "Cloud backup removed";
  String get store_synced_done => "All synced";
  String get store_device_only => "Saved on this device only";
  String store_synced_with(String target) => "Synced with $target";
  String get store_done => "Done";
  String get store_remove_q => "Remove cloud backup?";
  String store_remove_help(String target) => "Your data will be removed from $target and kept on this device only.";
  String get store_remove_cta => "Remove cloud backup";
  Object operator [](String key) {
    var index = key.indexOf('.');
    if (index > 0) {
      return (this[key.substring(0, index)] as i69n.I69nMessageBundle)[key.substring(index + 1)];
    }
    switch (key) {
      case 'store_delete_rec':
        return store_delete_rec;
      case 'store_delete_rec_h':
        return store_delete_rec_h;
      case 'store_deleted_rec':
        return store_deleted_rec;
      case 'store_manage':
        return store_manage;
      case 'storage':
        return storage;
      case 'store_local':
        return store_local;
      case 'store_icloud':
        return store_icloud;
      case 'store_gdrive':
        return store_gdrive;
      case 'store_balsm_cloud':
        return store_balsm_cloud;
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
      case 'store_coming_soon':
        return store_coming_soon;
      case 'store_available_soon':
        return store_available_soon;
      case 'store_always_on':
        return store_always_on;
      case 'store_no_backup':
        return store_no_backup;
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
