import 'package:alfapos_app/utils/payment_checkout_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentCheckoutMath', () {
    test('partial mixed payment does not cover total', () {
      const total = 9000.988;
      final allocated = PaymentCheckoutMath.allocate(
        entered: {'1': 100, '2': 0},
        keyOrder: ['1', '2'],
        totalAfterDiscount: total,
      );
      final paid = PaymentCheckoutMath.sumValues(allocated);
      expect(paid, 100);
      expect(PaymentCheckoutMath.coversTotal(paid: paid, total: total), isFalse);
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: paid), isFalse);
      expect(PaymentCheckoutMath.remaining(total: total, paid: paid), 8900.988);
    });

    test('exact fractional total is covered', () {
      const total = 9000.988;
      final allocated = PaymentCheckoutMath.allocate(
        entered: {'1': 5000, '2': 4000.988},
        keyOrder: ['1', '2'],
        totalAfterDiscount: total,
      );
      final paid = PaymentCheckoutMath.sumValues(allocated);
      expect(paid, total);
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: paid), isTrue);
      expect(PaymentCheckoutMath.remaining(total: total, paid: paid), 0);
    });

    test('0.897 total requires full 0.897 not rounded 1', () {
      const total = 0.897;
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: 0.896), isFalse);
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: 0.897), isTrue);
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: 1), isTrue);
    });

    test('overpay still covers total', () {
      const total = 100.5;
      expect(PaymentCheckoutMath.canComplete(totalAfterDiscount: total, paid: 101), isTrue);
      expect(PaymentCheckoutMath.remaining(total: total, paid: 101), 0);
    });

    test('allocation caps each line to remaining total', () {
      const total = 50.0;
      final allocated = PaymentCheckoutMath.allocate(
        entered: {'cash': 40, 'card': 40},
        keyOrder: ['cash', 'card'],
        totalAfterDiscount: total,
      );
      expect(PaymentCheckoutMath.sumValues(allocated), 50);
    });
  });
}
