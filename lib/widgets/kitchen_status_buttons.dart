import 'package:flutter/material.dart';

import '../utils/kitchen_status.dart';

/// Restoran: Tayyorlanmoqda / Tayyor / Yakunlandi.
class KitchenStatusButtons extends StatelessWidget {
  const KitchenStatusButtons({
    super.key,
    this.current,
    this.busy = false,
    required this.onSelected,
  });

  final KitchenStatus? current;
  final bool busy;
  final ValueChanged<KitchenStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in KitchenStatus.values) ...[
          if (status != KitchenStatus.values.first) const SizedBox(width: 6),
          _chip(status, current == status),
        ],
      ],
    );
  }

  Widget _chip(KitchenStatus status, bool selected) {
    final Color selectedBg;
    final Color selectedFg;
    final Color selectedBorder;
    switch (status) {
      case KitchenStatus.preparing:
        selectedBg = const Color(0xFFFFF8E1);
        selectedFg = const Color(0xFFF57F17);
        selectedBorder = const Color(0xFFFFB300);
      case KitchenStatus.ready:
        selectedBg = const Color(0xFFE8F5E9);
        selectedFg = const Color(0xFF2E7D32);
        selectedBorder = const Color(0xFF66BB6A);
      case KitchenStatus.completed:
        selectedBg = const Color(0xFFE3F2FD);
        selectedFg = const Color(0xFF1565C0);
        selectedBorder = const Color(0xFF64B5F6);
    }
    return Material(
      color: selected ? selectedBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? selectedBorder : const Color(0xFFCFD8DC)),
      ),
      child: InkWell(
        onTap: busy ? null : () => onSelected(status),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? selectedFg : const Color(0xFF546E7A),
            ),
          ),
        ),
      ),
    );
  }
}
