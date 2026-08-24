import 'package:flutter/material.dart';

import '../core/app_notify.dart';
import '../models/product.dart';
import '../services/barcode_label_printer.dart';
import '../services/barcode_label_settings.dart';
import '../widgets/barcode_label_print_dialog.dart';

/// Mahsulot shtrix kod yorlig‘ini chop etish oqimi.
Future<void> runBarcodeLabelPrintFlow(
  BuildContext context,
  Product product,
) async {
  final code = BarcodeLabelPrinter.resolvePrintCode(product);
  if (code == null) {
    AppNotify.error(context, 'Mahsulotda shtrix kod yo\'q');
    return;
  }

  final config = await showBarcodeLabelPrintDialog(
    context: context,
    product: product,
    barcode: code,
  );
  if (config == null || !context.mounted) return;

  await BarcodeLabelSettings.save(config);

  final result = await BarcodeLabelPrinter.printLabels(product, config);
  if (!context.mounted) return;

  if (result.ok) {
    AppNotify.success(context, result.message);
  } else {
    AppNotify.error(context, result.message);
  }
}
