import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/admin_panel.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../services/firestore_service.dart';
import '../services/secure_storage_service.dart';

class RoleNavigation {
  static final FirestoreService _firestore = FirestoreService();
  static final SecureStorageService _storage = SecureStorageService();

  static Future<Widget> resolveLandingScreen() async {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return const LoginScreen();
    }

    final user = await _firestore.getUserModel(authUser.uid);

    if (user == null || !user.canAccessApp) {
      await FirebaseAuth.instance.signOut();
      await _storage.clearSession();
      return const LoginScreen();
    }

    if (user.isAdmin) {
      return const AdminPanelScreen();
    }

    return const HomeScreen();
  }

  static Future<void> pushReplacementForCurrentUser(
    BuildContext context,
  ) async {
    final screen = await resolveLandingScreen();

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> pushAndClearForCurrentUser(BuildContext context) async {
    final screen = await resolveLandingScreen();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  static Future<bool> currentUserIsAdmin() async {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return false;
    }

    final user = await _firestore.getUserModel(authUser.uid);
    return user?.canAccessApp == true && user?.role == UserModel.adminRole;
  }
}
