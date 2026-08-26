import 'dart:io';

import 'package:alfapos_app/utils/thermal_receipt_logo_fit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  img.Image solid(int w, int h) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(20, 80, 160));
    return im;
  }

  test('large logo is shrunk into 80mm box', () {
    final out = ThermalReceiptLogoFit.fit(solid(2000, 1500), mm58: false);
    expect(out.width, lessThanOrEqualTo(ThermalReceiptLogoFit.width80));
    expect(out.height, lessThanOrEqualTo(ThermalReceiptLogoFit.height80));
    expect(
      out.width == ThermalReceiptLogoFit.width80 ||
          out.height == ThermalReceiptLogoFit.height80,
      isTrue,
    );
  });

  test('tiny logo is enlarged to standard size', () {
    final out = ThermalReceiptLogoFit.fit(solid(40, 20), mm58: false);
    expect(out.width, greaterThan(40));
    expect(out.height, greaterThan(20));
    expect(out.width, lessThanOrEqualTo(ThermalReceiptLogoFit.width80));
    expect(out.height, lessThanOrEqualTo(ThermalReceiptLogoFit.height80));
  });

  test('wide banner keeps aspect and does not exceed height', () {
    final out = ThermalReceiptLogoFit.fitToBox(solid(2000, 200), 384, 256);
    expect(out.width, 384);
    expect(out.height, 38);
  });

  test('fitted logo width is multiple of 8 for GS v 0', () {
    final out = ThermalReceiptLogoFit.fitToBox(solid(70, 50), 384, 256);
    expect(out.width % 8, 0);
    final esc = ThermalReceiptLogoFit.rasterEscStar(out);
    expect(esc, isNotEmpty);
    expect(esc, containsAllInOrder([27, 42, 33]));
  });

  test('58mm box is smaller than 80mm', () {
    final src = solid(800, 800);
    final a = ThermalReceiptLogoFit.fit(src, mm58: true);
    final b = ThermalReceiptLogoFit.fit(src, mm58: false);
    expect(a.width, lessThan(b.width));
    expect(a.height, lessThanOrEqualTo(ThermalReceiptLogoFit.height58));
  });

  test('transparent padding is trimmed so artwork fills the box', () {
    final canvas = img.Image(width: 400, height: 400, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillRect(
      canvas,
      x1: 160,
      y1: 160,
      x2: 239,
      y2: 239,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
    final out = ThermalReceiptLogoFit.fit(canvas, mm58: false);
    expect(out.width, greaterThanOrEqualTo(140));
    expect(out.height, greaterThanOrEqualTo(140));
    var black = 0;
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        if (p.r < 40 && p.g < 40 && p.b < 40) black++;
      }
    }
    expect(black / (out.width * out.height), greaterThan(0.35));
  });

  test('fitted pixels are high-contrast black or white', () {
    final src = img.Image(width: 40, height: 40);
    img.fill(src, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      src,
      x1: 8,
      y1: 8,
      x2: 31,
      y2: 31,
      color: img.ColorRgb8(90, 90, 90),
    );
    final out = ThermalReceiptLogoFit.fit(src, mm58: false);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final v = out.getPixel(x, y).r.toInt();
        expect(v == 0 || v == 255, isTrue);
      }
    }
  });

  test('Untitled-1-08 prints at readable 80mm size with black ink', () {
    final file = File('Untitled-1-08.png');
    expect(file.existsSync(), isTrue);
    final decoded = img.decodeImage(file.readAsBytesSync());
    expect(decoded, isNotNull);
    final out = ThermalReceiptLogoFit.fit(decoded!, mm58: false);
    expect(out.width, lessThanOrEqualTo(ThermalReceiptLogoFit.width80));
    expect(out.height, lessThanOrEqualTo(ThermalReceiptLogoFit.height80));
    expect(out.width % 8, 0);
    var black = 0;
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        if (p.r < 40) black++;
      }
    }
    expect(black, greaterThan(2000));
    final esc = ThermalReceiptLogoFit.rasterEscStar(out);
    expect(esc, containsAllInOrder([27, 42, 33]));
    final ink = esc.where((b) => b != 0 && b != 27 && b != 42 && b != 33 && b != 10).length;
    expect(ink, greaterThan(80));
  });
}
