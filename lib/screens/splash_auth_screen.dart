import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';
import '../utils/role_navigation.dart';

class SplashAuthScreen extends StatefulWidget {
  const SplashAuthScreen({super.key});

  @override
  State<SplashAuthScreen> createState() => _SplashAuthScreenState();
}

class _SplashAuthScreenState extends State<SplashAuthScreen> {
  final SecureStorageService storage = SecureStorageService();
  final BiometricService biometric = BiometricService();

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    final session = await storage.getSession();
    final authUser = FirebaseAuth.instance.currentUser;

    if (session == null || authUser == null) {
      if (!mounted) {
        return;
      }

      await RoleNavigation.pushReplacementForCurrentUser(context);
      return;
    }

    bool success = await biometric.authenticate();

    if (success) {
      if (!mounted) {
        return;
      }

      await RoleNavigation.pushReplacementForCurrentUser(context);
    } else {
      await FirebaseAuth.instance.signOut();
      await storage.clearSession();

      if (!mounted) {
        return;
      }

      await RoleNavigation.pushReplacementForCurrentUser(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
