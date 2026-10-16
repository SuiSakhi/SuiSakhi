import 'package:flutter/material.dart';

import '../../services/order_pickup_photo_service.dart';

class PickupPhotoAttachmentButton extends StatelessWidget {
  const PickupPhotoAttachmentButton({
    super.key,
    required this.storagePath,
    this.label = 'View pickup photo',
  });

  final String storagePath;
  final String label;

  Future<void> _showPhoto(BuildContext context) async {
    try {
      final url = await OrderPickupPhotoService.downloadUrl(storagePath);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load the pickup photo.'),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the pickup photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => _showPhoto(context),
    icon: const Icon(Icons.photo_camera_back_outlined),
    label: Text(label),
  );
}
