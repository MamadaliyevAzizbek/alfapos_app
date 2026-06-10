import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/desktop_runtime.dart';
import '../core/product_image_utils.dart';
import '../core/theme.dart';
import 'auth_network_image.dart';
import '../providers/categories_provider.dart';
import '../utils/platform_layout.dart';
import '../utils/product_image_upload.dart';
import 'ios_style_modals.dart';

/// Kategoriya nomi va rasmini tahrirlash (Mahsulotlar → Kategoriyalar).
class EditCategorySheet {
  EditCategorySheet._();

  static Future<void> show(BuildContext context, {required String categoryName}) {
    return IosStyleModals.showSheet<void>(
      context: context,
      isScrollControlled: true,
      showGrabber: true,
      child: _EditCategorySheetBody(categoryName: categoryName),
    );
  }
}

class _EditCategorySheetBody extends StatefulWidget {
  final String categoryName;

  const _EditCategorySheetBody({required this.categoryName});

  @override
  State<_EditCategorySheetBody> createState() => _EditCategorySheetBodyState();
}

class _EditCategorySheetBodyState extends State<_EditCategorySheetBody> {
  late final TextEditingController _controller;
  String? _localImagePath;
  String? _remoteImagePath;
  bool _imageDeleted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.categoryName);
    final id = CategoriesProvider.instance.getCategoryIdByName(widget.categoryName);
    _remoteImagePath = CategoriesProvider.instance.categoryImageUrl(id?.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasLocalImage =>
      _localImagePath != null && _localImagePath!.isNotEmpty && File(_localImagePath!).existsSync();

  bool get _hasRemoteImage =>
      !_imageDeleted && !_hasLocalImage && (_remoteImagePath?.trim().isNotEmpty ?? false);

  Future<void> _pickDesktopImage() async {
    try {
      final persisted = await ProductImageUpload.pickDesktopImageFile();
      if (!mounted || persisted == null) return;
      setState(() {
        _localImagePath = persisted;
        _imageDeleted = false;
      });
    } catch (e) {
      if (mounted) {
        AppNotify.warning(
          context,
          '${desktopImagePickHelpText()} Xato: $e',
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (!mounted || xFile == null) return;
      final persisted = await ProductImageUpload.persistFromXFile(xFile);
      if (!mounted) return;
      setState(() {
        _localImagePath = persisted ?? xFile.path;
        _imageDeleted = false;
      });
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Rasm tanlanmadi: $e');
    }
  }

  void _showImageSourcePicker() {
    if (isDesktopPosLayout) {
      unawaited(_pickDesktopImage());
      return;
    }
    IosStyleModals.showSheet(
      context: context,
      showGrabber: true,
      child: Builder(
        builder: (sheetCtx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
              title: const Text('Kameradan olish'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
              title: const Text('Galereyadan tanlash'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageUploadArea() {
    final hasImage = _hasLocalImage || _hasRemoteImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kategoriya rasmi',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _saving ? null : _showImageSourcePicker,
            child: Container(
              height: hasImage ? 168 : 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_hasLocalImage)
                          Image.file(
                            File(_localImagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary, size: 48),
                            ),
                          )
                        else
                          AuthNetworkImage(
                            url: ProductImageUtils.resolveToUrl(_remoteImagePath),
                            fit: BoxFit.cover,
                            placeholder: Center(
                              child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary, size: 48),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Text(
                              'Almashtirish uchun bosing',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                        _localImagePath = null;
                                        _remoteImagePath = null;
                                        _imageDeleted = true;
                                      }),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppTheme.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Rasm qo‘shish (restoran rejimida ko‘rinadi)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.25),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final newName = _controller.text.trim();
    if (newName.isEmpty) return;

    setState(() => _saving = true);
    try {
      await CategoriesProvider.instance.updateCategory(
        widget.categoryName,
        newName,
        imagePath: _localImagePath,
        removeImage: _imageDeleted,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Kategoriya saqlanmadi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IosStyleModals.sheetKeyboardForm(
      context: context,
      onCancel: _saving ? null : () => Navigator.pop(context),
      onSave: _saving ? null : _save,
      isSaving: _saving,
      cancelLabel: Strings.bekorQilish,
      saveLabel: Strings.saqlash,
      body: [
        const Text('Kategoriyani tahrirlash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_saving,
          decoration: InputDecoration(
            labelText: 'Kategoriya nomi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        _imageUploadArea(),
      ],
    );
  }
}
