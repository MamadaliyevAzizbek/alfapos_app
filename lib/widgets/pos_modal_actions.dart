import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Filtr, chegirma va boshqa modallar uchun bir xil pastki tugmalar.
class PosModalActions extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback? onClear;
  final String saveLabel;
  final String cancelLabel;
  final String clearLabel;
  final bool saveEnabled;

  const PosModalActions({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.onClear,
    this.saveLabel = 'Saqlash',
    this.cancelLabel = 'Bekor qilish',
    this.clearLabel = 'Tozalash',
    this.saveEnabled = true,
  });

  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerLight = Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: saveEnabled ? onSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              saveLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    cancelLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      backgroundColor: _dangerLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      clearLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
