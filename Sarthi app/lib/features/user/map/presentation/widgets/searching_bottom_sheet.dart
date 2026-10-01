import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'drag_handle.dart';

class SearchingBottomSheet extends StatelessWidget {
  final VoidCallback onCancelRequest;

  const SearchingBottomSheet({
    super.key,
    required this.onCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragHandle(),
          const SizedBox(height: 16),
          const _SearchingState(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancelRequest,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              backgroundColor: const Color(0xFFFFF7F7),
              side: const BorderSide(color: Color(0xFFFECACA)),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingState extends StatefulWidget {
  const _SearchingState();

  @override
  State<_SearchingState> createState() => _SearchingStateState();
}

class _SearchingStateState extends State<_SearchingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _searchAnimationController;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSmoothProgressBar() {
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: 4,
        child: CustomPaint(
          painter: _SearchProgressPainter(
            animation: _searchAnimationController,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RepaintBoundary(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _SearchSpinnerPainter(
                              animation: _searchAnimationController,
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.person_search_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINDING YOUR CAPTAIN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.75,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Searching nearby captains',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Matching you with the closest available ride',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 9.5,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildSmoothProgressBar(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Most matches take about 10–30 seconds',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF86EFAC),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSpinnerPainter extends CustomPainter {
  _SearchSpinnerPainter({required Animation<double> animation})
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;
  final Paint _trackPaint = Paint()
    ..color = const Color(0x2EFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;
  final Paint _arcPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.4;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcBounds = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, _trackPaint);
    canvas.drawArc(
      arcBounds,
      -math.pi / 2 + (math.pi * 2 * _animation.value),
      math.pi * 1.44,
      false,
      _arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchSpinnerPainter oldDelegate) => false;
}

class _SearchProgressPainter extends CustomPainter {
  _SearchProgressPainter({required Animation<double> animation})
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;
  final Paint _trackPaint = Paint()..color = const Color(0x24FFFFFF);
  final Paint _segmentPaint = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, _trackPaint);

    final segmentWidth = size.width * 0.34;
    final easedProgress = Curves.easeInOutCubic.transform(_animation.value);
    final segmentLeft =
        ((size.width + segmentWidth) * easedProgress) - segmentWidth;
    final segmentRect = Rect.fromLTWH(
      segmentLeft,
      0,
      segmentWidth,
      size.height,
    );

    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRRect(
      RRect.fromRectAndRadius(segmentRect, radius),
      _segmentPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SearchProgressPainter oldDelegate) => false;
}
