import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../providers/clients_provider.dart';
import '../services/sales_ui_scale_settings.dart';

/// Mijoz qarzi yoki balansi — qidiruv va tanlangan kartada.
class CustomerDebtBalanceBadge extends StatelessWidget {
  final Client client;
  final bool compact;

  const CustomerDebtBalanceBadge({
    super.key,
    required this.client,
    this.compact = false,
  });

  static int debtAmount(Client c) => (c.dueAmount ?? 0).round();

  static int balanceAmount(Client c) => (c.balance ?? 0).round();

  @override
  Widget build(BuildContext context) {
    final debt = debtAmount(client);
    if (debt > 0) {
      return _pill(
        compact ? formatThousands(debt) : 'Qarzi: ${formatThousands(debt)}',
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFFB91C1C),
      );
    }
    final balance = balanceAmount(client);
    if (balance > 0) {
      return _pill(
        compact ? formatThousands(balance) : 'Balans: ${formatThousands(balance)}',
        background: const Color(0xFFDCFCE7),
        foreground: const Color(0xFF166534),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _pill(String label, {required Color background, required Color foreground}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SalesUiScaleSettings.scaled(compact ? 8 : 10),
        vertical: SalesUiScaleSettings.scaled(compact ? 2 : 4),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SalesUiScaleSettings.scaled(compact ? 6 : 20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SalesUiScaleSettings.scaled(compact ? 11 : 12),
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1.2,
        ),
      ),
    );
  }
}
