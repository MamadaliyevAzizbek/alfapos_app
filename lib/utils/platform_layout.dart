import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Testlar mobil va desktop ko‘rinishlarini alohida tekshirishi uchun.
/// Testlar host (macOS) da ishlagani sabab mobil tarmoq odatda tushib qolardi.
@visibleForTesting
bool? debugIsDesktopPosLayoutOverride;

/// Windows (va Mac’da sinov) uchun POS — ikki ustunli katalog + savatcha.
bool get isDesktopPosLayout {
  final override = debugIsDesktopPosLayoutOverride;
  if (override != null) return override;
  if (kIsWeb) {
    // Flutter Web’da katta kenglik bo‘lsa — desktop layoutni ishlatamiz.
    // (Aks holda mobile UI cho‘zilib va juda kichik bo‘lib qoladi.)
    final view = ui.PlatformDispatcher.instance.views.first;
    final logicalW = view.physicalSize.width / view.devicePixelRatio;
    return logicalW >= 1100;
  }
  return Platform.isWindows || Platform.isMacOS;
}

/// Keng ekranda grid ustunlari soni.
int desktopProductGridColumns(double width) {
  if (width >= 1400) return 5;
  if (width >= 1100) return 4;
  if (width >= 850) return 3;
  return 2;
}
