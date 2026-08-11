import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_notify.dart';
import '../../core/theme.dart';
import '../../models/receipt_design_config.dart';
import '../../services/receipt_design_storage.dart';
import '../../widgets/receipt_logo_image.dart';

/// Faqat chek logosi — matn sozlamalari standart, yashirin.
class ReceiptDesignEditorPanel extends StatefulWidget {
  final VoidCallback? onSaved;

  const ReceiptDesignEditorPanel({super.key, this.onSaved});

  @override
  State<ReceiptDesignEditorPanel> createState() => _ReceiptDesignEditorPanelState();
}

class _ReceiptDesignEditorPanelState extends State<ReceiptDesignEditorPanel> {
  ReceiptDesignConfig _config = ReceiptDesignConfig.defaults;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      ReceiptDesignStorage.invalidateCache();
      final c = await ReceiptDesignStorage.reload();
      if (!mounted) return;
      setState(() {
        _config = c;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppNotify.error(context, 'Chek logosi: $e');
      }
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    try {
      final picked = result.files.single;
      final ReceiptDesignConfig c;
      if (path != null && path.isNotEmpty) {
        c = await ReceiptDesignStorage.saveLogoFromPath(_config, path);
      } else if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        c = await ReceiptDesignStorage.saveLogoFromBytes(
          _config,
          picked.bytes!,
          extension: '.png',
        );
      } else {
        throw StateError('Logo faylini o\'qib bo\'lmadi');
      }
      if (!mounted) return;
      setState(() => _config = ReceiptDesignConfig.standardFrom(c));
      AppNotify.success(context, 'Logo saqlandi');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Logo saqlanmadi: $e');
    }
  }

  Future<void> _removeLogo() async {
    var c = await ReceiptDesignStorage.removeLogo(_config);
    await ReceiptDesignStorage.save(c);
    if (!mounted) return;
    setState(() => _config = c);
    widget.onSaved?.call();
  }

  Future<void> _toggleLogo(bool show) async {
    final c = await ReceiptDesignStorage.setShowLogo(_config, show);
    if (!mounted) return;
    setState(() => _config = c);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final path = _config.logoFilePath;
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: _config.showLogo && hasFile
              ? ReceiptLogoImage(path: path, fit: BoxFit.contain)
              : Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chek logosi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chek matnlari standart. Mijoz qatori faqat mijoz tanlanganda chiqadi.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chek boshida logo'),
                value: _config.showLogo,
                onChanged: _toggleLogo,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Logo yuklash'),
                  ),
                  if (hasFile)
                    TextButton.icon(
                      onPressed: _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('O‘chirish'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
