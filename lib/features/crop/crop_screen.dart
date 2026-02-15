import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../services/image_processing_service.dart';

/// Crop screen with 4 draggable corner points + zoom magnifier lens
class CropScreen extends StatefulWidget {
  final String imagePath;
  const CropScreen({super.key, required this.imagePath});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  // 4 corner points (normalized 0.0 - 1.0)
  List<Offset> _corners = [
    const Offset(0.1, 0.1), // Top-left
    const Offset(0.9, 0.1), // Top-right
    const Offset(0.9, 0.9), // Bottom-right
    const Offset(0.1, 0.9), // Bottom-left
  ];

  int? _activeCornerIndex;
  Size _imageDisplaySize = Size.zero;
  bool _isProcessing = false;

  // For magnifier
  Offset? _activeCornerScreenPos; // screen position of dragged corner
  final double _magnifierSize = 120;
  final double _magnifierZoom = 2.5;

  final GlobalKey _imageKey = GlobalKey();

  void _updateImageMetrics() {
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _imageDisplaySize = renderBox.size;
    }
  }

  void _onCornerDragStart(int index, DragStartDetails details) {
    _updateImageMetrics();
    setState(() {
      _activeCornerIndex = index;
      _activeCornerScreenPos = details.globalPosition;
    });
  }

  void _onCornerDragUpdate(int index, DragUpdateDetails details) {
    if (_imageDisplaySize.width == 0) return;

    final dx = details.delta.dx / _imageDisplaySize.width;
    final dy = details.delta.dy / _imageDisplaySize.height;

    setState(() {
      _corners[index] = Offset(
        (_corners[index].dx + dx).clamp(0.0, 1.0),
        (_corners[index].dy + dy).clamp(0.0, 1.0),
      );
      _activeCornerScreenPos = details.globalPosition;
    });
  }

  void _onCornerDragEnd(int index) {
    setState(() {
      _activeCornerIndex = null;
      _activeCornerScreenPos = null;
    });
  }

  void _resetCorners() {
    setState(() {
      _corners = [
        const Offset(0.1, 0.1),
        const Offset(0.9, 0.1),
        const Offset(0.9, 0.9),
        const Offset(0.1, 0.9),
      ];
    });
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);

    try {
      final imageFile = File(widget.imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      final imgWidth = decodedImage.width;
      final imgHeight = decodedImage.height;

      double minX = _corners.map((c) => c.dx).reduce((a, b) => a < b ? a : b);
      double maxX = _corners.map((c) => c.dx).reduce((a, b) => a > b ? a : b);
      double minY = _corners.map((c) => c.dy).reduce((a, b) => a < b ? a : b);
      double maxY = _corners.map((c) => c.dy).reduce((a, b) => a > b ? a : b);

      final cropX = (minX * imgWidth).round();
      final cropY = (minY * imgHeight).round();
      final cropW = ((maxX - minX) * imgWidth).round();
      final cropH = ((maxY - minY) * imgHeight).round();

      final service = ImageProcessingService();
      final croppedPath = await service.cropImage(
        widget.imagePath,
        x: cropX,
        y: cropY,
        width: cropW.clamp(1, imgWidth - cropX),
        height: cropH.clamp(1, imgHeight - cropY),
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.editor,
        arguments: {
          'imagePaths': [croppedPath],
        },
      );
    } catch (e) {
      debugPrint('Crop error: $e');
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.editor,
        arguments: {
          'imagePaths': [widget.imagePath],
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop & Luruskan'),
        actions: [
          TextButton(
            onPressed: _resetCorners,
            child: const Text('Reset',
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── IMAGE WITH CROP OVERLAY + MAGNIFIER ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Image
                    Center(
                      child: Image.file(
                        File(widget.imagePath),
                        key: _imageKey,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Crop Overlay
                    if (_imageDisplaySize.width > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CropOverlayPainter(
                            corners: _corners,
                            activeIndex: _activeCornerIndex,
                          ),
                        ),
                      ),

                    // Draggable Corner Points
                    ..._buildCornerHandles(constraints),

                    // ─── ZOOM MAGNIFIER LENS ──────────
                    if (_activeCornerIndex != null &&
                        _activeCornerScreenPos != null)
                      _buildMagnifier(constraints),
                  ],
                );
              },
            ),
          ),

          // ─── BOTTOM ACTIONS ──────────────────
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: AppRadius.sheetRadius,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white),
                    label: const Text('Ulang',
                        style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.buttonRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _applyCrop,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label:
                        Text(_isProcessing ? 'Memproses...' : 'Terapkan'),
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

  /// Builds the zoom magnifier positioned above the active corner
  Widget _buildMagnifier(BoxConstraints constraints) {
    final corner = _corners[_activeCornerIndex!];
    final cornerX = corner.dx * constraints.maxWidth;
    final cornerY = corner.dy * constraints.maxHeight;

    // Position magnifier above the corner (offset upward so it doesn't
    // hide under the user's finger)
    final magLeft =
        (cornerX - _magnifierSize / 2).clamp(4.0, constraints.maxWidth - _magnifierSize - 4);
    final magTop = cornerY - _magnifierSize - 50; // 50px above finger
    final clampedTop = magTop.clamp(4.0, constraints.maxHeight - _magnifierSize - 4);

    // Calculate what region of the image to show (centered on corner)
    // The source rect is the area on the displayed image that maps to
    // the magnifier viewport
    final viewportHalf = _magnifierSize / (2 * _magnifierZoom);
    final srcLeft = cornerX - viewportHalf;
    final srcTop = cornerY - viewportHalf;

    return Positioned(
      left: magLeft,
      top: clampedTop,
      child: IgnorePointer(
        child: Container(
          width: _magnifierSize,
          height: _magnifierSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.secondary,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // Zoomed image
                Positioned(
                  left: -srcLeft * _magnifierZoom,
                  top: -srcTop * _magnifierZoom,
                  child: SizedBox(
                    width: constraints.maxWidth * _magnifierZoom,
                    height: constraints.maxHeight * _magnifierZoom,
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Crosshair overlay
                Center(
                  child: CustomPaint(
                    size: Size(_magnifierSize, _magnifierSize),
                    painter: _CrosshairPainter(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerHandles(BoxConstraints constraints) {
    // Ensure image metrics are up to date
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateImageMetrics());

    return List.generate(4, (index) {
      final corner = _corners[index];
      final x = corner.dx * constraints.maxWidth;
      final y = corner.dy * constraints.maxHeight;
      final isActive = _activeCornerIndex == index;

      return Positioned(
        left: x - 20,
        top: y - 20,
        child: GestureDetector(
          onPanStart: (d) => _onCornerDragStart(index, d),
          onPanUpdate: (d) => _onCornerDragUpdate(index, d),
          onPanEnd: (_) => _onCornerDragEnd(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.secondary
                  : AppColors.secondary.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary
                      .withValues(alpha: isActive ? 0.5 : 0.3),
                  blurRadius: isActive ? 16 : 8,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Crosshair overlay for the magnifier center
class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final armLen = 10.0;

    // Horizontal
    canvas.drawLine(
        Offset(cx - armLen, cy), Offset(cx + armLen, cy), paint);
    // Vertical
    canvas.drawLine(
        Offset(cx, cy - armLen), Offset(cx, cy + armLen), paint);

    // Small center dot
    canvas.drawCircle(
      Offset(cx, cy),
      2,
      Paint()..color = AppColors.secondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws crop lines connecting the 4 corners
class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final int? activeIndex;

  _CropOverlayPainter({required this.corners, this.activeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final points = corners
        .map((c) => Offset(c.dx * size.width, c.dy * size.height))
        .toList();

    // Draw filled overlay outside the crop area
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    // Dim outside area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final combinedPath =
        Path.combine(PathOperation.difference, outerPath, path);
    canvas.drawPath(combinedPath, overlayPaint);

    // Draw border lines
    final linePaint = Paint()
      ..color = AppColors.edgeOverlay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(points[0], points[1], linePaint);
    canvas.drawLine(points[1], points[2], linePaint);
    canvas.drawLine(points[2], points[3], linePaint);
    canvas.drawLine(points[3], points[0], linePaint);

    // Draw grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = AppColors.edgeOverlay.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 1; i < 3; i++) {
      final t = i / 3;
      // Horizontal
      final left = Offset.lerp(points[0], points[3], t)!;
      final right = Offset.lerp(points[1], points[2], t)!;
      canvas.drawLine(left, right, gridPaint);
      // Vertical
      final top = Offset.lerp(points[0], points[1], t)!;
      final bottom = Offset.lerp(points[3], points[2], t)!;
      canvas.drawLine(top, bottom, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) => true;
}
