'use strict';

const crypto = require('node:crypto');

const PROCESSING_PROFILE =
  'suisakhiStructuredSvgV1';

const PROCESSING_VERSION =
  '1.0.0-cloud-worker';

function requireIdentityText(value, code) {
  const normalized =
    value === null || value === undefined
      ? ''
      : String(value).trim();

  if (!normalized) {
    throw new Error(
      `${code}: A non-empty identity value is required.`,
    );
  }

  return normalized;
}

function sha256(value) {
  return crypto
    .createHash('sha256')
    .update(value)
    .digest('hex');
}

function buildEventIdentity({
  bucket,
  objectPath,
  generation,
  profileCode = PROCESSING_PROFILE,
  processingVersion = PROCESSING_VERSION,
}) {
  const normalized = {
    bucket: requireIdentityText(
      bucket,
      'RUN_BUCKET_MISSING',
    ),
    objectPath: requireIdentityText(
      objectPath,
      'RUN_OBJECT_PATH_MISSING',
    ),
    generation: requireIdentityText(
      generation,
      'RUN_GENERATION_MISSING',
    ),
    profileCode: requireIdentityText(
      profileCode,
      'RUN_PROFILE_MISSING',
    ),
    processingVersion: requireIdentityText(
      processingVersion,
      'RUN_VERSION_MISSING',
    ),
  };

  const runId = sha256([
    'catalogue-storage-event',
    normalized.bucket,
    normalized.objectPath,
    normalized.generation,
    normalized.profileCode,
    normalized.processingVersion,
  ].join('|'));

  return Object.freeze({
    runId,
    ...normalized,
    firestorePath:
      `catalogue_processing_runs/${runId}`,
  });
}

module.exports = {
  PROCESSING_PROFILE,
  PROCESSING_VERSION,
  buildEventIdentity,
};
