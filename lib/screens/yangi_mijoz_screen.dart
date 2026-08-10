import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/clients_provider.dart';
import '../services/api_service.dart';
import '../utils/customer_store_body.dart';
import '../utils/platform_layout.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/ios_style_modals.dart';
import '../widgets/pos_editable_focus_scope.dart';

/// Yangi mijoz — POST /contacts/customers/store
class YangiMijozScreen extends StatelessWidget {
  const YangiMijozScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.yangiMijoz),
      ),
      body: const YangiMijozFormBody(),
    );
  }
}

/// Desktop: [showYangiMijozDialog] / [showMijozTahrirlashDialog]. Mobil: [YangiMijozScreen].
class YangiMijozFormBody extends StatefulWidget {
  const YangiMijozFormBody({
    super.key,
    this.embedded = false,
    this.editClient,
  });

  final bool embedded;
  final Client? editClient;

  bool get isEdit => editClient != null;

  @override
  State<YangiMijozFormBody> createState() => _YangiMijozFormBodyState();
}

class _YangiMijozFormBodyState extends State<YangiMijozFormBody> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;
  bool _loadingGroups = true;
  List<Map<String, dynamic>> _groups = [];
  int? _selectedGroupId;
  String? _selectedPriceType;
  List<({String value, String label})> _priceTypeOptions = CustomerStoreBody.defaultPriceTypeOptions;

  bool get _desktop => isDesktopPosLayout || widget.embedded;

  double get _fieldFont => _desktop ? 15 : 14;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    List<Map<String, dynamic>> g = [];
    try {
      final res = await ContactsApi.getCustomerFormOptions();
      _priceTypeOptions = CustomerStoreBody.parsePriceTypeOptions(res);
    } catch (_) {
      try {
        final res = await ContactsApi.getCustomerGroups();
        _priceTypeOptions = CustomerStoreBody.parsePriceTypeOptions(res);
      } catch (_) {}
    }
    try {
      g = await ClientsProvider.instance.fetchCustomerGroups();
    } catch (_) {}

    Client? source = widget.editClient;
    if (widget.isEdit && source != null) {
      final idNum = int.tryParse(source.id);
      if (idNum != null) {
        try {
          final res = await ContactsApi.getCustomer(idNum);
          final raw = res['customer'] ?? res['data'] ?? res;
          if (raw is Map) {
            source = Client.fromApiJson(Map<String, dynamic>.from(raw));
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _groups = g;
      if (source != null) {
        _nameController.text = source.name;
        _phoneController.text = _phoneForField(source.phone);
        _addressController.text = source.address ?? '';
        _selectedGroupId = source.customerGroupId;
        _selectedPriceType = source.customerGroupDiscountPriceType;
      }
      if (_selectedGroupId == null && g.isNotEmpty) {
        _selectedGroupId = _groupIdFrom(g.first);
      }
      if (_selectedPriceType == null || _selectedPriceType!.isEmpty) {
        final grp = _groupById(_selectedGroupId);
        if (grp != null) {
          _selectedPriceType = CustomerStoreBody.priceTypeFromGroup(grp);
        }
      }
      if (_selectedPriceType == null || _selectedPriceType!.isEmpty) {
        _selectedPriceType = _priceTypeOptions.first.value;
      }
      _loadingGroups = false;
    });
  }

  static String _phoneForField(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    var s = phone.trim();
    if (s.startsWith('+998')) s = s.substring(4);
    else if (s.startsWith('998') && s.length > 9) s = s.substring(3);
    return s.replaceAll(RegExp(r'\D'), '');
  }

  Map<String, dynamic>? _groupById(int? id) {
    if (id == null) return null;
    for (final g in _groups) {
      if (_groupIdFrom(g) == id) return g;
    }
    return null;
  }

  static int _groupIdFrom(Map<String, dynamic> g) {
    final id = g['id'] ?? g['value'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 1;
  }

  static String _groupTitle(Map<String, dynamic> g) {
    return (g['title'] ?? g['name'] ?? g['text'] ?? 'Guruh ${g['id']}').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  static String? _normalizePhone(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('998')) return '+$digits';
    if (digits.length == 9) return '+998$digits';
    return '+998$digits';
  }

  InputDecoration _fieldDecoration(String label, {Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefix: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: _desktop ? 18 : 14),
      labelStyle: TextStyle(fontSize: _fieldFont),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotify.info(context, 'Ismni kiriting');
      return;
    }
    if (_selectedGroupId == null) {
      AppNotify.info(context, 'Mijoz guruhini tanlang');
      return;
    }
    if (_selectedPriceType == null || _selectedPriceType!.isEmpty) {
      AppNotify.info(context, 'Guruh foizi qaysi narx asosida — tanlang');
      return;
    }

    setState(() => _saving = true);
    try {
      final phone = _normalizePhone(_phoneController.text.trim());
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();

      if (widget.isEdit) {
        final existing = widget.editClient!;
        final updated = Client(
          id: existing.id,
          name: name,
          email: existing.email,
          phone: phone,
          address: address,
          dueAmount: existing.dueAmount,
          balance: existing.balance,
          customerGroupId: _selectedGroupId,
          customerGroupName: _groupTitle(_groupById(_selectedGroupId) ?? {}),
          customerGroupDiscount: existing.customerGroupDiscount,
          customerGroupDiscountPriceType: _selectedPriceType,
          supplierName: existing.supplierName,
          supplierId: existing.supplierId,
        );
        await ClientsProvider.instance.updateClient(
          updated,
          groupDiscountPriceType: _selectedPriceType,
        );
        if (!mounted) return;
        AppNotify.success(context, 'Mijoz yangilandi');
        Navigator.pop(context, updated);
      } else {
        final client = Client(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          phone: phone,
          address: address,
          customerGroupId: _selectedGroupId,
          customerGroupDiscountPriceType: _selectedPriceType,
        );
        final saved = await ClientsProvider.instance.add(
          client,
          groupDiscountPriceType: _selectedPriceType,
        );
        if (!mounted) return;
        AppNotify.success(context, "Mijoz qo'shildi");
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        AppNotify.error(
          context,
          msg.contains('Server Error') || msg.contains('500')
              ? 'Server xatosi. Guruh va narx turini tekshiring yoki keyinroq urinib ko\'ring.'
              : 'Xatolik: $msg',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _formTitle =>
      widget.isEdit ? 'Mijozni tahrirlash' : "Yangi Mijoz qo'shish";

  @override
  Widget build(BuildContext context) {
    final form = _loadingGroups
        ? const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              _desktop ? 28 : 16,
              _desktop ? 8 : 16,
              _desktop ? 28 : 16,
              _desktop ? 8 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.embedded) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formTitle,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F0FE),
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _twoCol(
                  TextField(
                    controller: _nameController,
                    style: TextStyle(fontSize: _fieldFont),
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration('Ism'),
                  ),
                  TextField(
                    controller: _phoneController,
                    style: TextStyle(fontSize: _fieldFont),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
                    ],
                    decoration: _fieldDecoration(
                      'Telefon raqami',
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇺🇿', style: TextStyle(fontSize: _desktop ? 20 : 18)),
                            const SizedBox(width: 6),
                            Text('+998', style: TextStyle(fontSize: _fieldFont, fontWeight: FontWeight.w600)),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 22),
                            Container(
                              width: 1,
                              height: 24,
                              margin: const EdgeInsets.only(left: 8),
                              color: AppTheme.divider,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: _desktop ? 16 : 12),
                _twoCol(
                  TextField(
                    controller: _addressController,
                    style: TextStyle(fontSize: _fieldFont),
                    decoration: _fieldDecoration('Manzil'),
                  ),
                  AppDropdownField<int>(
                    label: 'Mijoz guruh',
                    value: _selectedGroupId,
                    items: _groups
                        .map(
                          (g) => appDropdownItem(
                            value: _groupIdFrom(g),
                            label: _groupTitle(g),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedGroupId = v;
                        final grp = _groupById(v);
                        if (grp != null) {
                          final fromGroup = CustomerStoreBody.priceTypeFromGroup(grp);
                          if (fromGroup != null) _selectedPriceType = fromGroup;
                        }
                      });
                    },
                  ),
                ),
                SizedBox(height: _desktop ? 16 : 12),
                AppDropdownField<String>(
                  label: 'Guruh foizi qaysi narx asosida',
                  hint: 'Tanlang',
                  value: _priceTypeOptions.any((o) => o.value == _selectedPriceType)
                      ? _selectedPriceType
                      : null,
                  items: _priceTypeOptions
                      .map((o) => appDropdownItem(value: o.value, label: o.label))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPriceType = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Savdoda mijoz tanlanganda shu narx ustidan guruh foizi qo\'llanadi (sotish / kelish / ulgurji).',
                  style: TextStyle(
                    fontSize: _desktop ? 13 : 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: _desktop ? 24 : 20),
                if (widget.embedded)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: const Text(Strings.bekorQilish, style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(Strings.saqlash, style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(Strings.saqlash),
                    ),
                  ),
              ],
            ),
          );

    return PosEditableFocusScope(child: form);
  }

  Widget _twoCol(Widget left, Widget right) {
    if (!_desktop) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

/// Desktop — yangi mijoz.
Future<Client?> showYangiMijozDialog(BuildContext context) {
  return AppModals.showPopupPanel<Client>(
    context: context,
    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
    child: const SizedBox(
      width: 720,
      child: YangiMijozFormBody(embedded: true),
    ),
  );
}

/// Desktop / mobil — mijoz tahrirlash (qo‘shish formasi bilan bir xil maydonlar).
Future<Client?> showMijozTahrirlashDialog(BuildContext context, {required Client client}) {
  if (isDesktopPosLayout) {
    return AppModals.showPopupPanel<Client>(
      context: context,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 720,
        child: YangiMijozFormBody(embedded: true, editClient: client),
      ),
    );
  }
  return Navigator.of(context).push<Client>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Mijozni tahrirlash'),
        ),
        body: YangiMijozFormBody(editClient: client),
      ),
    ),
  );
}
