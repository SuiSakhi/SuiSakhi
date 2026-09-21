'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildEventIdentity,
} = require('../run_identity');

const {
  createProcessingRunStore,
} = require('../processing_run_store');

const IDENTITY =
  buildEventIdentity({
    bucket:
      'suisakhitest.firebasestorage.app',
    objectPath:
      'catalogue_designs/design-123/' +
      'versions/version-456/' +
      'views/view-789/' +
      'original/source.jpg',
    generation: '8001',
  });

function fakeFirestore(initial = {}) {
  const documents =
    new Map(
      Object.entries(initial),
    );

  const calls = {
    transactions: 0,
    creates: [],
    sets: [],
    updates: [],
  };

  function snapshot(path) {
    return {
      exists: documents.has(path),
      data() {
        return documents.get(path);
      },
    };
  }

  const db = {
    doc(path) {
      return { path };
    },

    async runTransaction(callback) {
      calls.transactions += 1;

      const transaction = {
        async get(ref) {
          return snapshot(ref.path);
        },

        create(ref, data) {
          if (
            documents.has(ref.path)
          ) {
            throw new Error(
              'Document already exists.',
            );
          }

          calls.creates.push({
            path: ref.path,
            data,
          });

          documents.set(
            ref.path,
            { ...data },
          );
        },

        set(ref, data, options) {
          calls.sets.push({
            path: ref.path,
            data,
            options,
          });

          const existing =
            documents.get(ref.path) ||
            {};

          documents.set(
            ref.path,
            options?.merge
              ? {
                  ...existing,
                  ...data,
                }
              : { ...data },
          );
        },

        update(ref, data) {
          calls.updates.push({
            path: ref.path,
            data,
          });

          const existing =
            documents.get(ref.path);

          if (!existing) {
            throw new Error(
              'Document does not exist.',
            );
          }

          documents.set(
            ref.path,
            {
              ...existing,
              ...data,
            },
          );
        },
      };

      return callback(transaction);
    },
  };

  return {
    db,
    calls,
    documents,
  };
}

function fixedStore(fake, {
  now =
    new Date(
      '2026-09-21T17:00:00.000Z',
    ),
  token = 'claim-token-1',
} = {}) {
  return createProcessingRunStore({
    db: fake.db,
    now: () => now,
    leaseMs: 15 * 60 * 1000,
    tokenFactory: () => token,
  });
}

test('atomically creates a new processing claim', async () => {
  const fake = fakeFirestore();
  const store = fixedStore(fake);

  const result =
    await store.claim(IDENTITY);

  assert.equal(
    result.acquired,
    true,
  );

  assert.equal(
    result.reason,
    'NEW_RUN',
  );

  assert.equal(
    result.attemptCount,
    1,
  );

  assert.equal(
    result.claimToken,
    'claim-token-1',
  );

  const document =
    fake.documents.get(
      IDENTITY.firestorePath,
    );

  assert.equal(
    document.status,
    'processing',
  );

  assert.equal(
    document.runId,
    IDENTITY.runId,
  );

  assert.equal(
    fake.calls.creates.length,
    1,
  );
});

test('ignores an already completed run', async () => {
  const fake = fakeFirestore({
    [IDENTITY.firestorePath]: {
      status: 'completed',
      attemptCount: 1,
      claimToken:
        'old-claim-token',
    },
  });

  const store = fixedStore(fake);

  const result =
    await store.claim(IDENTITY);

  assert.equal(
    result.acquired,
    false,
  );

  assert.equal(
    result.reason,
    'ALREADY_COMPLETED',
  );

  assert.equal(
    fake.calls.sets.length,
    0,
  );
});

test('ignores a duplicate with an active lease', async () => {
  const fake = fakeFirestore({
    [IDENTITY.firestorePath]: {
      status: 'processing',
      attemptCount: 1,
      claimToken:
        'active-token',
      leaseExpiresAt:
        new Date(
          '2026-09-21T17:10:00.000Z',
        ),
    },
  });

  const store = fixedStore(fake);

  const result =
    await store.claim(IDENTITY);

  assert.equal(
    result.acquired,
    false,
  );

  assert.equal(
    result.reason,
    'ALREADY_PROCESSING',
  );
});

test('retries an earlier failed run', async () => {
  const fake = fakeFirestore({
    [IDENTITY.firestorePath]: {
      status: 'failed',
      attemptCount: 1,
      claimToken:
        'failed-token',
      failureCode:
        'STORAGE_DOWNLOAD_FAILED',
    },
  });

  const store = fixedStore(fake, {
    token: 'retry-token',
  });

  const result =
    await store.claim(IDENTITY);

  assert.equal(
    result.acquired,
    true,
  );

  assert.equal(
    result.reason,
    'RETRY_FAILED_RUN',
  );

  assert.equal(
    result.attemptCount,
    2,
  );

  assert.equal(
    result.claimToken,
    'retry-token',
  );
});

test('takes over an expired processing lease', async () => {
  const fake = fakeFirestore({
    [IDENTITY.firestorePath]: {
      status: 'processing',
      attemptCount: 2,
      claimToken:
        'expired-token',
      leaseExpiresAt:
        new Date(
          '2026-09-21T16:59:59.000Z',
        ),
    },
  });

  const store = fixedStore(fake, {
    token: 'takeover-token',
  });

  const result =
    await store.claim(IDENTITY);

  assert.equal(
    result.acquired,
    true,
  );

  assert.equal(
    result.reason,
    'RETRY_EXPIRED_LEASE',
  );

  assert.equal(
    result.attemptCount,
    3,
  );

  assert.equal(
    result.claimToken,
    'takeover-token',
  );
});

test('completes only the currently owned claim', async () => {
  const fake = fakeFirestore();
  const store = fixedStore(fake);

  const claim =
    await store.claim(IDENTITY);

  const completed =
    await store.complete({
      identity: IDENTITY,
      claimToken:
        claim.claimToken,
      processorRunId:
        'processor-run-123',
      manifestPath:
        'catalogue_designs/design-123/' +
        'structured/manifest.json',
      completedAt:
        new Date(
          '2026-09-21T17:05:00.000Z',
        ),
    });

  assert.equal(
    completed.completed,
    true,
  );

  const document =
    fake.documents.get(
      IDENTITY.firestorePath,
    );

  assert.equal(
    document.status,
    'completed',
  );

  assert.equal(
    document.processorRunId,
    'processor-run-123',
  );

  await assert.rejects(
    store.complete({
      identity: IDENTITY,
      claimToken:
        'wrong-token',
      processorRunId:
        'other-run',
      manifestPath:
        'other.json',
    }),
    /RUN_CLAIM_LOST/,
  );
});

test('records failure only for the current claim owner', async () => {
  const fake = fakeFirestore();
  const store = fixedStore(fake);

  const claim =
    await store.claim(IDENTITY);

  const failed =
    await store.fail({
      identity: IDENTITY,
      claimToken:
        claim.claimToken,
      error:
        new Error(
          'IMG_DECODE_FAILED: Invalid image.',
        ),
      failedAt:
        new Date(
          '2026-09-21T17:06:00.000Z',
        ),
    });

  assert.equal(
    failed.failed,
    true,
  );

  assert.equal(
    failed.failureCode,
    'IMG_DECODE_FAILED',
  );

  const document =
    fake.documents.get(
      IDENTITY.firestorePath,
    );

  assert.equal(
    document.status,
    'failed',
  );

  assert.equal(
    document.failureCode,
    'IMG_DECODE_FAILED',
  );

  await assert.rejects(
    store.fail({
      identity: IDENTITY,
      claimToken:
        'wrong-token',
      error:
        new Error(
          'OTHER_FAILURE: Test.',
        ),
    }),
    /RUN_CLAIM_LOST/,
  );
});
