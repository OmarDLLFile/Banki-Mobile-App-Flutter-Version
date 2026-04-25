import 'dart:math';

class OtpService {

  String? _generatedOtp;

  String generateOtp() {
    final random = Random();

    int otp = 100000 + random.nextInt(900000);

    _generatedOtp = otp.toString();

    return _generatedOtp!;
  }

  bool verifyOtp(String code) {

    if (_generatedOtp == null) {
      return false;
    }

    if (code == _generatedOtp) {
      _generatedOtp = null; // invalidate OTP after success
      return true;
    }

    return false;
  }

}