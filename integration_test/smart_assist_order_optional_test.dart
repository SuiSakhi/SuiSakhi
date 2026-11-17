import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:suisakhi/services/order_service.dart';
import 'package:suisakhi/services/smart_assist_client.dart';

const _demoProjectId = 'demo-suisakhi-smart-assist';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;

  setUpAll(() async {
    const emulatorRun = bool.fromEnvironment(
      'SUI_SAKHI_USE_FIREBASE_EMULATORS',
    );
    if (!emulatorRun) {
      throw StateError(
        'Run this integration test with SUI_SAKHI_USE_FIREBASE_EMULATORS=true.',
      );
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-only',
          appId: '1:1234567890:android:smartassisttest',
          messagingSenderId: '1234567890',
          projectId: _demoProjectId,
        ),
      );
    }
    if (Firebase.app().options.projectId != _demoProjectId) {
      throw StateError('This test is restricted to the demo Firebase project.');
    }

    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).useFunctionsEmulator(emulatorHost, 5001);

    firestore = FirebaseFirestore.instance;
    await FirebaseAuth.instance.signInAnonymously();
  });

  testWidgets('client rules deny access to the legacy API-key document', (
    tester,
  ) async {
    await expectLater(
      firestore.collection('config').doc('api').get(),
      throwsA(isA<FirebaseException>()),
    );
  });

  testWidgets('Smart Assist failure does not block normal order creation', (
    tester,
  ) async {
    final smartAssist = SmartAssistClient(
      invoker: (_) async => throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'test-only provider outage',
      ),
    );
    final assistResult = await smartAssist.request(
      feature: 'suggestFabricStyling',
      input: {'garmentType': 'Kurti'},
    );
    expect(assistResult.success, isFalse);

    final orderId = await OrderService.createCoreTailoringOrder(
      dressType: 'Kurti',
      price: 1000,
      fit: 'Regular Fit',
      measurements: const {'Chest': '80'},
      notes: 'Emulator test order only',
      orderId: 'smart-assist-test-order',
    );

    expect(orderId, 'smart-assist-test-order');
    final order = await firestore.collection('orders').doc(orderId).get();
    expect(order.exists, isTrue);
    expect(order.data()?['dressType'], 'Kurti');
    await order.reference.delete();
  });
}
