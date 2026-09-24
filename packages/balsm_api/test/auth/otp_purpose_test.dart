import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

/// What the OTP request tells the server it is for.
void main() {
  test('continue serializes as the server spells it', () {
    // One merged entry: the code is requested after a failed email+password
    // attempt, for an address that may or may not have an account. The server
    // calls that purpose "continue" and answers the same way either way.
    final json = const RequestOtpRequest(
      email: 'patient@example.test',
      countryCode: 'EG',
      purpose: OtpPurpose.continueFlow,
    ).toJson();

    expect(json['purpose'], 'continue');
  });

  test('reset is unchanged — forgot-password still has its own path', () {
    final json = const RequestOtpRequest(
      email: 'patient@example.test',
      countryCode: 'EG',
      purpose: OtpPurpose.reset,
    ).toJson();

    expect(json['purpose'], 'reset');
  });
}
