import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  static const String tokenKey = "session_token";
  static const String emailKey = "user_email";

  Future<void> saveSession(String email) async {
    await storage.write(key: tokenKey, value: "active_session");
    await storage.write(key: emailKey, value: email);
  }

  Future<String?> getSession() async {
    return await storage.read(key: tokenKey);
  }

  Future<String?> getEmail() async {
    return await storage.read(key: emailKey);
  }

  Future<void> clearSession() async {
    await storage.delete(key: tokenKey);
    await storage.delete(key: emailKey);
  }
}