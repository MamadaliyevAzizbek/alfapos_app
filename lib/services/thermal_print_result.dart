/// Printerga yuborish natijasi (yengil — og‘ir thermal_receipt_printer importisiz).
class ThermalPrintResult {
  final bool ok;
  final String message;

  const ThermalPrintResult._(this.ok, this.message);

  factory ThermalPrintResult.ok(String message) => ThermalPrintResult._(true, message);
  factory ThermalPrintResult.fail(String message) => ThermalPrintResult._(false, message);
}
