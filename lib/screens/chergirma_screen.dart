import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/input_formatters.dart';
import '../models/chergirma_result.dart';
import '../utils/cart_discount_percent.dart';
import '../widgets/pos_modal_actions.dart';

class ChergirmaScreen extends StatefulWidget {
  final int totalUzs;

  /// true — so'm: mijoz to'laydi, qolgani qatorlarga; false — desktop chek foiz/summa.
  final bool distributeToCartLines;

  const ChergirmaScreen({
    super.key,
    required this.totalUzs,
    this.distributeToCartLines = false,
  });

  @override
  State<ChergirmaScreen> createState() => _ChergirmaScreenState();
}

class _ChergirmaScreenState extends State<ChergirmaScreen> {
  static const double _fieldHeight = 56;

  final _valueController = TextEditingController();
  bool _byPercent = true;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  int? get _percentValue {
    final t = _valueController.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int get _percentPreviewDiscount {
    final v = _percentValue ?? 0;
    return CartDiscountPercent.previewDiscountUzs(widget.totalUzs, v);
  }

  int? get _sumValue => parseFormattedSum(_valueController.text);

  int get _previewDiscount {
    final paid = (_sumValue ?? widget.totalUzs).clamp(0, widget.totalUzs);
    return widget.totalUzs - paid;
  }

  bool get _canSave {
    if (_byPercent) {
      final v = _percentValue;
      return v != null && v >= 0 && v <= 100;
    }
    final v = _sumValue;
    if (v == null) return false;
    return v >= 0 && v <= widget.totalUzs;
  }

  void _setUnit(bool percent) {
    setState(() {
      _byPercent = percent;
      _valueController.clear();
      if (!percent && widget.distributeToCartLines) {
        _valueController.text = formatThousands(widget.totalUzs);
      }
    });
  }

  void _save() {
    if (_byPercent) {
      final v = _percentValue;
      if (v == null) return;
      Navigator.pop(
        context,
        ChergirmaResult.percent(CartDiscountPercent.discountPercentFromUi(v)),
      );
      return;
    }
    final v = _sumValue;
    if (v == null) return;
    if (widget.distributeToCartLines) {
      Navigator.pop(context, ChergirmaResult.customerPays(v));
    } else {
      Navigator.pop(context, ChergirmaResult.discountUzs(v));
    }
  }

  void _clear() {
    Navigator.pop(context, const ChergirmaResult.clear());
  }

  @override
  Widget build(BuildContext context) {
    final showPayPreview = widget.distributeToCartLines && !_byPercent;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chegirma'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _totalCard(),
                const SizedBox(height: 20),
                Text(
                  _byPercent
                      ? 'Foizni kiriting'
                      : widget.distributeToCartLines
                          ? "Mijoz qancha to'laydi?"
                          : 'Chegirma summasini kiriting',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (showPayPreview) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "Qolgan summa chegirma bo'lib mahsulotlarga teng taqsimlanadi",
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: _fieldHeight,
                        child: TextField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          inputFormatters: _byPercent
                              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}'))]
                              : [ThousandsInputFormatter()],
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: _byPercent
                                ? 'Foiz'
                                : widget.distributeToCartLines
                                    ? "Mijoz to'laydi"
                                    : 'Chegirma summasi',
                            suffixText: _byPercent ? '%' : "so'm",
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: _fieldHeight,
                      child: _unitToggle(),
                    ),
                  ],
                ),
                if (_byPercent) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Masalan: 10 — 10% chegirma',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
                if (_byPercent && _percentPreviewDiscount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Chegirma', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          "${formatThousands(_percentPreviewDiscount)} so'm",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showPayPreview && _sumValue != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Chegirma', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          "${formatThousands(_previewDiscount)} so'm",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _byPercent ? _percentQuickChips() : _sumQuickChips(),
                ),
              ],
            ),
          ),
          PosModalActions(
            onSave: _save,
            onCancel: () => Navigator.pop(context),
            onClear: _clear,
            saveEnabled: _canSave,
          ),
        ],
      ),
    );
  }

  List<Widget> _percentQuickChips() {
    return [5, 10, 15, 20, 30, 50]
        .map(
          (p) => _quickChip(
            '$p%',
            () {
              _valueController.text = '$p';
              setState(() {});
            },
          ),
        )
        .toList();
  }

  List<Widget> _sumQuickChips() {
    if (widget.distributeToCartLines) {
      return [1.0, 0.85, 0.7, 0.5].map((f) {
        final pay = (widget.totalUzs * f).round();
        final label = f == 1.0 ? 'To\'liq' : '${formatThousands(pay)}';
        return _quickChip(label, () {
          _valueController.text = formatThousands(pay);
          setState(() {});
        });
      }).toList();
    }
    final amounts = [
      (widget.totalUzs * 0.15).round(),
      (widget.totalUzs * 0.30).round(),
      (widget.totalUzs * 0.50).round(),
    ];
    return amounts
        .map(
          (u) => _quickChip("${formatThousands(u)} so'm", () {
            _valueController.text = formatThousands(u);
            setState(() {});
          }),
        )
        .toList();
  }

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Jami', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          Text(
            "${formatThousands(widget.totalUzs)} so'm",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary),
          ),
        ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _unitToggle() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _unitSegment('%', _byPercent, () => _setUnit(true)),
          _unitSegment("so'm", !_byPercent, () => _setUnit(false)),
        ],
      ),
    );
  }

  Widget _unitSegment(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
