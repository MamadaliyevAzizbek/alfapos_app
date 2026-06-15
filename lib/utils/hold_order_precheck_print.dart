import 'dart:io';

import '../core/seller_preferences.dart';
import '../models/receipt_design_config.dart';
import '../providers/sales_session_provider.dart';
import '../services/printer_settings.dart';
import '../services/receipt_design_storage.dart';
import '../services/thermal_receipt_printer.dart';
import '../services/desktop_sales_layout_settings.dart';
import '../utils/receipt_row_builder.dart';
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
    final sellerNameFuture = getSellerName();
    final sellerPhoneFuture = getSellerPhone();

    final resume = await resumeFuture;
    if (resume == null || resume.items.isEmpty) {
      return ThermalPrintResult.fail('Savat bo\'sh yoki yuklanmadi');
    }

    final results = await Future.wait([
      designFuture,
      sellerNameFuture,
      sellerPhoneFuture,
      DesktopSalesLayoutSettings.getMode(),
    ]);
    final design = results[0] as ReceiptDesignConfig;
    final seller = results[1] as String;
    final sellerPhone = results[2] as String?;
    final isRestaurantLayout = results[3] == DesktopSalesLayoutMode.restaurant;

    final raw = resume.items.fold<int>(0, (s, e) => s + e.total);
    final total = _resolveGrandTotal(raw, resume);
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
      productRows: ReceiptRowBuilder.fromCartItems(resume.items),
      paymentRows: const [],
      discount: ReceiptRowBuilder.totalDiscountUzs(
        items: resume.items,
        totalAfterDiscount: total,
      ),
      totalSum: total,
      isPrecheck: true,
      isRestaurantLayout: isRestaurantLayout,
      design: design,
    );

    final directOnly = await PrinterSettings.isPrinterReady();
    return ThermalReceiptPrinter.printLocalReceipt(
      widget.toThermalPrintLines(),
      directOnly: directOnly,
      openCashDrawer: false,
    );
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
