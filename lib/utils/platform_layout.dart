import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Windows (va Mac’da sinov) uchun POS — ikki ustunli katalog + savatcha.
bool get isDesktopPosLayout {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS;
}

/// Keng ekranda grid ustunlari soni.
int desktopProductGridColumns(double width) {
  if (width >= 1400) return 5;
  if (width >= 1100) return 4;
  if (width >= 850) return 3;
  return 2;
}
