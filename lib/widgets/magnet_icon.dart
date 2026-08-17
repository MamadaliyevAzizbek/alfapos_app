import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Taqasimon magnit belgisi.
///
/// Material Icons to‘plamida magnit yo‘q, shuning uchun qo‘lda chiziladi.
/// Qutb uchlari asosiy rangdan ochroq bo‘lib, belgini magnit sifatida
/// tanib olishni osonlashtiradi.
class MagnetIcon extends StatelessWidget {
  const MagnetIcon({
    super.key,
    this.size = 18,
    this.color = const Color(0xFF2563EB),
    this.tipColor,
  });

  final double size;
  final Color color;
  final Color? tipColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MagnetPainter(
          color: color,
          tipColor: tipColor ?? color.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _MagnetPainter extends CustomPainter {
  _MagnetPainter({required this.color, required this.tipColor});

  final Color color;
  final Color tipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 0.24;
    final cx = size.width / 2;
    final radius = s * 0.30;
    final arcCenterY = s * 0.42;
    final tipTop = s * 0.70;
    final bottom = s * 0.86;

    final leftX = cx - radius;
    final rightX = cx + radius;

    final body = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Taqa: chap oyoq → yuqori yarim doira → o‘ng oyoq.
    final path = Path()
      ..moveTo(leftX, tipTop)
      ..lineTo(leftX, arcCenterY)
      ..arcToPoint(
        Offset(rightX, arcCenterY),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..lineTo(rightX, tipTop);
    canvas.drawPath(path, body);

    // Qutblar.
    final tip = Paint()
      ..color = tipColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(leftX, tipTop), Offset(leftX, bottom), tip);
    canvas.drawLine(Offset(rightX, tipTop), Offset(rightX, bottom), tip);
  }

  @override
  bool shouldRepaint(_MagnetPainter old) =>
      old.color != color || old.tipColor != tipColor;
}
