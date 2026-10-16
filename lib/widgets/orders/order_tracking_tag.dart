import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OrderTrackingTag {
  const OrderTrackingTag._();

  static Future<void> show(BuildContext context, String orderTrackingId) {
    final link = Uri(
      scheme: 'suisakhi',
      host: 'order-tag',
      pathSegments: [orderTrackingId],
    ).toString();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Order tag',
                  style: Theme.of(dialogContext).textTheme.titleLarge,
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
                      color: Theme.of(dialogContext).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 216,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'QR code for order $orderTrackingId',
                    errorStateBuilder: (context, error) =>
                        const Icon(Icons.qr_code_2_rounded, size: 112),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  orderTrackingId,
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan with SuiSakhi to open this order directly, or read the order ID below for handoffs.',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget button(BuildContext context, String? orderTrackingId) {
    if (orderTrackingId == null || orderTrackingId.isEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: () => show(context, orderTrackingId),
      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
      label: const Text('Show order tag'),
    );
  }
}
