import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Fondo animado y discreto para dar profundidad tipo Liquid Glass a una vista.
class LiquidGlassBackground extends StatefulWidget {
  const LiquidGlassBackground({
    required this.child,
    this.backgroundColor = const Color(0xFFE5EEF8),
    super.key,
  });

  final Widget child;
  final Color backgroundColor;

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final progress = _controller.value;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: 30 + progress * 100,
                          right: -90 + progress * 40,
                          child: _glow(220, const Color(0xFF74B9FF)),
                        ),
                        Positioned(
                          top: 390 - progress * 90,
                          left: -120 + progress * 45,
                          child: _glow(250, const Color(0xFF8DE0D2)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ),
        ),
      ),
    );
  }
}
