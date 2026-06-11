import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import 'thermal_bitmap.dart';

/// Chek widgetini termal chop uchun PNG ga aylantiradi (aniq qora-oq).
Future<Uint8List> captureReceiptForThermal(
  Widget receiptWidget, {
  BuildContext? context,
}) async {
  final controller = ScreenshotController();
  final ratio = thermalReceiptCapturePixelRatio();
  final wrapped = Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Material(
        color: Colors.white,
        child: receiptWidget,
      ),
    ),
  );

  final png = await controller.captureFromWidget(
    wrapped,
    context: context,
    pixelRatio: ratio,
    delay: const Duration(milliseconds: 150),
  );
  return prepareThermalBitmap(png);
}
