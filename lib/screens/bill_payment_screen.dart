import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/fraud_detection_service.dart';
import '../services/sound_feedback_service.dart';
import '../utils/input_validators.dart';

class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({super.key});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  final FraudDetectionService fraudDetection = FraudDetectionService();
  final SoundFeedbackService soundFeedback = SoundFeedbackService();
  final formKey = GlobalKey<FormState>();

  String selectedBill = "Electricity";

  final amountController = TextEditingController();

  Future<void> payBill() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final fraudResult = await fraudDetection.checkBeforeTransaction();

    if (!fraudResult.allowed) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fraudResult.message ?? "Transaction blocked")),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    final userName = userDoc['name'];

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    final amount = double.parse(amountController.text.trim());

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      double balance = (snapshot['balance'] ?? 0).toDouble();

      if (balance < amount) {
        throw Exception("Not enough balance");
      }

      balance -= amount;

      transaction.update(userRef, {"balance": balance});

      transaction
          .set(FirebaseFirestore.instance.collection("transactions").doc(), {
            "userId": uid,
            "username": userName,
            "type": "bill_payment",
            "billType": selectedBill,
            "amount": amount,
            "timestamp": FieldValue.serverTimestamp(),
          });
    });

    await soundFeedback.playSuccessSound();

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Payment"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: formKey,
          child: Column(
            children: [
              DropdownButtonFormField(
                initialValue: selectedBill,

                items: const [
                  DropdownMenuItem(
                    value: "Electricity",
                    child: Text("Electricity Bill"),
                  ),

                  DropdownMenuItem(value: "Water", child: Text("Water Bill")),

                  DropdownMenuItem(value: "Gas", child: Text("Gas Bill")),

                  DropdownMenuItem(
                    value: "Internet",
                    child: Text("Internet Bill"),
                  ),
                ],

                onChanged: (value) {
                  setState(() {
                    selectedBill = value!;
                  });
                },

                decoration: const InputDecoration(
                  labelText: "Select Bill Type",
                ),
              ),

              const SizedBox(height: 20),

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

                decoration: const InputDecoration(
                  labelText: "Enter amount",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: payBill,

                  child: const Text("Pay Bill"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
