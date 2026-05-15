import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/app_notify.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../widgets/ios_style_modals.dart';

/// Yangi xarajat qo'shish — alohida ekran. API dan paymentTypes va expenseCategories ishlatiladi.
class XarajatQoshishScreen extends StatefulWidget {
  const XarajatQoshishScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final pt = _expenses.paymentTypes;
    final ec = _expenses.expenseCategories;
    if (pt.isNotEmpty) {
      final id = pt.first['id'];
      _paymentTypeId = id is int ? id : int.tryParse(id?.toString() ?? '');
    }
    if (ec.isNotEmpty) {
      final id = ec.first['id'];
      _expenseCategoryId = id is int ? id : int.tryParse(id?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static int? _firstId(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    final id = list.first['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _labelById(List<Map<String, dynamic>> items, int? id, String fallback) {
    if (id == null) return fallback;
    for (final item in items) {
      final rawId = item['id'] ?? item['expense_category_id'] ?? item['payment_type_id'];
      final parsed = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (parsed == id) return (item['name'] ?? fallback).toString();
    }
    return fallback;
  }

  Future<void> _showPickerSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required int? selectedId,
    required ValueChanged<int> onSelected,
  }) async {
    await AppModals.showSheet<void>(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetCtx) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 260,
              maxHeight: 420,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      final rawId = item['id'] ?? item['expense_category_id'] ?? item['payment_type_id'];
                      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
                      final name = (item['name'] ?? '').toString();
                      final selected = id != null && id == selectedId;
                      return ListTile(
                        onTap: id == null
                            ? null
                            : () {
                                onSelected(id);
                                Navigator.pop(sheetCtx);
                              },
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: selected ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = parseFormattedSum(_amountController.text) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = "Xarajat nomini kiriting");
      return;
    }
    if (amount <= 0) {
      setState(() => _error = "Summani kiriting");
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

  @override
  Widget build(BuildContext context) {
    final paymentTypes = _expenses.paymentTypes;
    final expenseCategories = _expenses.expenseCategories;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sana
            Text(
              'Sana: ${_formatDate(_selectedDate)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              label: const Text("Sana tanlash"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: Strings.xarajatNomi,
                hintText: "Masalan: Ijara, elektr",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: Strings.xarajatNarxi,
                border: OutlineInputBorder(),
              ),
            ),
            if (expenseCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showPickerSheet(
                  title: "Xarajat kategoriyasi",
                  items: expenseCategories,
                  selectedId: _expenseCategoryId ?? _firstId(expenseCategories),
                  onSelected: (v) => setState(() => _expenseCategoryId = v),
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Xarajat kategoriyasi",
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labelById(expenseCategories, _expenseCategoryId ?? _firstId(expenseCategories), "Tanlanmagan"),
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
            if (paymentTypes.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showPickerSheet(
                  title: "To'lov turi",
                  items: paymentTypes,
                  selectedId: _paymentTypeId ?? _firstId(paymentTypes),
                  onSelected: (v) => setState(() => _paymentTypeId = v),
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "To'lov turi",
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labelById(paymentTypes, _paymentTypeId ?? _firstId(paymentTypes), "Tanlanmagan"),
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
        ),
      ),
    );
  }
}
