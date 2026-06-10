import 'dart:io';

import 'package:flutter/material.dart';

import '../core/product_image_utils.dart';
import '../core/theme.dart';
import '../utils/product_image_upload.dart';
import 'auth_network_image.dart';

/// Kategoriya rasmi — mahalliy fayl yoki server URL.
class CategoryImageCover {
  CategoryImageCover._();

  static Widget build(
    String? raw, {
    required double width,
    required double height,
    IconData fallbackIcon = Icons.category_rounded,
    Color backgroundColor = const Color(0xFFF0F2F5),
  }) {
    final iconSize = (width < height ? width : height) * 0.38;
    final placeholder = Center(
      child: Icon(fallbackIcon, color: AppTheme.textSecondary, size: iconSize),
    );

    Widget box(Widget child) => SizedBox(width: width, height: height, child: child);

    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return box(ColoredBox(color: backgroundColor, child: placeholder));
    }

    final localPath = ProductImageUpload.resolveLocalPath(trimmed);
    if (localPath != null) {
      final localFile = File(localPath);
      if (localFile.existsSync()) {
        return box(
          Image.file(
            localFile,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: backgroundColor, child: placeholder),
          ),
        );
      }
    }

    final url = ProductImageUtils.resolveToUrl(trimmed);
    if (url.isEmpty) {
      return box(ColoredBox(color: backgroundColor, child: placeholder));
    }

    return box(
      AuthNetworkImage(
        url: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: ColoredBox(color: backgroundColor, child: placeholder),
      ),
    );
  }
}
