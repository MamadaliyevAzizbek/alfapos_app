import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../core/input_formatters.dart';
import '../providers/products_provider.dart';
import '../providers/sales_session_provider.dart';
import '../services/api_service.dart';
import '../utils/platform_layout.dart';
import '../widgets/ios_style_modals.dart';
import 'hold_order_cart.dart';
import 'invoice_edit_utils.dart';
import 'pos_navigation.dart';
import '../screens/desktop/desktop_shell.dart';

/// Chekni tahrirlash — sabab, editable-order, POS savatiga yuklash.
class InvoiceEditFlow {
  InvoiceEditFlow._();

  static Future<String?> _askEditReason(BuildContext context) async {
    final ctrl = TextEditingController();
    String? reason;
    try {
      if (isDesktopPosLayout) {
        reason = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Chekni tahrirlash', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tahrirlash sababini kiriting (majburiy). Eski chek bekor qilinadi, yangi chek yaratiladi.',
                    style: TextStyle(fontSize: 14, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Masalan: noto‘g‘ri miqdor kiritilgan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
              FilledButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (t.isEmpty) {
                    AppNotify.warning(ctx, 'Tahrirlash sababi majburiy');
                    return;
                  }
                  Navigator.pop(ctx, t);
                },
                child: const Text('Davom etish'),
              ),
            ],
          ),
        );
      } else {
        reason = await IosStyleModals.showSheet<String>(
          context: context,
          showGrabber: true,
          child: Builder(
            builder: (sheetCtx) => IosStyleModals.sheetKeyboardForm(
              context: sheetCtx,
              saveLabel: 'Davom etish',
              body: const [
                Text(
                  'Chekni tahrirlash',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Tahrirlash sababini kiriting (majburiy). Eski chek bekor qilinadi, yangi chek yaratiladi.',
                  style: TextStyle(fontSize: 14, height: 1.35),
                ),
                SizedBox(height: 12),
              ],
              middle: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Masalan: noto‘g‘ri miqdor kiritilgan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              onCancel: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(sheetCtx);
              },
              onSave: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) {
                  AppNotify.warning(sheetCtx, 'Tahrirlash sababi majburiy');
                  return;
                }
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(sheetCtx, t);
              },
            ),
          ),
        );
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    }
    return reason;
  }

  static Future<bool> startFullEdit(
    BuildContext context,
    Map<String, dynamic> sale, {
    Map<String, dynamic>? invoiceDetail,
    /// Chek batafsil ekranidan chaqirilganda yopiladi; ro‘yxatdan emas.
    bool popCurrentRoute = false,
  }) async {
    final sess = SalesSessionProvider.instance;
    if (!canShowInvoiceEditButton(sale, invoiceDetail: invoiceDetail)) {
      AppNotify.info(context, 'Bu chekni tahrirlash mumkin emas');
      return false;
    }

    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) {
      AppNotify.error(context, 'Chek ID aniqlanmadi');
      return false;
    }

    final reason = await _askEditReason(context);
    if (reason == null || reason.trim().isEmpty || !context.mounted) return false;

    try {
      await sess.ensureSalesSettingsLoaded();
      if (!ProductsProvider.instance.isLoaded) {
        try {
          await ProductsProvider.instance.warmFromCache();
          if (!ProductsProvider.instance.isLoaded) {
            await ProductsProvider.instance.refreshFromServer(force: false);
          }
        } catch (_) {}
      }
      final res = await SalesApi.getEditableOrder(orderId, orderType: 'sales');
      final orderMap = Map<String, dynamic>.from(res['order'] as Map);
      final resume = invoiceEditResumeFromApi(
        res,
        editOrderId: orderId,
        editReason: reason.trim(),
      );
      if (resume == null) {
        if (context.mounted) AppNotify.error(context, 'Chek savati yuklanmadi');
        return false;
      }

      // editable-order: katalog + discount to‘g‘ri; markup yo‘qoladi.
      // invoice-details: total=5000 to‘g‘ri, lekin price ba’zan 6/3/11 (scale) —
      // shuning uchun katalog uchun editable-order asosiy manba.
      var hold = HoldOrderCart.parse(orderMap);
      if ((hold == null || hold.items.isEmpty) && invoiceDetail != null) {
        hold = HoldOrderCart.fromInvoiceDetails(
          Map<String, dynamic>.from(invoiceDetail),
          metaSource: orderMap,
        );
      }
      if (hold == null || hold.items.isEmpty) {
        if (context.mounted) AppNotify.error(context, 'Savat bo‘sh yoki mahsulotlar topilmadi');
        return false;
      }

      // Markup (katalogdan qimmat) yo‘qolgan bo‘lsa — grandTotal farqini qaytarish.
      final grand = resume.grandTotal ?? hold.grandTotal;
      HoldOrderCart.applyGrandTotalSoldPriceCorrection(
        hold.items,
        grand,
        allowAllCatalogMarkup: true,
      );
      assert(() {
        for (final item in hold!.items) {
          // ignore: avoid_print
          print(
            '[invoiceEdit] ${item.product.name} unit=${item.unitPriceForLine} '
            'catalog=${item.defaultLineUnitPrice} locked=${item.priceLocked} '
            'total=${item.total}',
          );
        }
        // ignore: avoid_print
        print(
          '[invoiceEdit] grand=$grand '
          'sum=${hold.items.fold<num>(0, (s, e) => s + e.total)}',
        );
        return true;
      }());

      sess.setPendingInvoiceEdit(resume, hold);
      if (!context.mounted) return true;
      FocusManager.instance.primaryFocus?.unfocus();

      final nav = Navigator.of(context);
      final shouldPop = popCurrentRoute && nav.canPop();
      if (shouldPop) {
        // ApiChekDetailScreen push<bool> bilan ochiladi — faqat bool qaytaramiz.
        nav.pop(true);
      }

      // 1) Sidebar → Sotuv bo‘limi
      // 2) Savatcha ichidagi «cheklar ro‘yxati» yopiladi (PosNavigation signal)
      void jumpToSalesCart() {
        if (isDesktopPosLayout) {
          DesktopShell.goToSalesTab();
        }
        PosNavigation.goToSales();
      }

      jumpToSalesCart();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpToSalesCart();
        Future<void>.delayed(const Duration(milliseconds: 48), jumpToSalesCart);
      });
      return true;
    } on ApiException catch (e) {
      if (context.mounted) AppNotify.error(context, e.message);
      return false;
    } catch (e) {
      if (context.mounted) {
        AppNotify.error(context, 'Tahrirlash xatosi: ${e.toString().replaceFirst('Exception: ', '')}');
      }
      return false;
    }
  }

  static Future<bool> editSaleDate(
    BuildContext context,
    Map<String, dynamic> sale, {
    Map<String, dynamic>? invoiceDetail,
    bool popCurrentRoute = false,
  }) async {
    if (!canShowInvoiceDateEditButton(sale, invoiceDetail: invoiceDetail)) {
      AppNotify.info(context, 'Sana tahrirlash mumkin emas');
      return false;
    }

    final orderId = getOrderIdFromSale(sale);
    if (orderId == null) {
      AppNotify.error(context, 'Chek ID aniqlanmadi');
      return false;
    }

    final dateRaw = sale['date'] ?? sale['created_at'] ?? invoiceDetail?['date'];
    var initial = DateTime.now();
    if (dateRaw != null && dateRaw.toString().isNotEmpty) {
      initial = DateTime.tryParse(dateRaw.toString().replaceFirst(' ', 'T')) ?? initial;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !context.mounted) return false;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !context.mounted) return false;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
      initial.second,
    );
    final formatted =
        '${combined.year}-${combined.month.toString().padLeft(2, '0')}-${combined.day.toString().padLeft(2, '0')} '
        '${combined.hour.toString().padLeft(2, '0')}:${combined.minute.toString().padLeft(2, '0')}:${combined.second.toString().padLeft(2, '0')}';

    try {
      await SalesApi.updateSaleDate(orderId, editedSalesDate: formatted);
      if (context.mounted) {
        AppNotify.success(context, 'Sotish sanasi yangilandi');
        if (popCurrentRoute && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
      return true;
    } on ApiException catch (e) {
      if (context.mounted) AppNotify.error(context, e.message);
      return false;
    } catch (e) {
      if (context.mounted) {
        AppNotify.error(context, 'Sana yangilash xatosi: $e');
      }
      return false;
    }
  }
}
