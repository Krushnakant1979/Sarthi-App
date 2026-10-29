import 'package:flutter/material.dart';

class SarthiLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showText;
  final TextStyle? textStyle;
  final Gradient? textGradient;

  const SarthiLogo({
    super.key,
    this.size = 28,
    this.borderRadius,
    this.showText = false,
    this.textStyle,
    this.textGradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.25);
    final iconWidget = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/app-logo/Sarthi app user logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF005AFE),
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.55,
            ),
          ),
        ),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final shouldShowText = screenWidth >= 340;

    final effectiveGradient = textGradient ??
        const LinearGradient(
          colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        if (shouldShowText) ...[
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => effectiveGradient.createShader(bounds),
            child: Text(
              'Sarthi',
              style: (textStyle ??
                      const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.5,
                      ))
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }
}
