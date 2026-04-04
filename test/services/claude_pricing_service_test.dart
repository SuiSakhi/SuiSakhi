import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/services/claude_pricing_service.dart';

void main() {
  group('PriceEstimate', () {
    group('success', () {
      test('success flag is true', () {
        const estimate = PriceEstimate.success('PRICE: ₹500 – ₹700\nREASON: Simple kurti.');
        expect(estimate.success, isTrue);
      });

      test('text is preserved exactly', () {
        const text = 'PRICE: ₹800 – ₹1000\nREASON: Embroidery work.';
        const estimate = PriceEstimate.success(text);
        expect(estimate.text, text);
      });

      test('text contains price range', () {
        const estimate = PriceEstimate.success('PRICE: ₹500 – ₹700\nREASON: Basic stitching.');
        expect(estimate.text, contains('₹500'));
        expect(estimate.text, contains('₹700'));
      });
    });

    group('error', () {
      test('success flag is false', () {
        const estimate = PriceEstimate.error('API key not configured.');
        expect(estimate.success, isFalse);
      });

      test('text is preserved exactly', () {
        const msg = 'Anthropic api-key is missing.\n\n'
            'Firebase Console → Firestore → config → api → field claudeKey (string, your sk-ant-… key from console.anthropic.com). '
            'No spaces or quotes; redeploy rules so authenticated clients may read config/api if needed.';
        const estimate = PriceEstimate.error(msg);
        expect(estimate.text, msg);
      });

      test('network error message', () {
        const estimate = PriceEstimate.error('Network error. Check your connection.');
        expect(estimate.success, isFalse);
        expect(estimate.text, contains('Network error'));
      });

      test('invalid key error message', () {
        const estimate = PriceEstimate.error(
            'Anthropic rejected the api-key (HTTP 401). test\n\n'
            'Firebase Console → Firestore → config → api → field claudeKey (string, your sk-ant-… key from console.anthropic.com). '
            'No spaces or quotes; redeploy rules so authenticated clients may read config/api if needed.');
        expect(estimate.success, isFalse);
        expect(estimate.text, contains('401'));
        expect(estimate.text, contains('Firestore'));
      });
    });

    test('success and error are mutually exclusive', () {
      const s = PriceEstimate.success('ok');
      const e = PriceEstimate.error('fail');
      expect(s.success, isTrue);
      expect(e.success, isFalse);
      expect(s.success, isNot(e.success));
    });
  });
}
