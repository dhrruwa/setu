import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Setu means bridge. The mark is an arc joining two banks, with a warm dot
/// resting on it - the mother being carried across.
class SetuLogo extends StatelessWidget {
  const SetuLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.teal,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: kCardShadow,
      ),
      child: CustomPaint(painter: _BridgePainter()),
    );
  }
}

class _BridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.075;

    final line = Paint()
      ..color = C.onDark
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // The deck.
    final deckY = h * 0.66;
    canvas.drawLine(
        Offset(w * 0.17, deckY), Offset(w * 0.83, deckY), line);

    // The arc above it.
    final rect = Rect.fromLTWH(w * 0.19, h * 0.30, w * 0.62, h * 0.62);
    canvas.drawArc(rect, math.pi, math.pi, false, line);

    // Two piers.
    canvas.drawLine(
        Offset(w * 0.32, deckY), Offset(w * 0.32, h * 0.82), line);
    canvas.drawLine(
        Offset(w * 0.68, deckY), Offset(w * 0.68, h * 0.82), line);

    // The mother, carried across.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.36),
      w * 0.085,
      Paint()..color = C.terra,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
