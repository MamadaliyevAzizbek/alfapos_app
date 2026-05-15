import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/clients_provider.dart';

/// Yangi mijoz qo'shish — to'liq ekran (YangiTovarScreen uslubida)
class YangiMijozScreen extends StatefulWidget {
  const YangiMijozScreen({super.key});

  @override
  State<YangiMijozScreen> createState() => _YangiMijozScreenState();
}

class _YangiMijozScreenState extends State<YangiMijozScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Telefonni +998 bilan normalizatsiya: "994414001" yoki "99 441 40 01" → "+998994414001"
  static String? _normalizePhone(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('998')) return '+$digits';
    return '+998$digits';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppNotify.info(context, "Ismni kiriting");
      return;
    }
    setState(() => _saving = true);
    try {
      final client = Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: null,
        phone: _normalizePhone(_phoneController.text.trim()),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );
      await ClientsProvider.instance.add(client);
      if (!mounted) return;
      AppNotify.success(context, "Mijoz qo'shildi");
      Navigator.pop(context, client);
    } catch (e) {
      if (mounted) {
        AppNotify.error(context, 'Xatolik: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(Strings.yangiMijoz),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(Strings.saqlash, style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              "Mijoz ma'lumotlarini kiriting",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Ism",
                hintText: "Mijoz ismi",
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: "Telefon raqami",
                hintText: "90 123 45 67",
                prefixIcon: const Icon(Icons.phone_rounded),
                prefixText: "+998 ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: Strings.yashashJoyi,
                hintText: "Manzil",
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 22),
                label: const Text(Strings.saqlash, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
