import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/theme.dart';
import '../../providers/cash_register_shift_provider.dart';
import '../../providers/sales_session_provider.dart';
import 'cash_register_shift_screens.dart';

/// Kassa smenasi talab qilinsa, smena ochiq bo‘lmaguncha sotuv bloklanadi.
class CashRegisterShiftGate extends StatefulWidget {
  final Widget child;

  const CashRegisterShiftGate({super.key, required this.child});

  @override
  State<CashRegisterShiftGate> createState() => _CashRegisterShiftGateState();
}

class _CashRegisterShiftGateState extends State<CashRegisterShiftGate> {
  final _shift = CashRegisterShiftProvider.instance;

  @override
  void initState() {
    super.initState();
    _wasShiftOpen = _shift.isShiftOpen;
    _shift.addListener(_onShift);
    if (!_shift.loading && _shift.registers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _shift.loadRegisters());
    }
  }

  @override
  void dispose() {
    _shift.removeListener(_onShift);
    super.dispose();
  }

  bool _wasShiftOpen = false;

  void _onShift() {
    final open = _shift.isShiftOpen;
    if (open && !_wasShiftOpen) {
      SalesSessionProvider.instance.syncFromShift();
    }
    _wasShiftOpen = open;
    if (mounted) setState(() {});
  }

  Future<void> _openPickScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const CashRegisterPickScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _syncRegisters() async {
    final ok = await _shift.syncWithServer();
    SalesSessionProvider.instance.syncFromShift();
    if (!mounted) return;
    if (ok && _shift.isShiftOpen) {
      AppNotify.success(context, 'Kassa sinxronlandi — smena ochiq');
    } else if (ok) {
      AppNotify.info(context, 'Kassalar yangilandi');
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shift.loading && _shift.registers.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF0F2F5),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (!_shift.requiresCashRegister) {
      return widget.child;
    }

    if (!_shift.isShiftOpen) {
      return CashRegisterShiftClosedScreen(
        onOpenShift: _openPickScreen,
        onSync: _syncRegisters,
        syncing: _shift.loading,
      );
    }

    if (_shift.detailLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          const Positioned(
            top: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return widget.child;
  }
}
