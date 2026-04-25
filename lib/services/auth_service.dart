import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<User?> signUp(String email, String password) async {

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return credential.user;
  }

  Future<User?> login(String email, String password) async {

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return credential.user;
  }

  /*
  ============================
  CHECK IF BIOMETRIC AVAILABLE
  ============================
  */

  Future<bool> canUseBiometric() async {

    final canCheckBiometrics = await _localAuth.canCheckBiometrics;

    final isSupported = await _localAuth.isDeviceSupported();

    return canCheckBiometrics && isSupported;
  }

  /*
  ============================
  GET AVAILABLE BIOMETRICS
  ============================
  */

  Future<List<BiometricType>> getAvailableBiometrics() async {

    return await _localAuth.getAvailableBiometrics();
  }

  /*
  ============================
  BIOMETRIC LOGIN
  ============================
  */

  Future<bool> loginWithBiometrics() async {

    try {

      final authenticated = await _localAuth.authenticate(
        localizedReason: "Authenticate to access your bank account",
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );

      return authenticated;

    } catch (e) {

      return false;

    }

  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? getCurrentUser(){
    return _auth.currentUser;
  }

}