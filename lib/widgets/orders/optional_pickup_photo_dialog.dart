import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/order_pickup_photo_service.dart';

enum _PickupPhotoChoice { camera, gallery, withoutPhoto, cancel }

class OptionalPickupPhotoResult {
  const OptionalPickupPhotoResult({required this.cancelled, this.storagePath});

  final bool cancelled;
  final String? storagePath;
}

Future<OptionalPickupPhotoResult> showOptionalPickupPhotoDialog({
  required BuildContext context,
  required String orderId,
}) async {
  final choice = await showDialog<_PickupPhotoChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Optional pickup photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Optionally photograph the garment or material at pickup. The Tailor can review it as a reference. You can continue without a photo.',
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take photo'),
            onTap: () =>
                Navigator.pop(dialogContext, _PickupPhotoChoice.camera),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () =>
                Navigator.pop(dialogContext, _PickupPhotoChoice.gallery),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _PickupPhotoChoice.cancel),
          child: const Text('Cancel pickup'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _PickupPhotoChoice.withoutPhoto),
          child: const Text('Continue without photo'),
        ),
      ],
    ),
  );
  if (choice == null || choice == _PickupPhotoChoice.cancel) {
    return const OptionalPickupPhotoResult(cancelled: true);
  }
  if (choice == _PickupPhotoChoice.withoutPhoto) {
    return const OptionalPickupPhotoResult(cancelled: false);
  }

  final photo = await ImagePicker().pickImage(
    source: choice == _PickupPhotoChoice.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    imageQuality: 82,
    maxWidth: 1600,
  );
  if (photo == null) return const OptionalPickupPhotoResult(cancelled: true);
  final storagePath = await OrderPickupPhotoService.upload(
    orderId: orderId,
    file: photo,
  );
  return OptionalPickupPhotoResult(cancelled: false, storagePath: storagePath);
}
