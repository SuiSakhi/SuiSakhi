'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  PROCESSING_PROFILE,
  PROCESSING_VERSION,
  buildEventIdentity,
} = require('../run_identity');

const EVENT = Object.freeze({
  bucket:
    'suisakhitest.firebasestorage.app',
  objectPath:
    'catalogue_designs/design-123/' +
    'versions/version-456/' +
    'views/view-789/' +
    'original/source.jpg',
  generation: '7001',
});

test('creates a deterministic event identity', () => {
  const first = buildEventIdentity(EVENT);
  const second = buildEventIdentity(EVENT);

  assert.equal(first.runId, second.runId);
  assert.match(first.runId, /^[a-f0-9]{64}$/);

  assert.equal(
    first.firestorePath,
    `catalogue_processing_runs/${first.runId}`,
  );

  assert.equal(
    first.profileCode,
    PROCESSING_PROFILE,
  );

  assert.equal(
    first.processingVersion,
    PROCESSING_VERSION,
  );
});

test('changes identity when generation changes', () => {
  const first =
    buildEventIdentity(EVENT);

  const second =
    buildEventIdentity({
      ...EVENT,
      generation: '7002',
    });

  assert.notEqual(
    first.runId,
    second.runId,
  );
});

test('changes identity when object path changes', () => {
  const first =
    buildEventIdentity(EVENT);

  const second =
    buildEventIdentity({
      ...EVENT,
      objectPath:
        EVENT.objectPath.replace(
          'view-789',
          'view-999',
        ),
    });

  assert.notEqual(
    first.runId,
    second.runId,
  );
});

test('changes identity when processor version changes', () => {
  const first =
    buildEventIdentity(EVENT);

  const second =
    buildEventIdentity({
      ...EVENT,
      processingVersion:
        '1.0.1-cloud-worker',
    });

  assert.notEqual(
    first.runId,
    second.runId,
  );
});

test('normalizes surrounding whitespace', () => {
  const plain =
    buildEventIdentity(EVENT);

  const padded =
    buildEventIdentity({
      bucket: `  ${EVENT.bucket}  `,
      objectPath:
        `  ${EVENT.objectPath}  `,
      generation:
        `  ${EVENT.generation}  `,
    });

  assert.equal(
    plain.runId,
    padded.runId,
  );
});

test('rejects missing identity fields', () => {
  assert.throws(
    () =>
      buildEventIdentity({
        ...EVENT,
        bucket: '',
      }),
    /RUN_BUCKET_MISSING/,
  );

  assert.throws(
    () =>
      buildEventIdentity({
        ...EVENT,
        objectPath: null,
      }),
    /RUN_OBJECT_PATH_MISSING/,
  );

  assert.throws(
    () =>
      buildEventIdentity({
        ...EVENT,
        generation: '',
      }),
    /RUN_GENERATION_MISSING/,
  );
});
