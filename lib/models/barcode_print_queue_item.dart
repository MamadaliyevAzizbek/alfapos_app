import 'product.dart';
import 'barcode_label_config.dart';

/// Mobil shtrix chop etish savatidagi qator.
class BarcodePrintQueueItem {
  BarcodePrintQueueItem({
    required this.product,
    required this.config,
  });

  final Product product;
  BarcodeLabelConfig config;
}
