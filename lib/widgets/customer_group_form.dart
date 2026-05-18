import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../utils/customer_groups_list.dart';
import '../utils/platform_layout.dart';
import 'ios_style_modals.dart';

class CustomerGroupFormData {
  const CustomerGroupFormData({
    required this.title,
    required this.discount,
    required this.isDefault,
  });

  final String title;
  final num discount;
  final bool isDefault;
}

/// Mijoz guruhi qo'shish / tahrirlash — POST groups/store, POST groups/{id}.
class CustomerGroupFormBody extends StatefulWidget {
  const CustomerGroupFormBody({
    super.key,
    this.groupId,
    this.initialTitle = '',
    this.initialDiscount = 0,
    this.initialIsDefault = false,
    this.embedded = false,
  });

  final int? groupId;
  final String initialTitle;
  final num initialDiscount;
  final bool initialIsDefault;
  final bool embedded;

  @override
  State<CustomerGroupFormBody> createState() => _CustomerGroupFormBodyState();
}

class _CustomerGroupFormBodyState extends State<CustomerGroupFormBody> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _discountCtrl;
  late bool _isDefault;
  bool _saving = false;

  bool get _isEdit => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _discountCtrl = TextEditingController(
      text: widget.initialDiscount == widget.initialDiscount.round()
          ? widget.initialDiscount.round().toString()
          : widget.initialDiscount.toString(),
    );
    _isDefault = widget.initialIsDefault;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  CustomerGroupFormData? _readForm() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppNotify.info(context, 'Guruh nomini kiriting');
      return null;
    }
    var discountRaw = _discountCtrl.text.trim().replaceAll(' ', '');
    if (discountRaw.startsWith('+')) discountRaw = discountRaw.substring(1);
    final discount = num.tryParse(discountRaw) ?? 0;
    if (discount < -100 || discount > 500) {
      AppNotify.info(context, 'Foiz −100 dan +500 gacha (− chegirma, + ustiga qo\'shish)');
      return null;
    }
    return CustomerGroupFormData(title: title, discount: discount, isDefault: _isDefault);
  }

  Future<void> _save() async {
    final data = _readForm();
    if (data == null || _saving) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ContactsApi.updateCustomerGroup(
          widget.groupId!,
          title: data.title,
          discount: data.discount,
          isDefault: data.isDefault,
        );
      } else {
        await ContactsApi.storeCustomerGroup(
          title: data.title,
          discount: data.discount,
          isDefault: data.isDefault,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, data);
    } catch (e) {
      if (mounted) AppNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      TextField(
        controller: _titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: _decoration('Guruh nomi'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _discountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-+,\s]'))],
        decoration: _decoration('Foiz', suffix: '%', hint: '− chegirma, + qo\'shish'),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Standart guruh'),
        subtitle: const Text(
          'Yangi mijozlar uchun avtomatik tanlanadi',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        value: _isDefault,
        onChanged: _saving ? null : (v) => setState(() => _isDefault = v),
      ),
    ];

    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Text(
              _isEdit ? 'Guruhni tahrirlash' : 'Yangi mijoz guruhi',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: fields),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: AppModals.sheetPillCancelSaveRow(
              onCancel: () => Navigator.pop(context),
              onSave: _saving ? () {} : _save,
              saveLabel: _saving ? 'Saqlanmoqda...' : Strings.saqlash,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Guruhni tahrirlash' : 'Yangi mijoz guruhi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...fields,
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text(Strings.bekorQilish),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '...' : Strings.saqlash),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? suffix, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
    );
  }
}

Future<CustomerGroupFormData?> showCustomerGroupForm(
  BuildContext context, {
  int? groupId,
}) async {
  Map<String, dynamic>? initial;
  if (groupId != null) {
    try {
      final res = await ContactsApi.getCustomerGroup(groupId);
      initial = CustomerGroupsListParser.unwrapGroupPayload(res);
    } catch (_) {}
  }

  final title = initial != null ? CustomerGroupsListParser.groupTitle(initial) : '';
  final discount = initial != null ? CustomerGroupsListParser.groupDiscount(initial) : 0;
  final isDefault = initial != null ? CustomerGroupsListParser.groupIsDefault(initial) : false;

  if (isDesktopPosLayout) {
    return AppModals.showPopupPanel<CustomerGroupFormData>(
      context: context,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 480,
        child: CustomerGroupFormBody(
          groupId: groupId,
          initialTitle: title,
          initialDiscount: discount,
          initialIsDefault: isDefault,
          embedded: true,
        ),
      ),
    );
  }

  return showModalBottomSheet<CustomerGroupFormData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: CustomerGroupFormBody(
        groupId: groupId,
        initialTitle: title,
        initialDiscount: discount,
        initialIsDefault: isDefault,
      ),
    ),
  );
}
