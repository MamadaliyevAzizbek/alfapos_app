import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// Desktop: kamera o‘rniga shtrix-kod qo‘lda kiritish.
Future<String?> showBarcodeInputDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Shtrix-kod'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Shtrix-kodni kiriting',
            prefixIcon: Icon(Icons.qr_code_2_rounded, color: AppTheme.primary),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(Strings.bekorQilish)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Qo‘shish'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  final digits = result.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 8 && digits.length <= 14) return digits;
  return result;
}
