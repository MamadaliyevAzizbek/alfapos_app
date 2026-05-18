/// Chegirma ekranidan qaytish — qaysi usul qo'llanishi.
enum ChergirmaMode { clear, percent, discountUzs, customerPays }

class ChergirmaResult {
  final ChergirmaMode mode;
  final int value;

  const ChergirmaResult._(this.mode, this.value);

  const ChergirmaResult.clear() : this._(ChergirmaMode.clear, 0);

  const ChergirmaResult.percent(int percent)
      : this._(ChergirmaMode.percent, percent);

  /// Oddiy tab: chegirma summasi (so'm).
  const ChergirmaResult.discountUzs(int uzs) : this._(ChergirmaMode.discountUzs, uzs);

  /// Mijoz to'laydi (so'm).
  const ChergirmaResult.customerPays(int uzs) : this._(ChergirmaMode.customerPays, uzs);

  /// Desktop to'lov ekrani (chek darajasida foiz/summa).
  Map<String, int?> get legacyMap {
    switch (mode) {
      case ChergirmaMode.percent:
        return {'percent': value, 'uzs': null};
      case ChergirmaMode.discountUzs:
        return {'percent': null, 'uzs': value};
      default:
        return {'percent': null, 'uzs': null};
    }
  }
}
