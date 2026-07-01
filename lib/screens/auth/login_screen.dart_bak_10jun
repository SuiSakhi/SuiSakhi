import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router_keys.dart';
import '../../models/user_profile.dart';

String _formatPhoneVerifyError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'Invalid phone number.';
    case 'missing-phone-number':
      return 'Enter a valid phone number.';
    case 'too-many-requests':
      // Firebase often returns the real reason (device block, abuse protection).
      if (e.message != null && e.message!.trim().isNotEmpty) {
        return e.message!.trim();
      }
      return 'Too many attempts. Firebase may temporarily block this device. Wait several hours, '
          'try another device or network, or add a test phone number in Firebase Console.';
    case 'internal-error':
      // Common after device block, APNs/reCAPTCHA edge cases, or transient backend issues.
      if (e.message != null && e.message!.trim().isNotEmpty) {
        return '${e.message!.trim()}\n\nIf you recently saw “blocked” or “too many requests”, wait several '
            'hours or use a Firebase test phone number. Otherwise check iOS push capability and try again.';
      }
      return 'Phone verification failed (internal error). This often follows rate limits or a temporary '
          'Firebase issue. Wait, use a test number in Firebase Console (Authentication → Phone), or try '
          'another device.';
    case 'invalid-app-credential':
      return 'iOS app credential rejected (APNs / Firebase setup). In Xcode enable Push Notifications, '
          'ensure the same bundle ID as Firebase, and that Phone auth is enabled for this iOS app.';
    case 'quota-exceeded':
      return 'SMS quota exceeded for this project.';
    case 'captcha-check-failed':
      return 'Security check failed. Close and try again, or complete any browser step.';
    case 'missing-client-identifier':
      return 'iOS setup issue: enable Phone in Firebase Console and check bundle ID.';
    case 'app-not-authorized':
      return 'Phone sign-in is not enabled for this app in Firebase.';
    case 'network-request-failed':
      return 'Network error. Check connection and try again.';
    case 'invalid-verification-code':
      return 'Wrong verification code. Use the 6-digit code from the SMS Firebase sent — '
          'not a made-up code like 123456 unless you added this exact number as a '
          'test phone in Firebase Console → Authentication → Phone.';
    case 'invalid-verification-id':
    case 'expired-action-code':
      return 'Verification expired or invalid. Tap Continue with OTP and tap Send OTP again.';
    case 'session-expired':
      return 'Session expired. Open Continue with OTP again and request a new code.';
    case 'credential-already-in-use':
      return 'This phone number is already linked to another account. Contact support if you need help.';
    default:
      return e.message?.trim().isNotEmpty == true
          ? '${e.message}\n(${e.code})'
          : 'Error: ${e.code}';
  }
}

UserRole _roleFromRegistryString(String? r) {
  switch ((r ?? 'customer').toLowerCase().trim()) {
    case 'owner':
      return UserRole.owner;
    case 'tailor':
      return UserRole.tailor;
    case 'delivery':
      return UserRole.delivery;
    default:
      return UserRole.customer;
  }
}

String _humanRolePhrase(UserRole r) {
  return switch (r) {
    UserRole.owner => 'shop owner',
    UserRole.tailor => 'tailor',
    UserRole.delivery => 'delivery partner',
    UserRole.customer => 'customer',
  };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Holds phone-verification UI state. Firebase callbacks must not depend on
/// [State.mounted] for the login route — with GoRouter + a pushed page, [mounted]
/// can be false even though this model and the phone route are still active.
class _PhoneAuthFlowModel extends ChangeNotifier {
  String? verificationId;
  bool otpStep = false;
  bool loading = false;
  String? error;
  String phoneDisplay = '';
  /// Set when user taps Send OTP (used after sign-in for profile name).
  String collectedDisplayName = '';
  /// Captured when the phone sheet opens (survives [LoginScreen] recreation).
  UserRole intentRole = UserRole.customer;
  bool _disposed = false;
  Timer? _verificationFailDebounce;

  bool get alive => !_disposed;

  @override
  void dispose() {
    _verificationFailDebounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  void cancelVerificationFailDebounce() {
    _verificationFailDebounce?.cancel();
    _verificationFailDebounce = null;
  }

  /// Firebase sometimes fires [verificationFailed] briefly before [codeSent]; delay
  /// so a real error still shows after 500ms, but spurious failures are cancelled.
  void debouncedVerificationFailed(String message) {
    cancelVerificationFailDebounce();
    _verificationFailDebounce = Timer(const Duration(milliseconds: 500), () {
      _verificationFailDebounce = null;
      if (_disposed) return;
      if (otpStep) return;
      setFailed(message);
    });
  }

  void reset() {
    if (_disposed) return;
    cancelVerificationFailDebounce();
    verificationId = null;
    otpStep = false;
    loading = false;
    error = null;
    phoneDisplay = '';
    collectedDisplayName = '';
    notifyListeners();
  }

  void setFailed(String message) {
    if (_disposed) return;
    loading = false;
    error = message;
    notifyListeners();
  }

  void setLoading(bool value) {
    if (_disposed) return;
    loading = value;
    notifyListeners();
  }

  void clearError() {
    if (_disposed) return;
    error = null;
    notifyListeners();
  }

  void backToPhoneInput() {
    if (_disposed) return;
    otpStep = false;
    error = null;
    notifyListeners();
  }

  void mergeTimeoutVerificationId(String id) {
    if (_disposed) return;
    verificationId ??= id;
    notifyListeners();
  }

  /// Firebase may invoke [codeSent] during layout/build; notify immediately and
  /// again after the frame so the pushed route always repaints.
  void setCodeSent(String id) {
    if (_disposed) return;
    cancelVerificationFailDebounce();
    verificationId = id;
    otpStep = true;
    loading = false;
    error = null;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      notifyListeners();
    });
  }
}

/// Shared instance — must not be tied to [LoginScreen] lifecycle. GoRouter can
/// rebuild login when Firebase reCAPTCHA returns a custom URL scheme, which
/// would dispose a per-screen model while the phone sheet is still open.
final _kPhoneAuthFlowModel = _PhoneAuthFlowModel();

/// Pushed on root navigator; [State.setState] on model updates so the OTP step
/// reliably repaints with GoRouter + overlay routes.
class _PhoneAuthRouteHost extends StatefulWidget {
  const _PhoneAuthRouteHost({
    required this.model,
    required this.navCtx,
    required this.pageBuilder,
  });

  final _PhoneAuthFlowModel model;
  final BuildContext navCtx;
  final Widget Function(BuildContext navCtx) pageBuilder;

  @override
  State<_PhoneAuthRouteHost> createState() => _PhoneAuthRouteHostState();
}

class _PhoneAuthRouteHostState extends State<_PhoneAuthRouteHost> {
  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModel);
  }

  @override
  void didUpdateWidget(covariant _PhoneAuthRouteHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_onModel);
      widget.model.addListener(_onModel);
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModel);
    super.dispose();
  }

  void _onModel() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Do not add manual viewInsets padding here — [Scaffold] already resizes the body
    // for the keyboard. Doubling insets left a large empty band between fields and keys.
    final m = widget.model;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          if (m.loading)
            const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: SafeArea(
              child: widget.pageBuilder(widget.navCtx),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  _PhoneAuthFlowModel get _phoneAuthModel => _kPhoneAuthFlowModel;
  TextEditingController? _phoneFlowNameCtrl;
  TextEditingController? _phoneFlowPhoneCtrl;
  TextEditingController? _phoneFlowOtpCtrl;
  Timer? _phoneVerifyWatchdog;
  bool _loading = false;
  String? _error;
  UserRole _selectedRole = UserRole.customer;

  void _cancelPhoneWatchdog() {
    _phoneVerifyWatchdog?.cancel();
    _phoneVerifyWatchdog = null;
  }

  void _armPhoneWatchdog() {
    _cancelPhoneWatchdog();
    _phoneVerifyWatchdog = Timer(const Duration(seconds: 130), () {
      if (!_phoneAuthModel.alive) return;
      if (_phoneAuthModel.otpStep || !_phoneAuthModel.loading) return;
      _phoneAuthModel.setFailed(
        'No response from Firebase after 2 minutes. Check: SMS quota (Spark plan ~10/day), '
        'Firebase Console → Authentication → Phone → test numbers, App Check not blocking Auth, '
        'and complete reCAPTCHA in the browser.',
      );
    });
  }

  @override
  void dispose() {
    _cancelPhoneWatchdog();
    super.dispose();
  }

  static bool _isMeaningfulDisplayName(String? s) {
    final t = s?.trim() ?? '';
    return t.isNotEmpty && t != 'User' && t != 'Guest';
  }

  /// Display name: saved Firestore name first (returning phone users), then name
  /// typed on the OTP sheet, then profile email local-part — never raw phone as display name.
  String _resolvedProfileDisplayName({
    required User user,
    String? email,
    String? override,
    UserProfile? existing,
  }) {
    final existingName = existing?.name.trim();
    if (_isMeaningfulDisplayName(existingName)) return existingName!;

    final o = override?.trim();
    if (_isMeaningfulDisplayName(o)) return o!;

    final dn = user.displayName?.trim();
    if (_isMeaningfulDisplayName(dn)) return dn!;

    final local = user.email?.split('@').first;
    if (_isMeaningfulDisplayName(local)) return local!;

    return 'User';
  }

  String _destinationFor(UserRole role, {bool returning = false}) {
    return switch (role) {
      UserRole.owner    => '/owner',
      UserRole.tailor   => '/tailor',
      UserRole.delivery => '/delivery',
      UserRole.customer => returning ? '/home' : '/onboarding',
    };
  }

  // ── Shared post-auth handler ─────────────────────────────────────────────
  Future<void> _handleSignedInUser(
    User user, {
    String? email,
    UserRole? loginRoleOverride,
    String? displayNameOverride,
  }) async {
    // Step 1: Temporary profile
    AppState.instance.setProfile(UserProfile(
      name: _resolvedProfileDisplayName(
        user: user,
        email: email,
        override: displayNameOverride,
      ),
      email: email ?? user.email,
      photoUrl: user.photoURL,
      role: UserRole.customer,
      notifyWhatsApp: true,
    ));

    // Step 2: Check config role (admin: owner/tailor/delivery emails + tailorPhones for OTP).
    final configRole = await AppState.instance.getRoleFromConfig(
      email ?? user.email,
      phoneE164: user.phoneNumber,
    );

    // Step 3: Load existing Firestore profile
    await AppState.instance.loadUserProfile(user.uid);
    await AppState.instance.loadRates();

    final chosenRole = loginRoleOverride ?? _selectedRole;

    UserRole finalRole;
    bool returning = AppState.instance.hasCompletedSetup;
    final existing = AppState.instance.profile;
    String? ownerEnrollmentEmail;

    if (configRole != null) {
      // Email in owner/tailor/delivery config — highest priority
      finalRole = configRole;
    } else if (existing != null && existing.role != UserRole.customer) {
      // Firestore profile already has a non-customer role (set from a prior login)
      finalRole = existing.role;
    } else if (chosenRole == UserRole.owner) {
      final ownerEmail = await _promptOwnerSetup(
        existingEmail: email ?? user.email,
      );
      if (ownerEmail == null) {
        if (mounted) {
          setState(() {
            _error = 'Owner access denied. Contact the app administrator.';
            _loading = false;
          });
        }
        await FirebaseAuth.instance.signOut();
        return;
      }
      finalRole = UserRole.owner;
      returning = false;
      ownerEnrollmentEmail = ownerEmail;
      await AppState.instance.enrollOwner(ownerEmail);
    } else if (chosenRole == UserRole.tailor) {
      // Tailor is invite-only: config/admin.tailorEmails and/or tailorPhones (Owner → Enroll Tailor).
      final em = (email ?? user.email)?.trim();
      final ph = user.phoneNumber?.trim();
      final detail = (em != null && em.isNotEmpty)
          ? 'Ask the owner to add this email under Owner → Enroll Tailor:\n\n$em'
          : (ph != null && ph.isNotEmpty)
              ? 'Ask the owner to add this exact phone (E.164) under Owner → Enroll Tailor:\n\n$ph'
              : 'Sign in with the phone number the owner enrolled under Owner → Enroll Tailor '
                  '(E.164, e.g. +91…), or ask them to add your email in config.';
      if (mounted) {
        setState(() {
          _error = 'Tailor access is not enabled for this account.\n\n$detail';
          _loading = false;
        });
      }
      await FirebaseAuth.instance.signOut();
      return;
    } else {
      finalRole = chosenRole;
    }

    // Step 4: Save final profile
    AppState.instance.setProfile(UserProfile(
      name: _resolvedProfileDisplayName(
        user: user,
        email: email,
        override: displayNameOverride,
        existing: existing,
      ),
      email: ownerEnrollmentEmail ??
          existing?.email ??
          email ??
          user.email,
      photoUrl: existing?.photoUrl ?? user.photoURL,
      age: existing?.age ?? 0,
      role: finalRole,
      notifyWhatsApp: existing?.notifyWhatsApp ?? true,
      payoutUpiId: existing?.payoutUpiId,
      deliveryAddress: existing?.deliveryAddress,
    ));
    try {
      await AppState.instance.saveUserProfile();
    } on FirebaseException catch (e) {
      // Most common: Firestore rules block writes to users/{uid}. Auth still succeeded.
      final navCtx0 = (mounted && context.mounted)
          ? context
          : stitchSmartRootNavigatorKey.currentContext;
      if (navCtx0 != null && navCtx0.mounted) {
        final pid = Firebase.app().options.projectId.trim();
        final rulesUri = pid.isEmpty
            ? null
            : Uri.parse(
                'https://console.firebase.google.com/project/$pid/firestore/rules',
              );
        ScaffoldMessenger.of(navCtx0).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 12),
            content: Text(
              e.code == 'permission-denied'
                  ? 'Signed in, but Firestore blocked saving your profile. '
                      'Publish rules for users/{userId} (see firebase/firestore.rules).'
                  : 'Could not save profile: ${e.message ?? e.code}',
            ),
            action: rulesUri != null && e.code == 'permission-denied'
                ? SnackBarAction(
                    label: 'Rules',
                    onPressed: () async {
                      if (await canLaunchUrl(rulesUri)) {
                        await launchUrl(rulesUri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  )
                : null,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
    final navCtx = (mounted && context.mounted)
        ? context
        : stitchSmartRootNavigatorKey.currentContext;
    if (navCtx != null && navCtx.mounted) {
      GoRouter.of(navCtx).go(_destinationFor(finalRole, returning: returning));
    }
  }

  // ── Phone / OTP Sign-In ──────────────────────────────────────────────────
  Future<void> _showPhoneSignInSheet() async {
    _cancelPhoneWatchdog();
    _phoneFlowNameCtrl = TextEditingController();
    _phoneFlowPhoneCtrl = TextEditingController();
    _phoneFlowOtpCtrl = TextEditingController();
    _phoneAuthModel.reset();
    _phoneAuthModel.intentRole = _selectedRole;

    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (navCtx) {
          return _PhoneAuthRouteHost(
            model: _phoneAuthModel,
            navCtx: navCtx,
            pageBuilder: _buildPhoneOtpPage,
          );
        },
      ),
    );

    // Dispose after the route is gone — avoids races with TextField / focus teardown
    // that can trigger framework.dart _dependents assertions on iOS when popping with keyboard up.
    final nameC = _phoneFlowNameCtrl;
    final phoneC = _phoneFlowPhoneCtrl;
    final otpC = _phoneFlowOtpCtrl;
    _phoneFlowNameCtrl = null;
    _phoneFlowPhoneCtrl = null;
    _phoneFlowOtpCtrl = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameC?.dispose();
      phoneC?.dispose();
      otpC?.dispose();
    });
  }

  /// Pops the OTP sheet safely (keyboard + inherited widgets tear down in a stable order).
  void _closePhoneAuthSheet(BuildContext sheetContext) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!sheetContext.mounted) return;
      Navigator.of(sheetContext, rootNavigator: true).pop();
    });
  }

  Future<void> _completePhoneSignInAndPop(
    BuildContext navCtx,
    PhoneAuthCredential credential,
  ) async {
    if (navCtx.mounted) {
      Navigator.of(navCtx, rootNavigator: true).pop();
    }
    _phoneAuthModel.setLoading(false);
    await _signInWithPhoneCredential(credential);
  }

  Future<void> _sendPhoneFlowOtp(BuildContext navCtx) async {
    final nameCtrl = _phoneFlowNameCtrl;
    final phoneCtrl = _phoneFlowPhoneCtrl;
    if (phoneCtrl == null || nameCtrl == null) return;
    final raw = phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.length < 10) {
      _phoneAuthModel.setFailed('Enter a valid phone number (10+ digits)');
      return;
    }
    final e164 = raw.startsWith('+') ? raw : '+91$raw';
    final display = raw.startsWith('+') ? raw : '+91$raw';

    _phoneAuthModel.clearError();

    final reg = await AppState.instance.fetchPhoneRegistry(e164);
    if (reg != null && reg.uid.isNotEmpty && navCtx.mounted) {
      final regRole = _roleFromRegistryString(reg.roleName);
      if (regRole != _phoneAuthModel.intentRole) {
        final ok = await showDialog<bool>(
              context: navCtx,
              builder: (ctx) => AlertDialog(
                title: const Text('Account type'),
                content: Text(
                  'This number is registered as ${_humanRolePhrase(regRole)}'
                  '${reg.displayName != null && reg.displayName!.trim().isNotEmpty ? ' (${reg.displayName})' : ''}. '
                  'You chose ${_humanRolePhrase(_phoneAuthModel.intentRole)}. Continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Back'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
      } else {
        final nm = reg.displayName?.trim();
        if (nm != null && nm.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!navCtx.mounted) return;
            ScaffoldMessenger.of(navCtx).showSnackBar(
              SnackBar(
                content: Text(
                  'Registered as ${_humanRolePhrase(regRole)} · $nm',
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          });
        }
      }
    }

    _phoneAuthModel.setLoading(true);

    var name = nameCtrl.text.trim();
    try {
      if (!_isMeaningfulDisplayName(name)) {
        final fromDb =
            await AppState.instance.lookupDisplayNameByPhoneForSignIn(e164);
        if (_isMeaningfulDisplayName(fromDb)) {
          name = fromDb!;
          nameCtrl.text = name;
        }
      }
    } catch (_) {
      // Lookup is best-effort (rules / network); continue with typed or empty name.
    }

    // Name may stay empty: after OTP, [loadUserProfile] + [_resolvedProfileDisplayName]
    // prefer the saved Firestore name for returning users.
    _phoneAuthModel.collectedDisplayName = name;
    _phoneAuthModel.phoneDisplay = display;
    _armPhoneWatchdog();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 120),
      // Android instant verification — auto sign-in. On iOS always show OTP (avoids
      // rare plugin/callback ordering that pops the sheet before the OTP UI paints).
      verificationCompleted: (credential) async {
        _cancelPhoneWatchdog();
        if (!_phoneAuthModel.alive) return;
        _phoneAuthModel.cancelVerificationFailDebounce();
        _phoneAuthModel.setLoading(false);
        if (defaultTargetPlatform == TargetPlatform.iOS) return;
        if (!navCtx.mounted) return;
        await _completePhoneSignInAndPop(navCtx, credential);
      },
      verificationFailed: (e) {
        _cancelPhoneWatchdog();
        if (kDebugMode) {
          debugPrint('[PhoneAuth] verificationFailed code=${e.code} message=${e.message}');
        }
        _phoneAuthModel.debouncedVerificationFailed(_formatPhoneVerifyError(e));
      },
      // Do NOT gate on LoginScreen mounted — it is often false here with GoRouter + push.
      codeSent: (verificationId, _) {
        _cancelPhoneWatchdog();
        if (kDebugMode) {
          debugPrint('[PhoneAuth] codeSent verificationId received');
        }
        _phoneAuthModel.setCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (kDebugMode) {
          debugPrint('[PhoneAuth] codeAutoRetrievalTimeout');
        }
        _phoneAuthModel.mergeTimeoutVerificationId(verificationId);
      },
    );
    } catch (e) {
      _cancelPhoneWatchdog();
      _phoneAuthModel.cancelVerificationFailDebounce();
      _phoneAuthModel.setFailed('Could not start phone verification. Try again.');
    }
  }

  Future<void> _verifyPhoneFlowOtp(BuildContext navCtx) async {
    final vid = _phoneAuthModel.verificationId;
    final otpCtrl = _phoneFlowOtpCtrl;
    if (vid == null || otpCtrl == null) {
      _phoneAuthModel.setFailed('No verification in progress. Send OTP again.');
      return;
    }
    final code = otpCtrl.text.trim();
    if (code.length != 6) {
      _phoneAuthModel.setFailed('Enter the 6-digit OTP');
      return;
    }
    _phoneAuthModel.clearError();
    _phoneAuthModel.setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: code,
      );
      await _completePhoneSignInAndPop(navCtx, credential);
    } on FirebaseAuthException catch (e) {
      _phoneAuthModel.setFailed(_formatPhoneVerifyError(e));
    } catch (_) {
      _phoneAuthModel.setFailed('Invalid OTP. Please try again.');
    }
  }

  Widget _buildPhoneOtpPage(BuildContext navCtx) {
    final m = _phoneAuthModel;
    final nameCtrl = _phoneFlowNameCtrl!;
    final phoneCtrl = _phoneFlowPhoneCtrl!;
    final otpCtrl = _phoneFlowOtpCtrl!;
    const fieldScrollPad = EdgeInsets.only(bottom: 100);

    Widget primaryButton() {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: m.loading
              ? null
              : () {
                  if (m.otpStep) {
                    _verifyPhoneFlowOtp(navCtx);
                  } else {
                    _sendPhoneFlowOtp(navCtx);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: m.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  m.otpStep ? 'Verify & Sign In' : 'Send OTP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
        ),
      );
    }

    // [Builder] uses context under [Scaffold] body (insets already applied there).
    // Single scroll column keeps fields + button contiguous — no SliverFillRemaining gap.
    return Builder(
      builder: (context) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.otpStep ? 'Enter OTP' : 'Sign in with OTP',
                      style: AppTextStyles.titleLarge,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _closePhoneAuthSheet(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                m.otpStep
                    ? 'Code sent to ${m.phoneDisplay}'
                    : 'Mobile for SMS OTP. Name optional if you already use the app.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (!m.otpStep) ...[
                TextField(
                  controller: nameCtrl,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  scrollPadding: fieldScrollPad,
                  decoration: InputDecoration(
                    // Short label — long copy belongs in helper + subtitle (long labels
                    // + prefixIcon + isDense overlap the outline on narrow phones).
                    labelText: 'Your name',
                    hintText: 'e.g. Priya Sharma',
                    helperText: 'Optional for returning users',
                    helperMaxLines: 1,
                    isDense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    prefixIcon: const Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) {
                    FocusScope.of(context).nextFocus();
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  scrollPadding: fieldScrollPad,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Mobile number',
                    hintText: '9876543210',
                    prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                    prefixText: '+91 ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!m.loading) _sendPhoneFlowOtp(navCtx);
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  'India +91. Else include country code.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ] else ...[
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  autofocus: true,
                  scrollPadding: fieldScrollPad,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '• • • • • •',
                    hintStyle: const TextStyle(letterSpacing: 8, fontSize: 18),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!m.loading) _verifyPhoneFlowOtp(navCtx);
                  },
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: m.loading
                        ? null
                        : () {
                            otpCtrl.clear();
                            _phoneAuthModel.backToPhoneInput();
                          },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Change number'),
                  ),
                ),
              ],
              if (!m.loading && m.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          m.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              primaryButton(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    if (mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      await _handleSignedInUser(
        user,
        loginRoleOverride: _kPhoneAuthFlowModel.intentRole,
        displayNameOverride: _kPhoneAuthFlowModel.collectedDisplayName.trim().isEmpty
            ? null
            : _kPhoneAuthFlowModel.collectedDisplayName.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatPhoneVerifyError(e);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Sign-in failed: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Owner bootstrap (OTP-only: collect shop email for config enrollment) ─
  static bool _looksLikeEmail(String s) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());
  }

  Future<String?> _promptOwnerSetup({String? existingEmail}) async {
    const bootstrapCode = 'STITCHSMART2024';
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController(text: existingEmail?.trim() ?? '');
    final dialogCtx = (mounted && context.mounted)
        ? context
        : stitchSmartRootNavigatorKey.currentContext;
    if (dialogCtx == null) return null;
    final result = await showDialog<String?>(
      context: dialogCtx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Owner setup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Owner access code and the email added to Firestore config for this shop.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Access code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Owner email',
                  hintText: 'you@shop.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.trim() != bootstrapCode) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid access code')),
                );
                return;
              }
              final em = emailCtrl.text.trim().toLowerCase();
              if (!_looksLikeEmail(em)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid owner email')),
                );
                return;
              }
              Navigator.pop(ctx, em);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      codeCtrl.dispose();
      emailCtrl.dispose();
    });
    return result;
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body [Container] must fill the viewport; otherwise it shrink-wraps and the
      // default scaffold color shows as a band under the safe area (e.g. home indicator).
      backgroundColor: AppColors.primary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.content_cut_rounded,
                      color: AppColors.primary, size: 52),
                ),
                const SizedBox(height: 28),
                Text(
                  'StitchSmart',
                  style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tailored Just For You',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 32),

                // Role selector
                Text('I am a…',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RoleCard(
                      label: 'Customer',
                      icon: Icons.person_rounded,
                      selected: _selectedRole == UserRole.customer,
                      onTap: () => setState(() => _selectedRole = UserRole.customer),
                    ),
                    const SizedBox(width: 10),
                    _RoleCard(
                      label: 'Tailor',
                      icon: Icons.content_cut_rounded,
                      selected: _selectedRole == UserRole.tailor,
                      onTap: () => setState(() => _selectedRole = UserRole.tailor),
                    ),
                    const SizedBox(width: 10),
                    _RoleCard(
                      label: 'Owner',
                      icon: Icons.store_rounded,
                      selected: _selectedRole == UserRole.owner,
                      onTap: () => setState(() => _selectedRole = UserRole.owner),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Sign in with SMS OTP.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                _OtpSignInButton(loading: _loading, onTap: _showPhoneSignInSheet),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'By continuing you agree to Terms & Privacy.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role Card ────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26,
                  color: selected ? AppColors.primary : Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : Colors.white,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── OTP Sign-In Button ───────────────────────────────────────────────────────
class _OtpSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _OtpSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Continue with OTP',
                style: AppTextStyles.titleMedium.copyWith(
                  color: const Color(0xFF3C4043),
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
