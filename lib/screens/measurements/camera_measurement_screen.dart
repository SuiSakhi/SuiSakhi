import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../core/garment_measurement_catalog.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../services/body_measurement_calculator.dart';
import '../../services/measurement_draft_service.dart';
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

  String? _draftId;
  String? _clientName;
  String? _personId;
  String? _relationship;
  double? _profileHeightCm;
  Future<void>? _profileHeightLoad;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileHeightLoad = _loadProfileHeightFromDraft();
      _initCamera();
    });
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final params = GoRouterState.of(context).uri.queryParameters;

    _draftId = params['draftId'];
    _clientName = params['clientName'];
    _personId = params['personId'];
    _relationship = params['relationship'];
    _profileHeightCm ??= (_personId == null || _personId == 'self')
        ? _validProfileHeight(AppState.instance.profile?.heightCm)
        : null;
  }

  Future<void> _loadProfileHeightFromDraft() async {
    final draftId = _draftId?.trim();
    if (draftId == null || draftId.isEmpty) return;
    final height = await MeasurementDraftService.profileHeightForDraft(draftId);
    if (!mounted) return;
    final validHeight = _validProfileHeight(height);
    if (validHeight != null) {
      setState(() => _profileHeightCm = validHeight);
    }
  }

  double? _validProfileHeight(double? value) =>
      value != null && value >= 100 && value <= 220 ? value : null;

  // ─────────────────────────────────────────────────────────────────────────
  // Camera initialisation
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(
        () => _cameraError =
            'Camera permission denied.\nEnable it in Settings to use body scan.',
      );
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
      final distM = BodyMeasurementCalculator.estimatedDistanceMetres(
        pose,
        _imageSize,
      );
      final heightEst =
          _validProfileHeight(_profileHeightCm) ??
          BodyMeasurementCalculator.estimateHeightCm(pose);

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
          await _captureAndCalculate(pose);
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
  Future<void> _captureAndCalculate(Pose pose) async {
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

      // Profile height is the best available real-world scale. The draft read
      // runs alongside camera startup; wait briefly before using pose-only
      // height so a slow connection does not stall capture.
      try {
        await _profileHeightLoad?.timeout(const Duration(seconds: 2));
      } catch (_) {}

      final front = _frontPose;
      final side = _sidePose;
      final back = pose;
      final posesForHeight = <Pose>[
        ...[front, side].whereType<Pose>(),
        back,
      ];
      final consensus = BodyMeasurementCalculator.consensusHeightCm(
        posesForHeight,
      );
      final heightCm =
          _validProfileHeight(_profileHeightCm) ?? consensus ?? _frontHeightCm;

      final BodyMeasurements? result =
          (front != null && side != null && heightCm != null)
          ? BodyMeasurementCalculator.calculateWithSideView(
              front,
              side,
              heightCm,
            )
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _step == _ScanStep.done
          ? AppBar(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              title: const Text('Measurement Result'),
              leading: IconButton(
                tooltip: 'Back to measurement options',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/measurements');
                  }
                },
              ),
            )
          : null,
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
            Text(
              'Initialising camera…',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
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
                  screenSize: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            );
          },
        ),

        // ── 3. Guide oval (taller = crown–feet; narrow for side/back) ─
        LayoutBuilder(
          builder: (ctx, bc) {
            final narrow =
                _step == _ScanStep.sideScanning ||
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
        Positioned(top: 0, left: 0, right: 0, child: _buildScanTopBar()),

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
      _ScanStep.backScanning => (Icons.u_turn_left_rounded, 'Back  3/3'),
      _ => (Icons.person_search_rounded, 'Front  1/3'),
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _glassBtn(Icons.arrow_back_ios_rounded, () {
            try {
              _cameraController?.stopImageStream();
            } catch (_) {}
            _cameraController?.dispose();
            _cameraController = null;
            context.pop();
          }),
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
                Icon(icon, color: _poseColor, size: 18),
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
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
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
                    _ =>
                      'Face the camera — full body from head to feet in frame',
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
                          final usesProfileHeight =
                              _validProfileHeight(_profileHeightCm) != null;
                          final line = MeasurementFormat.formatDual(
                            h,
                            u,
                            fractionDigits: 0,
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                usesProfileHeight ? line : '~$line',
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
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  if (_isScanning && _posesNotifier.value.isNotEmpty) {
                    await _captureAndCalculate(_posesNotifier.value.first);
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
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
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
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap to capture',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
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
          Text(
            'Front Scan Done!',
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
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
                    const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Front ✓',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                // Person icon sideways
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.rotate_90_degrees_ccw_rounded,
                      color: AppColors.accent,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Side view',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
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
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AppColors.accent,
                  size: 18,
                ),
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
                    const Icon(
                      Icons.rotate_90_degrees_ccw_rounded,
                      color: AppColors.success,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Side ✓',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.u_turn_left_rounded,
                      color: AppColors.accent,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Back view',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                      ),
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
              Text(
                'Calculating Measurements…',
                style: AppTextStyles.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Merging front, side, and back scans…',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ...[
                ('Reading body landmarks…', Duration.zero),
                (
                  'Aligning depth from your side view…',
                  const Duration(milliseconds: 300),
                ),
                ('Finalising measurements…', const Duration(milliseconds: 600)),
              ].map((e) => _FadeInStep(label: e.$1, delay: e.$2)),
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
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan Complete!',
                  style: AppTextStyles.displayMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  'AI-calculated body measurements',
                  style: AppTextStyles.bodyMedium,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _editEstimatedMeasurements,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Adjust estimates'),
                  ),
                ),
                const SizedBox(height: 24),
                _buildUniversalMeasurementRows(m, unit),
                if (m.thigh != null || m.inseam != null) ...[
                  const SizedBox(height: 16),
                  _buildSupplementaryEstimates(m, unit),
                ],
                const SizedBox(height: 16),
                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
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
                  onTap: () {
                    final query = <String, String>{
                      if (_draftId?.trim().isNotEmpty == true)
                        'draftId': _draftId!.trim(),
                      if (_clientName?.trim().isNotEmpty == true)
                        'clientName': _clientName!.trim(),
                      if (_personId?.trim().isNotEmpty == true)
                        'personId': _personId!.trim(),
                      if (_relationship?.trim().isNotEmpty == true)
                        'relationship': _relationship!.trim(),
                    };

                    final uri = Uri(
                      path: '/designer',
                      queryParameters: query.isEmpty ? null : query,
                    );

                    context.push(uri.toString());
                  },
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'View Full Measurements',
                  icon: Icons.straighten_rounded,
                  onTap: () {
                    final query = <String, String>{
                      if (_draftId?.trim().isNotEmpty == true)
                        'draftId': _draftId!.trim(),
                      if (_clientName?.trim().isNotEmpty == true)
                        'clientName': _clientName!.trim(),
                      if (_personId?.trim().isNotEmpty == true)
                        'personId': _personId!.trim(),
                      if (_relationship?.trim().isNotEmpty == true)
                        'relationship': _relationship!.trim(),
                    };

                    final uri = Uri(
                      path: '/measurement-result',
                      queryParameters: query.isEmpty ? null : query,
                    );

                    context.push(uri.toString());
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    try {
                      _cameraController?.stopImageStream();
                    } catch (_) {}
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
                  child: Text(
                    'Retake Scan',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUniversalMeasurementRows(
    BodyMeasurements m,
    MeasurementUnit unit,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (
            var index = 0;
            index < GarmentMeasurementCatalog.all.length;
            index++
          ) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: AppColors.divider.withValues(alpha: .7),
              ),
            _buildUniversalMeasurementRow(
              GarmentMeasurementCatalog.all[index],
              m,
              unit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUniversalMeasurementRow(
    GarmentMeasurementSpec spec,
    BodyMeasurements measurements,
    MeasurementUnit unit,
  ) {
    final valueCm = measurements.universalChartValueCm(spec.number);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Text(
              spec.number.toString().padLeft(2, '0'),
              style: TextStyle(
                color: spec.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 5,
            child: Text(
              spec.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              valueCm == null
                  ? 'Needs tape measurement'
                  : MeasurementFormat.formatDual(
                      valueCm,
                      unit,
                      fractionDigits: 1,
                    ),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueCm == null ? AppColors.textHint : spec.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEstimatedMeasurements() async {
    final current = _measurements;
    if (current == null) return;

    final unit = AppState.instance.measurementUnit;
    final specs = GarmentMeasurementCatalog.all
        .where((spec) => current.universalChartValueCm(spec.number) != null)
        .toList(growable: false);
    final initialValues = {
      for (final spec in specs)
        spec.number: unit.fromCm(current.universalChartValueCm(spec.number)!),
    };
    final editedValues = await showModalBottomSheet<Map<int, double>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => _CameraEstimateEditorSheet(
        unit: unit,
        specs: specs,
        initialValues: initialValues,
      ),
    );
    if (editedValues == null || !mounted) return;

    double? valueInCm(int number) {
      final value = editedValues[number];
      return value == null ? null : unit.toCm(value);
    }

    final updated = BodyMeasurements(
      neck: valueInCm(1) ?? current.neck,
      chest: valueInCm(3) ?? current.chest,
      waist: valueInCm(5) ?? current.waist,
      hips: valueInCm(6) ?? current.hips,
      height: valueInCm(7) ?? current.height,
      armLength: valueInCm(10) ?? current.armLength,
      shoulder: valueInCm(19) ?? current.shoulder,
      thigh: current.thigh,
      inseam: current.inseam,
      capturedAt: current.capturedAt,
    );
    AppState.instance.setMeasurements(updated);
    setState(() => _measurements = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Updated estimates will appear in your measurement profile.',
        ),
      ),
    );
  }

  Widget _buildSupplementaryEstimates(
    BodyMeasurements m,
    MeasurementUnit unit,
  ) {
    final estimates = [
      if (m.thigh != null) ('Thigh', m.thigh!),
      if (m.inseam != null) ('Inseam', m.inseam!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional camera estimates', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'These are shown separately because they do not match a point in the universal 22-point chart.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          for (final estimate in estimates)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(estimate.$1, style: AppTextStyles.bodyMedium),
                  Text(
                    MeasurementFormat.formatWithUnit(estimate.$2, unit),
                    style: AppTextStyles.labelLarge,
                  ),
                ],
              ),
            ),
        ],
      ),
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
          const Icon(
            Icons.no_photography_outlined,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 20),
          Text(
            'Camera Unavailable',
            style: AppTextStyles.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
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

class _CameraEstimateEditorSheet extends StatefulWidget {
  const _CameraEstimateEditorSheet({
    required this.unit,
    required this.specs,
    required this.initialValues,
  });

  final MeasurementUnit unit;
  final List<GarmentMeasurementSpec> specs;
  final Map<int, double> initialValues;

  @override
  State<_CameraEstimateEditorSheet> createState() =>
      _CameraEstimateEditorSheetState();
}

class _CameraEstimateEditorSheetState
    extends State<_CameraEstimateEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<int, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final spec in widget.specs)
        spec.number: TextEditingController(
          text: widget.initialValues[spec.number]!.toStringAsFixed(1),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      for (final spec in widget.specs)
        spec.number: double.parse(_controllers[spec.number]!.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final maximum = widget.unit == MeasurementUnit.cm ? 500 : 200;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Adjust camera estimates',
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Review and correct the values detected by the camera. Other chart points can be entered with the manual measurement method.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    for (final spec in widget.specs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          controller: _controllers[spec.number],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText:
                                '${spec.number.toString().padLeft(2, '0')} · ${spec.label}',
                            suffixText: widget.unit.abbrev,
                          ),
                          validator: (raw) {
                            final value = double.tryParse(raw?.trim() ?? '');
                            if (value == null ||
                                !value.isFinite ||
                                value <= 0 ||
                                value > maximum) {
                              return 'Enter a valid value in ${widget.unit.abbrev}.';
                            }
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save adjusted estimates'),
                ),
              ),
            ),
          ],
        ),
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
    Future.delayed(
      widget.delay,
      () => mounted ? setState(() => _visible = true) : null,
    );
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
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
