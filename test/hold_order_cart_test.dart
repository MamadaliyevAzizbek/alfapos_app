import 'package:alfapos_app/models/cart_item.dart';
import 'package:alfapos_app/utils/hold_order_cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HoldOrderCart.parse', () {
    test('parses embedded cart lines', () {
      final resume = HoldOrderCart.parse({
        'orderID': 42,
        'invoice_id': 'POS10042',
        'grandTotal': 30000,
        'cart': [
          {
            'productID': 7,
            'variantID': 1,
            'quantity': 2,
            'price': 15000,
            'productTitle': 'Non',
            'orderType': 'sales',
            'calculatedPrice': 30000,
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.orderId, 42);
      expect(resume.items.length, 1);
      expect(resume.items.first.product.id, '7');
      expect(resume.items.first.quantity, 2);
      expect(resume.items.first.unitPriceDisplay.round(), 15000);
    });

    test('restores discounted unit from calculatedPrice + discount', () {
      final resume = HoldOrderCart.parse({
        'orderID': 1,
        'discount': 50000, // so‘m — foiz emas
        'cart': [
          {
            'productID': 9,
            'quantity': 2,
            'price': 20000,
            'discount': 4000,
            'calculatedPrice': 36000,
            'productTitle': 'Suv',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.discountPercent, 0);
      final item = resume.items.single;
      expect(item.unitPriceDisplay, 18000);
      expect(item.salePriceOverride, 18000);
      expect(item.priceLocked, isTrue);
    });

    test('restores sold unit from discount when calculatedPrice missing', () {
      final resume = HoldOrderCart.parse({
        'cart': [
          {
            'productID': 3,
            'quantity': 1,
            'price': 10000,
            'discount': 1500,
            'productTitle': 'Choy',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.single.unitPriceDisplay, 8500);
      expect(resume.items.single.priceLocked, isTrue);
    });

    test('cartPercentFromOrderDiscount treats large values as UZS', () {
      expect(HoldOrderCart.cartPercentFromOrderDiscount(10), 10);
      expect(HoldOrderCart.cartPercentFromOrderDiscount(-15), -15);
      expect(HoldOrderCart.cartPercentFromOrderDiscount(50000), 0);
      expect(HoldOrderCart.cartPercentFromOrderDiscount(0), 0);
    });

    test('restores sold unit from cartItemNote when API drops discount', () {
      final resume = HoldOrderCart.parse({
        'orderID': 2,
        'cart': [
          {
            'productID': 4,
            'quantity': 2,
            'price': 20000,
            'discount': 0,
            'calculatedPrice': 40000,
            'cartItemNote': 'alfapos_sold_unit=15000',
            'productTitle': 'Suv',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.single.unitPriceDisplay, 15000);
      expect(resume.items.single.salePriceOverride, 15000);
      expect(resume.items.single.priceLocked, isTrue);
    });

    test('restores sold unit from soldUnitPrice field', () {
      final resume = HoldOrderCart.parse({
        'cart': [
          {
            'productID': 8,
            'quantity': 1,
            'price': 12000,
            'soldUnitPrice': 9500,
            'productTitle': 'Non',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.single.unitPriceDisplay, 9500);
      expect(resume.items.single.priceLocked, isTrue);
    });

    test('does not truncate 10,000 / 10.000 string amounts to 10', () {
      final comma = HoldOrderCart.parse({
        'cart': [
          {
            'productID': 11,
            'quantity': 1,
            'price': '11,000',
            'discount': '1,000',
            'calculatedPrice': '10,000',
            'productTitle': 'Granula',
            'orderType': 'sales',
          },
        ],
      });
      expect(comma!.items.single.unitPriceDisplay, 10000);

      final euDot = HoldOrderCart.parse({
        'cart': [
          {
            'productID': 12,
            'quantity': 1,
            'price': '11.000',
            'calculatedPrice': '10.000',
            'soldUnitPrice': '10.000',
            'productTitle': 'Granula',
            'orderType': 'sales',
          },
        ],
      });
      expect(euDot!.items.single.unitPriceDisplay, 10000);
      expect(euDot.items.single.priceLocked, isTrue);
    });

    test('reads order_items key', () {
      final resume = HoldOrderCart.parse({
        'id': 99,
        'order_items': [
          {
            'product_id': 3,
            'quantity': 1,
            'price': 21000,
            'productTitle': 'Fanta 0.5L',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.items.single.product.name, 'Fanta 0.5L');
    });

    test('returns null when cart missing', () {
      expect(HoldOrderCart.parse({'orderID': 1, 'grandTotal': 0}), isNull);
    });

    test('skips discount orderType rows', () {
      final resume = HoldOrderCart.parse({
        'cart': [
          {'orderType': 'discount', 'productID': 1, 'quantity': 1, 'price': 100},
          {
            'productID': 2,
            'quantity': 1,
            'price': 5000,
            'productTitle': 'Choy',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.length, 1);
      expect(resume.items.first.product.id, '2');
    });

    test('restores lineTotalOverride for kerakli summa rounding (50000 vs 49995)', () {
      final resume = HoldOrderCart.parse({
        'orderID': 10122,
        'grandTotal': 50000,
        'cart': [
          {
            'productID': 101629,
            'quantity': 4.545,
            'price': 11000,
            'discount': 0,
            'calculatedPrice': 50000,
            'soldUnitPrice': 11000,
            'productTitle': 'GRANULA  37 / 1.6',
            'orderType': 'sales',
            'cartItemNote': 'alfapos_sold_unit=11000;alfapos_line_total=50000',
          },
        ],
      });
      expect(resume, isNotNull);
      expect(resume!.items.single.quantity, 4.545);
      expect(resume.items.single.unitPriceDisplay, 11000);
      expect((11000 * 4.545).round(), 49995);
      expect(resume.items.single.lineTotalOverride, 50000);
      expect(resume.items.single.total, 50000);
    });

    test('restores lineTotalOverride from calculatedPrice without note', () {
      final resume = HoldOrderCart.parse({
        'orderID': 2,
        'grandTotal': 50000,
        'cart': [
          {
            'productID': 9,
            'quantity': 4.545,
            'price': 11000,
            'discount': 0,
            'calculatedPrice': 50000,
            'productTitle': 'Granula',
            'orderType': 'sales',
          },
        ],
      });
      expect(resume!.items.single.total, 50000);
      expect(resume.items.single.lineTotalOverride, 50000);
    });

    test('ignores broken calculatedPrice discount residue on invoice edit', () {
      // Real bug: editable-order calculatedPrice=22 (chegirma), qty×narx≈50000.
      final resume = HoldOrderCart.parse({
        'orderID': 10139,
        'grandTotal': 149976,
        'cart': [
          {
            'productID': 1,
            'quantity': 5.556,
            'price': 9000,
            'discount': 22,
            'calculatedPrice': 22,
            'soldUnitPrice': 8999,
            'productTitle': 'GRANULA (Yangi) 32 / 6',
            'orderType': 'sales',
          },
          {
            'productID': 2,
            'quantity': 4.545,
            'price': 22000,
            'discount': 14,
            'calculatedPrice': 99978,
            'soldUnitPrice': 21997,
            'productTitle': 'GRANULA 37 / 1.6',
            'orderType': 'sales',
            'cartItemNote': 'alfapos_sold_unit=21997;alfapos_line_total=99978',
          },
        ],
      });
      expect(resume, isNotNull);
      final a = resume!.items[0];
      expect(a.unitPriceDisplay, 8999);
      expect(a.lineTotalOverride, isNull);
      expect(a.total, CartItem.quantizeLineTotal(8999 * 5.556));
      expect(a.total, greaterThan(1000));

      final b = resume.items[1];
      expect(b.lineTotalOverride, 99978);
      expect(b.total, 99978);
    });

    test('restores markup above catalog via grandTotal surplus', () {
      // Real POS10056 / order 420094 editable-order payload (company 99).
      final resume = HoldOrderCart.parse({
        'orderID': 420094,
        'invoice_id': 'POS10056',
        'grandTotal': 15000,
        'cart': [
          {
            'productID': 101625,
            'productTitle': '511',
            'quantity': '1.000',
            'price': 6000,
            'discount': 1000,
            'calculatedPrice': 1000,
            'soldUnitPrice': null,
            'cartItemNote': null,
            'orderType': 'sales',
          },
          {
            'productID': 101626,
            'productTitle': 'Венгер карп  56х95',
            'quantity': '1.000',
            'price': 3480,
            'discount': 0,
            'calculatedPrice': 3480,
            'soldUnitPrice': null,
            'cartItemNote': null,
            'orderType': 'sales',
          },
          {
            'productID': 101629,
            'productTitle': 'GRANULA  37 / 1.6',
            'quantity': '1.000',
            'price': 11000,
            'discount': 6000,
            'calculatedPrice': 6000,
            'soldUnitPrice': null,
            'cartItemNote': null,
            'orderType': 'sales',
          },
        ],
      });
      expect(resume, isNotNull);
      expect(
        resume!.items.map((e) => e.unitPriceDisplay.round()).toList(),
        [5000, 5000, 5000],
      );
      expect(resume.items.fold<num>(0, (s, e) => s + e.total), 15000);
      expect(resume.items[1].priceLocked, isTrue);
    });

    test('invoice-details total restores markup line without grandTotal hack', () {
      // Real invoice-details for order 420094: scaled price/discount, but total=5000.
      final resume = HoldOrderCart.fromInvoiceDetails(
        {
          'datarows': [
            {
              'title': '511 ',
              'quantity': '1.000',
              'price': 6,
              'discount': 1,
              'total': '5000.00',
            },
            {
              'title': 'Венгер карп  56х95 ',
              'quantity': '1.000',
              'price': 3,
              'discount': 0,
              'total': '5000.00',
            },
            {
              'title': 'GRANULA  37 / 1.6 ',
              'quantity': '1.000',
              'price': 11,
              'discount': 6,
              'total': '5000.00',
            },
            {'title': 'Umumiy summa', 'total': 15000},
            {'title': 'Soliq', 'total': 0},
            {'title': 'Umumiy', 'total': 15000},
            {'title': 'Naqd pul', 'total': '15000.00'},
          ],
          'count': 7,
        },
        metaSource: {
          'orderID': 420094,
          'invoice_id': 'POS10056',
          'grandTotal': 15000,
        },
      );
      expect(resume, isNotNull);
      expect(
        resume!.items.map((e) => e.unitPriceDisplay.round()).toList(),
        [5000, 5000, 5000],
      );
      expect(resume.items.fold<num>(0, (s, e) => s + e.total), 15000);
    });
  });
}
