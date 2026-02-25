import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../theme_provider.dart';

class TypingIndicator extends StatefulWidget {
  final ThemeColors themeColors;

  const TypingIndicator({super.key, required this.themeColors});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The dots are rendered inside the botBubble background.
    // Determine the optimal text color based on the botBubble's luminance to guarantee contrast.
    final bool isDarkBubble =
        widget.themeColors.botBubble.computeLuminance() < 0.5;
    final Color baseColor = isDarkBubble ? Colors.white : Colors.black87;

    // Apply opacities to create the distinct 3 dots
    final dotColor1 = baseColor.withValues(alpha: 0.8);
    final dotColor2 = baseColor.withValues(alpha: 0.6);
    final dotColor3 = baseColor.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0, dotColor1),
          const SizedBox(width: 4),
          _buildDot(1, dotColor2),
          const SizedBox(width: 4),
          _buildDot(2, dotColor3),
        ],
      ),
    );
  }

  Widget _buildDot(int index, Color baseColor) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Offset each dot by 1/3 of the animation duration
        final double offset = index * 0.33;
        double value = (_controller.value + offset) % 1.0;

        // Sine wave for smooth up and down movement
        final double sineValue = math.sin(value * math.pi * 2);

        // Map sine output (-1 to 1) to a translation in pixels
        final double dy = sineValue * -4.0;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
