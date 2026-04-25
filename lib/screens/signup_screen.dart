import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../utils/input_validators.dart';
import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final AuthService authService = AuthService();
  final FirestoreService firestore = FirestoreService();

  void signup() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      final user = await authService.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        return;
      }

      await firestore.createUser(user.uid, {
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": UserModel.userRole,
        "balance": 0,
        "isActive": true,
        "isDeleted": false,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Create Account"),
        actions: const [TopRightBackButton()],
      ),
      body: AuroraBackground(
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
                    const Text(
                      "Open Your Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create a secure profile and step into the app.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: nameController,
                      validator: (value) => InputValidators.requiredText(
                        value,
                        fieldName: 'Name',
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: InputValidators.email,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      validator: InputValidators.password,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Password"),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: signup,
                      child: const Text("Create Account"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
