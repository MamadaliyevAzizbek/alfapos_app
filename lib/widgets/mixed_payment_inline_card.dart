import 'package:flutter/material.dart';

import '../core/input_formatters.dart';
import '../core/theme.dart';

/// Aralash to'lov: summa kartaning ichida kiritiladi (modal yo'q).
class MixedPaymentInlineCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final int amount;
  final int? balanceUzs;
  final bool compact;
  final bool desktopLarge;
  final ValueChanged<String> onAmountChanged;

  const MixedPaymentInlineCard({
    super.key,
    required this.title,
    required this.icon,
    required this.amount,
    this.balanceUzs,
    this.compact = false,
    this.desktopLarge = false,
    required this.onAmountChanged,
  });

  @override
  State<MixedPaymentInlineCard> createState() => _MixedPaymentInlineCardState();
}

class _MixedPaymentInlineCardState extends State<MixedPaymentInlineCard> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _controller = TextEditingController(text: _textForAmount(widget.amount));
  }

  @override
  void didUpdateWidget(covariant MixedPaymentInlineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount && !_focus.hasFocus) {
      final next = _textForAmount(widget.amount);
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _textForAmount(int amount) => amount > 0 ? formatThousands(amount) : '';

  @override
  Widget build(BuildContext context) {
    final isBalance = widget.balanceUzs != null;
    final hasAmount = widget.amount > 0;
    final bg = hasAmount
        ? (isBalance ? const Color(0xFFE8F8ED) : const Color(0xFFEFF6FF))
        : Colors.white;
    final border = hasAmount
        ? (isBalance ? const Color(0xFF7FD99A) : const Color(0xFF8EC2FF))
        : const Color(0xFFE5E5EA);
    final iconColor = isBalance ? const Color(0xFF34C759) : AppTheme.primary;
    final large = widget.desktopLarge;
    final titleSize = large ? 15.0 : (widget.compact ? 11.0 : 14.0);
    final fieldStyle = TextStyle(
      fontSize: large ? 22 : (widget.compact ? 14 : 16),
      fontWeight: FontWeight.w700,
      color: iconColor,
    );
    final iconSize = large ? 30.0 : (widget.compact ? 20.0 : 24.0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(large ? 10 : (widget.compact ? 8 : 12)),
        border: Border.all(color: border, width: hasAmount ? 1.25 : 1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : (widget.compact ? 8 : 10),
        vertical: large ? 12 : (widget.compact ? 8 : 10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: iconSize, color: iconColor),
          SizedBox(height: large ? 8 : (widget.compact ? 4 : 6)),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: AppTheme.textPrimary,
            ),
          ),
          if (isBalance) ...[
            const SizedBox(height: 2),
            Text(
              formatThousands(widget.balanceUzs!),
              style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
          ],
          SizedBox(height: large ? 10 : (widget.compact ? 6 : 8)),
          TextField(
            controller: _controller,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            textAlign: TextAlign.center,
            style: fieldStyle,
            decoration: InputDecoration(
              isDense: !large,
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: fieldStyle.fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: large ? 12 : 8,
                vertical: large ? 14 : (widget.compact ? 8 : 10),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: iconColor, width: 1.5),
              ),
            ),
            onChanged: widget.onAmountChanged,
          ),
        ],
      ),
    );
  }
}
