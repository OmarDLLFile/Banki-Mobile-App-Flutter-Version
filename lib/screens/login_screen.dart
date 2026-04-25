import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vibration/vibration.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import '../services/biometric_service.dart';
import '../services/firestore_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sound_feedback_service.dart';
import '../utils/input_validators.dart';
import '../utils/role_navigation.dart';
import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final BiometricService biometric = BiometricService();
  final AuthService authService = AuthService();
  final FirestoreService firestore = FirestoreService();
  final SoundFeedbackService soundFeedback = SoundFeedbackService();

  final SecureStorageService storage = SecureStorageService();

  bool biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    checkBiometric();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void checkBiometric() async {
    bool available = await biometric.isBiometricAvailable();
    setState(() {
      biometricAvailable = available;
    });
  }

  void login() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      final user = await authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        return;
      }

      final userModel = await firestore.getUserModel(user.uid);

      if (userModel == null || !userModel.canAccessApp) {
        await authService.logout();
        await storage.clearSession();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This User Has Been Disabled By Admin")),
        );
        return;
      }

      await storage.saveSession(emailController.text.trim());

      if (!mounted) {
        return;
      }

      await soundFeedback.playSuccessSound();

      if (!mounted) {
        return;
      }

      await RoleNavigation.pushReplacementForCurrentUser(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 300, amplitude: 255);
        } else {
          await HapticFeedback.heavyImpact();
        }
      } catch (_) {
        await HapticFeedback.heavyImpact();
      }

      try {
        await soundFeedback.playErrorSound();
      } catch (_) {
        await SystemSound.play(SystemSoundType.alert);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credentials are not correct')),
      );
    }
  }

  void biometricLogin() async {
    bool available = await biometric.isBiometricAvailable();

    if (!available) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Biometric authentication not available on this device",
          ),
        ),
      );
      return;
    }

    final availableBiometrics = await biometric.getAvailableBiometrics();
    final loginChoices = biometric.getLoginChoices(availableBiometrics);

    BiometricType? selectedType;

    final hasExplicitFace = loginChoices.contains(BiometricType.face);
    final hasExplicitFingerprint = loginChoices.contains(
      BiometricType.fingerprint,
    );

    if (!(hasExplicitFace && hasExplicitFingerprint)) {
      selectedType = loginChoices.isEmpty ? null : loginChoices.first;
    } else if (loginChoices.length <= 1) {
      selectedType = loginChoices.isEmpty ? null : loginChoices.first;
    } else {
      if (!mounted) {
        return;
      }

      selectedType = await showModalBottomSheet<BiometricType>(
        context: context,
        backgroundColor: const Color(0xFF10242A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Biometric Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select how you want to sign in.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...loginChoices.map(
                    (type) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        type == BiometricType.face
                            ? Icons.face_retouching_natural
                            : Icons.fingerprint,
                        color: const Color(0xFF7BFFD4),
                      ),
                      title: Text(
                        biometric.getLabel(type),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(context, type),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selectedType == null) {
        return;
      }
    }

    final reason = selectedType == null
        ? "Authenticate to access your bank account"
        : "Use ${biometric.getLabel(selectedType)} to sign in";

    bool success = await biometric.authenticate(localizedReason: reason);

    if (success) {
      if (!mounted) {
        return;
      }

      await soundFeedback.playSuccessSound();

      if (!mounted) {
        return;
      }

      await RoleNavigation.pushReplacementForCurrentUser(context);
    } else {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric authentication failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(actions: const [TopRightBackButton()]),
      body: AuroraBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: FrostedPanel(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7BFFD4),
                                    Color(0xFF7AA8FF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: Color(0xFF072128),
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Secure Bank",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Secure Bank Mobile App.",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: InputValidators.email,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Email",
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              validator: InputValidators.password,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Password",
                              ),
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: login,
                              child: const Text("Login"),
                            ),
                            const SizedBox(height: 12),
                            if (biometricAvailable)
                              OutlinedButton.icon(
                                onPressed: biometricLogin,
                                icon: const Icon(Icons.fingerprint_rounded),
                                label: const Text("Login with Biometrics"),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "New here?",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text("Create Account"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
