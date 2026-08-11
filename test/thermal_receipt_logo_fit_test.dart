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
    expect(out.width == ThermalReceiptLogoFit.width80 || out.height == ThermalReceiptLogoFit.height80, isTrue);
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
    final esc = ThermalReceiptLogoFit.rasterGsV0(out);
    expect(esc, isNotEmpty);
    expect(esc, containsAllInOrder([29, 118, 48, 0]));
  });

  test('58mm box is smaller than 80mm', () {
    final src = solid(800, 800);
    final a = ThermalReceiptLogoFit.fit(src, mm58: true);
    final b = ThermalReceiptLogoFit.fit(src, mm58: false);
    expect(a.width, lessThan(b.width));
    expect(a.height, lessThanOrEqualTo(ThermalReceiptLogoFit.height58));
  });
}
