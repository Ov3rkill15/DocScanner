import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../services/image_processing_service.dart';

/// ID Card Mode — captures front & back, then composites into a single image
class IdCardScreen extends StatefulWidget {
  const IdCardScreen({super.key});

  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  String? _frontImagePath;
  String? _backImagePath;
  int _currentStep = 0; // 0 = front, 1 = back, 2 = preview

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras[0], ResolutionPreset.high,
        enableAudio: false);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isCameraReady = true);
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();

    setState(() {
      if (_currentStep == 0) {
        _frontImagePath = image.path;
        _currentStep = 1;
      } else if (_currentStep == 1) {
        _backImagePath = image.path;
        _currentStep = 2;
        _processComposite();
      }
    });
  }

  Future<void> _processComposite() async {
    if (_frontImagePath == null || _backImagePath == null) return;

    try {
      final service = ImageProcessingService();
      final compositePath = await service.compositeVertical(
        _frontImagePath!,
        _backImagePath!,
      );

      if (!mounted) return;

      // Navigate to editor with the composite
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.editor,
        arguments: {
          'imagePaths': [compositePath],
        },
      );
    } catch (e) {
      debugPrint('Composite error: $e');
    }
  }

  void _retake() {
    setState(() {
      if (_currentStep == 1) {
        _currentStep = 0;
        _frontImagePath = null;
      } else if (_currentStep == 2) {
        _currentStep = 1;
        _backImagePath = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Mode KTP/KTM'),
      ),
      body: Column(
        children: [
          // ─── STEP INDICATOR ─────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StepIndicator(
                  step: 1,
                  label: 'Depan',
                  isActive: _currentStep == 0,
                  isCompleted: _currentStep > 0,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep > 0 ? AppColors.secondary : Colors.white24,
                  ),
                ),
                _StepIndicator(
                  step: 2,
                  label: 'Belakang',
                  isActive: _currentStep == 1,
                  isCompleted: _currentStep > 1,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep > 1 ? AppColors.secondary : Colors.white24,
                  ),
                ),
                _StepIndicator(
                  step: 3,
                  label: 'Selesai',
                  isActive: _currentStep == 2,
                  isCompleted: false,
                ),
              ],
            ),
          ),

          // ─── INSTRUCTION ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              _currentStep == 0
                  ? 'Foto sisi DEPAN kartu identitas'
                  : _currentStep == 1
                      ? 'Balik kartu, lalu foto sisi BELAKANG'
                      : 'Memproses komposit...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ─── CAMERA / PREVIEW ───────────────────
          Expanded(
            child: _currentStep == 2
                ? _buildProcessingView()
                : _isCameraReady
                    ? Stack(
                        children: [
                          // Camera
                          Center(
                            child: AspectRatio(
                              aspectRatio: 85.6 / 53.98, // ID card ratio
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),

                          // ID card guide overlay
                          Center(
                            child: AspectRatio(
                              aspectRatio: 85.6 / 53.98,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: AppColors.edgeOverlay,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Captured front preview (when capturing back)
                          if (_currentStep == 1 && _frontImagePath != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 100,
                                height: 63,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.secondary,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(_frontImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.secondary),
                      ),
          ),

          // ─── BOTTOM CONTROLS ────────────────────
          if (_currentStep < 2)
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_currentStep == 1)
                    IconButton(
                      onPressed: _retake,
                      icon: const Icon(Icons.undo_rounded,
                          color: Colors.white, size: 30),
                    ),
                  // Shutter
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.shutterButton,
                        ),
                        child: const Icon(
                          Icons.credit_card_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  if (_currentStep == 1)
                    const SizedBox(width: 48),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.secondary),
          SizedBox(height: 16),
          Text(
            'Menggabungkan sisi depan & belakang...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepIndicator({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? AppColors.secondary
        : isActive
            ? AppColors.primary
            : Colors.white24;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
