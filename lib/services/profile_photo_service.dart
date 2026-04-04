import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'firebase_storage_helpers.dart';

class ProfilePhotoService {
  ProfilePhotoService._();

  /// Uploads to `users/{uid}/profile_{timestamp}.{ext}` and returns the download URL.
  static Future<String?> uploadProfilePhoto(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = FirebaseStorageHelpers.imageFileExt(
      file.path.isNotEmpty ? file.path : 'photo.jpg',
    );
    final storage = FirebaseStorage.instanceFor(app: Firebase.app());
    final ref = storage.ref('users/${user.uid}/profile_$ts.$ext');

    final contentType = FirebaseStorageHelpers.imageContentType(
      mimeType: file.mimeType,
      path: file.path,
    );

    File? ioFile;
    if (!kIsWeb && file.path.isNotEmpty) {
      final f = File(file.path);
      if (await f.exists() && await f.length() > 0) {
        ioFile = f;
      }
    }

    final bytes = ioFile == null ? await file.readAsBytes() : null;

    return FirebaseStorageHelpers.putImageGetDownloadUrl(
      ref: ref,
      file: ioFile,
      bytes: bytes,
      contentType: contentType,
    );
  }
}
