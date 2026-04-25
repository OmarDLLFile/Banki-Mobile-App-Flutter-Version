import 'dart:ui';

import 'package:flutter/material.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF04131A),
            Color(0xFF09252B),
            Color(0xFF071C2F),
            Color(0xFF120A23),
          ],
          stops: [0.0, 0.28, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            left: -70,
            child: _AuroraGlow(
              size: 280,
              colors: [Color(0xAA4CF4D1), Color(0x0032FFC7)],
            ),
          ),
          const Positioned(
            top: 120,
            right: -60,
            child: _AuroraGlow(
              size: 250,
              colors: [Color(0x8877F7FF), Color(0x002FA3FF)],
            ),
          ),
          const Positioned(
            bottom: -80,
            left: 30,
            child: _AuroraGlow(
              size: 260,
              colors: [Color(0x8880FFB4), Color(0x0000A86B)],
            ),
          ),
          const Positioned(
            bottom: 90,
            right: -40,
            child: _AuroraGlow(
              size: 220,
              colors: [Color(0x66B98BFF), Color(0x00000000)],
            ),
          ),
          SafeArea(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuroraGlow extends StatelessWidget {
  const _AuroraGlow({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
