'use strict';

const crypto = require('node:crypto');

function requireBucket(bucket) {
  if (!bucket || typeof bucket.file !== 'function') {
    throw new Error(
      'FIREBASE_BUCKET_INVALID: A Cloud Storage bucket is required.',
    );
  }
}

function requireFirestore(db) {
  if (!db || typeof db.doc !== 'function') {
    throw new Error(
      'FIREBASE_DB_INVALID: A Firestore instance is required.',
    );
  }
}

function requireText(value, code) {
  const normalized =
    typeof value === 'string'
      ? value.trim()
      : '';

  if (!normalized) {
    throw new Error(`${code}: A non-empty value is required.`);
  }

  return normalized;
}

function firebaseDownloadUrl({
  bucketName,
  objectPath,
  token,
}) {
  const encodedPath = encodeURIComponent(objectPath);

  return (
    `https://firebasestorage.googleapis.com/v0/b/` +
    `${encodeURIComponent(bucketName)}/o/` +
    `${encodedPath}?alt=media&token=${encodeURIComponent(token)}`
  );
}

function createStorageAdapter({
  bucket,
  bucketName,
}) {
  requireBucket(bucket);

  const normalizedBucketName =
    requireText(
      bucketName,
      'FIREBASE_BUCKET_NAME_MISSING',
    );

  return {
    async download({
      bucket: requestedBucket,
      objectPath,
      generation,
    }) {
      const normalizedRequestedBucket =
        requireText(
          requestedBucket,
          'FIREBASE_BUCKET_NAME_MISSING',
        );

      if (
        normalizedRequestedBucket !==
        normalizedBucketName
      ) {
        throw new Error(
          'FIREBASE_BUCKET_MISMATCH: ' +
          'Requested bucket does not match the configured bucket.',
        );
      }

      const normalizedPath =
        requireText(
          objectPath,
          'FIREBASE_OBJECT_PATH_MISSING',
        );

      const normalizedGeneration =
        requireText(
          String(generation ?? ''),
          'FIREBASE_GENERATION_MISSING',
        );

      const file = bucket.file(normalizedPath, {
        generation: normalizedGeneration,
      });

      const [buffer] = await file.download();

      if (!Buffer.isBuffer(buffer)) {
        throw new Error(
          'STORAGE_DOWNLOAD_INVALID: ' +
          'Cloud Storage did not return a Buffer.',
        );
      }

      return buffer;
    },

    async upload({
      bucket: requestedBucket,
      objectPath,
      contentType,
      buffer,
      metadata = {},
    }) {
      const normalizedRequestedBucket =
        requireText(
          requestedBucket,
          'FIREBASE_BUCKET_NAME_MISSING',
        );

      if (
        normalizedRequestedBucket !==
        normalizedBucketName
      ) {
        throw new Error(
          'FIREBASE_BUCKET_MISMATCH: ' +
          'Requested bucket does not match the configured bucket.',
        );
      }

      const normalizedPath =
        requireText(
          objectPath,
          'FIREBASE_OBJECT_PATH_MISSING',
        );

      const normalizedContentType =
        requireText(
          contentType,
          'FIREBASE_CONTENT_TYPE_MISSING',
        ).toLowerCase();

      if (!Buffer.isBuffer(buffer)) {
        throw new Error(
          'FIREBASE_UPLOAD_BUFFER_INVALID: ' +
          'Upload content must be a Buffer.',
        );
      }

      const downloadToken =
        crypto.randomUUID();

      const file = bucket.file(normalizedPath);

      await file.save(buffer, {
        resumable: false,
        validation: 'crc32c',
        contentType:
          normalizedContentType,
        metadata: {
          cacheControl:
            normalizedContentType ===
            'application/json'
              ? 'no-cache'
              : 'public,max-age=31536000,immutable',
          metadata: {
            ...Object.fromEntries(
              Object.entries(metadata)
                .filter(
                  ([, value]) =>
                    value !== null &&
                    value !== undefined,
                )
                .map(
                  ([key, value]) => [
                    key,
                    String(value),
                  ],
                ),
            ),
            firebaseStorageDownloadTokens:
              downloadToken,
          },
        },
      });

      const [savedMetadata] =
        await file.getMetadata();

      return {
        bucket:
          savedMetadata.bucket ||
          normalizedBucketName,
        objectPath:
          savedMetadata.name ||
          normalizedPath,
        generation:
          savedMetadata.generation ||
          null,
        contentType:
          savedMetadata.contentType ||
          normalizedContentType,
        byteSize:
          Number(savedMetadata.size || buffer.length),
        downloadUrl:
          normalizedContentType ===
          'application/json'
            ? null
            : firebaseDownloadUrl({
                bucketName:
                  normalizedBucketName,
                objectPath:
                  normalizedPath,
                token:
                  downloadToken,
              }),
      };
    },
  };
}

function viewRef(db, {
  designId,
  versionId,
  viewId,
}) {
  return db.doc(
    `designs/${requireText(
      designId,
      'FIREBASE_DESIGN_ID_MISSING',
    )}/versions/${requireText(
      versionId,
      'FIREBASE_VERSION_ID_MISSING',
    )}/views/${requireText(
      viewId,
      'FIREBASE_VIEW_ID_MISSING',
    )}`,
  );
}

function versionRef(db, {
  designId,
  versionId,
}) {
  return db.doc(
    `designs/${requireText(
      designId,
      'FIREBASE_DESIGN_ID_MISSING',
    )}/versions/${requireText(
      versionId,
      'FIREBASE_VERSION_ID_MISSING',
    )}`,
  );
}

function designRef(db, {
  designId,
}) {
  return db.doc(
    `designs/${requireText(
      designId,
      'FIREBASE_DESIGN_ID_MISSING',
    )}`,
  );
}

function createFirestoreAdapter({
  db,
}) {
  requireFirestore(db);

  return {
    async getView({
      designId,
      versionId,
      viewId,
    }) {
      const snapshot =
        await viewRef(db, {
          designId,
          versionId,
          viewId,
        }).get();

      return snapshot.exists
        ? snapshot.data()
        : null;
    },

    async updateView({
      designId,
      versionId,
      viewId,
      patch,
    }) {
      await viewRef(db, {
        designId,
        versionId,
        viewId,
      }).update(patch);
    },

    async listViewStatuses({
      designId,
      versionId,
    }) {
      const collection =
        versionRef(db, {
          designId,
          versionId,
        }).collection('views');

      const snapshot =
        await collection.get();

      return snapshot.docs.map((document) => {
        const data = document.data() || {};
        const processing =
          data.processing &&
          typeof data.processing === 'object'
            ? data.processing
            : {};

        return String(
          processing.status ||
          'notRequested',
        ).trim();
      });
    },

    async updateVersion({
      designId,
      versionId,
      patch,
    }) {
      await versionRef(db, {
        designId,
        versionId,
      }).update(patch);
    },

    async getDesign({
      designId,
    }) {
      const snapshot =
        await designRef(db, {
          designId,
        }).get();

      return snapshot.exists
        ? snapshot.data()
        : null;
    },

    async updateDesign({
      designId,
      patch,
    }) {
      await designRef(db, {
        designId,
      }).update(patch);
    },
  };
}

module.exports = {
  firebaseDownloadUrl,
  createStorageAdapter,
  createFirestoreAdapter,
};
