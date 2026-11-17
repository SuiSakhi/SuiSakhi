import 'package:flutter/foundation.dart';
//        show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useFirebaseEmulators = bool.fromEnvironment(
    'SUI_SAKHI_USE_FIREBASE_EMULATORS',
  );
  await Firebase.initializeApp(
    options: useFirebaseEmulators
        ? const FirebaseOptions(
            apiKey: 'demo-only',
            appId: '1:1234567890:android:smartassisttest',
            messagingSenderId: '1234567890',
            projectId: 'demo-suisakhi-smart-assist',
          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  if (useFirebaseEmulators) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  } else {
    try {
      if (kIsWeb) {
        const siteKey = String.fromEnvironment(
          'FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY',
        );
        if (siteKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            webProvider: ReCaptchaV3Provider(siteKey),
          );
        } else {
          debugPrint('App Check web provider is not configured.');
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        const useDebugProvider = bool.fromEnvironment(
          'SUI_SAKHI_APP_CHECK_DEBUG_PROVIDER',
          defaultValue: kDebugMode,
        );
        debugPrint(
          '[AppCheck] Android provider=${useDebugProvider ? 'debug' : 'Play Integrity'}; '
          'Firebase project=${Firebase.app().options.projectId}; '
          'appId=${Firebase.app().options.appId}',
        );
        await FirebaseAppCheck.instance.activate(
          androidProvider: useDebugProvider
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        const useDebugProvider = bool.fromEnvironment(
          'SUI_SAKHI_APP_CHECK_DEBUG_PROVIDER',
          defaultValue: kDebugMode,
        );
        await FirebaseAppCheck.instance.activate(
          appleProvider: useDebugProvider
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
        );
      }
    } catch (error) {
      // Keep the app and order flow available; enforced callable requests will
      // return a safe verification error until App Check is configured.
      debugPrint('[AppCheck] Initialization failed: $error');
    }
  }

  if (kIsWeb && !useFirebaseEmulators) {
    try {
      await FirebaseAuth.instance.initializeRecaptchaConfig();
    } catch (e) {
      debugPrint('reCAPTCHA init failed: $e');
    }
  }

  runApp(const SuiSakhiApp());
}
