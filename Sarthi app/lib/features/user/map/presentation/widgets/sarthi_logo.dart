import 'package:flutter/material.dart';

class SarthiLogo extends StatelessWidget {
  final double size;
  const SarthiLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * (26 / 24)),
      painter: _SarthiLogoPainter(),
    );
  }
}

class _SarthiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sw = size.width / 24;
    final double sh = size.height / 26;

    final paintDark = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 4 * sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintYellow = Paint()
      ..color = const Color(0xFFEAB308)
      ..strokeWidth = 4 * sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topPath = Path()
      ..moveTo(20 * sw, 11 * sh)
      ..lineTo(8 * sw, 11 * sh)
      ..arcToPoint(
        Offset(8 * sw, 5 * sh),
        radius: Radius.circular(3 * sw),
        clockwise: true,
      )
      ..lineTo(20 * sw, 5 * sh);

    final bottomPath = Path()
      ..moveTo(5 * sw, 15 * sh)
      ..lineTo(17 * sw, 15 * sh)
      ..arcToPoint(
        Offset(17 * sw, 21 * sh),
        radius: Radius.circular(3 * sw),
        clockwise: true,
      )
      ..lineTo(5 * sw, 21 * sh);

    canvas.drawPath(topPath, paintDark);
    canvas.drawPath(bottomPath, paintYellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
