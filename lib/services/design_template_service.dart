import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../models/design_template.dart';
import 'firebase_storage_helpers.dart';

class DesignTemplateService {
  DesignTemplateService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<List<DesignTemplate>> watchTemplates() {
    return _db
        .collection('designTemplates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DesignTemplate.fromDoc).toList());
  }

  /// Creates Firestore doc + Storage object under `design_templates/{id}.jpg`.
  static Future<String?> createTemplate({
    required String title,
    required XFile file,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = _db.collection('designTemplates').doc();
    final ext = FirebaseStorageHelpers.imageFileExt(
      file.path.isNotEmpty ? file.path : 'design.jpg',
    );
    final storage = FirebaseStorage.instanceFor(app: Firebase.app());
    final ref = storage.ref('design_templates/${doc.id}.$ext');
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
    Uint8List? bytes;
    if (ioFile == null) {
      bytes = Uint8List.fromList(await file.readAsBytes());
    }

    final url = await FirebaseStorageHelpers.putImageGetDownloadUrl(
      ref: ref,
      file: ioFile,
      bytes: bytes,
      contentType: contentType,
    );
    if (url == null) return null;
    final label = title.trim().isEmpty ? 'Design' : title.trim();
    await doc.set({
      'title': label,
      'imageUrl': url,

      // Phase-1 catalog metadata defaults.
      'catalogType': 'free',
      'dressType': null,
      'occasionIds': <String>[],
      'priceInr': null,
      'ownerProfileId': null,
      'isActive': true,

      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
