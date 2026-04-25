import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication auth = LocalAuthentication();

  /*
  ==========================
  CHECK DEVICE SUPPORT
  ==========================
  */

  Future<bool> isBiometricAvailable() async {
    final canCheckBiometrics = await auth.canCheckBiometrics;

    final isSupported = await auth.isDeviceSupported();

    return canCheckBiometrics && isSupported;
  }

  /*
  ==========================
  GET AVAILABLE BIOMETRICS
  ==========================
  */

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await auth.getAvailableBiometrics();
  }

  List<BiometricType> getLoginChoices(List<BiometricType> biometrics) {
    final choices = <BiometricType>[];

    if (biometrics.contains(BiometricType.face)) {
      choices.add(BiometricType.face);
    }

    if (biometrics.contains(BiometricType.fingerprint)) {
      choices.add(BiometricType.fingerprint);
    }

    if (choices.isEmpty) {
      return biometrics;
    }

    return choices;
  }

  String getLabel(BiometricType biometricType) {
    switch (biometricType) {
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometrics';
      case BiometricType.weak:
        return 'Biometrics';
    }
  }

  /*
  ==========================
  AUTHENTICATE USER
  ==========================
  */

  Future<bool> authenticate({
    String localizedReason = "Authenticate to access your bank account",
  }) async {
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    bool supported = await auth.isDeviceSupported();

    if (!canCheckBiometrics || !supported) {
      return false;
    }

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }
}
