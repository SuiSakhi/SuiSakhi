import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/measurement.dart';

/// How far the person is from the camera.
enum DistanceCategory { tooFar, tooClose, perfect, unknown }

/// Converts ML Kit pose landmarks into real-world body measurements.
///
/// Auto-height method (no manual input):
///   - Uses shoulder width as a scale reference (avg female shoulder ≈ 38 cm).
///   - Estimates crown position from nose + neck-to-nose offset.
///   - height_cm = pixel_body_height × (38 / pixel_shoulder_width)
///
/// Distance estimation:
///   - Measures the body pixel height as a fraction of the image height.
///   - Too far  : body < 50% of frame height
///   - Perfect  : body 55–85% of frame height
///   - Too close: body > 85% of frame height
///
/// Circumference formulas (front-view only):
///   Simplified multipliers tuned to average body proportions.
class BodyMeasurementCalculator {
  static const double _chestMultiplier = 2.95;  // chest_circ = shoulder_width × 2.95
  static const double _waistMultiplier = 2.65;  // waist_circ  = waist_width   × 2.65
  static const double _hipMultiplier = 3.05;    // hip_circ    = hip_width     × 3.05
  static const double _thighMultiplier = 1.6;   // thigh_circ  = thigh_width   × 1.6
  static const double _neckMultiplier = 1.75;   // neck_circ   = ear_dist      × 1.75

  // Average female shoulder width used as auto-scale reference
  static const double _avgShoulderCm = 38.0;

  /// Vertical span from estimated crown to ankles (must match [estimateHeightCm]).
  /// Used to convert pixels → cm so calibration matches the stored height value.
  static double? _verticalBodySpanPx(Pose pose) {
    final lm = pose.landmarks;
    final nose = lm[PoseLandmarkType.nose];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final rAnkle = lm[PoseLandmarkType.rightAnkle];
    final lEye = lm[PoseLandmarkType.leftEye];
    final rEye = lm[PoseLandmarkType.rightEye];

    if (nose == null || lShoulder == null || rShoulder == null || lAnkle == null) {
      return null;
    }

    final double headTopY;
    if (lEye != null &&
        rEye != null &&
        lEye.likelihood > 0.5 &&
        rEye.likelihood > 0.5) {
      final eyeMidY = (lEye.y + rEye.y) / 2;
      // Extrapolate further above eyes so crown / hair is included (was 1.3).
      headTopY = eyeMidY - (nose.y - eyeMidY) * 1.55;
    } else {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final neckToNose = shoulderMidY - nose.y;
      headTopY = nose.y - neckToNose * 1.05;
    }

    var ankleY = rAnkle != null ? (lAnkle.y + rAnkle.y) / 2 : lAnkle.y;
    // Ankles sit above the sole; extend span slightly toward the floor.
    final draftSpan = ankleY - headTopY;
    if (draftSpan > 0) {
      ankleY = ankleY + draftSpan * 0.035;
    }
    final span = ankleY - headTopY;
    return span > 0 ? span : null;
  }

  // ── Distance estimation ────────────────────────────────────────────────
  /// Returns how far the person is from the camera based on body-span ratio.
  static DistanceCategory estimateDistance(Pose pose, Size imageSize) {
    // Same crown→feet span as [estimateHeightCm] so framing matches full height.
    final bodyPixelSpan = _verticalBodySpanPx(pose);
    if (bodyPixelSpan == null || bodyPixelSpan <= 0) {
      return DistanceCategory.unknown;
    }

    final ratio = bodyPixelSpan / imageSize.height;
    if (ratio < 0.50) return DistanceCategory.tooFar;
    if (ratio > 0.85) return DistanceCategory.tooClose;
    return DistanceCategory.perfect;
  }

  /// Estimated distance in metres (rough). Returns null if not enough info.
  static double? estimatedDistanceMetres(Pose pose, Size imageSize) {
    final lm = pose.landmarks;
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    if (lShoulder == null || rShoulder == null) return null;

    final shoulderPx = (rShoulder.x - lShoulder.x).abs();
    if (shoulderPx < 5) return null;

    // rough: assume focal_length_px ≈ image_width * 1.2 (typical mobile)
    final focalPx = imageSize.width * 1.2;
    return (focalPx * _avgShoulderCm) / (shoulderPx * 100.0); // metres
  }

  // Inter-eye distance reference (very consistent: avg 6.2 cm, std dev ~0.3 cm)
  static const double _avgInterEyeCm = 6.2;

  // ── Auto height estimation ─────────────────────────────────────────────
  /// Estimates height in cm without manual input.
  /// Uses multiple scale references (shoulder width + inter-eye distance) and
  /// eye landmarks for more accurate crown (head top) estimation.
  static double? estimateHeightCm(Pose pose) {
    final lm = pose.landmarks;
    final nose = lm[PoseLandmarkType.nose];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];
    final lEye = lm[PoseLandmarkType.leftEye];
    final rEye = lm[PoseLandmarkType.rightEye];

    if (nose == null || lShoulder == null || rShoulder == null || lAnkle == null) {
      return null;
    }

    // ── Scale calibration: collect estimates from multiple references ──────
    final scales = <double>[];

    // Reference 1: shoulder width (avg female ~38 cm)
    final shoulderPx = sqrt(
        pow(lShoulder.x - rShoulder.x, 2) + pow(lShoulder.y - rShoulder.y, 2));
    if (shoulderPx >= 10) scales.add(shoulderPx / _avgShoulderCm);

    // Reference 2: inter-eye distance (avg ~6.2 cm, very consistent)
    if (lEye != null && rEye != null &&
        lEye.likelihood > 0.5 && rEye.likelihood > 0.5) {
      final eyePx = sqrt(
          pow(lEye.x - rEye.x, 2) + pow(lEye.y - rEye.y, 2));
      if (eyePx >= 3) scales.add(eyePx / _avgInterEyeCm);
    }

    if (scales.isEmpty) return null;

    // Use median to reduce outlier impact
    scales.sort();
    final pxPerCm = scales[scales.length ~/ 2];

    final pixelBodyHeight = _verticalBodySpanPx(pose);
    if (pixelBodyHeight == null) return null;

    return _round(pixelBodyHeight / pxPerCm);
  }

  /// Median of per-pose height estimates (100–220 cm). Use after front + side + back.
  static double? consensusHeightCm(Iterable<Pose> poses) {
    final heights = <double>[];
    for (final p in poses) {
      final h = estimateHeightCm(p);
      if (h != null && h >= 100 && h <= 220) heights.add(h);
    }
    if (heights.isEmpty) return null;
    heights.sort();
    return heights[heights.length ~/ 2];
  }

  // ── Auto calculate (no manual height needed) ───────────────────────────
  /// Same as [calculate] but estimates height automatically from pose.
  static BodyMeasurements? calculateAuto(Pose pose) {
    final heightCm = estimateHeightCm(pose);
    if (heightCm == null || heightCm < 100 || heightCm > 220) return null;
    return calculate(pose, heightCm);
  }

  // ── Dual-angle: front + side view for accurate circumferences ──────────
  /// Calculates body measurements using front + side pose for 3D accuracy.
  ///
  /// Circumference formula (ellipse approximation):
  ///   C ≈ π × √(2 × (a² + b²))
  ///   where a = half of front-view width, b = half of side-view depth
  ///
  /// Falls back to multiplier estimates if side landmarks are not confident.
  static BodyMeasurements? calculateWithSideView(
      Pose frontPose, Pose sidePose, double knownHeightCm) {
    final lm = frontPose.landmarks;

    final nose = lm[PoseLandmarkType.nose];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];

    if (nose == null ||
        lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lAnkle == null) {
      return null;
    }
    final required = [nose, lShoulder, rShoulder, lHip, rHip, lAnkle];
    if (required.any((l) => l.likelihood < 0.55)) return null;

    // ── Front-view calibration (same vertical span as [estimateHeightCm]) ──
    final heightPx = _verticalBodySpanPx(frontPose);
    if (heightPx == null) return null;
    final pxPerCm = heightPx / knownHeightCm;

    double fDist(PoseLandmark a, PoseLandmark b) =>
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
    double pxToCm(double px) => px / pxPerCm;

    // Front widths (these are the "a" values in the ellipse formula)
    final shoulderWidthCm = pxToCm(fDist(lShoulder, rShoulder));
    final hipWidthCm = pxToCm(fDist(lHip, rHip));

    final waistX = (lShoulder.x + rShoulder.x + lHip.x + rHip.x) / 4;
    final waistY = (lShoulder.y + rShoulder.y + lHip.y + rHip.y) / 4;
    final waistWidthCm = pxToCm(
      sqrt(pow(waistX - lHip.x, 2) + pow(waistY - lHip.y, 2)) +
          sqrt(pow(waistX - rHip.x, 2) + pow(waistY - rHip.y, 2)),
    );

    // Other front-only measurements
    double? armLengthCm;
    final lElbow = lm[PoseLandmarkType.leftElbow];
    final lWrist = lm[PoseLandmarkType.leftWrist];
    if (lElbow != null &&
        lWrist != null &&
        lElbow.likelihood > 0.5 &&
        lWrist.likelihood > 0.5) {
      armLengthCm =
          pxToCm(fDist(lShoulder, lElbow) + fDist(lElbow, lWrist));
    }

    double? neckCm;
    final lEar = lm[PoseLandmarkType.leftEar];
    final rEar = lm[PoseLandmarkType.rightEar];
    if (lEar != null && rEar != null) {
      neckCm = pxToCm(fDist(lEar, rEar)) * _neckMultiplier;
    }

    double? inseamCm;
    if (lAnkle.likelihood > 0.5) inseamCm = pxToCm(fDist(lHip, lAnkle));

    double? thighCm;
    final lKnee = lm[PoseLandmarkType.leftKnee];
    if (lKnee != null && lKnee.likelihood > 0.5) {
      thighCm = pxToCm(fDist(lHip, lKnee)) * 0.55 * _thighMultiplier;
    }

    // ── Side-view depths (the "b" values in the ellipse formula) ──────
    // When person stands 90° sideways, their body depth (front-to-back)
    // appears as the horizontal span of landmarks in the camera frame.
    final slm = sidePose.landmarks;
    final sNose = slm[PoseLandmarkType.nose];
    final sLAnkle = slm[PoseLandmarkType.leftAnkle];

    double? chestDepthCm, hipDepthCm, waistDepthCm;

    if (sNose != null && sLAnkle != null && sLAnkle.likelihood > 0.5) {
      // Same crown→ankle span as front so side scale matches [knownHeightCm].
      final sHeightPx = _verticalBodySpanPx(sidePose);
      if (sHeightPx != null && sHeightPx > 0) {
        final sPxPerCm = sHeightPx / knownHeightCm;
        double sWidthCm(double px) => px / sPxPerCm;

        final sLShoulder = slm[PoseLandmarkType.leftShoulder];
        final sRShoulder = slm[PoseLandmarkType.rightShoulder];
        if (sLShoulder != null &&
            sRShoulder != null &&
            sLShoulder.likelihood > 0.5 &&
            sRShoulder.likelihood > 0.5) {
          // shoulder X-span in side view = chest depth
          chestDepthCm =
              sWidthCm((sLShoulder.x - sRShoulder.x).abs());
        }

        final sLHip = slm[PoseLandmarkType.leftHip];
        final sRHip = slm[PoseLandmarkType.rightHip];
        if (sLHip != null &&
            sRHip != null &&
            sLHip.likelihood > 0.5 &&
            sRHip.likelihood > 0.5) {
          hipDepthCm = sWidthCm((sLHip.x - sRHip.x).abs());
        }

        if (chestDepthCm != null && hipDepthCm != null) {
          // Waist is typically ~75% of the average of chest and hip depths
          waistDepthCm = (chestDepthCm + hipDepthCm) / 2 * 0.75;
        }
      }
    }

    // ── Ellipse circumference: C ≈ π × √(2(a² + b²)) ─────────────────
    double ellipseC(double width, double depth) {
      final a = width / 2;
      final b = depth / 2;
      return pi * sqrt(2 * (a * a + b * b));
    }

    final chestCm = chestDepthCm != null
        ? ellipseC(shoulderWidthCm, chestDepthCm)
        : shoulderWidthCm * _chestMultiplier;
    final hipCm = hipDepthCm != null
        ? ellipseC(hipWidthCm, hipDepthCm)
        : hipWidthCm * _hipMultiplier;
    final waistCm = waistDepthCm != null
        ? ellipseC(waistWidthCm, waistDepthCm)
        : waistWidthCm * _waistMultiplier;

    return BodyMeasurements(
      chest: _round(chestCm),
      waist: _round(waistCm),
      hips: _round(hipCm),
      shoulder: _round(shoulderWidthCm),
      armLength: armLengthCm != null ? _round(armLengthCm) : null,
      height: knownHeightCm,
      neck: neckCm != null ? _round(neckCm) : null,
      thigh: thighCm != null ? _round(thighCm) : null,
      inseam: inseamCm != null ? _round(inseamCm) : null,
      capturedAt: DateTime.now(),
    );
  }

  /// Returns [BodyMeasurements] if enough landmarks are detected with
  /// sufficient confidence, otherwise returns null.
  static BodyMeasurements? calculate(Pose pose, double knownHeightCm) {
    final lm = pose.landmarks;

    // ----- Required landmarks -----
    final nose = lm[PoseLandmarkType.nose];
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lAnkle = lm[PoseLandmarkType.leftAnkle];

    if (nose == null ||
        lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lAnkle == null) {
      return null;
    }

    // Minimum confidence check
    final required = [nose, lShoulder, rShoulder, lHip, rHip, lAnkle];
    if (required.any((lm) => lm.likelihood < 0.55)) return null;

    // ---------- Calibration (match crown→ankle used for known height) -----
    final heightPixels = _verticalBodySpanPx(pose);
    if (heightPixels == null) return null;

    final pxPerCm = heightPixels / knownHeightCm;

    // ---------- Helper ----------
    double dist(PoseLandmark a, PoseLandmark b) =>
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));

    double pxToCm(double pixels) => pixels / pxPerCm;

    // ---------- Shoulder ----------
    final shoulderWidthCm = pxToCm(dist(lShoulder, rShoulder));

    // ---------- Chest ----------
    // Chest ≈ shoulder_width × multiplier (accounts for depth)
    final chestCm = shoulderWidthCm * _chestMultiplier;

    // ---------- Hip ----------
    final hipWidthCm = pxToCm(dist(lHip, rHip));
    final hipCm = hipWidthCm * _hipMultiplier;

    // ---------- Waist ----------
    // Waist landmark = midpoint between shoulder and hip, scaled
    final waistX = (lShoulder.x + rShoulder.x + lHip.x + rHip.x) / 4;
    final waistY = (lShoulder.y + rShoulder.y + lHip.y + rHip.y) / 4;
    final lWaistDist = sqrt(pow(waistX - lHip.x, 2) + pow(waistY - lHip.y, 2));
    final rWaistDist = sqrt(pow(waistX - rHip.x, 2) + pow(waistY - rHip.y, 2));
    final waistWidthCm = pxToCm(lWaistDist + rWaistDist);
    final waistCm = waistWidthCm * _waistMultiplier;

    // ---------- Arm length (left side) ----------
    double? armLengthCm;
    final lElbow = lm[PoseLandmarkType.leftElbow];
    final lWrist = lm[PoseLandmarkType.leftWrist];
    if (lElbow != null &&
        lWrist != null &&
        lElbow.likelihood > 0.5 &&
        lWrist.likelihood > 0.5) {
      armLengthCm = pxToCm(
        dist(lShoulder, lElbow) + dist(lElbow, lWrist),
      );
    }

    // ---------- Neck ----------
    double? neckCm;
    final lEar = lm[PoseLandmarkType.leftEar];
    final rEar = lm[PoseLandmarkType.rightEar];
    if (lEar != null && rEar != null) {
      neckCm = pxToCm(dist(lEar, rEar)) * _neckMultiplier;
    }

    // ---------- Inseam ----------
    double? inseamCm;
    if (lAnkle.likelihood > 0.5) {
      inseamCm = pxToCm(dist(lHip, lAnkle));
    }

    // ---------- Thigh ----------
    double? thighCm;
    final lKnee = lm[PoseLandmarkType.leftKnee];
    if (lKnee != null && lKnee.likelihood > 0.5) {
      final thighWidthCm = pxToCm(dist(lHip, lKnee)) * 0.55;
      thighCm = thighWidthCm * _thighMultiplier;
    }

    return BodyMeasurements(
      chest: _round(chestCm),
      waist: _round(waistCm),
      hips: _round(hipCm),
      shoulder: _round(shoulderWidthCm),
      armLength: armLengthCm != null ? _round(armLengthCm) : null,
      height: knownHeightCm,
      neck: neckCm != null ? _round(neckCm) : null,
      thigh: thighCm != null ? _round(thighCm) : null,
      inseam: inseamCm != null ? _round(inseamCm) : null,
      capturedAt: DateTime.now(),
    );
  }

  static double _round(double v) =>
      double.parse(v.toStringAsFixed(1));

  /// Returns a confidence score 0–1 based on how many key landmarks
  /// are detected above the threshold. Used for UI feedback.
  static double poseConfidence(Pose pose) {
    final keyLandmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];
    int detected = 0;
    for (final type in keyLandmarks) {
      final lm = pose.landmarks[type];
      if (lm != null && lm.likelihood > 0.55) detected++;
    }
    return detected / keyLandmarks.length;
  }
}
