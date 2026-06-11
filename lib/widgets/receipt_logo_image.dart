import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

/// Chek logosi — har safar fayldan o‘qiladi, eski rasm keshi qolmasin.
class ReceiptLogoImage extends StatefulWidget {
  final String path;
  final double? height;
  final double? width;
  final BoxFit fit;
  /// Chop etish skrinshoti uchun — faylni sinxron o‘qib, darhol chizadi.
  final bool forceSync;

  const ReceiptLogoImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.forceSync = false,
  });

  static void evictCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  @override
  State<ReceiptLogoImage> createState() => _ReceiptLogoImageState();
}

class _ReceiptLogoImageState extends State<ReceiptLogoImage> {
  Uint8List? _bytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ReceiptLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.forceSync != widget.forceSync) {
      _reload();
    }
  }

  void _reload() {
    if (widget.forceSync) {
      _bytes = _readBytes(widget.path);
      _loadedPath = widget.path;
      return;
    }
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    final target = widget.path;
    final bytes = await _readBytesAsync(target);
    if (!mounted || target != widget.path) return;
    setState(() {
      _bytes = bytes;
      _loadedPath = target;
    });
  }

  static Uint8List? _readBytes(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _readBytesAsync(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceSync) {
      final bytes = _bytes ?? _readBytes(widget.path);
      return _imageFromBytes(bytes, widget.path);
    }

    if (_bytes == null || _loadedPath != widget.path) {
      return SizedBox(height: widget.height, width: widget.width);
    }
    return _imageFromBytes(_bytes, widget.path);
  }

  Widget _imageFromBytes(Uint8List? bytes, String path) {
    if (bytes == null || bytes.isEmpty) {
      return SizedBox(height: widget.height, width: widget.width);
    }
    return Image.memory(
      bytes,
      key: ValueKey('$path#${bytes.length}'),
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      gaplessPlayback: false,
      filterQuality: FilterQuality.medium,
    );
  }
}
