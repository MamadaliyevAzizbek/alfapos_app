/// Server yukini kamaytirish: ketma-ket so‘rovlar orasidagi pauza.
class ApiPacing {
  ApiPacing._();

  static const staggerStep = Duration(milliseconds: 400);
  static const productPageStep = Duration(milliseconds: 450);

  static Future<void> staggerPause([Duration? d]) =>
      Future<void>.delayed(d ?? staggerStep);
}
