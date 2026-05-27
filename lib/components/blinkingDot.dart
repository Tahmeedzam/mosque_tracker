import 'package:flutter/material.dart';

class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 3.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnim = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring 1
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF52B788),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          // Ring 2 — offset by 500ms
          AnimatedBuilder(
            animation: CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.33, 1.0, curve: Curves.easeOut),
            ),
            builder: (_, __) {
              final t = (_controller.value - 0.33).clamp(0.0, 0.67) / 0.67;
              return Transform.scale(
                scale: 1.0 + t * 2.5,
                child: Opacity(
                  opacity: (0.6 - t * 0.6).clamp(0.0, 1.0),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF52B788),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          // Core dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF52B788),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
