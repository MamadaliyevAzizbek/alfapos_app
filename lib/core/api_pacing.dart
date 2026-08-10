/// Server yukini kamaytirish: ketma-ket so‘rovlar orasidagi pauza.
class ApiPacing {
  ApiPacing._();

  /// Sync zanjiri — Laravel throttle (429) kamayishi uchun biroz sekinroq.
  static const staggerStep = Duration(milliseconds: 650);
  static const productPageStep = Duration(milliseconds: 700);

  static Future<void> staggerPause([Duration? d]) =>
      Future<void>.delayed(d ?? staggerStep);
}
