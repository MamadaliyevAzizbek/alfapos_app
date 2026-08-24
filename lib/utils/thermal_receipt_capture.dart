import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

/// ReceiptWidget — galereyaga saqlash / ulashish uchun skrinshot.
Future<Uint8List> captureReceiptWidget(
  Widget receiptWidget, {
  BuildContext? context,
  required double targetHeight,
  double targetWidth = 360,
  int lineCount = 0,
  double pixelRatio = 3,
}) async {
  final controller = ScreenshotController();
  final delayMs = (200 + lineCount * 3).clamp(200, 2000);
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
    pixelRatio: pixelRatio,
    targetSize: Size(targetWidth, targetHeight),
    delay: Duration(milliseconds: delayMs),
  );
  return png;
}
