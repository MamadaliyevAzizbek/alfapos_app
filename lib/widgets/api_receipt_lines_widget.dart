import 'package:flutter/material.dart';

/// API dan parse qilingan chek qatorlari (ko'rinish / skrinshot uchun).
class ApiReceiptLinesWidget extends StatelessWidget {
  final List<String> lines;
  final double width;

  const ApiReceiptLinesWidget({
    super.key,
    required this.lines,
    this.width = 302,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 13,
      color: Colors.black,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            if (line.isEmpty)
              const SizedBox(height: 6)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(line, style: textStyle),
              ),
        ],
      ),
    );
  }
}
