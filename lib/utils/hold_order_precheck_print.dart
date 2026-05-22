import 'dart:io';

import '../core/seller_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/printer_settings.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../widgets/receipt_widget.dart';
import 'hold_order_cart.dart';
import 'hold_orders_response.dart';

/// Saqlangan (hold) buyurtma uchun oldindan chek — to‘lov chekidan oldin.
class HoldOrderPrecheckPrint {
  HoldOrderPrecheckPrint._();

  static Future<ThermalPrintResult> printHoldOrder(Map<String, dynamic> hold) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      return ThermalPrintResult.fail(
        'Termal chop etish faqat Windows yoki macOS desktop ilovasida',
      );
    }

    final resumeFuture = HoldOrderCart.fetchResumeForPrint(hold);
    final designFuture = ReceiptDesignStorage.load();
    final sellerFuture = Future.wait([getSellerName(), getSellerPhone()]);

    final resume = await resumeFuture;
    if (resume == null || resume.items.isEmpty) {
      return ThermalPrintResult.fail('Savat bo\'sh yoki yuklanmadi');
    }

    final results = await Future.wait([designFuture, sellerFuture]);
    final design = results[0] as ReceiptDesignConfig;
    final sellerPair = results[1] as List<String>;
    final seller = sellerPair[0];
    final sellerPhone = sellerPair[1].isNotEmpty ? sellerPair[1] : null;

    final raw = resume.items.fold<int>(0, (s, e) => s + e.total);
    final total = _resolveGrandTotal(raw, resume);
    final discount = (raw - total).clamp(0, raw);
    final client = resume.customer;

    final widget = ReceiptWidget(
      dateTime: DateTime.now(),
      receiptNumber: _receiptLabel(hold, resume) ?? '—',
      sellerName: seller.isNotEmpty ? seller : 'Sotuvchi',
      sellerPhone: sellerPhone,
      branchName: SalesSessionProvider.instance.branchName.trim(),
      clientName: client?.name,
      clientPhone: client?.phone,
      clientAddress: client?.address,
      productRows: _productRows(resume.items),
      paymentRows: const [],
      discount: discount,
      totalSum: total,
      isPrecheck: true,
      design: design,
    );

    final directOnly = await PrinterSettings.isPrinterReady();
    return ThermalReceiptPrinter.printLocalReceipt(
      widget.toThermalPrintLines(),
      directOnly: directOnly,
    );
  }

  static List<ReceiptRow> _productRows(List<CartItem> items) {
    return items.map((item) {
      final p = item.product;
      final unitLabel = item.sellByPack ? 'pachka' : Product.unitDisplayShort(p.unit);
      return ReceiptRow(
        productName: p.name,
        quantityStr: '${item.quantity} $unitLabel',
        price: item.unitPriceDisplay,
        sum: item.total,
      );
    }).toList();
  }

  static int _resolveGrandTotal(int raw, HoldOrderResume resume) {
    final fromApi = resume.grandTotal;
    if (fromApi != null && fromApi > 0) return fromApi;
    final pct = resume.discountPercent;
    if (pct != null && pct != 0) {
      return (raw * (100 + pct) / 100).round();
    }
    return raw;
  }

  static String? _receiptLabel(Map<String, dynamic> hold, HoldOrderResume resume) {
    final inv = HoldOrdersResponse.resolveInvoiceId(hold) ?? resume.invoiceId;
    if (inv != null && inv.isNotEmpty) {
      final s = inv.trim();
      return s.toUpperCase().startsWith('POS') ? s : 'POS$s';
    }
    final id = HoldOrdersResponse.resolveOrderId(hold) ?? resume.orderId;
    if (id != null && id > 0) return 'POS$id';
    return null;
  }
}
