import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../widgets/mode_selector.dart';

/// Camera screen with edge detection overlay, flash, and mode selector
class CameraScreen extends StatefulWidget {
  final String mode;
  const CameraScreen({super.key, this.mode = 'DOCUMENT'});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  int _selectedCameraIndex = 0;
  late String _selectedMode;
  final List<String> _capturedPages = []; // Batch mode
  late AnimationController _shutterAnimController;
  late Animation<double> _shutterScaleAnim;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.mode;
    WidgetsBinding.instance.addObserver(this);
    _shutterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _shutterScaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _shutterAnimController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _shutterAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _isCameraInitialized = true);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    setState(() => _isCameraInitialized = false);
    await _initCamera();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    _shutterAnimController.forward().then((_) => _shutterAnimController.reverse());

    try {
      final XFile image = await _controller!.takePicture();

      if (!mounted) return;

      // Navigate to crop/edit screen
      if (_selectedMode == 'ID CARD') {
        Navigator.pushNamed(context, AppRoutes.idCard);
      } else {
        _capturedPages.add(image.path);

        Navigator.pushNamed(
          context,
          AppRoutes.crop,
          arguments: image.path,
        );
      }
    } catch (e) {
      debugPrint('Error capturing: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          Positioned.fill(
            child: CameraPreview(_controller!),
          ),


          Positioned.fill(
            child: CustomPaint(
              painter: _ScanOverlayPainter(),
            ),
          ),


          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    _CircleButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: AppRadius.chipRadius,
                      ),
                      child: const Text(
                        'DocScanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    _CircleButton(
                      icon: _isFlashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onTap: _toggleFlash,
                      isActive: _isFlashOn,
                    ),
                  ],
                ),
              ),
            ),
          ),


          if (_capturedPages.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    borderRadius: AppRadius.chipRadius,
                  ),
                  child: Text(
                    '${_capturedPages.length} halaman diambil',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),


          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  ModeSelector(
                    selectedMode: _selectedMode,
                    onModeChanged: (mode) {
                      setState(() => _selectedMode = mode);
                    },
                  ),

                  const SizedBox(height: 24),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      _CircleButton(
                        icon: Icons.photo_library_rounded,
                        onTap: () {

                        },
                        size: 50,
                      ),

                      // Shutter Button
                      ScaleTransition(
                        scale: _shutterScaleAnim,
                        child: GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isCapturing
                                    ? Colors.grey
                                    : AppColors.shutterButton,
                              ),
                            ),
                          ),
                        ),
                      ),


                      _CircleButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: _switchCamera,
                        size: 50,
                      ),
                    ],
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

/// Circle button for camera controls
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isActive;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppColors.secondary.withValues(alpha: 0.3)
              : Colors.black38,
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.secondary : Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Visual scan guide overlay — draws a rounded rectangle in the center
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.edgeOverlay.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;


    final margin = size.width * 0.08;
    final top = size.height * 0.15;
    final bottom = size.height * 0.75;
    final rect = RRect.fromLTRBR(
      margin,
      top,
      size.width - margin,
      bottom,
      const Radius.circular(12),
    );

    canvas.drawRRect(rect, paint);


    final cornerPaint = Paint()
      ..color = AppColors.edgeOverlay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;


    canvas.drawLine(
      Offset(margin, top + cornerLength),
      Offset(margin, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(margin, top),
      Offset(margin + cornerLength, top),
      cornerPaint,
    );


    canvas.drawLine(
      Offset(size.width - margin - cornerLength, top),
      Offset(size.width - margin, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - margin, top),
      Offset(size.width - margin, top + cornerLength),
      cornerPaint,
    );


    canvas.drawLine(
      Offset(margin, bottom - cornerLength),
      Offset(margin, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(margin, bottom),
      Offset(margin + cornerLength, bottom),
      cornerPaint,
    );


    canvas.drawLine(
      Offset(size.width - margin - cornerLength, bottom),
      Offset(size.width - margin, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - margin, bottom),
      Offset(size.width - margin, bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
