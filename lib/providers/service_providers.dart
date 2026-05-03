import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/fraud_detection_service.dart';
import '../services/sound_feedback_service.dart';
import '../services/secure_storage_service.dart';
import '../services/transaction_security_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final fraudDetectionServiceProvider = Provider<FraudDetectionService>((ref) {
  return FraudDetectionService();
});

final soundFeedbackServiceProvider = Provider<SoundFeedbackService>((ref) {
  return SoundFeedbackService();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final transactionSecurityServiceProvider = Provider<TransactionSecurityService>((ref) {
  return TransactionSecurityService();
});
