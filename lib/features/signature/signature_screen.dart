import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../config/app_theme.dart';

/// E-Signature screen — draw signature, preview, and save as PNG
class SignatureScreen extends StatefulWidget {
  final String? pdfPath;

  const SignatureScreen({super.key, this.pdfPath});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late SignatureController _signatureController;
  Color _penColor = Colors.black;
  double _penWidth = 3.0;

  final List<Color> _colorOptions = [
    Colors.black,
    AppColors.primary,
    AppColors.accent2,
    AppColors.secondary,
    Colors.blue,
  ];

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: _penWidth,
      penColor: _penColor,
      exportBackgroundColor: Colors.white,
      exportPenColor: _penColor,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  void _changePenColor(Color color) {
    setState(() {
      _penColor = color;
      _signatureController = SignatureController(
        penStrokeWidth: _penWidth,
        penColor: color,
        exportBackgroundColor: Colors.white,
        exportPenColor: color,
        points: _signatureController.points,
      );
    });
  }

  void _changePenWidth(double width) {
    setState(() {
      _penWidth = width;
      _signatureController = SignatureController(
        penStrokeWidth: width,
        penColor: _penColor,
        exportBackgroundColor: Colors.white,
        exportPenColor: _penColor,
        points: _signatureController.points,
      );
    });
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan tanda tangan terlebih dahulu')),
      );
      return;
    }

    final Uint8List? signatureBytes =
        await _signatureController.toPngBytes(
      height: 400,
      width: 600,
    );

    if (signatureBytes == null) return;

    // Save to permanent app directory (not temp)
    final appDir = await getApplicationDocumentsDirectory();
    final sigDir = Directory(p.join(appDir.path, 'DocScanner', 'signatures'));
    if (!await sigDir.exists()) {
      await sigDir.create(recursive: true);
    }

    final filePath = p.join(sigDir.path,
        'signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(filePath).writeAsBytes(signatureBytes);

    if (!mounted) return;


    // Show preview dialog
    _showPreviewDialog(filePath);
  }

  void _showPreviewDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.secondary, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Tanda Tangan Tersimpan!',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview signature
            Container(
              height: 150,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tersimpan di: DocScanner/signatures/',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
            },
            child: const Text('Buat Lagi'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context, imagePath); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan'),
        actions: [
          TextButton(
            onPressed: _saveSignature,
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // ─── INSTRUCTION ────────────────────────
          Text(
            'Tanda tangan di area bawah',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // ─── SIGNATURE PAD ──────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.grey[50],
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── PEN CONTROLS ───────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              children: [
                // Color picker
                Row(
                  children: [
                    Text('Warna:', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 12),
                    ..._colorOptions.map((color) {
                      final isSelected = color == _penColor;
                      return GestureDetector(
                        onTap: () => _changePenColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 34 : 28,
                          height: isSelected ? 34 : 28,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 12),

                // Pen width slider
                Row(
                  children: [
                    Text('Tebal:', style: theme.textTheme.labelLarge),
                    Expanded(
                      child: Slider(
                        value: _penWidth,
                        min: 1,
                        max: 8,
                        divisions: 7,
                        activeColor: AppColors.primary,
                        onChanged: _changePenWidth,
                      ),
                    ),
                    Text(
                      '${_penWidth.toInt()}px',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── BOTTOM ACTIONS ─────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _signatureController.clear();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saveSignature,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan Tanda Tangan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
