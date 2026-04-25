import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailOtpService {

  final smtpServer = gmail(
    "your_email@gmail.com",
    "your_app_password",
  );

  Future<void> sendOtp(String toEmail, String otp) async {

    final message = Message()
      ..from = const Address("your_email@gmail.com", "Bank App")
      ..recipients.add(toEmail)
      ..subject = "Transaction OTP"
      ..text = "Your OTP code is $otp";

    await send(message, smtpServer);
  }

}