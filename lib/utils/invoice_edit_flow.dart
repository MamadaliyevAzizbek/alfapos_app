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

/// Chekni tahrirlash — sabab, editable-order, POS savatiga yuklash.
class InvoiceEditFlow {
  InvoiceEditFlow._();

  static Future<String?> _askEditReason(BuildContext context) async {
    final ctrl = TextEditingController();
    final content = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chekni tahrirlash',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 14),
          Builder(
            builder: (ctx) => IosStyleModals.sheetPillCancelSaveRow(
              cancelLabel: 'Bekor qilish',
              saveLabel: 'Davom etish',
              onCancel: () => Navigator.pop(ctx),
              onSave: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) {
                  AppNotify.warning(ctx, 'Tahrirlash sababi majburiy');
                  return;
                }
                Navigator.pop(ctx, t);
              },
            ),
          ),
        ],
      ),
    );

    final String? reason;
    if (isDesktopPosLayout) {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(width: 440, child: content),
        ),
      );
    } else {
      reason = await IosStyleModals.showSheet<String>(
        context: context,
        showGrabber: true,
        child: content,
      );
    }
    ctrl.dispose();
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
          await ProductsProvider.instance.loadFromApi();
        } catch (_) {}
      }
      final res = await SalesApi.getEditableOrder(orderId, orderType: 'sales');
      final resume = invoiceEditResumeFromApi(
        res,
        editOrderId: orderId,
        editReason: reason.trim(),
      );
      if (resume == null) {
        if (context.mounted) AppNotify.error(context, 'Chek savati yuklanmadi');
        return false;
      }

      final hold = HoldOrderCart.parse(Map<String, dynamic>.from(res['order'] as Map));
      if (hold == null || hold.items.isEmpty) {
        if (context.mounted) AppNotify.error(context, 'Savat bo‘sh yoki mahsulotlar topilmadi');
        return false;
      }

      sess.setPendingInvoiceEdit(resume, hold);
      if (!context.mounted) return true;
      if (popCurrentRoute && Navigator.canPop(context)) {
        Navigator.pop(context, 'invoice_edit');
      }
      PosNavigation.openSalesSection?.call();
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
