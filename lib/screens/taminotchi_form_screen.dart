import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';

/// Yangi / tahrirlash — POST store yoki POST /contacts/suppliers/{id}.
class TaminotchiFormScreen extends StatefulWidget {
  const TaminotchiFormScreen({super.key, this.supplier});

  final Supplier? supplier;

  bool get isEdit => supplier != null;

  @override
  State<TaminotchiFormScreen> createState() => _TaminotchiFormScreenState();
}

class _TaminotchiFormScreenState extends State<TaminotchiFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _tinCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameCtrl.text = s.firstName.trim().isNotEmpty ? s.name : s.firstName;
      _phoneCtrl.text = _phoneForField(s.phone);
      _companyCtrl.text = s.company ?? '';
      _emailCtrl.text = s.email ?? '';
      _tinCtrl.text = s.tinNumber ?? '';
      _addressCtrl.text = s.address ?? '';
      _descCtrl.text = s.description ?? '';
      _loadEditData(s.id);
    }
  }

  Future<void> _loadEditData(int id) async {
    setState(() => _loading = true);
    try {
      final res = await ContactsApi.getSupplier(id);
      final loaded = Supplier.fromResponse(res);
      if (loaded != null && mounted) {
        _nameCtrl.text =
            loaded.firstName.trim().isNotEmpty ? loaded.name : loaded.firstName;
        _phoneCtrl.text = _phoneForField(loaded.phone);
        _companyCtrl.text = loaded.company ?? '';
        _emailCtrl.text = loaded.email ?? '';
        _tinCtrl.text = loaded.tinNumber ?? '';
        _addressCtrl.text = loaded.address ?? '';
        _descCtrl.text = loaded.description ?? '';
      }
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _phoneForField(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    var s = phone.trim();
    if (s.startsWith('+998')) {
      s = s.substring(4);
    } else if (s.startsWith('998') && s.length > 9) {
      s = s.substring(3);
    }
    return s.replaceAll(RegExp(r'\D'), '');
  }

  static String? _normalizePhone(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('998')) return '+$digits';
    if (digits.length == 9) return '+998$digits';
    return '+998$digits';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _tinCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefix: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppNotify.info(context, 'Ismni kiriting');
      return;
    }

    setState(() => _saving = true);
    try {
      final phone = _normalizePhone(_phoneCtrl.text.trim());
      final body = <String, dynamic>{
        'first_name': name,
        if (phone != null) 'phone_number': phone,
        if (_companyCtrl.text.trim().isNotEmpty)
          'company': _companyCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_tinCtrl.text.trim().isNotEmpty) 'tin_number': _tinCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
      };

      if (widget.isEdit) {
        await ContactsApi.updateSupplier(widget.supplier!.id, body);
        if (!mounted) return;
        AppNotify.success(context, 'Taminotchi yangilandi');
      } else {
        await ContactsApi.storeSupplier(body);
        if (!mounted) return;
        AppNotify.success(context, 'Taminotchi qo‘shildi');
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEdit ? 'Taminotchini tahrirlash' : Strings.yangiTaminotchi,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Ism *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: _decoration(
                    'Telefon',
                    prefix: const Text(
                      '+998 ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Kompaniya'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tinCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('STIR (TIN)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Manzil'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: _decoration('Izoh'),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving || _loading ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEdit ? Strings.saqlash : 'Qo‘shish'),
          ),
        ),
      ),
    );
  }
}
