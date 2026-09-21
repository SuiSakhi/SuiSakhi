'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  firebaseDownloadUrl,
  createStorageAdapter,
  createFirestoreAdapter,
} = require('../firebase_adapter');

const BUCKET_NAME =
  'suisakhitest.firebasestorage.app';

function fakeBucket({
  downloadBuffer =
    Buffer.from('source-image'),
} = {}) {
  const calls = {
    files: [],
    saves: [],
    downloads: [],
  };

  const bucket = {
    file(objectPath, options) {
      calls.files.push({
        objectPath,
        options,
      });

      return {
        async download() {
          calls.downloads.push({
            objectPath,
            options,
          });

          return [downloadBuffer];
        },

        async save(buffer, saveOptions) {
          calls.saves.push({
            objectPath,
            buffer,
            saveOptions,
          });
        },

        async getMetadata() {
          return [{
            bucket: BUCKET_NAME,
            name: objectPath,
            generation: '5001',
            contentType:
              objectPath.endsWith('.json')
                ? 'application/json'
                : 'image/webp',
            size: '1234',
          }];
        },
      };
    },
  };

  return {
    bucket,
    calls,
  };
}

function fakeFirestore({
  viewExists = true,
  designExists = true,
} = {}) {
  const calls = {
    gets: [],
    updates: [],
    collections: [],
  };

  const documents = new Map();

  documents.set(
    'designs/design-123',
    {
      activeVersionId:
        'version-456',
    },
  );

  documents.set(
    'designs/design-123/' +
    'versions/version-456/' +
    'views/view-789',
    {
      originalAsset: {
        storagePath:
          'catalogue_designs/design-123/' +
          'versions/version-456/' +
          'views/view-789/' +
          'original/source.jpg',
      },
      processing: {
        status:
          'manualReviewRequired',
      },
    },
  );

  const viewDocuments = [
    {
      data() {
        return {
          processing: {
            status:
              'manualReviewRequired',
          },
        };
      },
    },
    {
      data() {
        return {
          processing: {
            status:
              'processing',
          },
        };
      },
    },
  ];

  function doc(path) {
    return {
      async get() {
        calls.gets.push(path);

        if (
          path.endsWith(
            '/views/view-789',
          ) &&
          !viewExists
        ) {
          return {
            exists: false,
            data() {
              return undefined;
            },
          };
        }

        if (
          path ===
            'designs/design-123' &&
          !designExists
        ) {
          return {
            exists: false,
            data() {
              return undefined;
            },
          };
        }

        const data = documents.get(path);

        return {
          exists: data !== undefined,
          data() {
            return data;
          },
        };
      },

      async update(patch) {
        calls.updates.push({
          path,
          patch,
        });
      },

      collection(name) {
        calls.collections.push({
          path,
          name,
        });

        return {
          async get() {
            return {
              docs: viewDocuments,
            };
          },
        };
      },
    };
  }

  return {
    db: {
      doc,
    },
    calls,
  };
}

test('creates encoded Firebase download URL', () => {
  const url = firebaseDownloadUrl({
    bucketName: BUCKET_NAME,
    objectPath:
      'catalogue_designs/design 123/' +
      'normalized/preview.webp',
    token: 'token-123',
  });

  assert.match(
    url,
    /firebasestorage\.googleapis\.com/,
  );

  assert.match(
    url,
    /catalogue_designs%2Fdesign%20123%2F/,
  );

  assert.match(
    url,
    /token=token-123/,
  );
});

test('downloads the exact Storage object generation', async () => {
  const fake = fakeBucket();

  const adapter =
    createStorageAdapter({
      bucket: fake.bucket,
      bucketName: BUCKET_NAME,
    });

  const buffer =
    await adapter.download({
      bucket: BUCKET_NAME,
      objectPath:
        'catalogue_designs/design-123/' +
        'original/source.jpg',
      generation: '5002',
    });

  assert.ok(Buffer.isBuffer(buffer));

  assert.equal(
    fake.calls.files[0].options.generation,
    '5002',
  );

  assert.equal(
    fake.calls.downloads.length,
    1,
  );
});

test('uploads an image with immutable cache metadata', async () => {
  const fake = fakeBucket();

  const adapter =
    createStorageAdapter({
      bucket: fake.bucket,
      bucketName: BUCKET_NAME,
    });

  const result =
    await adapter.upload({
      bucket: BUCKET_NAME,
      objectPath:
        'catalogue_designs/design-123/' +
        'normalized/preview.webp',
      contentType: 'image/webp',
      buffer:
        Buffer.from('derived-image'),
      metadata: {
        sourceGeneration: '5003',
        catalogueRunId: 'run-123',
      },
    });

  assert.equal(
    fake.calls.saves.length,
    1,
  );

  const save =
    fake.calls.saves[0];

  assert.equal(
    save.saveOptions.contentType,
    'image/webp',
  );

  assert.equal(
    save.saveOptions.metadata.cacheControl,
    'public,max-age=31536000,immutable',
  );

  assert.equal(
    save.saveOptions.metadata.metadata
      .sourceGeneration,
    '5003',
  );

  assert.match(
    result.downloadUrl,
    /alt=media&token=/,
  );
});

test('uploads manifest without returning public URL', async () => {
  const fake = fakeBucket();

  const adapter =
    createStorageAdapter({
      bucket: fake.bucket,
      bucketName: BUCKET_NAME,
    });

  const result =
    await adapter.upload({
      bucket: BUCKET_NAME,
      objectPath:
        'catalogue_designs/design-123/' +
        'structured/manifest.json',
      contentType:
        'application/json',
      buffer:
        Buffer.from('{}\n'),
    });

  assert.equal(
    result.downloadUrl,
    null,
  );

  assert.equal(
    fake.calls.saves[0]
      .saveOptions.metadata.cacheControl,
    'no-cache',
  );
});

test('rejects a mismatched Storage bucket', async () => {
  const fake = fakeBucket();

  const adapter =
    createStorageAdapter({
      bucket: fake.bucket,
      bucketName: BUCKET_NAME,
    });

  await assert.rejects(
    adapter.download({
      bucket: 'another-bucket',
      objectPath: 'source.jpg',
      generation: '5004',
    }),
    /FIREBASE_BUCKET_MISMATCH/,
  );
});

test('reads and updates exact Firestore paths', async () => {
  const fake = fakeFirestore();

  const adapter =
    createFirestoreAdapter({
      db: fake.db,
    });

  const view =
    await adapter.getView({
      designId: 'design-123',
      versionId: 'version-456',
      viewId: 'view-789',
    });

  assert.ok(view);

  await adapter.updateView({
    designId: 'design-123',
    versionId: 'version-456',
    viewId: 'view-789',
    patch: {
      processing: {
        status: 'processing',
      },
    },
  });

  const design =
    await adapter.getDesign({
      designId: 'design-123',
    });

  assert.equal(
    design.activeVersionId,
    'version-456',
  );

  await adapter.updateVersion({
    designId: 'design-123',
    versionId: 'version-456',
    patch: {
      processing: {
        status:
          'manualReviewRequired',
      },
    },
  });

  await adapter.updateDesign({
    designId: 'design-123',
    patch: {
      processingStatus:
        'manualReviewRequired',
    },
  });

  assert.equal(
    fake.calls.updates[0].path,
    'designs/design-123/' +
    'versions/version-456/' +
    'views/view-789',
  );

  assert.equal(
    fake.calls.updates[1].path,
    'designs/design-123/' +
    'versions/version-456',
  );

  assert.equal(
    fake.calls.updates[2].path,
    'designs/design-123',
  );
});

test('lists View processing statuses', async () => {
  const fake = fakeFirestore();

  const adapter =
    createFirestoreAdapter({
      db: fake.db,
    });

  const statuses =
    await adapter.listViewStatuses({
      designId: 'design-123',
      versionId: 'version-456',
    });

  assert.deepEqual(
    statuses,
    [
      'manualReviewRequired',
      'processing',
    ],
  );

  assert.deepEqual(
    fake.calls.collections[0],
    {
      path:
        'designs/design-123/' +
        'versions/version-456',
      name: 'views',
    },
  );
});
