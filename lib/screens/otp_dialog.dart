import 'package:flutter/material.dart';

class OtpDialog extends StatefulWidget {

  final String otp;
  final Function(bool) onResult;

  const OtpDialog({
    super.key,
    required this.otp,
    required this.onResult,
  });

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {

  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Text("OTP Verification"),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Text(
            "OTP Code: ${widget.otp}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter OTP",
            ),
          ),

        ],
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onResult(false);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: () {

            if (controller.text == widget.otp) {

              Navigator.pop(context);
              widget.onResult(true);

            } else {

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Wrong OTP"),
                ),
              );

            }

          },
          child: const Text("Verify"),
        )

      ],
    );

  }
}
