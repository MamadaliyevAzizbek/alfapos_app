import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/input_formatters.dart';
import '../../core/theme.dart';
import '../../providers/cash_register_shift_provider.dart';
import '../../providers/sales_session_provider.dart';
import '../../utils/cash_register_utils.dart';
import '../../utils/platform_layout.dart';

/// Smena yopilgan — to‘liq ekran.
class CashRegisterShiftClosedScreen extends StatelessWidget {
  final VoidCallback onOpenShift;
  final VoidCallback? onSync;
  final bool syncing;

  const CashRegisterShiftClosedScreen({
    super.key,
    required this.onOpenShift,
    this.onSync,
    this.syncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final shift = CashRegisterShiftProvider.instance;
    final openByOthers = shift.registers.where((r) {
      return cashRegisterIsOpen(r) && !cashRegisterUserIsEnrolled(r, shift.currentUserId);
    }).toList();

    return ColoredBox(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded, size: 36, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Smena yopilgan',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      openByOthers.isEmpty
                          ? 'Ish boshlash uchun yangi smena oching'
                          : 'Boshqa xodim ochgan kassaga «Birlashish» orqali qo‘shiling yoki yangi kassa oching.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.4),
                    ),
                    if (openByOthers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ochiq kassalar',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            ...openByOthers.map((r) {
                              final staff = cashRegisterShiftStaffNames(r);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${cashRegisterDisplayTitle(r)}${staff.isNotEmpty ? ' — $staff' : ''}',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: syncing ? null : onOpenShift,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          openByOthers.isEmpty ? 'SMENA OCHISH' : 'KASSANI TANLASH',
                          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    if (onSync != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: syncing ? null : onSync,
                          icon: syncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: const Text('Sinxronlash'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Telefondan kassa ochilgan bo‘lsa, avval sinxronlang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kassani tanlash: ochish yoki birlashish (enroll).
class CashRegisterPickScreen extends StatefulWidget {
  const CashRegisterPickScreen({super.key});

  @override
  State<CashRegisterPickScreen> createState() => _CashRegisterPickScreenState();
}

class _CashRegisterPickScreenState extends State<CashRegisterPickScreen> {
  final _shift = CashRegisterShiftProvider.instance;
  int? _expandedId;
  final _openingController = TextEditingController(text: '0');
  final _passwordController = TextEditingController();
  bool _busy = false;

  bool get _mobile => !isDesktopPosLayout;

  @override
  void initState() {
    super.initState();
    _shift.addListener(_onShift);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_shift.registers.isEmpty) await _shift.loadRegisters();
    });
  }

  @override
  void dispose() {
    _shift.removeListener(_onShift);
    _openingController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onShift() {
    if (mounted) setState(() {});
  }

  Future<void> _openRegister(Map<String, dynamic> r) async {
    final id = cashRegisterParseId(r['id']);
    if (id == null) return;
    setState(() => _busy = true);
    final amount = parseFormattedSum(_openingController.text) ?? 0;
    final ok = await _shift.openShift(
      registerId: id,
      openingAmount: amount,
      accessPassword: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      SalesSessionProvider.instance.syncFromShift();
      if (mounted) {
        AppNotify.success(context, 'Kassa ochildi');
        Navigator.of(context).pop();
      }
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  Future<void> _enrollRegister(Map<String, dynamic> r) async {
    final id = cashRegisterParseId(r['id']);
    if (id == null) return;
    setState(() => _busy = true);
    final ok = await _shift.enrollShift(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      SalesSessionProvider.instance.syncFromShift();
      if (mounted) {
        AppNotify.success(context, 'Kassaga muvaffaqiyatli birlashdingiz');
        Navigator.of(context).pop();
      }
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  void _continueToSales() {
    SalesSessionProvider.instance.syncFromShift();
    Navigator.of(context).pop();
  }

  Future<void> _syncRegisters() async {
    final ok = await _shift.syncWithServer();
    SalesSessionProvider.instance.syncFromShift();
    if (!mounted) return;
    if (ok && _shift.isShiftOpen) {
      AppNotify.success(context, 'Kassa sinxronlandi');
      Navigator.of(context).pop();
    } else if (ok) {
      AppNotify.info(context, 'Kassalar yangilandi');
      setState(() {});
    } else if (_shift.error != null) {
      AppNotify.error(context, _shift.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registers = _shift.registers;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(_mobile ? 16 : 20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KASSA', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          'Kassani tanlang',
                          style: TextStyle(fontSize: _mobile ? 22 : 26, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _mobile
                              ? 'Yopiq kassani oching yoki ochiq kassaga birlashing — bir kassada bir nechta xodim ishlashi mumkin.'
                              : 'Kerakli kassani tanlang. Yangi smena oching yoki ochiq kassaga birlashing.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sinxronlash',
                    onPressed: _busy || _shift.loading ? null : _syncRegisters,
                    icon: _shift.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_shift.loading && registers.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
            else
              Expanded(
                child: _mobile
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: registers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _RegisterCard(
                          register: registers[index],
                          mobile: true,
                          expanded: _expandedId == cashRegisterParseId(registers[index]['id']),
                          busy: _busy,
                          currentUserId: _shift.currentUserId,
                          openingController: _openingController,
                          passwordController: _passwordController,
                          onTap: () {
                            setState(() {
                              final id = cashRegisterParseId(registers[index]['id']);
                              _expandedId = _expandedId == id ? null : id;
                            });
                          },
                          onOpen: () => _openRegister(registers[index]),
                          onEnroll: () => _enrollRegister(registers[index]),
                          onContinue: _continueToSales,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: registers
                                .map(
                                  (r) => _RegisterCard(
                                    register: r,
                                    mobile: false,
                                    expanded: _expandedId == cashRegisterParseId(r['id']),
                                    busy: _busy,
                                    currentUserId: _shift.currentUserId,
                                    openingController: _openingController,
                                    passwordController: _passwordController,
                                    onTap: () {
                                      setState(() {
                                        final id = cashRegisterParseId(r['id']);
                                        _expandedId = _expandedId == id ? null : id;
                                      });
                                    },
                                    onOpen: () => _openRegister(r),
                                    onEnroll: () => _enrollRegister(r),
                                    onContinue: _continueToSales,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final Map<String, dynamic> register;
  final bool mobile;
  final bool expanded;
  final bool busy;
  final int? currentUserId;
  final TextEditingController openingController;
  final TextEditingController passwordController;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onEnroll;
  final VoidCallback onContinue;

  const _RegisterCard({
    required this.register,
    required this.mobile,
    required this.expanded,
    required this.busy,
    required this.currentUserId,
    required this.openingController,
    required this.passwordController,
    required this.onTap,
    required this.onOpen,
    required this.onEnroll,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final open = cashRegisterIsOpen(register);
    final enrolled = cashRegisterUserIsEnrolled(register, currentUserId);
    final title = cashRegisterDisplayTitle(register);
    final staffNames = cashRegisterShiftStaffNames(register);
    final w = MediaQuery.sizeOf(context).width;
    final cardWidth = mobile ? double.infinity : (w > 900 ? 320.0 : (w - 56).clamp(260.0, 400.0));

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: expanded ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: expanded ? AppTheme.primary : AppTheme.divider,
                width: expanded ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              if (staffNames.isNotEmpty && open) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        staffNames,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: open ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            open ? 'Ochiq' : 'Yopilgan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: open ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        if (enrolled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Siz smenadasiz',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (open && enrolled) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Text(
                          'Bu kassada smenadasiz. Bir xil kassada boshqa xodimlar ham sotuv qilishi mumkin.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: busy ? null : onContinue,
                          child: const Text('Sotuvga davom etish'),
                        ),
                      ),
                    ] else if (open) ...[
                      Text(
                        staffNames.isNotEmpty
                            ? '«$staffNames» ochgan smenaga qo‘shiling — shu kassada birgalikda ishlaysiz.'
                            : 'Boshqa xodim ochgan smenaga qo‘shiling — bir kassada 2 va undan ortiq xodim ishlashi mumkin.',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onEnroll,
                          icon: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.group_add_rounded),
                          label: const Text('Birlashish'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text('Ochilish miqdori', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: openingController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsInputFormatter()],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                      if (register['has_password'] == true || register['has_password'] == 1) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Kassa paroli',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onOpen,
                          icon: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.lock_open_rounded),
                          label: const Text('Kassani ochish'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
