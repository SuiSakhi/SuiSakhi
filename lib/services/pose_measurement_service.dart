import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Wraps ML Kit PoseDetector for live camera frame processing.
/// Handles Android (YUV420) and iOS (BGRA8888) image formats.
class PoseMeasurementService {
  late final PoseDetector _detector;
  bool _isBusy = false;

  PoseMeasurementService() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Process a single camera frame. Returns empty list if busy or on error.
  Future<List<Pose>> processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isBusy) return [];
    _isBusy = true;
    try {
      final inputImage = _toInputImage(image, camera);
      if (inputImage == null) return [];
      return await _detector.processImage(inputImage);
    } catch (e) {
      debugPrint('[PoseService] Error: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation = _getRotation(camera);
    final format = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormat.nv21;

    final bytes = Platform.isIOS
        ? image.planes[0].bytes
        : _yuv420toNv21(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  /// Convert Android YUV420 (3-plane) to NV21 (Y + interleaved VU).
  Uint8List _yuv420toNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final result = Uint8List(ySize + uvSize);

    var outputOffset = 0;

    // Copy Y plane safely, respecting row stride.
    for (var row = 0; row < height; row++) {
      final inputOffset = row * yPlane.bytesPerRow;
      final inputEnd = inputOffset + width;

      if (inputOffset >= yPlane.bytes.length) {
        break;
      }

      final safeEnd = inputEnd <= yPlane.bytes.length
          ? inputEnd
          : yPlane.bytes.length;

      final rowBytes = safeEnd - inputOffset;

      if (rowBytes > 0 && outputOffset + rowBytes <= result.length) {
        result.setRange(
          outputOffset,
          outputOffset + rowBytes,
          yPlane.bytes,
          inputOffset,
        );
      }

      outputOffset += width;
    }

    // Convert chroma planes to NV21 safely: VU interleaved.
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    var uvOutputOffset = ySize;

    for (var row = 0; row < uvHeight; row++) {
      final uRowOffset = row * uPlane.bytesPerRow;
      final vRowOffset = row * vPlane.bytesPerRow;

      for (var col = 0; col < uvWidth; col++) {
        final uIndex = uRowOffset + col * uPixelStride;
        final vIndex = vRowOffset + col * vPixelStride;

        if (uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length ||
            uvOutputOffset + 1 >= result.length) {
          continue;
        }

        result[uvOutputOffset++] = vPlane.bytes[vIndex];
        result[uvOutputOffset++] = uPlane.bytes[uIndex];
      }
    }

    return result;
  }

  InputImageRotation _getRotation(CameraDescription camera) {
    final isFront = camera.lensDirection == CameraLensDirection.front;
    final orientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return isFront
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation90deg;
    }

    // Android
    switch (orientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return isFront
            ? InputImageRotation.rotation270deg
            : InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      default:
        return isFront
            ? InputImageRotation.rotation90deg
            : InputImageRotation.rotation270deg;
    }
  }

  void dispose() => _detector.close();
}
