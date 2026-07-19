import 'package:flutter/material.dart';

import '../../theme/rummy_colors.dart';

/// Oval felt table with a warm brown rim (reference-style board).
class TableSurface extends StatelessWidget {
  final Widget? child;

  const TableSurface({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TableSurfacePainter(),
      child: child,
    );
  }
}

class _TableSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final rimShadow = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(rect.translate(0, 10), rimShadow);

    final rimPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5A2B), RummyColors.rimOuter, RummyColors.rimInner],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawOval(rect, rimPaint);

    final inlayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFD4A84B).withOpacity(0.65);
    canvas.drawOval(rect.deflate(size.shortestSide * 0.018), inlayPaint);

    final inset = size.shortestSide * 0.048;
    final feltRect = rect.deflate(inset);
    final feltPaint = Paint()..shader = RummyColors.tableGradient.createShader(feltRect);
    canvas.drawOval(feltRect, feltPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withOpacity(0.12);
    canvas.drawOval(feltRect.deflate(8), ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
