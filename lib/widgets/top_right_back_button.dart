import 'package:flutter/material.dart';

class TopRightBackButton extends StatelessWidget {
  const TopRightBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () {
        Navigator.of(context).maybePop();
      },
    );
  }
}
