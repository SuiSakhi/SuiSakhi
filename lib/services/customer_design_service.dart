import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../models/customer_design.dart';
import 'firebase_storage_helpers.dart';

class CustomerDesignService {
  CustomerDesignService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<CustomerDesign?> uploadDesign({
    required String accountId,
    required String profileId,
    required String title,
    required String dressType,
    required String? occasionId,
    required String? notes,
    required XFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();
    final normalizedTitle = title.trim();
    final normalizedDressType = dressType.trim();
    final normalizedOccasionId = occasionId?.trim();
    final normalizedNotes = notes?.trim();

    if (normalizedAccountId.isEmpty ||
        normalizedProfileId.isEmpty ||
        normalizedDressType.isEmpty) {
      return null;
    }

    final document = _db.collection('customer_designs').doc();

    final extension = FirebaseStorageHelpers.imageFileExt(
      file.path.isNotEmpty ? file.path : 'design.jpg',
    );

    final contentType = FirebaseStorageHelpers.imageContentType(
      mimeType: file.mimeType,
      path: file.path,
    );

    final storage = FirebaseStorage.instanceFor(app: Firebase.app());

    final storageReference = storage.ref(
      'customer_designs/'
      '${user.uid}/'
      '$normalizedAccountId/'
      '$normalizedProfileId/'
      '${document.id}.$extension',
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
      final loadedBytes = await file.readAsBytes();

      if (loadedBytes.isEmpty) {
        return null;
      }

      bytes = Uint8List.fromList(loadedBytes);
    }

    final imageUrl = await FirebaseStorageHelpers.putImageGetDownloadUrl(
      ref: storageReference,
      file: ioFile,
      bytes: bytes,
      contentType: contentType,
    );

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final customerDesign = CustomerDesign(
      id: document.id,
      accountId: normalizedAccountId,
      profileId: normalizedProfileId,
      title: normalizedTitle.isEmpty ? 'My Design' : normalizedTitle,
      imageUrl: imageUrl,
      thumbnailUrl: null,
      dressType: normalizedDressType,
      occasionId: normalizedOccasionId?.isNotEmpty == true
          ? normalizedOccasionId
          : null,
      notes: normalizedNotes?.isNotEmpty == true ? normalizedNotes : null,
      status: CustomerDesignStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    await document.set({
      ...customerDesign.toMap(),

      // Security ownership belongs to the signed-in account user.
      'createdByUid': user.uid,

      // Original storage object reference is retained for
      // support, archival and future controlled deletion.
      'storagePath': storageReference.fullPath,

      // Uploaded designs are private profile-owned references.
      'visibility': 'private',
    });

    return customerDesign;
  }

  static Stream<List<CustomerDesign>> watchActiveDesigns({
    required String accountId,
    required String profileId,
    String? dressType,
    String? occasionId,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(const <CustomerDesign>[]);
    }

    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();
    final normalizedDressType = dressType?.trim().toLowerCase() ?? '';
    final normalizedOccasionId = occasionId?.trim() ?? '';

    if (normalizedAccountId.isEmpty || normalizedProfileId.isEmpty) {
      return Stream.value(const <CustomerDesign>[]);
    }

    return _db
        .collection('customer_designs')
        .where('createdByUid', isEqualTo: user.uid)
        .where('accountId', isEqualTo: normalizedAccountId)
        .where('profileId', isEqualTo: normalizedProfileId)
        .where('status', isEqualTo: CustomerDesignStatus.active.name)
        .snapshots()
        .map((snapshot) {
          final designs = snapshot.docs.map(CustomerDesign.fromDoc).where((
            design,
          ) {
            if (normalizedDressType.isNotEmpty &&
                design.dressType.trim().toLowerCase() != normalizedDressType) {
              return false;
            }

            if (normalizedOccasionId.isNotEmpty &&
                design.occasionId?.trim().isNotEmpty == true &&
                design.occasionId != normalizedOccasionId) {
              return false;
            }

            return design.isActive;
          }).toList();

          designs.sort(
            (left, right) => right.createdAt.compareTo(left.createdAt),
          );

          return designs;
        });
  }

  static Future<void> archiveDesign({
    required String designId,
    required String accountId,
    required String profileId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    final document = _db.collection('customer_designs').doc(designId.trim());

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Uploaded design could not be found.');
    }

    final data = snapshot.data() ?? {};

    final ownsDesign =
        data['createdByUid'] == user.uid &&
        data['accountId'] == accountId.trim() &&
        data['profileId'] == profileId.trim();

    if (!ownsDesign) {
      throw StateError('This design does not belong to the selected profile.');
    }

    await document.update({
      'status': CustomerDesignStatus.archived.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
