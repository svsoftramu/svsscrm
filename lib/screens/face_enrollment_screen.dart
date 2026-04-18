import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../services/face_detection_service.dart';
import '../theme/app_theme.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _error;
  String? _capturedImagePath;
  Uint8List? _capturedBytes;
  FaceLandmarkData? _detectedLandmarks;
  int _step = 0; // 0=camera, 1=preview/confirm, 2=uploading

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras available');
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  Future<void> _capture() async {
    if (_isProcessing || _controller == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // On mobile, use file path for ML Kit
      if (!kIsWeb) {
        final result = await FaceDetectionService.instance.detectFace(image.path);

        if (!result.isValid) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _error = result.error;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _capturedImagePath = image.path;
            _capturedBytes = bytes;
            _detectedLandmarks = result.landmarks;
            _step = 1;
            _isProcessing = false;
          });
        }
      } else {
        // Web: skip ML Kit face detection, just capture
        if (mounted) {
          setState(() {
            _capturedBytes = bytes;
            _detectedLandmarks = null; // No ML Kit on web
            _step = 1;
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Capture failed: $e';
        });
      }
    }
  }

  Future<void> _confirmEnrollment() async {
    if (_capturedBytes == null) return;
    setState(() => _step = 2);

    try {
      final base64Image = base64Encode(_capturedBytes!);
      final meshJson = _detectedLandmarks?.toJson() ?? '[]';

      if (mounted) {
        await context.read<CRMProvider>().enrollFace(
          faceImage: base64Image,
          meshData: meshJson,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face enrolled successfully!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = 1;
          _error = 'Enrollment failed: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _step = 0;
      _capturedImagePath = null;
      _capturedBytes = null;
      _detectedLandmarks = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Clean up temp file
    if (_capturedImagePath != null && !kIsWeb) {
      try { File(_capturedImagePath!).delete(); } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Face Enrollment', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _step == 0
          ? _buildCameraStep()
          : _step == 1
              ? _buildPreviewStep()
              : _buildUploadingStep(),
    );
  }

  Widget _buildCameraStep() {
    if (_error != null && !_isInitialized) {
      return _buildErrorWidget(_error!);
    }
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5));
    }

    return Column(
      children: [
        // Instructions
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 18),
                SizedBox(width: 8),
                Text('Enrollment Instructions', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
              SizedBox(height: 8),
              Text(
                '1. Look straight at the camera\n2. Ensure good, even lighting\n3. Remove sunglasses or masks\n4. Keep a neutral expression',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        // Camera
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CameraPreview(_controller!),
                ),
              ),
              Container(
                width: 220, height: 290,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 3),
                  borderRadius: BorderRadius.circular(110),
                ),
              ),
            ],
          ),
        ),
        // Error message
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
              ],
            ),
          ),
        // Capture button
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 16, 40, 40),
          child: GestureDetector(
            onTap: _isProcessing ? null : _capture,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
                gradient: LinearGradient(
                  colors: _isProcessing
                      ? [Colors.grey, Colors.grey.shade700]
                      : [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: _isProcessing
                  ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return Column(
      children: [
        // Success indicator
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                _detectedLandmarks != null
                    ? 'Face detected with ${_detectedLandmarks!.points.length} landmarks'
                    : 'Photo captured (web mode)',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        // Preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _capturedBytes != null
                  ? Image.memory(_capturedBytes!, fit: BoxFit.cover)
                  : const SizedBox(),
            ),
          ),
        ),
        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _confirmEnrollment,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadingStep() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 20),
          Text('Enrolling your face...', style: TextStyle(color: Colors.white70, fontSize: 15)),
          SizedBox(height: 4),
          Text('Please wait', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white30),
            const SizedBox(height: 20),
            Text(error, style: const TextStyle(color: Colors.white60, fontSize: 15), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
