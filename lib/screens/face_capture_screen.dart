import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/face_detection_service.dart';
import '../theme/app_theme.dart';

class FaceCaptureResult {
  final String base64Image;
  final double? matchScore;
  final String? meshJson;
  FaceCaptureResult({required this.base64Image, this.matchScore, this.meshJson});
}

class FaceCaptureScreen extends StatefulWidget {
  final String action;
  final String? referenceMeshJson;

  const FaceCaptureScreen({super.key, required this.action, this.referenceMeshJson});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _verified = false;
  String? _error;
  String _statusText = 'Initializing camera...';
  Timer? _autoScanTimer;
  int _retryCount = 0;
  late AnimationController _pulseController;

  // Liveness state
  final LivenessState _livenessState = LivenessState();
  bool _livenessComplete = false;
  String? _capturedBase64; // Store the image captured after liveness passes
  String? _capturedMeshJson; // Store mesh for server-side verification

  static const double _matchThreshold = 85.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras available on this device');
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusText = _livenessState.instruction;
        });
        // Start auto-scanning
        _autoScanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) => _autoScan());
        Future.delayed(const Duration(seconds: 1), () => _autoScan());
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: ${e.toString()}');
    }
  }

  Future<void> _autoScan() async {
    if (_isProcessing || _verified || _controller == null || !_controller!.value.isInitialized || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      double? matchScore;

      if (kIsWeb) {
        // On web: ML Kit not available, capture image only
        if (mounted) setState(() => _faceDetected = true);
        _livenessComplete = true;
        matchScore = null;
        final base64Image = base64Encode(bytes);
        _capturedBase64 = base64Image;
      } else {
        // On Android: full face detection + liveness + matching
        final result = await FaceDetectionService.instance.detectFace(image.path);

        if (!result.isValid) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _faceDetected = false;
              _statusText = result.error ?? 'No face detected. Position your face in the frame.';
            });
          }
          try { await File(image.path).delete(); } catch (_) {}
          return;
        }

        // Face detected
        if (mounted) setState(() => _faceDetected = true);

        // --- Liveness check ---
        if (!_livenessComplete) {
          final passed = FaceDetectionService.instance.updateLiveness(_livenessState, result);

          if (!passed) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _statusText = _livenessState.instruction;
              });
            }
            try { await File(image.path).delete(); } catch (_) {}
            return;
          }

          // Liveness passed!
          _livenessComplete = true;
          if (mounted) {
            setState(() => _statusText = 'Liveness verified! Checking face...');
          }
        }

        // --- Face matching (only after liveness passes) ---
        final base64Image = base64Encode(bytes);

        if (widget.referenceMeshJson != null && widget.referenceMeshJson!.isNotEmpty && widget.referenceMeshJson != '[]') {
          try {
            final referenceMesh = FaceLandmarkData.fromJson(widget.referenceMeshJson!);
            final capturedMesh = result.landmarks!;
            final similarity = FaceDetectionService.instance.getSimilarity(referenceMesh, capturedMesh);
            matchScore = similarity;

            if (similarity < _matchThreshold) {
              _retryCount++;
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _faceDetected = true;
                  _statusText = 'Match: ${similarity.toStringAsFixed(0)}% (need ${_matchThreshold.toInt()}%). Retry $_retryCount/10';
                });
              }
              try { await File(image.path).delete(); } catch (_) {}

              if (_retryCount >= 10) {
                _autoScanTimer?.cancel();
                if (mounted) {
                  setState(() {
                    _error = 'Face verification failed. Your face does not match the enrolled face (${similarity.toStringAsFixed(0)}% match, need ${_matchThreshold.toInt()}%).';
                    _statusText = 'Verification failed';
                  });
                }
              }
              return;
            }

            // Match successful
            if (mounted) {
              setState(() => _statusText = 'Match: ${similarity.toStringAsFixed(0)}%');
            }
          } catch (e) {
            debugPrint('Face comparison error: $e');
          }
        }

        _capturedBase64 = base64Image;
        _capturedMeshJson = result.landmarks?.toJson();
        try { await File(image.path).delete(); } catch (_) {}
      }

      // Success! Stop scanning and return
      _autoScanTimer?.cancel();
      if (mounted) {
        setState(() {
          _verified = true;
          _statusText = matchScore != null
              ? 'Verified! ${matchScore.toStringAsFixed(0)}% match'
              : 'Face captured! Processing...';
        });

        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted && _capturedBase64 != null) {
          Navigator.pop(context, FaceCaptureResult(base64Image: _capturedBase64!, matchScore: matchScore, meshJson: _capturedMeshJson));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = _livenessComplete ? 'Scanning...' : _livenessState.instruction;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.action == 'check_in';
    final accentColor = isCheckIn ? AppColors.success : AppColors.error;

    // Border color based on state
    Color borderColor;
    if (_verified) {
      borderColor = AppColors.success;
    } else if (_livenessComplete) {
      borderColor = AppColors.primary;
    } else if (_faceDetected) {
      borderColor = AppColors.warning;
    } else {
      borderColor = accentColor;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isCheckIn ? 'Face Check In' : 'Face Check Out',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _error != null && !_isInitialized
          ? _buildErrorState(_error!)
          : !_isInitialized
              ? _buildLoadingState()
              : Column(
                  children: [
                    // Liveness step indicator
                    if (!_verified)
                      _buildLivenessIndicator(),

                    // Camera preview
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.2), blurRadius: 24)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CameraPreview(_controller!),
                            ),
                          ),
                          // Face guide oval - animated
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, child) {
                              final pulseVal = _pulseController.value;
                              return Container(
                                width: 220,
                                height: 290,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _verified
                                        ? AppColors.success
                                        : borderColor.withValues(alpha: 0.4 + (pulseVal * 0.5)),
                                    width: _verified ? 4 : 3,
                                  ),
                                  borderRadius: BorderRadius.circular(110),
                                ),
                                child: _verified
                                    ? const Center(
                                        child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                                      )
                                    : null,
                              );
                            },
                          ),
                          // Top status bar
                          Positioned(
                            top: 36,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isProcessing && !_verified)
                                    const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                                    )
                                  else
                                    Icon(
                                      _verified ? Icons.check_circle_rounded
                                          : _livenessComplete ? Icons.verified_user_rounded
                                          : _faceDetected ? Icons.face_rounded
                                          : Icons.face_retouching_off_rounded,
                                      size: 16,
                                      color: _verified ? AppColors.success
                                          : _livenessComplete ? AppColors.primary
                                          : _faceDetected ? AppColors.warning
                                          : Colors.white54,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _statusText,
                                    style: TextStyle(
                                      color: _verified ? AppColors.success : Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Scanning indicator at bottom
                          if (_isProcessing && !_verified)
                            Positioned(
                              bottom: 30,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _livenessComplete ? 'Verifying face...' : 'Checking liveness...',
                                      style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Error / retry area
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _error = null;
                                    _retryCount = 0;
                                    _livenessState.reset();
                                    _livenessComplete = false;
                                    _capturedBase64 = null;
                                    _statusText = _livenessState.instruction;
                                    _faceDetected = false;
                                  });
                                  _autoScanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) => _autoScan());
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Bottom info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Text(
                        _verified ? 'Verified successfully!'
                            : _error != null ? ''
                            : 'Hold still. Liveness check in progress.',
                        style: TextStyle(
                          color: _verified ? AppColors.success : Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLivenessIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildStepDot(
            label: 'Face',
            done: _livenessState.currentStep.index > 0 || _livenessComplete,
            active: _livenessState.currentStep == LivenessStep.lookStraight,
          ),
          _buildStepConnector(done: _livenessState.currentStep.index > 0 || _livenessComplete),
          _buildStepDot(
            label: 'Turn',
            done: _livenessState.currentStep.index > 1 || _livenessComplete,
            active: _livenessState.currentStep == LivenessStep.turnHead,
          ),
          _buildStepConnector(done: _livenessState.currentStep.index > 2 || _livenessComplete),
          _buildStepDot(
            label: 'Return',
            done: _livenessComplete,
            active: _livenessState.currentStep == LivenessStep.returnCenter,
          ),
          _buildStepConnector(done: _livenessComplete),
          _buildStepDot(
            label: 'Verify',
            done: _verified,
            active: _livenessComplete && !_verified,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot({required String label, required bool done, required bool active}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppColors.success
                  : active
                      ? AppColors.warning
                      : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: done
                    ? AppColors.success
                    : active
                        ? AppColors.warning
                        : Colors.white24,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : active
                    ? const Icon(Icons.radio_button_unchecked, size: 10, color: Colors.white)
                    : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: done
                  ? AppColors.success
                  : active
                      ? AppColors.warning
                      : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool done}) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: done ? AppColors.success.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Starting camera...', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
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
              onPressed: () => Navigator.pop(context, null),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
