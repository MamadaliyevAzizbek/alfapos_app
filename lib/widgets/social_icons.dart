import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Instagram belgisi.
///
/// Lucide brend ikonkalarini tashlab yuborgan, shuning uchun chiziq uslubi
/// (stroke) qolgan ikonkalarga mos qilib qo‘lda chiziladi.
class InstagramIcon extends StatelessWidget {
  const InstagramIcon({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _InstagramPainter(color)),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  _InstagramPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s / 12;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = s * 0.12;
    final frame = Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(s * 0.28)),
      paint,
    );

    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.21, paint);

    // Yuqori o‘ngdagi nuqta.
    canvas.drawCircle(
      Offset(s * 0.71, s * 0.29),
      stroke * 0.62,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InstagramPainter old) => old.color != color;
}

/// YouTube belgisi — yumaloq to‘rtburchak va ichida «play» uchburchagi.
class YoutubeIcon extends StatelessWidget {
  const YoutubeIcon({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _YoutubePainter(color)),
    );
  }
}

class _YoutubePainter extends CustomPainter {
  _YoutubePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s / 12;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final frame = Rect.fromLTWH(s * 0.08, s * 0.22, s * 0.84, s * 0.56);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(s * 0.16)),
      paint,
    );

    final play = Path()
      ..moveTo(s * 0.42, s * 0.37)
      ..lineTo(s * 0.63, s * 0.50)
      ..lineTo(s * 0.42, s * 0.63)
      ..close();
    canvas.drawPath(
      play,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_YoutubePainter old) => old.color != color;
}
