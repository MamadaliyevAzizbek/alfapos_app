import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../providers/cash_register_shift_provider.dart';
import '../../services/api_service.dart';
import '../../utils/cash_register_utils.dart';
import '../../utils/platform_layout.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/pos_editable_focus_scope.dart';
import '../../widgets/sales_customer_search.dart';
import '../../providers/clients_provider.dart';
import '../../utils/quick_cash_form_loader.dart';

Future<void> showQuickIncomeDialog(BuildContext context) async {
  await _showQuickCash(context, isIncome: true);
}

Future<void> showQuickExpenseDialog(BuildContext context) async {
  await _showQuickCash(context, isIncome: false);
}

Future<void> _showQuickCash(BuildContext context, {required bool isIncome}) async {
  if (isDesktopPosLayout) {
    await showDialog<void>(
      context: context,
      builder: (_) => _QuickCashDialog(isIncome: isIncome),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _QuickCashScreen(isIncome: isIncome),
      ),
    );
  }
}

class _QuickCashDialog extends StatelessWidget {
  final bool isIncome;

  const _QuickCashDialog({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: PosEditableFocusScope(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _QuickCashForm(isIncome: isIncome, onClose: () => Navigator.pop(context)),
          ),
        ),
      ),
    );
  }
}

class _QuickCashScreen extends StatelessWidget {
  final bool isIncome;

  const _QuickCashScreen({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? 'Tezkor kirim' : 'Tezkor chiqim'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _QuickCashForm(isIncome: isIncome, onClose: () => Navigator.pop(context)),
        ),
      ),
    );
  }
}

class _QuickCashForm extends StatefulWidget {
  final bool isIncome;
  final VoidCallback onClose;

  const _QuickCashForm({required this.isIncome, required this.onClose});

  @override
  State<_QuickCashForm> createState() => _QuickCashFormState();
}

class _QuickCashFormState extends State<_QuickCashForm> {
  final _shift = CashRegisterShiftProvider.instance;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _paymentTypes = [];
  List<Map<String, dynamic>> _categories = [];
  int? _paymentTypeId;
  int? _categoryId;
  Client? _customer;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    try {
      final data = await QuickCashFormLoader.load(isIncome: widget.isIncome);
      _paymentTypes = data.paymentTypes;
      _categories = data.categories;
      _paymentTypeId = _paymentTypes.isNotEmpty ? dropdownId(_paymentTypes.first) : null;
      _categoryId = _categories.isNotEmpty ? dropdownId(_categories.first) : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final logId = _shift.registerLogId;
    if (logId == null) return;
    final price = parseFormattedSum(_amountController.text);
    if (price == null || price <= 0) {
      AppNotify.info(context, 'Summani kiriting');
      return;
    }
    if (_paymentTypeId == null) {
      AppNotify.info(context, "To'lov turini tanlang");
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'price': price,
        'payment_type_id': _paymentTypeId,
        'cash_register_log_id': logId,
        if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
        if (_categoryId != null)
          widget.isIncome ? 'income_category_id' : 'expense_category_id': _categoryId,
        if (_customer != null) 'customer_id': int.tryParse(_customer!.id),
      };
      if (widget.isIncome) {
        await IncomesApi.createIncome(body);
      } else {
        await ExpensesApi.createExpense(body);
      }
      unawaited(_shift.loadShiftDetail());
      if (mounted) {
        AppNotify.success(context, 'Saqlandi');
        widget.onClose();
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncome ? 'Tezkor kirim' : 'Tezkor chiqim';
    final subtitle = widget.isIncome
        ? 'Kassaga kirimni tez qayd eting'
        : 'Kassadan chiqimni tez qayd eting';
    final logId = _shift.registerLogId;
    final desktop = isDesktopPosLayout;

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Narxi',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AppDropdownField<int>(
          label: 'Kategoriya',
          value: _categoryId,
          icon: _loading && _categories.isEmpty
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  ),
                )
              : null,
          items: _categories
              .map((c) {
                final id = dropdownId(c);
                if (id == null) return null;
                return appDropdownItem(value: id, label: dropdownLabel(c));
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
        AppDropdownField<int>(
          label: "To'lov turlari *",
          value: _paymentTypeId,
          icon: _loading && _paymentTypes.isEmpty
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  ),
                )
              : null,
          items: _paymentTypes
              .map((c) {
                final id = dropdownId(c);
                if (id == null) return null;
                return appDropdownItem(value: id, label: dropdownLabel(c));
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (v) => setState(() => _paymentTypeId = v),
        ),
        const SizedBox(height: 12),
        const Text('Mijoz (ixtiyoriy)', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          widget.isIncome
              ? 'Tanlansa, summa avval mijoz qarzidan yechiladi, qolgani balansga yoziladi.'
              : "Tanlansa, summa mijozning Qarz bo'limida qarz sifatida yoziladi.",
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        SalesCustomerSearch(
          selected: _customer,
          onSelected: (c) => setState(() => _customer = c),
          onAddNew: () {},
          largeButtons: desktop,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Izoh',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );

    final actions = desktop
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : widget.onClose,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(150, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Bekor qilish'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Saqlash'),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _saving ? null : widget.onClose, child: const Text('Bekor qilish')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Saqlash'),
              ),
            ],
          );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kassa: ${_shift.cashRegisterTitle}${logId != null ? ' — Smena #$logId' : ''}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: fields)),
          const SizedBox(height: 12),
          actions,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    'Kassa: ${_shift.cashRegisterTitle}${logId != null ? ' — Smena #$logId' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(child: fields)),
        const SizedBox(height: 16),
        actions,
      ],
    );
  }
}
