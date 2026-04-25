import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FraudCheckResult {
  final bool allowed;
  final String? message;

  const FraudCheckResult({required this.allowed, this.message});
}

class FraudDetectionService {
  static const int _maxTransactionsPerWindow = 5;
  static const int _windowSeconds = 90;
  static const int _blockSeconds = 30;
  static const Set<String> _monitoredTypes = {
    'deposit',
    'withdraw',
    'transfer_sent',
    'bill_payment',
  };

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<FraudCheckResult> checkBeforeTransaction() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const FraudCheckResult(
        allowed: false,
        message: 'Please log in again.',
      );
    }

    final userDoc = await _db.collection('users').doc(uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};
    final blockedUntil = data['fraudBlockedUntil'];

    if (blockedUntil is Timestamp) {
      final blockedUntilDate = blockedUntil.toDate();

      if (blockedUntilDate.isAfter(DateTime.now())) {
        final secondsLeft = blockedUntilDate
            .difference(DateTime.now())
            .inSeconds
            .clamp(1, _blockSeconds);

        return FraudCheckResult(
          allowed: false,
          message:
              'Suspicious activity detected. Transactions are blocked for $secondsLeft more second${secondsLeft == 1 ? '' : 's'}.',
        );
      }

      await _db.collection('users').doc(uid).update({
        'fraudBlockedUntil': FieldValue.delete(),
      });
    }

    final recentWindowStart = DateTime.now().subtract(
      const Duration(seconds: _windowSeconds),
    );

    final userTransactions = await _db
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .get();

    final suspiciousCount = userTransactions.docs.where((doc) {
      final data = doc.data();
      final type = data['type'];
      final timestamp = data['timestamp'];

      if (!_monitoredTypes.contains(type) || timestamp is! Timestamp) {
        return false;
      }

      return timestamp.toDate().isAfter(recentWindowStart);
    }).length;

    if (suspiciousCount >= _maxTransactionsPerWindow) {
      await _db.collection('users').doc(uid).update({
        'fraudBlockedUntil': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: _blockSeconds)),
        ),
        'lastFraudReason': 'Too many transactions in a short period',
      });

      return const FraudCheckResult(
        allowed: false,
        message:
            'Suspicious activity detected. Transactions have been blocked for 30 seconds.',
      );
    }

    return const FraudCheckResult(allowed: true);
  }
}
