import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../providers/categories_provider.dart';
import 'ios_style_modals.dart';

/// Yangi kategoriya — bitta saqlash, fon rejimida ro‘yxat yangilanadi.
class AddCategorySheet {
  AddCategorySheet._();

  /// Muvaffaqiyatda qo‘shilgan kategoriya nomi; bekor / xato — null.
  static Future<String?> show(BuildContext context) {
    return IosStyleModals.showSheet<String>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: const _AddCategorySheetBody(),
    );
  }
}

class _AddCategorySheetBody extends StatefulWidget {
  const _AddCategorySheetBody();

  @override
  State<_AddCategorySheetBody> createState() => _AddCategorySheetBodyState();
}

class _AddCategorySheetBodyState extends State<_AddCategorySheetBody> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final added = await CategoriesProvider.instance.addCategory(name);
      if (!mounted) return;
      if (added) {
        Navigator.pop(context, name);
        return;
      }
      AppNotify.info(context, 'Bu kategoriya allaqachon mavjud yoki qo‘shilmoqda');
    } on ApiException catch (e) {
      if (mounted) AppNotify.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Kategoriya saqlanmadi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IosStyleModals.sheetKeyboardForm(
      context: context,
      onCancel: _saving ? null : () => Navigator.pop(context),
      onSave: _saving ? null : _save,
      isSaving: _saving,
      cancelLabel: Strings.bekorQilish,
      saveLabel: Strings.saqlash,
      body: [
        const Text(Strings.yangiKategoriya, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_saving,
          decoration: InputDecoration(
            labelText: 'Kategoriya nomi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: _saving ? null : (_) => _save(),
        ),
      ],
    );
  }
}
