import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/input_formatters.dart';
import '../core/theme.dart';
import '../models/receive_supplier.dart';
import '../providers/receive_session_provider.dart';
import '../services/api_service.dart';
import '../services/receive_draft_storage.dart';
import '../utils/receive_payment_types.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/ios_style_modals.dart';

class KirimYakunlashScreen extends StatefulWidget {
  const KirimYakunlashScreen({super.key});

  @override
  State<KirimYakunlashScreen> createState() => _KirimYakunlashScreenState();
}

class _KirimYakunlashScreenState extends State<KirimYakunlashScreen> {
  final _session = ReceiveSessionProvider.instance;
  final _commentCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commentCtrl.text = _session.comment;
    if (_session.deliveryCostUzs > 0) {
      _deliveryCtrl.text = formatThousands(_session.deliveryCostUzs);
    }
    if (!_session.isReady) {
      _session.loadInit().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _session.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) _session.setDate(d);
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    _session.setComment(_commentCtrl.text);
    _session.setDeliveryCost(parseFormattedSum(_deliveryCtrl.text) ?? 0);
    if (_session.selectedSupplier == null) {
      AppNotify.info(context, 'Yetkazib beruvchini tanlang');
      return;
    }
    setState(() => _submitting = true);
    final draftId = _session.activeDraftId;
    final branchId = _session.branchId ?? 1;
    try {
      final res = await _session.submitReceive();
      if (draftId != null) {
        await ReceiveDraftStorage.deleteDraft(branchId, draftId);
      }
      if (!mounted) return;
      final msg = (res['message'] ?? '').toString();
      AppNotify.success(context, msg.isNotEmpty ? msg : 'Kirim saqlandi');
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Xatolik: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final total = _session.cartTotalUzs;
    final suppliers = _session.suppliers;
    final payments = _session.paymentTypes;
    final selectedPayId = _session.selectedPaymentType != null
        ? ReceivePaymentTypes.idOf(_session.selectedPaymentType!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Kirimni yakunlash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Jami: ${formatThousands(total)} so\'m',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          AppDropdownField<int>(
            label: 'Yetkazib beruvchi *',
            value: _session.selectedSupplier?.id,
            items: suppliers
                .map((s) => appDropdownItem(value: s.id, label: s.name))
                .toList(),
            onChanged: (id) {
              ReceiveSupplier? picked;
              for (final s in suppliers) {
                if (s.id == id) {
                  picked = s;
                  break;
                }
              }
              _session.setSupplier(picked);
              setState(() {});
            },
          ),
          TextButton.icon(
            onPressed: _addSupplier,
            icon: const Icon(Icons.add),
            label: const Text('Yangi taminotchi'),
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            label: 'To\'lov turi *',
            value: selectedPayId,
            items: payments
                .map((e) {
                  final id = ReceivePaymentTypes.idOf(e);
                  if (id == null) return null;
                  return appDropdownItem(
                    value: id,
                    label: ReceivePaymentTypes.labelOf(e),
                  );
                })
                .whereType<DropdownMenuItem<int>>()
                .toList(),
            onChanged: (id) {
              Map<String, dynamic>? picked;
              for (final e in payments) {
                if (ReceivePaymentTypes.idOf(e) == id) {
                  picked = e;
                  break;
                }
              }
              _session.setPaymentType(picked);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sana'),
            subtitle: Text(
              '${_session.selectedDate.day.toString().padLeft(2, '0')}.'
              '${_session.selectedDate.month.toString().padLeft(2, '0')}.'
              '${_session.selectedDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Izoh',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Kelish xarajati (so\'m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Tasdiqlash va saqlash'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSupplier() async {
    final firstCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await IosStyleModals.showSheet<bool>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: Builder(
        builder: (ctx) => IosStyleModals.sheetKeyboardForm(
          context: ctx,
          onCancel: () => Navigator.pop(ctx, false),
          onSave: () => Navigator.pop(ctx, true),
          cancelLabel: Strings.bekorQilish,
          saveLabel: Strings.saqlash,
          body: [
            const Text('Yangi taminotchi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: firstCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ism', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) {
      firstCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }
    try {
      final res = await ContactsApi.storeSupplier({
        'first_name': firstCtrl.text.trim(),
        'phone_number': phoneCtrl.text.trim(),
      });
      firstCtrl.dispose();
      phoneCtrl.dispose();
      final sup = res['supplier'];
      if (sup is Map) {
        final s = ReceiveSupplier.fromJson(Map<String, dynamic>.from(sup));
        if (s != null) {
          _session.suppliers = [..._session.suppliers, s];
          _session.setSupplier(s);
          setState(() {});
          AppNotify.success(context, 'Taminotchi qo\'shildi');
          return;
        }
      }
      await _session.loadInit();
      setState(() {});
    } catch (e) {
      if (mounted) AppNotify.error(context, '$e');
    }
  }
}
