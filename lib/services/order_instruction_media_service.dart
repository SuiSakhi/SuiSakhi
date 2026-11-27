import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Stores short customer voice/video instructions for tailoring and care orders.
/// Draft uploads remain private to the customer; order uploads can also be
/// opened by the Tailor assigned to that order through Storage rules.
class OrderInstructionMediaService {
  OrderInstructionMediaService._();

  static const int maxAudioBytes = 15 * 1024 * 1024;
  static const int maxVideoBytes = 30 * 1024 * 1024;

  static FirebaseStorage get _storage => FirebaseStorage.instance;

  static Future<List<Map<String, dynamic>>> uploadDraftMedia({
    required String customerUid,
    required String draftId,
    required List<Map<String, dynamic>> existingMedia,
    XFile? audioFile,
    XFile? videoFile,
  }) async {
    final media = existingMedia.map(Map<String, dynamic>.from).toList();
    final uploadedPaths = <String>[];
    try {
      if (audioFile != null) {
        media.removeWhere((item) => item['kind'] == 'audio');
        final item = await _uploadFile(
          customerUid: customerUid,
          scopeType: 'drafts',
          scopeId: draftId,
          kind: 'audio',
          file: audioFile,
        );
        uploadedPaths.add(item['storagePath'] as String);
        media.add(item);
      }
      if (videoFile != null) {
        media.removeWhere((item) => item['kind'] == 'video');
        final item = await _uploadFile(
          customerUid: customerUid,
          scopeType: 'drafts',
          scopeId: draftId,
          kind: 'video',
          file: videoFile,
        );
        uploadedPaths.add(item['storagePath'] as String);
        media.add(item);
      }
      return media;
    } catch (_) {
      await deletePaths(uploadedPaths);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> uploadOrderMedia({
    required String customerUid,
    required String orderId,
    required List<Map<String, dynamic>> savedDraftMedia,
    XFile? audioFile,
    XFile? videoFile,
  }) async {
    final media = <Map<String, dynamic>>[];
    final uploadedPaths = <String>[];
    try {
      final pendingKinds = {
        if (audioFile != null) 'audio',
        if (videoFile != null) 'video',
      };
      for (final item in savedDraftMedia) {
        final kind = item['kind']?.toString();
        if (kind == null || pendingKinds.contains(kind)) continue;
        final sourcePath = item['storagePath']?.toString() ?? '';
        if (sourcePath.isEmpty) continue;
        final bytes = await _storage.ref(sourcePath).getData(maxVideoBytes);
        if (bytes == null || bytes.isEmpty) {
          throw StateError('A saved instruction recording could not be read.');
        }
        final fileName = item['fileName']?.toString() ?? '$kind.m4a';
        final contentType =
            item['contentType']?.toString() ??
            (kind == 'audio' ? 'audio/mp4' : 'video/mp4');
        final targetPath =
            'order_instruction_media/$customerUid/orders/$orderId/$fileName';
        await _storage
            .ref(targetPath)
            .putData(
              bytes,
              SettableMetadata(
                contentType: contentType,
                customMetadata: {
                  'customerUid': customerUid,
                  'orderId': orderId,
                },
              ),
            );
        uploadedPaths.add(targetPath);
        media.add({
          'kind': kind,
          'storagePath': targetPath,
          'fileName': fileName,
          'contentType': contentType,
        });
      }

      for (final entry in [
        if (audioFile != null) ('audio', audioFile),
        if (videoFile != null) ('video', videoFile),
      ]) {
        final item = await _uploadFile(
          customerUid: customerUid,
          scopeType: 'orders',
          scopeId: orderId,
          kind: entry.$1,
          file: entry.$2,
        );
        uploadedPaths.add(item['storagePath'] as String);
        media.removeWhere((existing) => existing['kind'] == entry.$1);
        media.add(item);
      }

      return media;
    } catch (_) {
      await deletePaths(uploadedPaths);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _uploadFile({
    required String customerUid,
    required String scopeType,
    required String scopeId,
    required String kind,
    required XFile file,
  }) async {
    final fileObject = File(file.path);
    final size = await fileObject.length();
    final maxBytes = kind == 'audio' ? maxAudioBytes : maxVideoBytes;
    if (size <= 0 || size > maxBytes) {
      final limitMb = maxBytes ~/ (1024 * 1024);
      throw StateError(
        'The $kind recording must be smaller than $limitMb MB. Please record a shorter clip.',
      );
    }

    final extension = kind == 'audio'
        ? 'm4a'
        : (file.path.toLowerCase().endsWith('.mov') ? 'mov' : 'mp4');
    final contentType = kind == 'audio'
        ? 'audio/mp4'
        : extension == 'mov'
        ? 'video/quicktime'
        : 'video/mp4';
    final fileName =
        '${kind}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storagePath =
        'order_instruction_media/$customerUid/$scopeType/$scopeId/$fileName';
    await _storage
        .ref(storagePath)
        .putFile(
          fileObject,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'customerUid': customerUid,
              if (scopeType == 'orders') 'orderId': scopeId,
            },
          ),
        );

    return {
      'kind': kind,
      'storagePath': storagePath,
      'fileName': fileName,
      'contentType': contentType,
    };
  }

  static Future<void> deletePaths(Iterable<String> paths) async {
    for (final path in paths) {
      if (path.trim().isEmpty) continue;
      await _storage.ref(path).delete().catchError((_) {});
    }
  }
}
