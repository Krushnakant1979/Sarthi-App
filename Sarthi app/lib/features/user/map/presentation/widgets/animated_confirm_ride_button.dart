import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/design/tokens.dart';

class AnimatedConfirmRideButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const AnimatedConfirmRideButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<AnimatedConfirmRideButton> createState() =>
      _AnimatedConfirmRideButtonState();
}

class _AnimatedConfirmRideButtonState extends State<AnimatedConfirmRideButton>
    with TickerProviderStateMixin {
  late final AnimationController _sheenController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _sheenController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primaryColor = context.colors.primary;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final t = _pulseAnimation.value;
            final blur = 10.0 + (8.0 * t);
            final shadowAlpha = 0.25 + (0.15 * t);

            return Container(
              height: 42,
              width: (screenWidth * 0.42).clamp(142.0, 168.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: shadowAlpha),
                    blurRadius: blur,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base background & content
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirm Ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth < 380 ? 13.5 : 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _sheenController,
                        builder: (context, _) {
                          final value = _sheenController.value;
                          final double arrowNudge;
                          if (value <= 0.42) {
                            final p = value / 0.42;
                            arrowNudge = math.sin(p * math.pi) * 3.5;
                          } else {
                            arrowNudge = 0.0;
                          }
                          return Transform.translate(
                            offset: Offset(arrowNudge, 0),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Shimmer sheen sweep overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sheenController,
                      builder: (context, _) {
                        final value = _sheenController.value;
                        if (value > 0.42) {
                          return const SizedBox.shrink();
                        }
                        final progress = value / 0.42;
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final left = -60.0 + (width + 120.0) * progress;
                            return Stack(
                              children: [
                                Positioned(
                                  left: left,
                                  top: -20,
                                  bottom: -20,
                                  width: 40,
                                  child: Transform.rotate(
                                    angle: 0.35,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: 0.38),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
