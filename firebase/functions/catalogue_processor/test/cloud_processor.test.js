'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');

const {
  MAX_SOURCE_BYTES,
  buildCloudRunId,
  processCloudImage,
} = require('../cloud_processor');

const {
  parseCatalogueOriginalPath,
} = require('../catalogue_path');

const OBJECT_PATH =
  'catalogue_designs/design-123/' +
  'versions/version-456/' +
  'views/view-789/' +
  'original/source.png';

async function samplePng({
  width = 1200,
  height = 1800,
  alpha = false,
} = {}) {
  return sharp({
    create: {
      width,
      height,
      channels: alpha ? 4 : 3,
      background: alpha
        ? { r: 80, g: 50, b: 160, alpha: 0.5 }
        : { r: 80, g: 50, b: 160 },
    },
  })
    .png()
    .toBuffer();
}

function outputPaths() {
  const parsed = parseCatalogueOriginalPath(OBJECT_PATH);
  assert.ok(parsed);

  return {
    normalizedPath: parsed.normalizedPath,
    thumbnailPath: parsed.thumbnailPath,
    manifestPath: parsed.manifestPath,
  };
}

test('processes a portrait image into governed WebP outputs', async () => {
  const sourceBuffer = await samplePng();

  const result = await processCloudImage({
    sourceBuffer,
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    generation: '1001',
    contentType: 'image/png',
    outputPaths: outputPaths(),
  });

  assert.equal(result.manifest.source.width, 1200);
  assert.equal(result.manifest.source.height, 1800);

  assert.equal(result.manifest.normalized.width, 1200);
  assert.equal(result.manifest.normalized.height, 1800);

  assert.ok(result.manifest.thumbnail.width <= 512);
  assert.ok(result.manifest.thumbnail.height <= 512);

  assert.equal(
    result.manifest.quality.status,
    'manualReviewRequired',
  );

  assert.deepEqual(
    result.manifest.quality.warnings,
    ['SVG_CONVERSION_SKIPPED'],
  );

  const normalizedMetadata =
    await sharp(result.normalizedBuffer).metadata();

  const thumbnailMetadata =
    await sharp(result.thumbnailBuffer).metadata();

  assert.equal(normalizedMetadata.format, 'webp');
  assert.equal(thumbnailMetadata.format, 'webp');
});

test('does not upscale a small image', async () => {
  const sourceBuffer = await samplePng({
    width: 358,
    height: 358,
  });

  const result = await processCloudImage({
    sourceBuffer,
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    generation: '1002',
    contentType: 'image/png',
    outputPaths: outputPaths(),
  });

  assert.equal(result.manifest.normalized.width, 358);
  assert.equal(result.manifest.normalized.height, 358);
  assert.equal(result.manifest.thumbnail.width, 358);
  assert.equal(result.manifest.thumbnail.height, 358);

  assert.ok(
    result.manifest.quality.warnings.includes(
      'SVG_CONVERSION_SKIPPED',
    ),
  );
});

test('preserves source alpha metadata', async () => {
  const sourceBuffer = await samplePng({
    width: 400,
    height: 300,
    alpha: true,
  });

  const result = await processCloudImage({
    sourceBuffer,
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    generation: '1003',
    contentType: 'image/png',
    outputPaths: outputPaths(),
  });

  assert.equal(result.manifest.source.hasAlpha, true);
  assert.equal(result.manifest.normalized.width, 400);
  assert.equal(result.manifest.normalized.height, 300);
});

test('creates the same run ID for identical input identity', async () => {
  const sourceBuffer = await samplePng();
  const args = {
    sourceBuffer,
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    generation: '1004',
    contentType: 'image/png',
    outputPaths: outputPaths(),
  };

  const first = await processCloudImage(args);
  const second = await processCloudImage(args);

  assert.equal(first.runId, second.runId);
});

test('changes run ID when object generation changes', () => {
  const common = {
    bucket: 'suisakhitest.firebasestorage.app',
    objectPath: OBJECT_PATH,
    sourceSha256: 'abc123',
  };

  const first = buildCloudRunId({
    ...common,
    generation: '2001',
  });

  const second = buildCloudRunId({
    ...common,
    generation: '2002',
  });

  assert.notEqual(first, second);
});

test('rejects an invalid image', async () => {
  await assert.rejects(
    processCloudImage({
      sourceBuffer: Buffer.from('not an image'),
      bucket: 'suisakhitest.firebasestorage.app',
      objectPath: OBJECT_PATH,
      generation: '1005',
      contentType: 'image/png',
      outputPaths: outputPaths(),
    }),
    /IMG_DECODE_FAILED/,
  );
});

test('rejects an empty source', async () => {
  await assert.rejects(
    processCloudImage({
      sourceBuffer: Buffer.alloc(0),
      bucket: 'suisakhitest.firebasestorage.app',
      objectPath: OBJECT_PATH,
      generation: '1006',
      contentType: 'image/png',
      outputPaths: outputPaths(),
    }),
    /IMG_SOURCE_EMPTY/,
  );
});

test('rejects a source larger than 12 MB', async () => {
  await assert.rejects(
    processCloudImage({
      sourceBuffer: Buffer.alloc(MAX_SOURCE_BYTES + 1),
      bucket: 'suisakhitest.firebasestorage.app',
      objectPath: OBJECT_PATH,
      generation: '1007',
      contentType: 'image/png',
      outputPaths: outputPaths(),
    }),
    /IMG_SOURCE_TOO_LARGE/,
  );
});

test('rejects unsupported declared content types', async () => {
  const sourceBuffer = await samplePng();

  await assert.rejects(
    processCloudImage({
      sourceBuffer,
      bucket: 'suisakhitest.firebasestorage.app',
      objectPath: OBJECT_PATH,
      generation: '1008',
      contentType: 'application/pdf',
      outputPaths: outputPaths(),
    }),
    /IMG_CONTENT_TYPE_UNSUPPORTED/,
  );
});
