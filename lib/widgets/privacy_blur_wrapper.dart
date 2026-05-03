import 'dart:ui';
import 'package:flutter/material.dart';

class PrivacyBlurWrapper extends StatefulWidget {
  final Widget child;

  const PrivacyBlurWrapper({super.key, required this.child});

  @override
  State<PrivacyBlurWrapper> createState() => _PrivacyBlurWrapperState();
}

class _PrivacyBlurWrapperState extends State<PrivacyBlurWrapper>
    with WidgetsBindingObserver {
  bool _needsBlur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_needsBlur) {
        setState(() {
          _needsBlur = false;
        });
      }
    } else {
      if (!_needsBlur) {
        setState(() {
          _needsBlur = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_needsBlur)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xFF04131A).withValues(alpha: 0.7),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF7BFFD4),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Secure Bank',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
