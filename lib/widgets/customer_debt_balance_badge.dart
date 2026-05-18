import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';

/// Mijoz qarzi yoki balansi — qidiruv va tanlangan kartada.
class CustomerDebtBalanceBadge extends StatelessWidget {
  final Client client;

  const CustomerDebtBalanceBadge({super.key, required this.client});

  static int debtAmount(Client c) => (c.dueAmount ?? 0).round();

  static int balanceAmount(Client c) => (c.balance ?? 0).round();

  @override
  Widget build(BuildContext context) {
    final debt = debtAmount(client);
    if (debt > 0) {
      return _pill(
        'Qarzi: ${formatThousands(debt)}',
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFFB91C1C),
      );
    }
    final balance = balanceAmount(client);
    if (balance > 0) {
      return _pill(
        'Balans: ${formatThousands(balance)}',
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
      );
    }
    return const SizedBox.shrink();
  }

  static Widget _pill(String label, {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
