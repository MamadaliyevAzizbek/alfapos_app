import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/app_notify.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../utils/platform_layout.dart';
import '../widgets/app_dropdown.dart';

/// Yangi xarajat — mobil: to‘liq ekran; desktop: dialog (dropdown, bottom sheet emas).
class XarajatQoshishScreen extends StatefulWidget {
  /// Dialog ichida: AppBar o‘rniga sarlavha + yopish.
  final bool embedded;

  const XarajatQoshishScreen({super.key, this.embedded = false});

  @override
  State<XarajatQoshishScreen> createState() => _XarajatQoshishScreenState();
}

class _XarajatQoshishScreenState extends State<XarajatQoshishScreen> {
  final _expenses = ExpensesProvider.instance;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _paymentTypeId;
  int? _expenseCategoryId;
  bool _saving = false;
  String? _error;

  bool get _desktopUi => widget.embedded || isDesktopPosLayout;

  @override
  void initState() {
    super.initState();
    final pt = _expenses.paymentTypes;
    final ec = _expenses.expenseCategories;
    if (pt.isNotEmpty) {
      _paymentTypeId = _parseId(pt.first);
    }
    if (ec.isNotEmpty) {
      _expenseCategoryId = _parseId(ec.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static int? _parseId(Map<String, dynamic> item) {
    final id = item['id'] ?? item['expense_category_id'] ?? item['payment_type_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static String _itemLabel(Map<String, dynamic> item) =>
      (item['name'] ?? item['title'] ?? '').toString();

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_desktopUi ? 10 : 14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_desktopUi ? 10 : 14),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_desktopUi ? 10 : 14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = parseFormattedSum(_amountController.text) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Xarajat nomini kiriting');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Summani kiriting');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final expense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        name: name,
        amountUzs: amount,
      );
      await _expenses.addExpense(
        expense,
        paymentTypeId: _paymentTypeId,
        expenseCategoryId: _expenseCategoryId,
      );
      if (!mounted) return;
      AppNotify.success(context, "$name — $amount so'm qo'shildi");
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  Widget _buildForm() {
    final paymentTypes = _expenses.paymentTypes;
    final expenseCategories = _expenses.expenseCategories;
    final categoryIds = expenseCategories.map(_parseId).whereType<int>().toSet();
    final paymentIds = paymentTypes.map(_parseId).whereType<int>().toSet();
    final categoryValue =
        _expenseCategoryId != null && categoryIds.contains(_expenseCategoryId) ? _expenseCategoryId : null;
    final paymentValue =
        _paymentTypeId != null && paymentIds.contains(_paymentTypeId) ? _paymentTypeId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: _fieldDecoration('Sana'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          decoration: _fieldDecoration(Strings.xarajatNomi).copyWith(
            hintText: 'Masalan: Ijara, elektr',
          ),
          autofocus: true,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: _fieldDecoration(Strings.xarajatNarxi),
        ),
        if (expenseCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppDropdownField<int>(
            label: 'Xarajat kategoriyasi',
            value: categoryValue,
            items: expenseCategories
                .map((c) {
                  final id = _parseId(c);
                  if (id == null) return null;
                  return appDropdownItem(value: id, label: _itemLabel(c));
                })
                .whereType<DropdownMenuItem<int>>()
                .toList(),
            onChanged: (v) => setState(() => _expenseCategoryId = v),
          ),
        ],
        if (paymentTypes.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppDropdownField<int>(
            label: "To'lov turi",
            value: paymentValue,
            items: paymentTypes
                .map((c) {
                  final id = _parseId(c);
                  if (id == null) return null;
                  return appDropdownItem(value: id, label: _itemLabel(c));
                })
                .whereType<DropdownMenuItem<int>>()
                .toList(),
            onChanged: (v) => setState(() => _paymentTypeId = v),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: TextStyle(fontSize: 13, color: Colors.red.shade900)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (_desktopUi)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Bekor qilish'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(140, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(Strings.saqlash),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(Strings.saqlash),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_desktopUi) {
      return Material(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      Strings.yangiXarajat,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yopish',
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.yangiXarajat),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildForm(),
      ),
    );
  }
}
