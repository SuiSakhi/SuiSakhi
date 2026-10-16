import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GarmentRecordQrDialog {
  const GarmentRecordQrDialog._();

  static Future<void> show(BuildContext context, String orderDocumentId) {
    final linkFuture = FirebaseFunctions.instance
        .httpsCallable('getGarmentRecordShareLink')
        .call<Map<String, dynamic>>({'orderId': orderDocumentId});
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<HttpsCallableResult<Map<String, dynamic>>>(
              future: linkFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Report link unavailable',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The report may not be published yet. Please refresh the order and try again.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }
                final link = snapshot.data?.data['url']?.toString() ?? '';
                if (link.isEmpty) {
                  return const Text('The report link could not be created.');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Garment DNA report QR',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan with any phone camera to open the report directly. Anyone with this QR can view the report, so share it only with the intended recipients.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 244,
                      height: 244,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: link,
                        version: QrVersions.auto,
                        size: 216,
                        backgroundColor: Colors.white,
                        semanticsLabel: 'Direct garment DNA report QR',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Order $orderDocumentId',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
