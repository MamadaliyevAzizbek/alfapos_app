import 'package:flutter/material.dart';
import '../core/input_formatters.dart';

/// Bir qator chek qatori: mahsulot, miqdor, narx, summa
class ReceiptRow {
  final String productName;
  final String quantityStr; // "0.67kg", "2 dona"
  final int price;
  final int sum;

  const ReceiptRow({
    required this.productName,
    required this.quantityStr,
    required this.price,
    required this.sum,
  });
}

/// To'lov qatori: usul, vaqt, summa
class ReceiptPaymentRow {
  final String methodName;
  final int sum;

  const ReceiptPaymentRow({
    required this.methodName,
    required this.sum,
  });
}

/// Chek boshida matnli ALFAPOS, keyin: sana/vaqt, raqam, sotuvchi, jadval, ...
class ReceiptWidget extends StatelessWidget {
  final DateTime dateTime;
  final String receiptNumber;
  final String sellerName;
  final String? clientName;
  final String? description;
  final List<ReceiptRow> productRows;
  final List<ReceiptPaymentRow> paymentRows;
  final int discount;
  final int totalSum;
  final String barcodeData;
  /// To'lovdan oldin mijozga beriladigan oldindan chek.
  final bool isPrecheck;

  const ReceiptWidget({
    super.key,
    required this.dateTime,
    required this.receiptNumber,
    required this.sellerName,
    this.clientName,
    this.description,
    required this.productRows,
    required this.paymentRows,
    required this.discount,
    required this.totalSum,
    this.barcodeData = '',
    this.isPrecheck = false,
  });

  static String _fmt(int n) => formatThousands(n);

  @override
  Widget build(BuildContext context) {
    const width = 340.0;
    const padding = 16.0;
    final textStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey.shade800,
      height: 1.35,
    );
    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade900,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(padding),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'ALFAPOS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: Colors.grey.shade900,
                height: 1.1,
              ),
            ),
          ),
          if (isPrecheck) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "OLDINDAN CHEK",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Sana va vaqt
          Center(
            child: Text(
              '${_dateStr(dateTime)} - ${_timeStr(dateTime)}',
              style: textStyle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPrecheck ? "Chek raqami: to'lov oldin" : 'Chek raqami: $receiptNumber',
            style: textStyle,
          ),
          Text('Sotuvchi: $sellerName', style: textStyle),
          if (clientName != null && clientName!.trim().isNotEmpty)
            Text('Mijoz: ${clientName!.trim()}', style: textStyle),
          if ((description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Tavsif: ${description!.trim()}', style: textStyle),
          ],
          const SizedBox(height: 12),
          // Jadval sarlavha
          Row(
            children: [
              SizedBox(width: width * 0.35, child: Text('Mahsulot', style: headerStyle)),
              SizedBox(width: width * 0.18, child: Text('Miqdor', style: headerStyle)),
              SizedBox(width: width * 0.22, child: Text('Narx', style: headerStyle)),
              Expanded(child: Text('Summa', style: headerStyle)),
            ],
          ),
          _dashedLine(width - padding * 2),
          // Mahsulot qatorlari
          for (final row in productRows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: width * 0.35, child: Text(row.productName, style: textStyle)),
                  SizedBox(width: width * 0.18, child: Text(row.quantityStr, style: textStyle)),
                  SizedBox(width: width * 0.22, child: Text(_fmt(row.price), style: textStyle)),
                  Expanded(child: Text(_fmt(row.sum), style: textStyle)),
                ],
              ),
            ),
          _dashedLine(width - padding * 2),
          // To'lov qatorlari
          if (!isPrecheck)
          for (final row in paymentRows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(row.methodName, style: textStyle)),
                  Text(_fmt(row.sum), style: textStyle),
                ],
              ),
            ),
          _dashedLine(width - padding * 2),
          Text('Chegirma: ${_fmt(discount)}', style: textStyle),
          _dashedLine(width - padding * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Umumiy summa', style: headerStyle),
              Text(_fmt(totalSum), style: headerStyle),
            ],
          ),
          if (!isPrecheck) ...[
            const SizedBox(height: 16),
            Center(
              child: _BarcodeStrip(
                data: barcodeData.isEmpty ? receiptNumber : barcodeData,
                width: width - padding * 2,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Спасибо за покупку!',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "To'lov hali amalga oshirilmagan",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _timeStr(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  static Widget _dashedLine(double w) {
    return CustomPaint(
      size: Size(w, 1),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Oddiy shtrix-kod ko‘rinishi (vertikal chiziqlar)
class _BarcodeStrip extends StatelessWidget {
  final String data;
  final double width;

  const _BarcodeStrip({required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 56),
      painter: _BarcodePainter(seed: data),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String seed;

  _BarcodePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final codes = seed.codeUnits;
    var i = 0;
    double x = 0;
    // Uzun shtrix-kod uchun: seed bo'yicha 1..4 px chiziqlarni takrorlab to'ldiramiz.
    while (x < size.width) {
      final v = codes.isEmpty ? (i * 7 + 3) : codes[i % codes.length];
      final w = 1.0 + (v % 4); // 1..4
      final isBar = ((v + i) % 2) == 0;
      final bw = w;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, bw, size.height), paint);
      }
      x += bw + 1; // gap = 1
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
