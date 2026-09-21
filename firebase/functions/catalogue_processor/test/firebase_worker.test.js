'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  TARGET_BUCKET,
  TARGET_REGION,
  createCatalogueWorkerHandler,
} = require('../firebase_worker');

function fakeAdmin() {
  const calls = {
    bucketNames: [],
    firestoreCalls: 0,
  };

  const bucket = {
    file() {
      throw new Error(
        'Storage should not be accessed for ignored events.',
      );
    },
  };

  const db = {
    doc() {
      throw new Error(
        'Firestore should not be accessed for ignored events.',
      );
    },
  };

  return {
    calls,
    admin: {
      storage() {
        return {
          bucket(name) {
            calls.bucketNames.push(name);
            return bucket;
          },
        };
      },

      firestore() {
        calls.firestoreCalls += 1;
        return db;
      },
    },
  };
}

test('freezes the confirmed bucket and region', () => {
  assert.equal(
    TARGET_BUCKET,
    'suisakhitest.firebasestorage.app',
  );

  assert.equal(
    TARGET_REGION,
    'us-east1',
  );
});

test('creates adapters for the confirmed Firebase resources', () => {
  const fake = fakeAdmin();

  const handler =
    createCatalogueWorkerHandler({
      admin: fake.admin,
      logger: {
        info() {},
        error() {},
      },
    });

  assert.equal(typeof handler, 'function');

  assert.deepEqual(
    fake.calls.bucketNames,
    [TARGET_BUCKET],
  );

  assert.equal(
    fake.calls.firestoreCalls,
    1,
  );
});

test('ignores derivative objects through the real handler wiring', async () => {
  const fake = fakeAdmin();

  const handler =
    createCatalogueWorkerHandler({
      admin: fake.admin,
      logger: {
        info() {},
        error() {},
      },
    });

  const result = await handler({
    bucket: TARGET_BUCKET,
    name:
      'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'normalized/preview.webp',
    generation: '6001',
    contentType: 'image/webp',
  });

  assert.equal(result.ok, true);
  assert.equal(result.ignored, true);
  assert.equal(
    result.reason,
    'PATH_NOT_TARGETED',
  );
});

test('ignores objects from another bucket', async () => {
  const fake = fakeAdmin();

  const handler =
    createCatalogueWorkerHandler({
      admin: fake.admin,
      logger: {
        info() {},
        error() {},
      },
    });

  const result = await handler({
    bucket: 'another-bucket',
    name:
      'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'original/source.jpg',
    generation: '6002',
    contentType: 'image/jpeg',
  });

  assert.equal(result.ok, true);
  assert.equal(result.ignored, true);
  assert.equal(
    result.reason,
    'BUCKET_NOT_TARGETED',
  );
});

test('rejects missing Firebase Admin dependency', () => {
  assert.throws(
    () =>
      createCatalogueWorkerHandler({
        admin: null,
      }),
    /WORKER_ADMIN_INVALID/,
  );
});
