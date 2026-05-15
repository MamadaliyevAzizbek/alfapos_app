import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/ios_style_modals.dart';

/// To'liq ekran skaner (eski variant – kerak bo'lsa ishlatiladi)
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    // Android’da EAN/UPC/Code128 kabi shtrix-kodlar aniq topilishi uchun formatlarni ochiq beramiz.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
    ],
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    if (capture.barcodes.isEmpty) return;
    String? value;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim().isNotEmpty == true ? b.rawValue!.trim() : b.displayValue?.trim();
      if (v != null && v.isNotEmpty && !v.startsWith('<')) {
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        value = (digits.length >= 8 && digits.length <= 14) ? digits : v;
        break;
      }
    }
    if (value == null || value.isEmpty) return;
    _hasScanned = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(Strings.skaner),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Skaner xatosi: ${error.errorCode}\n${error.errorDetails ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(Strings.skanerInstruction, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text(Strings.qaytish),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ixcham skaner – har safar yangi controller bilan ochiladi (2-chi marta ham ishlashi uchun).
void showCompactScanner(
  BuildContext context, {
  required ValueChanged<String?> onResult,
}) {
  IosStyleModals.showSheet<void>(
    context: context,
    isScrollControlled: true,
    showGrabber: false,
    child: Builder(
      builder: (sheetCtx) => _CompactScannerSheet(
        key: ValueKey(DateTime.now().millisecondsSinceEpoch),
        onScanned: (barcode) {
          onResult(barcode);
          Navigator.pop(sheetCtx);
        },
        onClose: () => Navigator.pop(sheetCtx),
      ),
    ),
  );
}

class _CompactScannerSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;
  final VoidCallback onClose;

  const _CompactScannerSheet({
    super.key,
    required this.onScanned,
    required this.onClose,
  });

  @override
  State<_CompactScannerSheet> createState() => _CompactScannerSheetState();
}

class _CompactScannerSheetState extends State<_CompactScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
    ],
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    if (capture.barcodes.isEmpty) return;
    String? value;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim().isNotEmpty == true ? b.rawValue!.trim() : b.displayValue?.trim();
      if (v != null && v.isNotEmpty && !v.startsWith('<')) {
        // EAN/UPC kabi raqamli shtrix-kodda prefiks/suffix olib tashlash — pachkali mahsulot skaneri ishlashi uchun
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        value = (digits.length >= 8 && digits.length <= 14) ? digits : v;
        break;
      }
    }
    if (value == null || value.isEmpty) return;
    _hasScanned = true;
    widget.onScanned(value);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final sheetHeight = (h * 0.46).clamp(360.0, 400.0);
    const cameraHeight = 200.0;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(Strings.skaner, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              IconButton(
                icon: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    switch (state.torchState) {
                      case TorchState.on:
                        return const Icon(Icons.flash_on_rounded, color: AppTheme.primary);
                      case TorchState.off:
                      case TorchState.auto:
                      case TorchState.unavailable:
                        return const Icon(Icons.flash_off_rounded, color: AppTheme.textSecondary);
                    }
                  },
                ),
                onPressed: () => _controller.toggleTorch(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const Text(
            Strings.skanerInstruction,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: cameraHeight,
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Skaner xatosi: ${error.errorCode}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onClose,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(Strings.qaytish),
              ),
            ),
          ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Kamera mavjud emas yoki ruxsat yo'q bo'lsa ko'rsatiladigan placeholder
class ScannerPlaceholderSheet extends StatelessWidget {
  final VoidCallback onClose;

  const ScannerPlaceholderSheet({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                Strings.skaner,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                Strings.skanerInstruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 220,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 72,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(Strings.qaytish),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
