import 'dart:io' show File;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Shared image upload + download URL with retries (auth token, propagation, rules).
class FirebaseStorageHelpers {
  FirebaseStorageHelpers._();

  static bool _isObjectNotFound(FirebaseException e) {
    final c = e.code.toLowerCase();
    return c == 'object-not-found' || c.contains('object-not-found');
  }

  static Future<void> _refreshIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true);
    } catch (_) {}
  }

  /// Prefer [file] on iOS/Android (streaming upload); falls back to [bytes].
  static Future<String?> putImageGetDownloadUrl({
    required Reference ref,
    Uint8List? bytes,
    File? file,
    required String contentType,
  }) async {
    await _refreshIdToken();

    late final UploadTask task;
    if (!kIsWeb && file != null && await file.exists() && await file.length() > 0) {
      task = ref.putFile(file, SettableMetadata(contentType: contentType));
    } else if (bytes != null && bytes.isNotEmpty) {
      task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    } else {
      return null;
    }

    final snapshot = await task;
    if (snapshot.state != TaskState.success) return null;
    if (snapshot.bytesTransferred <= 0) return null;

    await waitUntilMetadataVisible(snapshot.ref);
    return getDownloadUrlWithRetry(snapshot.ref);
  }

  /// Confirms the object exists server-side before asking for a tokenized URL.
  static Future<void> waitUntilMetadataVisible(Reference ref) async {
    for (var attempt = 0; attempt < 24; attempt++) {
      try {
        await ref.getMetadata();
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'unauthorized') {
          rethrow;
        }
        if (_isObjectNotFound(e) && attempt < 23) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        rethrow;
      }
    }
  }

  static Future<String?> getDownloadUrlWithRetry(Reference ref) async {
    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        return await ref.getDownloadURL();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'unauthorized') {
          rethrow;
        }
        if (_isObjectNotFound(e) && attempt < 24) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  static String imageFileExt(String path) {
    final p = path.toLowerCase().trim();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.heic')) return 'heic';
    if (p.endsWith('.webp')) return 'webp';
    if (p.endsWith('.jpeg')) return 'jpeg';
    if (p.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  static String imageContentType({String? mimeType, String path = ''}) {
    final m = mimeType?.trim();
    if (m != null &&
        m.isNotEmpty &&
        m.contains('/') &&
        m.toLowerCase().startsWith('image/')) {
      return m;
    }
    switch (imageFileExt(path)) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
