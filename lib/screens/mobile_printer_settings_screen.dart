import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/network_printer_settings.dart';
import '../services/printer_settings.dart';

/// Mobil: WiFi termal printer (Xprinter va h.k.) sozlamalari.
class MobilePrinterSettingsScreen extends StatefulWidget {
  const MobilePrinterSettingsScreen({super.key});

  @override
  State<MobilePrinterSettingsScreen> createState() =>
      _MobilePrinterSettingsScreenState();
}

class _MobilePrinterSettingsScreenState extends State<MobilePrinterSettingsScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  bool _loading = true;
  bool _enabled = false;
  bool _autoPrint = true;
  bool _openCashDrawer = true;
  CashDrawerPin _drawerPin = CashDrawerPin.pin2;
  NetworkPrinterMode _mode = NetworkPrinterMode.computerRelay;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await NetworkPrinterSettings.load();
      final host = await NetworkPrinterSettings.getHost();
      final port = await NetworkPrinterSettings.getPort();
      final enabled = await NetworkPrinterSettings.isEnabled();
      final printMode = await NetworkPrinterSettings.getMode();
      final auto = await PrinterSettings.isAutoPrintEnabled();
      final drawer = await PrinterSettings.isCashDrawerOpenOnPrintEnabled();
      final pin = await PrinterSettings.cashDrawerPin();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _mode = printMode;
        _hostCtrl.text = host ?? '';
        _portCtrl.text = '$port';
        _autoPrint = auto;
        _openCashDrawer = drawer;
        _drawerPin = pin;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Sozlamalar: $e');
      }
    }
  }

  int? _readPort() {
    final n = int.tryParse(_portCtrl.text.trim());
    if (n == null) return null;
    return NetworkPrinterSettings.clampPort(n);
  }

  Future<void> _save() async {
    final host = _hostCtrl.text.trim();
    final port = _readPort();
    if (_enabled) {
      if (!NetworkPrinterSettings.isValidHost(host)) {
        AppNotify.info(context, 'To‘g‘ri IP manzil kiriting (masalan 192.168.1.100)');
        return;
      }
      if (port == null) {
        AppNotify.info(context, 'Port raqamini kiriting (odatda 9100)');
        return;
      }
    }

    await NetworkPrinterSettings.setEnabled(_enabled);
    await NetworkPrinterSettings.setHost(host.isEmpty ? null : host);
    await NetworkPrinterSettings.setPort(port ?? NetworkPrinterSettings.defaultPort);
    await NetworkPrinterSettings.setMode(_mode);
    await PrinterSettings.setAutoPrintEnabled(_autoPrint);
    await PrinterSettings.setCashDrawerOpenOnPrintEnabled(_openCashDrawer);
    await PrinterSettings.setCashDrawerPin(_drawerPin);
    if (!mounted) return;
    AppNotify.success(context, 'Printer sozlamalari saqlandi');
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    final host = _hostCtrl.text.trim();
    final port = _readPort() ?? NetworkPrinterSettings.defaultPort;
    if (!NetworkPrinterSettings.isValidHost(host)) {
      AppNotify.info(context, 'Avval IP manzilni kiriting');
      return;
    }
    await _runAction(() async {
      final result = await PrinterSettings.testNetworkConnection(
        host: host,
        port: port,
      );
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, result.message);
      } else {
        AppNotify.error(context, result.message);
      }
    });
  }

  Future<void> _testPrint() async {
    await _save();
    if (!mounted) return;
    await _runAction(() async {
      final result = await PrinterSettings.testPrint();
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, result.message);
      } else {
        AppNotify.error(context, result.message);
      }
    });
  }

  Future<void> _openDrawer() async {
    await _save();
    if (!mounted) return;
    await _runAction(() async {
      final result = await PrinterSettings.openCashDrawerViaNetwork();
      if (!mounted) return;
      if (result.ok) {
        AppNotify.success(context, 'Naqd qutisi ochildi');
      } else {
        AppNotify.error(context, result.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Printer sozlamalari'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _infoCard(),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'WiFi printer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Telefon va kompyuter/printer bir xil WiFi tarmog‘ida bo‘lishi kerak',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        value: _enabled,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      if (_enabled) ...[
                        const SizedBox(height: 12),
                        SegmentedButton<NetworkPrinterMode>(
                          segments: const [
                            ButtonSegment(
                              value: NetworkPrinterMode.computerRelay,
                              label: Text('Kompyuter relay'),
                            ),
                            ButtonSegment(
                              value: NetworkPrinterMode.directEscPos,
                              label: Text('To‘g‘ridan WiFi'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (v) {
                            if (v.isEmpty) return;
                            setState(() => _mode = v.first);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == NetworkPrinterMode.computerRelay
                              ? 'Xprinter 365B kabi TSPL label printer + Mac/Windows USB uchun.'
                              : 'ESC/POS WiFi printer (port 9100) uchun.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _hostCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(
                            'Kompyuter yoki printer IP',
                            hint: '192.168.0.104',
                            prefix: const Icon(Icons.router_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _fieldDecoration(
                            'Port',
                            hint: '${NetworkPrinterSettings.defaultPort}',
                            prefix: const Icon(Icons.settings_ethernet_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'USB printer: kompyuterdagi ALFAPOS → Sozlamalar → Mobil relay IP. '
                          'To‘g‘ridan-to‘g‘ri WiFi printer: printer IP, port 9100.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Avtomatik chop etish',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'To‘lovdan keyin chek avtomatik chiqadi (printer tayyor bo‘lsa)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        value: _autoPrint,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _autoPrint = v),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Naqd qutisini ochish',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Chek chop etilganda kassa qutisi ochiladi (printerga ulangan bo‘lsa)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        value: _openCashDrawer,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _openCashDrawer = v),
                      ),
                      if (_openCashDrawer) ...[
                        const SizedBox(height: 8),
                        SegmentedButton<CashDrawerPin>(
                          segments: const [
                            ButtonSegment(
                              value: CashDrawerPin.pin2,
                              label: Text('Pin 2'),
                            ),
                            ButtonSegment(
                              value: CashDrawerPin.pin5,
                              label: Text('Pin 5'),
                            ),
                          ],
                          selected: {_drawerPin},
                          onSelectionChanged: (v) {
                            setState(() => _drawerPin = v.first);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tekshirish',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Avval «Saqlash», keyin ulanish yoki test chop etishni bosing.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _testConnection,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find_rounded),
                        label: const Text('Ulanishni tekshirish'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy ? null : _testPrint,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Test chek chop etish'),
                      ),
                      if (_openCashDrawer) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _openDrawer,
                          icon: const Icon(Icons.point_of_sale_rounded),
                          label: const Text('Naqd qutisini ochish'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text(Strings.saqlash),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Printer kompyuterga USB orqali ulangan bo‘lsa, printerni emas — kompyuter IP manzilini kiriting. '
              'Kompyuterda ALFAPOS ochiq bo‘lishi va «Mobil relay» yoqilgan bo‘lishi kerak. '
              'Telefon ham, kompyuter ham bir xil WiFi da bo‘lsin.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: AppTheme.cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
    );
  }
}
