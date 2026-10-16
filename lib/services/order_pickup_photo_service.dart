import 'dart:io' show File;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'firebase_storage_helpers.dart';

class OrderPickupPhotoService {
  OrderPickupPhotoService._();

  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    app: Firebase.app(),
  );

  static Future<String> upload({
    required String orderId,
    required XFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before attaching a photo.');

    final extension = FirebaseStorageHelpers.imageFileExt(file.path);
    final storageRef = _storage.ref(
      'order_pickup_photos/$orderId/${user.uid}/'
      '${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    File? ioFile;
    if (!kIsWeb && file.path.isNotEmpty) {
      final candidate = File(file.path);
      if (await candidate.exists() && await candidate.length() > 0) {
        ioFile = candidate;
      }
    }
    Uint8List? bytes;
    if (ioFile == null) {
      final data = await file.readAsBytes();
      if (data.isEmpty) throw StateError('The selected photo is empty.');
      bytes = Uint8List.fromList(data);
    }
    final downloadUrl = await FirebaseStorageHelpers.putImageGetDownloadUrl(
      ref: storageRef,
      file: ioFile,
      bytes: bytes,
      contentType: FirebaseStorageHelpers.imageContentType(
        mimeType: file.mimeType,
        path: file.path,
      ),
    );
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw StateError('Could not upload the pickup photo.');
    }
    return storageRef.fullPath;
  }

  static Future<String> downloadUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();
}
