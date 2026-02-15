import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../config/app_theme.dart';

/// Overlay a signature on a document image — draggable + resizable
class SignatureOverlayScreen extends StatefulWidget {
  final String documentImagePath;
  final String signaturePath;

  const SignatureOverlayScreen({
    super.key,
    required this.documentImagePath,
    required this.signaturePath,
  });

  @override
  State<SignatureOverlayScreen> createState() => _SignatureOverlayScreenState();
}

class _SignatureOverlayScreenState extends State<SignatureOverlayScreen> {
  // Signature position & scale
  Offset _sigOffset = const Offset(80, 300);
  double _sigScale = 0.5;
  double _baseScale = 0.5;
  bool _isSaving = false;

  final GlobalKey _compositeKey = GlobalKey();

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _sigScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Move
      _sigOffset += details.focalPointDelta;

      // Scale (pinch)
      if (details.scale != 1.0) {
        _sigScale = (_baseScale * details.scale).clamp(0.15, 1.5);
      }
    });
  }

  Future<void> _saveComposite() async {
    setState(() => _isSaving = true);

    try {
      // Capture the composite widget as image
      final boundary = _compositeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(appDir.path, 'DocScanner', 'signed'));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final outPath = p.join(outDir.path,
          'signed_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(pngBytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dokumen + tanda tangan tersimpan!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Pop back to editor/home with the new path
      Navigator.pop(context, outPath);
    } catch (e) {
      debugPrint('Save composite error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Terapkan Tanda Tangan'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveComposite,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, color: AppColors.secondary),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instruction
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent1.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.pan_tool_rounded,
                    color: AppColors.accent2, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Geser tanda tangan • Cubit untuk resize',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.accent2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── COMPOSITE VIEW ─────────────────
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _compositeKey,
                child: Stack(
                  children: [
                    // Document image
                    Image.file(
                      File(widget.documentImagePath),
                      fit: BoxFit.contain,
                    ),

                    // Draggable + scalable signature
                    Positioned(
                      left: _sigOffset.dx,
                      top: _sigOffset.dy,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: Transform.scale(
                          scale: _sigScale,
                          child: Image.file(
                            File(widget.signaturePath),
                            width: 300,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── SIZE SLIDER ────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: AppColors.surfaceDark,
            child: Row(
              children: [
                const Icon(Icons.photo_size_select_small_rounded,
                    color: Colors.white54, size: 20),
                Expanded(
                  child: Slider(
                    value: _sigScale,
                    min: 0.15,
                    max: 1.5,
                    activeColor: AppColors.secondary,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _sigScale = v),
                  ),
                ),
                const Icon(Icons.photo_size_select_large_rounded,
                    color: Colors.white54, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
