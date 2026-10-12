// Wraps reCAPTCHA Enterprise. Lazy-loaded on first invocation per Q2 FR-045c.
class RecaptchaAdapter {
  static RecaptchaAdapter? _instance;
  static RecaptchaAdapter get instance => _instance ??= RecaptchaAdapter._();
  RecaptchaAdapter._();
  Future<String?> getToken(String action) async {
    // TODO: integrate flutter_recaptcha_enterprise SDK
    return null;
  }
}
