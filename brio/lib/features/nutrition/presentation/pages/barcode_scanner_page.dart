import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../providers/nutrition_providers.dart';

/// Scans a barcode and returns the matching [FoodItem] (or null).
/// Looks up the local DB first, then Open Food Facts (on the backend).
class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13, BarcodeFormat.ean8,
      BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128,
    ],
  );
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) _resolve(code);
  }

  Future<void> _resolve(String code) async {
    if (_handling) return;
    setState(() => _handling = true);
    await _controller.stop();
    final food = await lookupBarcode(ref, code);
    if (!mounted) return;
    if (food != null) {
      context.pop(food);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Código $code no encontrado'),
        backgroundColor: BrioColors.error));
      await _controller.start();
      if (mounted) setState(() => _handling = false);
    }
  }

  Future<void> _manualEntry() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _BarcodeDialog(),
    );
    if (code != null && code.isNotEmpty) _resolve(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _CameraError(onManual: _manualEntry),
          ),

          // Scan frame.
          const Center(child: _ScanFrame()),

          // Top gradient for the bar.
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent]))),
          ),

          // Top bar: close · torch.
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    Text('Escanear código', style: BrioTextStyles.h3.copyWith(color: Colors.white, fontSize: 17)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom text + manual entry.
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent])),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Apunta al código de barras del producto',
                        textAlign: TextAlign.center,
                        style: BrioTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _manualEntry,
                      icon: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
                      label: Text('Introducir código a mano',
                          style: BrioTextStyles.buttonSecondary.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Loading while looking up the product.
          if (_handling)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('Buscando producto…', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250, height: 170,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12)],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final VoidCallback onManual;
  const _CameraError({required this.onManual});
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 44),
              const SizedBox(height: 14),
              Text('No se pudo acceder a la cámara.\nDa permiso o introduce el código a mano.',
                  textAlign: TextAlign.center,
                  style: BrioTextStyles.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onManual,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Introducir código'),
              ),
            ],
          ),
        ),
      );
}

/// Dialog to type a barcode (fallback / no camera).
class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();
  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: BrioColors.bgSurface,
        title: Text('Código de barras', style: BrioTextStyles.h3.copyWith(fontSize: 18)),
        content: TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'p. ej. 8410000810004'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('Buscar')),
        ],
      );
}
