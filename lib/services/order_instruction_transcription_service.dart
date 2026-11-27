import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderInstructionTranscriptionService {
  OrderInstructionTranscriptionService._();

  static Future<String> transcribeStoragePath(String storagePath) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in to transcribe a voice note.',
      );
    }

    // This callable enforces App Check. Check it directly so an invalid debug
    // token is reported as an app-verification problem, not as a sign-in issue.
    final appCheckToken = await FirebaseAppCheck.instanceFor(
      app: auth.app,
    ).getToken();
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'App Check did not provide a verification token.',
      );
    }

    final callable =
        FirebaseFunctions.instanceFor(
          app: auth.app,
          region: 'us-central1',
        ).httpsCallable(
          'transcribeOrderInstructionAudioV2',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        );
    final request = {'storagePath': storagePath};
    try {
      final response = await callable.call<Map<String, dynamic>>(request);
      return response.data['transcript']?.toString().trim() ?? '';
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unauthenticated') rethrow;

      // Callable SDKs normally attach and refresh the Firebase ID token.
      // Retry once with a freshly issued token to recover from a stale token.
      final currentUser = auth.currentUser;
      if (currentUser == null) rethrow;
      await currentUser.getIdToken(true);

      try {
        final response = await callable.call<Map<String, dynamic>>(request);
        return response.data['transcript']?.toString().trim() ?? '';
      } on FirebaseFunctionsException catch (retryError) {
        if (retryError.code != 'unauthenticated') rethrow;
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message:
              'Transcription remained unauthenticated after token refresh.',
          details: const {'tokenRefreshRetried': true},
        );
      }
    }
  }
}
