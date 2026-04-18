import 'dart:convert';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePoint {
  final double x, y;
  FacePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory FacePoint.fromJson(Map<String, dynamic> json) =>
      FacePoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  double distanceTo(FacePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}

class FaceLandmarkData {
  final List<FacePoint> points;

  FaceLandmarkData(this.points);

  String toJson() => jsonEncode(points.map((p) => p.toJson()).toList());

  factory FaceLandmarkData.fromJson(String json) {
    final list = (jsonDecode(json) as List)
        .map((e) => FacePoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return FaceLandmarkData(list);
  }

  /// Normalize landmarks: translate centroid to origin, scale by inter-eye distance
  FaceLandmarkData normalize() {
    if (points.length < 2) return this;

    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= points.length;
    cy /= points.length;

    final translated = points.map((p) => FacePoint(p.x - cx, p.y - cy)).toList();

    final dx = translated[0].x - translated[1].x;
    final dy = translated[0].y - translated[1].y;
    double scale = sqrt(dx * dx + dy * dy);
    if (scale < 1.0) scale = 1.0;

    return FaceLandmarkData(
      translated.map((p) => FacePoint(p.x / scale, p.y / scale)).toList(),
    );
  }

  /// Compute geometric ratios that are unique to a person's face structure
  /// These ratios are scale/translation invariant and more discriminative
  List<double> _computeFaceRatios() {
    if (points.length < 10) return [];

    // Points order: leftEye(0), rightEye(1), noseBase(2), leftMouth(3),
    //               rightMouth(4), bottomMouth(5), leftEar(6), rightEar(7),
    //               leftCheek(8), rightCheek(9)
    final leftEye = points[0];
    final rightEye = points[1];
    final noseBase = points[2];
    final leftMouth = points[3];
    final rightMouth = points[4];
    final bottomMouth = points[5];

    final interEyeDist = leftEye.distanceTo(rightEye);
    if (interEyeDist < 1.0) return [];

    // Compute discriminative ratios normalized by inter-eye distance
    final ratios = <double>[
      // Eye-to-nose ratios
      leftEye.distanceTo(noseBase) / interEyeDist,
      rightEye.distanceTo(noseBase) / interEyeDist,
      // Eye-to-mouth ratios
      leftEye.distanceTo(leftMouth) / interEyeDist,
      rightEye.distanceTo(rightMouth) / interEyeDist,
      // Nose-to-mouth ratio
      noseBase.distanceTo(bottomMouth) / interEyeDist,
      // Mouth width ratio
      leftMouth.distanceTo(rightMouth) / interEyeDist,
      // Face height ratio (eye midpoint to bottom mouth)
      FacePoint((leftEye.x + rightEye.x) / 2, (leftEye.y + rightEye.y) / 2)
              .distanceTo(bottomMouth) /
          interEyeDist,
      // Nose bridge length (eye midpoint to nose)
      FacePoint((leftEye.x + rightEye.x) / 2, (leftEye.y + rightEye.y) / 2)
              .distanceTo(noseBase) /
          interEyeDist,
    ];

    // Add ear/cheek ratios if available
    if (points.length > 7) {
      final leftEar = points[6];
      final rightEar = points[7];
      ratios.add(leftEar.distanceTo(rightEar) / interEyeDist); // Face width
      ratios.add(leftEar.distanceTo(noseBase) / interEyeDist);
      ratios.add(rightEar.distanceTo(noseBase) / interEyeDist);
    }
    if (points.length > 9) {
      final leftCheek = points[8];
      final rightCheek = points[9];
      ratios.add(leftCheek.distanceTo(rightCheek) / interEyeDist);
      ratios.add(leftCheek.distanceTo(noseBase) / interEyeDist);
      ratios.add(rightCheek.distanceTo(noseBase) / interEyeDist);
    }

    return ratios;
  }

  /// Compare with another face using geometric ratios + contour shape
  /// Returns similarity percentage (0-100), 100 = identical
  double similarityTo(FaceLandmarkData other) {
    if (points.isEmpty || other.points.isEmpty) return 0.0;

    // --- Part 1: Geometric ratio comparison (weight: 60%) ---
    final ratiosA = _computeFaceRatios();
    final ratiosB = other._computeFaceRatios();
    double ratioScore = 0.0;

    if (ratiosA.isNotEmpty && ratiosB.isNotEmpty) {
      final count = min(ratiosA.length, ratiosB.length);
      double totalDiff = 0;
      for (int i = 0; i < count; i++) {
        // Percentage difference for each ratio
        final avg = (ratiosA[i].abs() + ratiosB[i].abs()) / 2;
        if (avg > 0.01) {
          totalDiff += (ratiosA[i] - ratiosB[i]).abs() / avg;
        }
      }
      final avgDiff = totalDiff / count;
      // avgDiff=0 → 100%, avgDiff=0.5 → ~22%, avgDiff=0.3 → ~41%
      ratioScore = 100.0 * exp(-3.0 * avgDiff);
    }

    // --- Part 2: Normalized contour point comparison (weight: 40%) ---
    final normA = normalize();
    final normB = other.normalize();
    final count = min(normA.points.length, normB.points.length);
    double contourScore = 0.0;

    if (count >= 5) {
      double totalDist = 0;
      for (int i = 0; i < count; i++) {
        final dx = normA.points[i].x - normB.points[i].x;
        final dy = normA.points[i].y - normB.points[i].y;
        totalDist += sqrt(dx * dx + dy * dy);
      }
      final avgDist = totalDist / count;
      // Steeper decay: k=5 instead of k=3 for stricter matching
      contourScore = 100.0 * exp(-5.0 * avgDist);
    }

    // Weighted combination
    final combined = (ratioScore * 0.6) + (contourScore * 0.4);
    return combined.clamp(0.0, 100.0);
  }
}

/// Liveness check state for multi-step challenge
/// Uses head movement (turn head) which works reliably with still images
/// unlike blink detection which requires video stream classification
enum LivenessStep {
  lookStraight,  // Step 1: Detect face looking straight
  turnHead,      // Step 2: Turn head to one side
  returnCenter,  // Step 3: Return to center (proves real movement)
  done,          // All steps passed
}

class LivenessState {
  LivenessStep currentStep;
  int stableFrames;
  double? baselineYaw; // Yaw when looking straight

  LivenessState()
      : currentStep = LivenessStep.lookStraight,
        stableFrames = 0,
        baselineYaw = null;

  void reset() {
    currentStep = LivenessStep.lookStraight;
    stableFrames = 0;
    baselineYaw = null;
  }

  String get instruction {
    switch (currentStep) {
      case LivenessStep.lookStraight:
        return 'Look straight at the camera';
      case LivenessStep.turnHead:
        return 'Slowly turn your head to the right';
      case LivenessStep.returnCenter:
        return 'Now look back at the camera';
      case LivenessStep.done:
        return 'Liveness verified!';
    }
  }
}

class FaceDetectionResult {
  final bool faceDetected;
  final bool isValid;
  final String? error;
  final FaceLandmarkData? landmarks;
  final double? leftEyeOpenProb;
  final double? rightEyeOpenProb;
  final double? smilingProb;
  final double? headEulerAngleY; // yaw (left-right)
  final double? headEulerAngleZ; // roll (tilt)

  FaceDetectionResult({
    required this.faceDetected,
    required this.isValid,
    this.error,
    this.landmarks,
    this.leftEyeOpenProb,
    this.rightEyeOpenProb,
    this.smilingProb,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });

  bool get eyesOpen =>
      (leftEyeOpenProb ?? 1.0) > 0.5 && (rightEyeOpenProb ?? 1.0) > 0.5;

  bool get eyesClosed =>
      (leftEyeOpenProb ?? 1.0) < 0.3 && (rightEyeOpenProb ?? 1.0) < 0.3;

  bool get isFacingStraight =>
      (headEulerAngleY ?? 0).abs() < 25 && (headEulerAngleZ ?? 0).abs() < 15;
}

class FaceDetectionService {
  static final FaceDetectionService instance = FaceDetectionService._();
  FaceDetectionService._();

  FaceDetector? _detector;

  FaceDetector get detector {
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true, // eye open & smile probabilities
        enableTracking: true,       // head euler angles
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    return _detector!;
  }

  /// Detect face and extract landmarks + classification from image file
  Future<FaceDetectionResult> detectFace(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await detector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(
          faceDetected: false,
          isValid: false,
          error: 'No face detected. Please position your face clearly.',
        );
      }

      if (faces.length > 1) {
        return FaceDetectionResult(
          faceDetected: true,
          isValid: false,
          error: 'Multiple faces detected. Only one face allowed.',
        );
      }

      final face = faces.first;
      final landmarks = _extractLandmarks(face);

      if (landmarks.points.length < 5) {
        return FaceDetectionResult(
          faceDetected: true,
          isValid: false,
          error: 'Could not detect face clearly. Try better lighting.',
        );
      }

      return FaceDetectionResult(
        faceDetected: true,
        isValid: true,
        landmarks: landmarks,
        leftEyeOpenProb: face.leftEyeOpenProbability,
        rightEyeOpenProb: face.rightEyeOpenProbability,
        smilingProb: face.smilingProbability,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
      );
    } catch (e) {
      return FaceDetectionResult(
        faceDetected: false,
        isValid: false,
        error: 'Face detection error: $e',
      );
    }
  }

  /// Extract key facial landmarks + contour points
  FaceLandmarkData _extractLandmarks(Face face) {
    final points = <FacePoint>[];

    // Key landmarks (order matters - left eye and right eye MUST be first two)
    final landmarkTypes = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
    ];

    for (final type in landmarkTypes) {
      final lm = face.landmarks[type];
      if (lm != null) {
        points.add(FacePoint(lm.position.x.toDouble(), lm.position.y.toDouble()));
      }
    }

    // Add contour points for more precise matching
    final contourTypes = [
      FaceContourType.face,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
      FaceContourType.noseBridge,
      FaceContourType.noseBottom,
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
    ];

    for (final type in contourTypes) {
      final contour = face.contours[type];
      if (contour != null) {
        for (final pt in contour.points) {
          points.add(FacePoint(pt.x.toDouble(), pt.y.toDouble()));
        }
      }
    }

    return FaceLandmarkData(points);
  }

  /// Get similarity percentage between two faces (0-100%)
  double getSimilarity(FaceLandmarkData reference, FaceLandmarkData captured) {
    final normRef = reference.normalize();
    final normCap = captured.normalize();
    return normRef.similarityTo(normCap);
  }

  /// Check if faces match with minimum similarity threshold (default 85%)
  bool isMatch(FaceLandmarkData reference, FaceLandmarkData captured,
      {double minSimilarity = 85.0}) {
    final similarity = getSimilarity(reference, captured);
    return similarity >= minSimilarity;
  }

  /// Update liveness state based on a detection result
  /// Uses head yaw angle to detect real head movement (works with still images)
  /// Returns true when all liveness steps are complete
  bool updateLiveness(LivenessState state, FaceDetectionResult result) {
    if (!result.isValid) return false;

    final yaw = result.headEulerAngleY ?? 0.0;

    switch (state.currentStep) {
      case LivenessStep.lookStraight:
        // Must be roughly facing camera (yaw within +-15 degrees)
        if (yaw.abs() < 15) {
          state.stableFrames++;
          if (state.stableFrames >= 2) {
            state.baselineYaw = yaw;
            state.currentStep = LivenessStep.turnHead;
            state.stableFrames = 0;
          }
        } else {
          state.stableFrames = 0;
        }
        return false;

      case LivenessStep.turnHead:
        // Head must turn at least 20 degrees from baseline to one side
        final baseline = state.baselineYaw ?? 0.0;
        final delta = (yaw - baseline).abs();
        if (delta > 20) {
          state.stableFrames++;
          if (state.stableFrames >= 1) {
            state.currentStep = LivenessStep.returnCenter;
            state.stableFrames = 0;
          }
        } else {
          state.stableFrames = 0;
        }
        return false;

      case LivenessStep.returnCenter:
        // Must return to roughly center (within +-15 degrees)
        if (yaw.abs() < 15) {
          state.stableFrames++;
          if (state.stableFrames >= 1) {
            state.currentStep = LivenessStep.done;
            return true;
          }
        } else {
          state.stableFrames = 0;
        }
        return false;

      case LivenessStep.done:
        return true;
    }
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
