'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');

const {
  processCloudImage,
} = require('../cloud_processor');

const {
  parseCatalogueOriginalPath,
} = require('../catalogue_path');

const {
  aggregateProcessingStatus,
  buildSuccessfulViewPatch,
  buildFailedViewPatch,
  buildVersionProcessingPatch,
  buildDesignProcessingPatch,
} = require('../firestore_mapper');

const OBJECT_PATH =
  'catalogue_designs/design-123/' +
  'versions/version-456/' +
  'views/view-789/' +
  'original/source.png';

async function processedManifest() {
  const sourceBuffer = await sharp({
    create: {
      width: 800,
      height: 1200,
      channels: 4,
      background: {
        r: 100,
        g: 60,
        b: 170,
        alpha: 0.75,
      },
    },
  })
    .png()
    .toBuffer();

  const parsed = parseCatalogueOriginalPath(OBJECT_PATH);
  assert.ok(parsed);

  return processCloudImage({
    sourceBuffer,
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    generation: '3001',
    contentType: 'image/png',
    outputPaths: {
      normalizedPath: parsed.normalizedPath,
      thumbnailPath: parsed.thumbnailPath,
      manifestPath: parsed.manifestPath,
    },
  });
}

test('maps successful processor output to View asset schema', async () => {
  const processed = await processedManifest();
  const processedAt = new Date('2026-09-21T15:30:00.000Z');

  const patch = buildSuccessfulViewPatch({
    manifest: processed.manifest,
    normalizedDownloadUrl:
      'https://example.invalid/preview.webp',
    thumbnailDownloadUrl:
      'https://example.invalid/card.webp',
    processedAt,
  });

  assert.equal(
    patch.normalizedPreviewAsset.assetType,
    'normalizedPreview',
  );

  assert.equal(
    patch.normalizedPreviewAsset.storagePath,
    processed.manifest.normalized.path,
  );

  assert.equal(
    patch.thumbnailAsset.assetType,
    'thumbnail',
  );

  assert.equal(
    patch.thumbnailAsset.storagePath,
    processed.manifest.thumbnail.path,
  );

  assert.equal(patch.structuredSvgAsset, null);
  assert.equal(
    patch.processing.status,
    'manualReviewRequired',
  );

  assert.deepEqual(
    patch.processing.qualityWarnings,
    ['SVG_CONVERSION_SKIPPED'],
  );

  assert.equal(
    patch.processing.failureCode,
    null,
  );

  assert.equal(patch.updatedAt, processedAt);
});

test('maps processor failure to governed View failure schema', () => {
  const processedAt = new Date('2026-09-21T15:31:00.000Z');

  const patch = buildFailedViewPatch({
    error: new Error(
      'IMG_DECODE_FAILED: Unsupported image format.',
    ),
    processedAt,
  });

  assert.equal(patch.processing.status, 'failed');
  assert.equal(
    patch.processing.failureCode,
    'IMG_DECODE_FAILED',
  );

  assert.match(
    patch.processing.failureMessage,
    /Unsupported image format/,
  );

  assert.equal(patch.updatedAt, processedAt);
});

test('aggregates processing statuses using governed precedence', () => {
  assert.equal(
    aggregateProcessingStatus([
      'manualReviewRequired',
      'manualReviewRequired',
    ]),
    'manualReviewRequired',
  );

  assert.equal(
    aggregateProcessingStatus([
      'manualReviewRequired',
      'processing',
    ]),
    'processing',
  );

  assert.equal(
    aggregateProcessingStatus([
      'manualReviewRequired',
      'failed',
    ]),
    'failed',
  );

  assert.equal(
    aggregateProcessingStatus([]),
    'notRequested',
  );
});

test('builds Version processing patch from View statuses', () => {
  const processedAt = new Date('2026-09-21T15:32:00.000Z');

  const patch = buildVersionProcessingPatch({
    viewStatuses: [
      'manualReviewRequired',
      'manualReviewRequired',
    ],
    processedAt,
  });

  assert.equal(
    patch.processing.status,
    'manualReviewRequired',
  );

  assert.deepEqual(
    patch.processing.qualityWarnings,
    ['SVG_CONVERSION_SKIPPED'],
  );

  assert.equal(patch.updatedAt, processedAt);
});

test('builds failed Version patch when any View failed', () => {
  const patch = buildVersionProcessingPatch({
    viewStatuses: [
      'manualReviewRequired',
      'failed',
    ],
    processedAt: new Date(
      '2026-09-21T15:33:00.000Z',
    ),
  });

  assert.equal(patch.processing.status, 'failed');
  assert.equal(
    patch.processing.failureCode,
    'VIEW_PROCESSING_FAILED',
  );
});

test('builds Design processing patch without lifecycle changes', () => {
  const processedAt = new Date('2026-09-21T15:34:00.000Z');

  const patch = buildDesignProcessingPatch({
    versionStatus: 'manualReviewRequired',
    activeVersionId: 'version-456',
    processedAt,
  });

  assert.deepEqual(
    Object.keys(patch).sort(),
    [
      'processingStatus',
      'processingUpdatedAt',
      'processingVersionId',
      'updatedAt',
    ].sort(),
  );

  assert.equal(
    patch.processingStatus,
    'manualReviewRequired',
  );

  assert.equal(
    patch.processingVersionId,
    'version-456',
  );

  assert.equal(patch.updatedAt, processedAt);
});
