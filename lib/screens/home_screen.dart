import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/transaction_screen.dart';
import '../screens/analytics_screen.dart';
import 'monthly_analytics_screen.dart';
import '../screens/bill_payment_screen.dart';
import '../services/secure_storage_service.dart';
import 'login_screen.dart';
import '../services/transaction_security_service.dart';
import 'admin_panel.dart';
import '../services/fraud_detection_service.dart';
import '../services/sound_feedback_service.dart';
import '../utils/input_validators.dart';
import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService firestore = FirestoreService();
  final SecureStorageService storage = SecureStorageService();
  final TransactionSecurityService security = TransactionSecurityService();
  final FraudDetectionService fraudDetection = FraudDetectionService();
  final SoundFeedbackService soundFeedback = SoundFeedbackService();

  Map<String, dynamic>? userData;

  DateTime lastActivity = DateTime.now();
  Timer? sessionTimer;
  StreamSubscription<Map<String, dynamic>?>? userSubscription;

  @override
  void initState() {
    super.initState();
    listenToUser();
    startSessionTimer();
  }

  @override
  void dispose() {
    userSubscription?.cancel();
    sessionTimer?.cancel();
    super.dispose();
  }

  void startSessionTimer() {
    sessionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkSessionTimeout(),
    );
  }

  void checkSessionTimeout() {
    final difference = DateTime.now().difference(lastActivity);

    if (difference.inMinutes > 5) {
      storage.clearSession();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void updateActivity() {
    lastActivity = DateTime.now();
  }

  void listenToUser() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    userSubscription = firestore.streamUser(uid).listen((data) {
      if (!mounted || data == null) {
        return;
      }

      if (data['role'] == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
        return;
      }

      setState(() {
        userData = data;
      });
    });
  }

  Future<void> depositMoney(double amount) async {
    updateActivity();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userName = (userData?['name'] ?? '').toString();

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      double balance = (snapshot['balance'] ?? 0).toDouble();

      balance += amount;

      transaction.update(userRef, {"balance": balance});
    });

    await FirebaseFirestore.instance.collection('transactions').add({
      'userId': uid,
      'username': userName,
      'type': 'deposit',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await soundFeedback.playSuccessSound();
  }

  Future<bool> guardTransaction() async {
    final result = await fraudDetection.checkBeforeTransaction();

    if (!result.allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Transaction blocked')),
      );
    }

    return result.allowed;
  }

  Future<void> withdrawMoney(double amount) async {
    updateActivity();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userName = (userData?['name'] ?? '').toString();

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      double balance = (snapshot['balance'] ?? 0).toDouble();

      final newBalance = balance - amount;

      transaction.update(userRef, {'balance': newBalance});

      transaction
          .set(FirebaseFirestore.instance.collection("transactions").doc(), {
            'userId': uid,
            'username': userName,
            'type': 'withdraw',
            'amount': amount,
            'timestamp': FieldValue.serverTimestamp(),
          });
    });

    await soundFeedback.playSuccessSound();
  }

  Future<void> transferMoney(String email, double amount) async {
    updateActivity();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final senderName = (userData?['name'] ?? '').toString();

    final receiverQuery = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    if (receiverQuery.docs.isEmpty) {
      return;
    }

    final receiverDoc = receiverQuery.docs.first;
    final receiverId = receiverDoc.id;
    final receiverName = receiverDoc['name'];

    final senderRef = FirebaseFirestore.instance.collection("users").doc(uid);

    final receiverRef = FirebaseFirestore.instance
        .collection("users")
        .doc(receiverId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final senderSnapshot = await transaction.get(senderRef);
      final receiverSnapshot = await transaction.get(receiverRef);

      double senderBalance = (senderSnapshot['balance'] ?? 0).toDouble();
      double receiverBalance = (receiverSnapshot['balance'] ?? 0).toDouble();

      if (senderBalance < amount) {
        throw Exception("Not enough balance");
      }

      senderBalance -= amount;
      receiverBalance += amount;

      transaction.update(senderRef, {'balance': senderBalance});
      transaction.update(receiverRef, {'balance': receiverBalance});

      transaction
          .set(FirebaseFirestore.instance.collection("transactions").doc(), {
            'userId': uid,
            'username': senderName,
            'type': 'transfer_sent',
            'amount': amount,
            'to': receiverName,
            'timestamp': FieldValue.serverTimestamp(),
          });

      transaction
          .set(FirebaseFirestore.instance.collection("transactions").doc(), {
            'userId': receiverId,
            'username': receiverName,
            'type': 'transfer_received',
            'amount': amount,
            'from': senderName,
            'timestamp': FieldValue.serverTimestamp(),
          });
    });

    await soundFeedback.playSuccessSound();
  }

  void showTransferDialog() {
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Transfer Money"),

          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: InputValidators.email,
                  decoration: const InputDecoration(
                    labelText: "Recipient Email",
                  ),
                ),

                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: (value) =>
                      InputValidators.amount(value, fieldName: 'Amount'),
                  decoration: const InputDecoration(labelText: "Amount"),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final email = emailController.text.trim();
                final amount = double.parse(amountController.text.trim());

                final allowed = await guardTransaction();

                if (!allowed) {
                  return;
                }

                if (!dialogContext.mounted) {
                  return;
                }

                /// SECURITY LAYER
                bool authorized = await security.authorize(
                  dialogContext,
                  userData!['email'],
                );

                if (!authorized) return;

                await transferMoney(email, amount);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    );
  }

  Widget buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FrostedPanel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF7BFFD4), Color(0xFF70A9FF)],
              ),
            ),
            child: Icon(icon, size: 24, color: const Color(0xFF062029)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            "Secure banking action",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
          onTap: () {
            updateActivity();
            onTap();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: updateActivity,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Secure Bank"),
          actions: const [TopRightBackButton()],
        ),
        body: AuroraBackground(
          child: ListView(
            children: [
              const SizedBox(height: 72),
              FrostedPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back, ${userData!['name']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Available Balance",
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "\$${userData!['balance']}",
                      style: const TextStyle(
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildStatChip(Icons.verified_user, "Protected"),
                        _buildStatChip(Icons.bolt, "Fast Transfers"),
                        _buildStatChip(Icons.insights, "Live Insights"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                "Banking Actions",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              buildActionCard(
                icon: Icons.arrow_downward,
                title: "Deposit",
                onTap: () => showAmountDialog(true),
              ),
              buildActionCard(
                icon: Icons.arrow_upward,
                title: "Withdraw",
                onTap: () => showAmountDialog(false),
              ),
              buildActionCard(
                icon: Icons.receipt,
                title: "Bill Payment",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BillPaymentScreen(),
                    ),
                  );
                },
              ),
              buildActionCard(
                icon: Icons.bar_chart,
                title: "Analytics",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),
              buildActionCard(
                icon: Icons.show_chart,
                title: "Monthly Analytics",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MonthlyAnalyticsScreen(),
                    ),
                  );
                },
              ),
              buildActionCard(
                icon: Icons.send,
                title: "Transfer Money",
                onTap: () {
                  showTransferDialog();
                },
              ),
              buildActionCard(
                icon: Icons.history,
                title: "Transaction History",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7BFFD4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void showAmountDialog(bool isDeposit) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isDeposit ? "Deposit Money" : "Withdraw Money"),

          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) =>
                  InputValidators.amount(value, fieldName: 'Amount'),
              decoration: const InputDecoration(labelText: "Enter amount"),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final amount = double.parse(controller.text.trim());

                final allowed = await guardTransaction();

                if (!allowed) {
                  return;
                }

                if (!dialogContext.mounted) {
                  return;
                }

                /// SECURITY LAYER
                bool authorized = await security.authorize(
                  dialogContext,
                  userData!['email'],
                );

                if (!authorized) return;

                if (isDeposit) {
                  await depositMoney(amount);
                } else {
                  await withdrawMoney(amount);
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
}
