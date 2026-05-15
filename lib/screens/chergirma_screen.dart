import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';

class ChergirmaScreen extends StatefulWidget {
  final int totalUzs;

  const ChergirmaScreen({super.key, required this.totalUzs});

  @override
  State<ChergirmaScreen> createState() => _ChergirmaScreenState();
}

class _ChergirmaScreenState extends State<ChergirmaScreen> {
  final _controller = TextEditingController();
  bool _byPercent = false; // false = UZS, true = %

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _value => parseFormattedSum(_controller.text);

  void _setPercent(int p) {
    _controller.text = p.toString();
    setState(() {});
  }

  void _setUzs(int amount) {
    _controller.text = formatThousands(amount);
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    final quickValues = _byPercent ? [15, 30, 50, 75] : [
      (widget.totalUzs * 0.15).round(),
      (widget.totalUzs * 0.30).round(),
      (widget.totalUzs * 0.50).round(),
      (widget.totalUzs * 0.75).round(),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chergirma'),
        actions: [
          TextButton(
            onPressed: () {
              final v = _value;
              if (v != null && v >= 0) {
                Navigator.pop(context, _byPercent ? {'percent': v} : {'uzs': v});
              }
            },
            child: const Text("Qo'shish", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Chegirma qiymatini kiriting",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: _byPercent
                        ? null
                        : [ThousandsInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _byPercent ? 'Foiz' : 'Chegirma summasi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip('%', _byPercent),
                      _chip('UZS', !_byPercent),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _byPercent
                  ? [15, 30, 50, 75].map((p) => _quickChip('$p%', () => _setPercent(p))).toList()
                  : quickValues.map((u) => _quickChip('${formatThousands(u)} UZS', () => _setUzs(u))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected) {
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _byPercent = label == '%'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
