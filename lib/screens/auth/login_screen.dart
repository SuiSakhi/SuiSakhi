import 'dart:async';

import 'package:pinput/pinput.dart';
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
import '../profile/profile_selection_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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
    // Preserve all existing customer profile fields loaded from Firestore.
    // Important: Do not lose DOB, height, weight, fit preference, language,
    // and notification preferences during login role resolution.
    AppState.instance.setProfile(UserProfile(
      name: _resolvedProfileDisplayName(
        user: user,
        email: email,
        override: displayNameOverride,
        existing: existing,
      ),
      gender: existing?.gender ?? Gender.female,
      age: existing?.age ?? 0,
      role: finalRole,
      avatarPath: existing?.avatarPath,
      email: ownerEnrollmentEmail ??
          existing?.email ??
          email ??
          user.email,
      photoUrl: existing?.photoUrl ?? user.photoURL,

      // Preserve new customer profile fields.
      dateOfBirth: existing?.dateOfBirth,
      heightCm: existing?.heightCm,
      weightKg: existing?.weightKg,
      fitPreference: existing?.fitPreference,
      preferredLanguage: existing?.preferredLanguage ?? 'English',

      // Preserve notification preferences.
      notifySms: existing?.notifySms ?? true,
      notifyWhatsApp: existing?.notifyWhatsApp ?? true,
      notifyApp: existing?.notifyApp ?? true,
      notifyEmail: existing?.notifyEmail ?? false,

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
    try {
      final signedInUser = FirebaseAuth.instance.currentUser;
      final signedInPhone = signedInUser?.phoneNumber;

      if (signedInUser != null &&
          signedInPhone != null &&
          signedInPhone.trim().isNotEmpty) {
        await AppState.instance.ensureAccountAndDefaultProfileAfterLogin(
          uid: signedInUser.uid,
          mobileE164: signedInPhone.trim(),
          displayName: signedInUser.displayName,
        );
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'SuiSakhi account/profile foundation skipped: ${e.code} ${e.message}',
      );
    } catch (e) {
      debugPrint('SuiSakhi account/profile foundation skipped: $e');
    }
    
final navCtx = (mounted && context.mounted)
    ? context
    : stitchSmartRootNavigatorKey.currentContext;

if (navCtx != null && navCtx.mounted) {
  try {
    final signedInUser = FirebaseAuth.instance.currentUser;
    final signedInPhone = signedInUser?.phoneNumber;

    if (signedInUser != null &&
        signedInPhone != null &&
        signedInPhone.trim().isNotEmpty) {
      final accountId = await AppState.instance.fetchAccountIdForMobile(
        signedInPhone.trim(),
      );

      if (accountId != null && accountId.isNotEmpty) {
        final profiles =
            await AppState.instance.fetchActiveProfilesForAccount(accountId);

        debugPrint('SuiSakhi active profile count: ${profiles.length}');    
/*
        debugPrint(
          'SuiSakhi profiles found for account $accountId: ${profiles.length}',
        );

        for (final p in profiles) {
          debugPrint(
            'Profile: role=${p['role']} displayName=${p['displayName']} shopName=${p['shopName']} status=${p['status']}',
          );
        }
*/
        if (profiles.length > 1 && navCtx.mounted) {
          final selectedProfile =
              await Navigator.of(navCtx, rootNavigator: true)
                  .push<Map<String, dynamic>>(
            MaterialPageRoute<Map<String, dynamic>>(
              builder: (_) => ProfileSelectionScreen(
                profiles: profiles,
              ),
            ),
          );

          if (selectedProfile != null) {
            final selectedProfileId =
                selectedProfile['profileId']?.toString() ??
                    selectedProfile['docId']?.toString();

            if (selectedProfileId != null &&
                selectedProfileId.trim().isNotEmpty) {
              await AppState.instance.setActiveProfileForAccount(
                accountId: accountId,
                profileId: selectedProfileId,
              );

              final selectedRole =
                  AppState.instance.roleFromProfileData(selectedProfile);

              if (mounted) {
                setState(() => _loading = false);
              }

              if (navCtx.mounted) {
                GoRouter.of(navCtx).go(
                  _destinationFor(selectedRole, returning: true),
                );
              }

              return;
            }
          }
        }
        if (profiles.length == 1 && navCtx.mounted) {
          final onlyProfile = profiles.first;

          final onlyProfileId =
              onlyProfile['profileId']?.toString() ??
                  onlyProfile['docId']?.toString();

          if (onlyProfileId != null && onlyProfileId.trim().isNotEmpty) {
            await AppState.instance.setActiveProfileForAccount(
              accountId: accountId,
              profileId: onlyProfileId,
            );

            final onlyRole = AppState.instance.roleFromProfileData(onlyProfile);

            if (mounted) {
              setState(() => _loading = false);
            }

            if (navCtx.mounted) {
              GoRouter.of(navCtx).go(
                _destinationFor(onlyRole, returning: true),
              );
            }

            return;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Profile selection skipped: $e');
  }

  if (mounted) {
    setState(() => _loading = false);
  }

  if (navCtx.mounted) {
    GoRouter.of(navCtx).go(
      _destinationFor(finalRole, returning: returning),
    );
  }
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
    if (reg != null && reg.uid.isNotEmpty) {
      debugPrint(
        'Legacy phoneRegistry role found: ${reg.roleName}. '
        'Skipping old account-type popup because SuiSakhi now supports multiple profiles.',
      );
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
/*  print('====================================');
  print('PHONE AUTH FAILED');
  print('CODE: ${e.code}');
  print('MESSAGE: ${e.message}');
  print('====================================');
*/
  _cancelPhoneWatchdog();

  _phoneAuthModel.debouncedVerificationFailed(
    _formatPhoneVerifyError(e),
  );
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
    //final nameCtrl = _phoneFlowNameCtrl!;
    final phoneCtrl = _phoneFlowPhoneCtrl;
    final otpCtrl = _phoneFlowOtpCtrl;

    if (phoneCtrl == null || otpCtrl == null) {
      return const SizedBox.shrink();
    }

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
                    : 'Enter your mobile number to continue ...',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (!m.otpStep) ...[
                /*
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
                    hintText: 'e.g. Annaya Sharma',
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
                */
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
                Pinput(
                  controller: otpCtrl,
                  length: 6,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  closeKeyboardWhenCompleted: true,
                  defaultPinTheme: PinTheme(
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
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 48,
                    height: 54,
                    textStyle: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  submittedPinTheme: PinTheme(
                    width: 46,
                    height: 52,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.3,
                      ),
                    ),
                  ),
                  errorPinTheme: PinTheme(
                    width: 46,
                    height: 52,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 1.3,
                      ),
                    ),
                  ),
                  onCompleted: (_) {
                    if (!m.loading) _verifyPhoneFlowOtp(navCtx);
                  },
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
  /* static bool _looksLikeEmail(String s) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());
  } */

Future<String?> _promptOwnerSetup({String? existingEmail}) async {
  try {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (phone == null) {
      return null;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('partner_users')
        .where('phone', isEqualTo: phone)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This mobile number is not registered as a Fashion Partner.',
            ),
          ),
        );
      }
      return null;
    }

    final data = snapshot.docs.first.data();

    final email = (data['email'] ?? '').toString().trim();

    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Partner email is missing. Contact Administrator.',
            ),
          ),
        );
      }
      return null;
    }

    return email;
  } catch (e) {
    debugPrint('Partner verification failed: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Partner verification failed.\n$e'),
        ),
      );
    }

    return null;
  }
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
		  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                         'assets/images/suisakhi_logo.png',
                         fit: BoxFit.contain,
                         ),
                      ),
                   ),
		),
                const SizedBox(height: 28),
                Text(
                  'SuiSakhi',
                  style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Design • Stitch • Wear',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 32),

                // Role selector
                Text('Choose how you want to continue ...',
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
                      label: 'Fashion Partner',
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
