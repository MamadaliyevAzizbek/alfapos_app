import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Android GPU da `BackdropFilter` ro‘yxat/scroll ichida juda og‘ir —
/// Asosiy oynadagi 10+ glass kartochka qotishga olib kelardi.
bool get _useBackdropBlur {
  if (kIsWeb) return false;
  return !Platform.isAndroid;
}

/// iOS 26 liquid glass uslubi: blur + yarim shaffof fon + ingichka chegarа.
/// Android: vizual yaqin, lekin blur yo‘q (barqaror FPS).
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _useBackdropBlur ? 0.68 : 0.94),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: _useBackdropBlur ? 0.8 : 0.95),
          width: 1.5,
        ),
      ),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: _useBackdropBlur ? 20 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: _useBackdropBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Pastki nav va boshqa "glass" zonalar uchun fon
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;

  const LiquidGlassSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
      ),
      child: child,
    );
  }
}
