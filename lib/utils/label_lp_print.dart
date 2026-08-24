import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../services/thermal_print_result.dart';

/// Yorliq PNG ni CUPS orqali aniq mm o‘lchamida chop etish.
class LabelLpPrint {
  LabelLpPrint._();

  static const double dotsPerMm = 203 / 25.4;

  /// PNG piksel o‘lchamidan mm taxmin qilish (203 DPI).
  static ({double widthMm, double heightMm})? mmFromPng(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;
    return (
      widthMm: decoded.width / dotsPerMm,
      heightMm: decoded.height / dotsPerMm,
    );
  }

  /// Kichik PNG — yorliq; katta PNG — chek.
  static bool looksLikeLabel(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return false;
    return decoded.width <= 480 && decoded.height <= 360;
  }

  static String pageSizeOption(double widthMm, double heightMm) {
    final w = widthMm.round().clamp(20, 100);
    final h = heightMm.round().clamp(15, 80);
    return 'Custom.${w}x${h}mm';
  }

  static Future<ThermalPrintResult> printPng(
    Uint8List pngBytes,
    String printer, {
    double? widthMm,
    double? heightMm,
  }) async {
    final file = File(
      '${Directory.systemTemp.path}/alfapos_label_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    double? w = widthMm;
    double? h = heightMm;
    if (w == null || h == null) {
      final inferred = mmFromPng(pngBytes);
      if (inferred != null && looksLikeLabel(pngBytes)) {
        w = inferred.widthMm;
        h = inferred.heightMm;
      }
    }

    final args = <String>['-d', printer];
    if (w != null && h != null) {
      args.addAll(['-o', 'PageSize=${pageSizeOption(w, h)}']);
    }
    args.addAll(['-o', 'fit-to-page', file.path]);

    var result = await Process.run('lp', args);
    if (result.exitCode == 0) {
      return ThermalPrintResult.ok('Yorliq yuborildi ($printer)');
    }

    result = await Process.run('lp', ['-d', printer, '-o', 'fit-to-page', file.path]);
    if (result.exitCode == 0) {
      return ThermalPrintResult.ok('Yorliq yuborildi ($printer)');
    }

    return ThermalPrintResult.fail(
      'Chop etib bo\'lmadi: ${result.stderr.toString().trim()}',
    );
  }
}
