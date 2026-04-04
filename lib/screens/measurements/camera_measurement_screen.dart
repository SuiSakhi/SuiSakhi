import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../services/body_measurement_calculator.dart';
import '../../services/pose_measurement_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_unit_toggle.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan steps
// ─────────────────────────────────────────────────────────────────────────────
enum _ScanStep {
  frontScanning,
  transitionToSide,
  sideScanning,
  transitionToBack,
  backScanning,
  processing,
  done,
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class CameraMeasurementScreen extends StatefulWidget {
  const CameraMeasurementScreen({super.key});

  @override
  State<CameraMeasurementScreen> createState() =>
      _CameraMeasurementScreenState();
}

class _CameraMeasurementScreenState extends State<CameraMeasurementScreen>
    with WidgetsBindingObserver {
  // ── step state ──────────────────────────────────────────────────────────
  _ScanStep _step = _ScanStep.frontScanning;

  // ── multi-angle scan storage ───────────────────────────────────────────
  Pose? _frontPose;
  double? _frontHeightCm;
  Pose? _sidePose;

  // ── camera ──────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraInitialized = false;
  String? _cameraError;
  Size _imageSize = Size.zero;

  // ── AI ──────────────────────────────────────────────────────────────────
  final _poseService = PoseMeasurementService();
  final _posesNotifier = ValueNotifier<List<Pose>>([]);
  double _poseConfidence = 0;
  int _stableFrames = 0;
  static const int _autoCaptureFrms = 25;
  DistanceCategory _distanceCategory = DistanceCategory.unknown;
  double? _estimatedDistanceM;
  double? _estimatedHeightCm;

  // ── results ─────────────────────────────────────────────────────────────
  BodyMeasurements? _measurements;

  // ── lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start camera immediately — no manual height entry needed
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseService.dispose();
    _posesNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed && _isScanning) {
      _initCamera();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera initialisation
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _cameraError =
          'Camera permission denied.\nEnable it in Settings to use body scan.');
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() => _cameraError = 'No camera found on this device.');
      return;
    }

    // Prefer back camera — better quality and field of view for body scanning
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // high is too heavy for real-time ML Kit
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      _cameraController = controller;
      // portrait-adjusted image size
      _imageSize = Size(
        controller.value.previewSize!.height,
        controller.value.previewSize!.width,
      );
      await controller.startImageStream(_onCameraFrame);
      setState(() => _cameraInitialized = true);
    } catch (e) {
      setState(() => _cameraError = 'Camera init error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Frame processing
  // ─────────────────────────────────────────────────────────────────────────
  bool get _isScanning =>
      _step == _ScanStep.frontScanning ||
      _step == _ScanStep.sideScanning ||
      _step == _ScanStep.backScanning;

  void _onCameraFrame(CameraImage image) async {
    if (!_isScanning) return;

    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final poses = await _poseService.processFrame(image, camera);
    if (!mounted) return;

    _posesNotifier.value = poses;

    if (poses.isNotEmpty) {
      final pose = poses.first;
      final conf = BodyMeasurementCalculator.poseConfidence(pose);
      final dist = BodyMeasurementCalculator.estimateDistance(pose, _imageSize);
      final distM = BodyMeasurementCalculator.estimatedDistanceMetres(pose, _imageSize);
      final heightEst = BodyMeasurementCalculator.estimateHeightCm(pose);

      if (mounted) {
        setState(() {
          _poseConfidence = conf;
          _distanceCategory = dist;
          _estimatedDistanceM = distM;
          _estimatedHeightCm = heightEst;
        });
      }

      // Only auto-capture when BOTH distance is perfect AND pose is confident
      if (conf >= 0.85 && dist == DistanceCategory.perfect) {
        _stableFrames++;
        if (_stableFrames >= _autoCaptureFrms) {
          _captureAndCalculate(pose);
        }
      } else {
        _stableFrames = 0;
      }
    } else {
      if (mounted) {
        setState(() {
          _poseConfidence = 0;
          _distanceCategory = DistanceCategory.unknown;
          _estimatedDistanceM = null;
          _estimatedHeightCm = null;
        });
      }
      _stableFrames = 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Capture & calculate
  // ─────────────────────────────────────────────────────────────────────────
  void _captureAndCalculate(Pose pose) {
    if (!_isScanning) return;
    _cameraController?.stopImageStream();

    if (_step == _ScanStep.frontScanning) {
      // Front scan done — estimate height and move to transition
      final heightCm = BodyMeasurementCalculator.estimateHeightCm(pose);
      if (heightCm == null || heightCm < 100 || heightCm > 220) {
        _cameraController?.startImageStream(_onCameraFrame);
        _showSnack('Pose not clear. Stand back so full body is visible.');
        setState(() {
          _stableFrames = 0;
          _poseConfidence = 0;
        });
        return;
      }
      setState(() {
        _frontPose = pose;
        _frontHeightCm = heightCm;
        _step = _ScanStep.transitionToSide;
        _stableFrames = 0;
        _poseConfidence = 0;
      });
    } else if (_step == _ScanStep.sideScanning) {
      setState(() {
        _sidePose = pose;
        _step = _ScanStep.transitionToBack;
        _stableFrames = 0;
        _poseConfidence = 0;
      });
    } else {
      // Back scan done — combine views using consensus height
      setState(() => _step = _ScanStep.processing);

      final front = _frontPose;
      final side = _sidePose;
      final back = pose;
      final posesForHeight = <Pose>[
        ...[front, side].whereType<Pose>(),
        back,
      ];
      final consensus =
          BodyMeasurementCalculator.consensusHeightCm(posesForHeight);
      final heightCm = consensus ?? _frontHeightCm;

      final BodyMeasurements? result = (front != null &&
              side != null &&
              heightCm != null)
          ? BodyMeasurementCalculator.calculateWithSideView(
              front, side, heightCm)
          : BodyMeasurementCalculator.calculateAuto(back);

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        if (result != null) {
          AppState.instance.setMeasurements(result);
          setState(() {
            _measurements = result;
            _step = _ScanStep.done;
          });
        } else {
          setState(() {
            _step = _ScanStep.sideScanning;
            _sidePose = null;
            _stableFrames = 0;
            _poseConfidence = 0;
          });
          _cameraController?.startImageStream(_onCameraFrame);
          _showSnack(
            'Could not combine scans. Redo the side view — full body, profile to camera.',
          );
        }
      });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: switch (_step) {
          _ScanStep.frontScanning => _buildCameraView(),
          _ScanStep.transitionToSide => _buildTransitionToSide(),
          _ScanStep.sideScanning => _buildCameraView(),
          _ScanStep.transitionToBack => _buildTransitionToBack(),
          _ScanStep.backScanning => _buildCameraView(),
          _ScanStep.processing => _buildProcessing(),
          _ScanStep.done => _buildResults(),
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 1 — Live camera with pose overlay
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCameraView() {
    if (_cameraError != null) return _buildError(_cameraError!);

    if (!_cameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Initialising camera…',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Camera preview ──────────────────────────────────────────
        CameraPreview(_cameraController!),

        // ── 2. Live pose skeleton overlay ─────────────────────────────
        ValueListenableBuilder<List<Pose>>(
          valueListenable: _posesNotifier,
          builder: (ctx, poses, _) {
            if (poses.isEmpty) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (ctx2, constraints) => CustomPaint(
                painter: _PoseOverlayPainter(
                  poses: poses,
                  imageSize: _imageSize,
                  screenSize:
                      Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            );
          },
        ),

        // ── 3. Guide oval (taller = crown–feet; narrow for side/back) ─
        LayoutBuilder(
          builder: (ctx, bc) {
            final narrow = _step == _ScanStep.sideScanning ||
                _step == _ScanStep.backScanning;
            final h = (bc.maxHeight * 0.88).clamp(420.0, 620.0);
            final w = narrow ? 120.0 : 220.0;
            return Center(
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _poseConfidence >= 0.85
                        ? AppColors.success
                        : Colors.white.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            );
          },
        ),

        // ── 4. Top bar ────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildScanTopBar(),
        ),

        // ── 5. Bottom panel ───────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildScanBottomPanel(),
        ),
      ],
    );
  }

  Widget _buildScanTopBar() {
    final (icon, stepLabel) = switch (_step) {
      _ScanStep.sideScanning => (
          Icons.rotate_90_degrees_ccw_rounded,
          'Side  2/3',
        ),
      _ScanStep.backScanning => (
          Icons.u_turn_left_rounded,
          'Back  3/3',
        ),
      _ => (Icons.person_search_rounded, 'Front  1/3'),
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _glassBtn(
            Icons.arrow_back_ios_rounded,
            () {
              try { _cameraController?.stopImageStream(); } catch (_) {}
              _cameraController?.dispose();
              _cameraController = null;
              context.pop();
            },
          ),
          const Spacer(),
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: _poseColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$stepLabel  $_poseLabel',
                  style: TextStyle(
                    color: _poseColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _buildScanBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.92),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Distance indicator ───────────────────────────────────────
          _buildDistanceIndicator(),
          const SizedBox(height: 12),

          // ── Pose confidence bar ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _poseConfidence,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(_poseColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _poseConfidence < 0.55
                ? switch (_step) {
                    _ScanStep.sideScanning =>
                      'Turn sideways, arms slightly away from body',
                    _ScanStep.backScanning =>
                      'Back to camera — heels on floor, full head to feet in frame',
                    _ => 'Face the camera — full body from head to feet in frame',
                  }
                : _poseConfidence < 0.85
                    ? 'Almost there — keep still…'
                    : 'Hold still — auto-capturing! ($_stableFrames/$_autoCaptureFrms)',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // ── Capture button ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live height estimate badge (left of button)
              SizedBox(
                width: 96,
                child: _estimatedHeightCm != null
                    ? ListenableBuilder(
                        listenable: AppState.instance,
                        builder: (context, _) {
                          final u = AppState.instance.measurementUnit;
                          final h = _estimatedHeightCm!;
                          final line = MeasurementFormat.formatDual(
                            h,
                            u,
                            fractionDigits: 0,
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '~$line',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'height',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_isScanning && _posesNotifier.value.isNotEmpty) {
                    _captureAndCalculate(_posesNotifier.value.first);
                  } else if (_posesNotifier.value.isEmpty) {
                    _showSnack('No pose detected yet. Step into the oval.');
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _poseConfidence >= 0.55
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.25),
                    boxShadow: _poseConfidence >= 0.55
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(width: 12),
              // Distance in metres (right of button)
              SizedBox(
                width: 80,
                child: _estimatedDistanceM != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_estimatedDistanceM!.toStringAsFixed(1)} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'distance',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Tap to capture',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final (icon, label, color) = switch (_distanceCategory) {
      DistanceCategory.tooFar => (
          Icons.zoom_in_rounded,
          'Step closer to the camera',
          Colors.orangeAccent,
        ),
      DistanceCategory.tooClose => (
          Icons.zoom_out_rounded,
          'Step back a little',
          Colors.redAccent,
        ),
      DistanceCategory.perfect => (
          Icons.check_circle_rounded,
          'Perfect distance ✓',
          AppColors.success,
        ),
      DistanceCategory.unknown => (
          Icons.person_search_rounded,
          'Stand facing the camera',
          Colors.white54,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _poseColor {
    if (_poseConfidence >= 0.85) return AppColors.success;
    if (_poseConfidence >= 0.55) return AppColors.accent;
    return Colors.white54;
  }

  String get _poseLabel {
    if (_poseConfidence >= 0.85) return 'Great pose!';
    if (_poseConfidence >= 0.55) return 'Pose detected';
    return 'No pose';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 2 — Transition (turn sideways)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTransitionToSide() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 28),
          Text('Front Scan Done!', style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Great! Now turn 90° to your right\nso your side profile faces the camera.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Visual guide
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Person icon facing camera
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 40),
                    const SizedBox(height: 4),
                    Text('Front ✓',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.success)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary, size: 28),
                ),
                // Person icon sideways
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rotate_90_degrees_ccw_rounded,
                        color: AppColors.accent, size: 40),
                    const SizedBox(height: 4),
                    Text('Side view',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.accent)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep arms slightly away from your body\nso the scanner can see your waist and hips.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          PrimaryButton(
            label: "I'm Ready — Start Side Scan",
            icon: Icons.camera_alt_rounded,
            onTap: () {
              setState(() {
                _step = _ScanStep.sideScanning;
                _stableFrames = 0;
                _poseConfidence = 0;
              });
              _cameraController?.startImageStream(_onCameraFrame);
            },
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Transition side → back
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTransitionToBack() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Side Scan Done!',
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Turn 180° so your back faces the camera.\nStand straight, arms slightly away from your sides.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rotate_90_degrees_ccw_rounded,
                        color: AppColors.success, size: 40),
                    const SizedBox(height: 4),
                    Text(
                      'Side ✓',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary, size: 28),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.u_turn_left_rounded,
                        color: AppColors.accent, size: 40),
                    const SizedBox(height: 4),
                    Text(
                      'Back view',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          PrimaryButton(
            label: "I'm Ready — Start Back Scan",
            icon: Icons.camera_alt_rounded,
            onTap: () {
              setState(() {
                _step = _ScanStep.backScanning;
                _stableFrames = 0;
                _poseConfidence = 0;
              });
              _cameraController?.startImageStream(_onCameraFrame);
            },
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 3 — Processing
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildProcessing() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Calculating Measurements…',
                  style: AppTextStyles.headlineLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Merging front, side, and back scans…',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ...[
                ('Reading body landmarks…', Duration.zero),
                ('Aligning depth from your side view…',
                    const Duration(milliseconds: 300)),
                ('Finalising measurements…',
                    const Duration(milliseconds: 600)),
              ].map(
                (e) => _FadeInStep(label: e.$1, delay: e.$2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 3 — Results
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildResults() {
    final m = _measurements;
    if (m == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.background,
      child: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final unit = AppState.instance.measurementUnit;
          return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: MeasurementUnitToggle(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 60),
            ),
            const SizedBox(height: 16),
            Text('Scan Complete!',
                style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center),
            Text('AI-calculated body measurements',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 24),
            _buildResultsGrid(m, unit),
            const SizedBox(height: 16),
            // Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Camera estimates are approximate. For fittings, confirm key numbers with a tailor’s tape.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Go to Home',
              icon: Icons.home_rounded,
              onTap: () {
                try {
                  _cameraController?.stopImageStream();
                } catch (_) {}
                _cameraController?.dispose();
                _cameraController = null;
                if (context.mounted) context.go('/home');
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Design a Dress Now',
              icon: Icons.design_services_rounded,
              onTap: () => context.push('/designer'),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'View Full Measurements',
              icon: Icons.straighten_rounded,
              onTap: () => context.push('/measurement-result'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                try { _cameraController?.stopImageStream(); } catch (_) {}
                _cameraController?.dispose();
                _cameraController = null;
                setState(() {
                  _cameraInitialized = false;
                  _step = _ScanStep.frontScanning;
                  _frontPose = null;
                  _frontHeightCm = null;
                  _sidePose = null;
                  _stableFrames = 0;
                  _poseConfidence = 0;
                });
                _initCamera();
              },
              child: Text('Retake Scan',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  Widget _buildResultsGrid(BodyMeasurements m, MeasurementUnit unit) {
    final items = [
      ('Height', m.height, AppColors.primary, Icons.height_rounded),
      ('Chest', m.chest, const Color(0xFFFF6B6B), Icons.straighten_rounded),
      ('Waist', m.waist, const Color(0xFFF5A623),
          Icons.radio_button_unchecked),
      ('Hips', m.hips, const Color(0xFF9C27B0), Icons.accessibility_rounded),
      ('Shoulder', m.shoulder, const Color(0xFF4CAF50),
          Icons.width_wide_rounded),
      ('Arm Length', m.armLength, AppColors.primaryDark,
          Icons.back_hand_outlined),
      ('Neck', m.neck, const Color(0xFF00BCD4), Icons.circle_outlined),
      ('Thigh', m.thigh, const Color(0xFFFF5722),
          Icons.airline_seat_legroom_normal),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final it = items[i];
        return _ResultTile(
            label: it.$1,
            valueCm: it.$2,
            unit: unit,
            color: it.$3,
            icon: it.$4);
      },
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────
  Widget _buildError(String message) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 80, color: AppColors.textHint),
          const SizedBox(height: 20),
          Text('Camera Unavailable',
              style: AppTextStyles.headlineLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(message,
              style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Open App Settings',
            icon: Icons.settings_rounded,
            onTap: () => openAppSettings(),
          ),
          const SizedBox(height: 12),
          SecondaryButton(label: 'Go Back', onTap: () => context.pop()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pose skeleton CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
class _PoseOverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size screenSize;

  const _PoseOverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.screenSize,
  });

  // Body connections to draw
  static const _connections = [
    [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
    [PoseLandmarkType.rightEar, PoseLandmarkType.rightEye],
    [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
    [PoseLandmarkType.rightEye, PoseLandmarkType.nose],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.accentLight
      ..style = PaintingStyle.fill;

    final dimDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (final pose in poses) {
      // Draw skeleton lines
      for (final conn in _connections) {
        final a = pose.landmarks[conn[0]];
        final b = pose.landmarks[conn[1]];
        if (a == null || b == null) continue;
        if (a.likelihood < 0.4 || b.likelihood < 0.4) continue;
        canvas.drawLine(_scale(a), _scale(b), linePaint);
      }
      // Draw landmark dots
      for (final lm in pose.landmarks.values) {
        final paint = lm.likelihood > 0.6 ? dotPaint : dimDotPaint;
        canvas.drawCircle(_scale(lm), lm.likelihood > 0.6 ? 5 : 3, paint);
      }
    }
  }

  /// Scale landmark (x,y) from image coordinate space to screen space.
  Offset _scale(PoseLandmark lm) {
    return Offset(
      lm.x / imageSize.width * screenSize.width,
      lm.y / imageSize.height * screenSize.height,
    );
  }

  @override
  bool shouldRepaint(_PoseOverlayPainter old) =>
      old.poses != poses || old.imageSize != imageSize;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  final String label;
  final double? valueCm;
  final MeasurementUnit unit;
  final Color color;
  final IconData icon;

  const _ResultTile(
      {required this.label,
      required this.valueCm,
      required this.unit,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                valueCm != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MeasurementFormat.formatWithUnit(valueCm, unit),
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: color, fontSize: 13),
                          ),
                          Text(
                            unit == MeasurementUnit.cm
                                ? '${MeasurementFormat.formatValue(valueCm, MeasurementUnit.inch)} in'
                                : '${MeasurementFormat.formatValue(valueCm, MeasurementUnit.cm)} cm',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Text('—',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeInStep extends StatefulWidget {
  final String label;
  final Duration delay;
  const _FadeInStep({required this.label, required this.delay});

  @override
  State<_FadeInStep> createState() => _FadeInStepState();
}

class _FadeInStepState extends State<_FadeInStep> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay,
        () => mounted ? setState(() => _visible = true) : null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(widget.label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
