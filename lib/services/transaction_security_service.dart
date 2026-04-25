import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../services/biometric_service.dart';
import '../screens/otp_dialog.dart';
import 'email_otp_service.dart';

class TransactionSecurityService {

  final OtpService otpService = OtpService();
  final EmailOtpService emailService = EmailOtpService();
  final BiometricService biometric = BiometricService();

  Future<bool> authorize(BuildContext context, String email) async {

    String otp = otpService.generateOtp();

    bool otpResult = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OtpDialog(
        otp: otp,
        onResult: (result) {
          otpResult = result;
        },
      ),
    );

    if (!otpResult) {
      return false;
    }

    bool bio = await biometric.authenticate();

    return bio;

  }

}
