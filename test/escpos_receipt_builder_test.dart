import 'package:alfapos_app/models/receipt_design_config.dart';
import 'package:alfapos_app/services/escpos_receipt_builder.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:alfapos_app/utils/receipt_strikethrough_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_formatter.dart';
import 'package:alfapos_app/utils/thermal_receipt_compact_text.dart';
import 'package:alfapos_app/utils/thermal_receipt_large_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildReceipt encodes catalog discount strikethrough line', () async {
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Alfa market',
        dateTime: DateTime(2026, 6, 11, 12, 0),
        receiptNumber: '10322',
        sellerName: 'Begzod Hamdamov',
        products: [
          ThermalReceiptProductLine(
            name: 'Муфта 20 Asiya Plast',
            quantity: '2 шт',
            unitPrice: '6,890',
            lineTotal: '13,780',
            catalogUnitPrice: '5,750',
          ),
        ],
        totalAmount: '13,780',
      ),
    );

    expect(
      lines.any(ReceiptStrikethroughText.containsMarker),
      isTrue,
      reason: 'chegirmali narx qatorida § marker bo‘lishi kerak',
    );

    final bytes = await EscPosReceiptBuilder.buildReceipt(lines: lines);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(20));
  });

  test('restaurant queue receipt builds with readable large number', () async {
    final config = ReceiptDesignConfig.defaults.copyWith(
      showRestaurantQueueNumber: true,
      restaurantQueueLabel: 'Navbat raqami',
      restaurantQueueHint: 'Navbatingizni kuzating',
    );
    final lines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: "Do'kon alfapos",
        dateTime: DateTime(2026, 6, 10, 14, 30),
        receiptNumber: 'POS99',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Latte',
            quantity: '2 dona',
            unitPrice: '25,000',
            lineTotal: '50,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '50,000'),
        ],
        discountAmount: '0',
        totalAmount: '50,000',
        queueNumber: 42,
        isRestaurantLayout: true,
      ),
      config: config,
    );

    expect(lines.any(ThermalReceiptLargeText.isLargeLine), isTrue);

    final bytes = await EscPosReceiptBuilder.buildReceipt(lines: lines, design: config);
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(40));
    // GS ! — matn kattalashtirish buyrug'i (navbat raqami uchun).
    expect(bytes.contains(29), isTrue);
  });

  test('cash drawer pulse is sent when enabled', () async {
    final withDrawer = await EscPosReceiptBuilder.buildReceipt(
      lines: const ['AlfaPOS', 'Test'],
      openCashDrawer: true,
      cashDrawerPin: PosDrawer.pin2,
    );
    final withoutDrawer = await EscPosReceiptBuilder.buildReceipt(
      lines: const ['AlfaPOS', 'Test'],
      openCashDrawer: false,
    );

    expect(withDrawer.contains(0x1B), isTrue);
    expect(withDrawer.contains(0x70), isTrue);
    expect(withDrawer.length, greaterThan(withoutDrawer.length));
  });

  test('standalone cash drawer pulse builds ESC/POS bytes', () async {
    final pulse = await EscPosReceiptBuilder.buildCashDrawerPulse(
      cashDrawerPin: PosDrawer.pin2,
    );
    expect(pulse, isNotEmpty);
    expect(pulse.contains(0x1B), isTrue);
    expect(pulse.contains(0x70), isTrue);
  });

  test('compact auto-scale lines build for printer', () async {
    final lines = [
      ThermalReceiptCompactText.line(
        '25 dona x 1,250,000 so\'m              31,250,000 so\'m',
      ),
    ];
    final bytes = await EscPosReceiptBuilder.buildReceipt(lines: lines);
    expect(bytes, isNotEmpty);
  });

  test('uzbek latin receipt lines build without error', () async {
    final lines = [
      "^Do'kon alfapos",
      'Chek raqami: POS100',
      '1. Non 1 dona x 4,000 = 4,000 so\'m',
      'Umumiy summa: 4,000 so\'m',
    ];
    final bytes = await EscPosReceiptBuilder.buildReceipt(lines: lines);
    expect(bytes, isNotEmpty);
  });

  test('restaurant receipt uses standard feed and enlarges total like shop', () async {
    final config = ReceiptDesignConfig.defaults.copyWith(
      showRestaurantQueueNumber: true,
      restaurantQueueLabel: 'Navbat raqami',
    );
    final restaurantLines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: 'Restoran',
        dateTime: DateTime(2026, 6, 10, 14, 30),
        receiptNumber: 'POS99',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Latte',
            quantity: '1 dona',
            unitPrice: '25,000',
            lineTotal: '25,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '25,000'),
        ],
        totalAmount: '25,000',
        queueNumber: 12,
        isRestaurantLayout: true,
      ),
      config: config,
    );
    final shopLines = ThermalReceiptFormatter.toPrintLines(
      ThermalReceiptPrintData(
        storeName: "Do'kon",
        dateTime: DateTime(2026, 6, 10, 14, 30),
        receiptNumber: 'POS100',
        sellerName: 'Kassir',
        products: const [
          ThermalReceiptProductLine(
            name: 'Non',
            quantity: '1 dona',
            unitPrice: '4,000',
            lineTotal: '4,000',
          ),
        ],
        payments: const [
          ThermalReceiptPaymentLine(method: 'Naqd pul', amount: '4,000'),
        ],
        totalAmount: '4,000',
      ),
    );

    final restaurantBytes = await EscPosReceiptBuilder.buildReceipt(
      lines: restaurantLines,
      design: config,
    );
    final shopBytes = await EscPosReceiptBuilder.buildReceipt(lines: shopLines);

    int feedBeforeCut(List<int> bytes) {
      final feedIndex = bytes.lastIndexOf(0x64);
      expect(feedIndex, greaterThan(0));
      expect(bytes[feedIndex - 1], 0x1B);
      return bytes[feedIndex + 1];
    }

    expect(feedBeforeCut(restaurantBytes), feedBeforeCut(shopBytes));
    expect(feedBeforeCut(restaurantBytes), 2);
    // GS ! — faqat navbat raqami kattalashtiriladi.
    expect(restaurantBytes.contains(29), isTrue);
  });

  test('standard receipt uses minimal feed before cut', () async {
    final bytes = await EscPosReceiptBuilder.buildReceipt(
      lines: const ['Naqd pul - 1', 'Umumiy summa - 1'],
    );
    final feedIndex = bytes.lastIndexOf(0x64);
    expect(feedIndex, greaterThan(0));
    expect(bytes[feedIndex - 1], 0x1B);
    expect(bytes[feedIndex + 1], 2);
  });

  test('XP-80C uses 3-line feed and compact spacing, not g.cut waste', () async {
    final bytes = await EscPosReceiptBuilder.buildReceipt(
      lines: const ['Naqd pul - 1', 'Umumiy summa - 1'],
      printerName: 'Xprinter XP-80C',
    );
    final feedIndex = bytes.lastIndexOf(0x64);
    expect(feedIndex, greaterThan(0));
    expect(bytes[feedIndex - 1], 0x1B);
    expect(bytes[feedIndex + 1], 3);
    expect(bytes[feedIndex + 2], 0x1D); // GS
    expect(bytes[feedIndex + 3], 0x56); // V
    expect(bytes[feedIndex + 4], 1); // partial cut, no extra 5-line feed
    expect(bytes, containsAllInOrder([27, 51, 24]));
  });
}
