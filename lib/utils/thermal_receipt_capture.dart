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
  final png = await controller.captureFromWidget(
    receiptWidget,
    context: context,
    pixelRatio: ratio,
    delay: const Duration(milliseconds: 120),
  );
  return prepareThermalBitmap(png);
}
