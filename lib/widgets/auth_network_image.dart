import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../core/api_http.dart';
import '../core/auth_storage.dart';

/// Token talab qiladigan server rasmlari uchun (Image.network Authorization yubormaydi).
class AuthNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;

  const AuthNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  static final CacheManager _cache = CacheManager(
    Config(
      'auth_image_cache_v1',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 1500,
    ),
  );

  File? _file;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _file = null;
        _loading = true;
        _failed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final u = widget.url.trim();
    if (u.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final token = await getToken();
      final companyId = await getCompanyId();
      final headers = <String, String>{
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (companyId != null && companyId.isNotEmpty) 'X-Company-Id': companyId,
      };

      // Disk+memory cache: bir marta yuklanadi, keyin hamma joyda cache'dan ochiladi.
      final f = await ApiHttp.withTransientRetry(
        () => _cache.getSingleFile(u, headers: headers),
      );
      if (!mounted) return;
      setState(() {
        _file = f;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty || _failed) return widget.placeholder;
    if (_loading || _file == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return Image.file(
      _file!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.placeholder,
    );
  }
}
