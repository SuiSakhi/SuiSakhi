import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router_keys.dart';

/// App access is managed by the persistent Firebase sign-in session.
/// OTP is required after sign-out or when authenticating on another device.
const bool kAppPinEnabled = false;

class AppPinStore {
  AppPinStore._();

  static const int maxAttempts = 5;
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _pinKey(String uid) => 'suisakhi_app_pin_$uid';
  static String _attemptsKey(String uid) => 'suisakhi_app_pin_attempts_$uid';
  static String _blockedKey(String uid) => 'suisakhi_app_pin_blocked_$uid';
  static String _routeKey(String uid) => 'suisakhi_app_pin_route_$uid';

  static Future<bool> hasPin(String uid) async =>
      (await _storage.read(key: _pinKey(uid)))?.isNotEmpty == true;

  static Future<void> savePin(String uid, String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain six digits.');
    }
    await _storage.write(key: _pinKey(uid), value: pin);
    await _storage.delete(key: _attemptsKey(uid));
    await _storage.delete(key: _blockedKey(uid));
  }

  static Future<bool> verifyPin(String uid, String pin) async {
    if (await isBlocked(uid)) return false;

    final saved = await _storage.read(key: _pinKey(uid));
    if (saved != null && saved == pin) {
      await _storage.delete(key: _attemptsKey(uid));
      return true;
    }

    final attempts =
        int.tryParse(await _storage.read(key: _attemptsKey(uid)) ?? '0') ?? 0;
    final nextAttempts = attempts + 1;
    if (nextAttempts >= maxAttempts) {
      await _storage.write(key: _blockedKey(uid), value: 'true');
      await _storage.delete(key: _attemptsKey(uid));
    } else {
      await _storage.write(
        key: _attemptsKey(uid),
        value: nextAttempts.toString(),
      );
    }
    return false;
  }

  static Future<bool> isBlocked(String uid) async =>
      (await _storage.read(key: _blockedKey(uid))) == 'true';

  static Future<int> attemptsRemaining(String uid) async {
    if (await isBlocked(uid)) return 0;
    final attempts =
        int.tryParse(await _storage.read(key: _attemptsKey(uid)) ?? '0') ?? 0;
    return maxAttempts - attempts;
  }

  static Future<void> saveDestination(String uid, String destination) async {
    if (destination.startsWith('/')) {
      await _storage.write(key: _routeKey(uid), value: destination);
    }
  }

  static Future<String?> readDestination(String uid) async {
    final value = await _storage.read(key: _routeKey(uid));
    return value != null && value.startsWith('/') ? value : null;
  }
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({required this.uid, this.replacing = false, super.key});

  final String uid;
  final bool replacing;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _controller = TextEditingController();
  String? _firstPin;
  String? _error;
  bool _confirming = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    final value = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      setState(() => _error = 'Enter all six digits.');
      return;
    }

    if (!_confirming) {
      setState(() {
        _firstPin = value;
        _confirming = true;
        _error = null;
        _controller.clear();
      });
      return;
    }

    if (value != _firstPin) {
      setState(() {
        _error = 'The PINs do not match. Enter your new PIN again.';
        _confirming = false;
        _firstPin = null;
        _controller.clear();
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppPinStore.savePin(widget.uid, value);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the PIN securely. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _confirming ? 'Confirm your PIN' : 'Create your PIN';
    final subtitle = _confirming
        ? 'Enter the same six-digit PIN once more.'
        : widget.replacing
        ? 'Choose a new six-digit PIN for this device.'
        : 'You will use this PIN to open SuiSakhi on this device.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 52,
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Pinput(
                      controller: _controller,
                      length: 6,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      onCompleted: (_) => _continue(),
                      defaultPinTheme: _pinTheme(),
                      focusedPinTheme: _pinTheme(focused: true),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _continue,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_confirming ? 'Save PIN' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({
    required this.uid,
    required this.onUnlocked,
    required this.onForgotPin,
    super.key,
  });

  final String uid;
  final Future<void> Function(String uid) onUnlocked;
  final Future<void> Function() onForgotPin;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _blocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshBlockState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshBlockState() async {
    final blocked = await AppPinStore.isBlocked(widget.uid);
    if (mounted) setState(() => _blocked = blocked);
  }

  Future<void> _submit() async {
    if (_busy || _blocked) return;
    final pin = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter your six-digit PIN.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final valid = await AppPinStore.verifyPin(widget.uid, pin);
      if (!mounted) return;
      if (valid) {
        await widget.onUnlocked(widget.uid);
        return;
      }
      final remaining = await AppPinStore.attemptsRemaining(widget.uid);
      setState(() {
        _blocked = remaining == 0;
        _error = _blocked
            ? 'Too many incorrect attempts. Verify by OTP to reset your PIN.'
            : 'Incorrect PIN. $remaining attempt(s) remain.';
        _controller.clear();
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not check the PIN. Please try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_person_outlined,
                      color: AppColors.primary,
                      size: 52,
                    ),
                    const SizedBox(height: 18),
                    Text('Welcome back', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      phone.isEmpty
                          ? 'Enter your SuiSakhi PIN to continue.'
                          : 'Enter your PIN to continue as $phone.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Pinput(
                      controller: _controller,
                      length: 6,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      onCompleted: (_) => _submit(),
                      defaultPinTheme: _pinTheme(),
                      focusedPinTheme: _pinTheme(focused: true),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy || _blocked ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : widget.onForgotPin,
                      child: const Text('Forgot PIN? Verify with OTP'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PinTheme _pinTheme({bool focused = false}) => PinTheme(
  width: 46,
  height: 52,
  textStyle: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  ),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: focused ? AppColors.primary : AppColors.divider,
      width: focused ? 1.8 : 1.2,
    ),
  ),
);

class PinLockGate extends StatefulWidget {
  const PinLockGate({required this.child, super.key});

  final Widget child;

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> with WidgetsBindingObserver {
  String? _lockedUid;
  bool _receivedInitialAuthState = false;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => unawaited(_handleAuthState(user)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleAuthState(User? user) async {
    final isInitial = !_receivedInitialAuthState;
    _receivedInitialAuthState = true;

    if (!kAppPinEnabled) {
      if (mounted) setState(() => _lockedUid = null);
      return;
    }

    if (user == null || user.phoneNumber == null) {
      if (mounted) setState(() => _lockedUid = null);
      return;
    }

    final hasPin = await AppPinStore.hasPin(user.uid);
    if (!mounted) return;

    if (isInitial) {
      if (hasPin) {
        setState(() => _lockedUid = user.uid);
      } else {
        // Existing Firebase sessions without a device PIN must verify by OTP
        // before setting one on this device.
        await AppState.instance.signOut();
      }
      return;
    }

    // A new Firebase sign-in followed a successful OTP flow.
    setState(() => _lockedUid = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_lockWhenBackgrounded());
    }
  }

  Future<void> _lockWhenBackgrounded() async {
    if (!kAppPinEnabled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.phoneNumber == null) return;
    if (!await AppPinStore.hasPin(user.uid) || !mounted) return;
    setState(() => _lockedUid = user.uid);
  }

  Future<void> _unlock(String uid) async {
    try {
      await AppState.instance.loadUserProfile(uid);
      await AppState.instance.loadRates();
    } catch (_) {}

    final destination = await AppPinStore.readDestination(uid) ?? '/home';
    if (!mounted) return;
    setState(() => _lockedUid = null);

    final navContext = suiSakhiRootNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      GoRouter.of(navContext).go(destination);
    }
  }

  Future<void> _forgotPin() async {
    await AppState.instance.signOut();
    if (!mounted) return;
    final navContext = suiSakhiRootNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      GoRouter.of(navContext).go('/login?intent=customer&resetPin=1');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kAppPinEnabled) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_lockedUid != null)
          Positioned.fill(
            child: PinUnlockScreen(
              key: ValueKey(_lockedUid),
              uid: _lockedUid!,
              onUnlocked: _unlock,
              onForgotPin: _forgotPin,
            ),
          ),
      ],
    );
  }
}
