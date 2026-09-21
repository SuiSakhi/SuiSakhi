'use strict';

const crypto = require('node:crypto');
const sharp = require('sharp');
const config = require('../tools/catalogue_processor/processor_config');

const MAX_SOURCE_BYTES = 12 * 1024 * 1024;

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function buildCloudRunId({
  bucket,
  objectPath,
  generation,
  sourceSha256,
}) {
  return sha256([
    'cloud',
    bucket,
    objectPath,
    String(generation),
    sourceSha256,
    config.profileCode,
    '1.0.0-cloud-worker',
  ].join('|'));
}

function validateInput({
  sourceBuffer,
  bucket,
  objectPath,
  generation,
  contentType,
}) {
  if (!Buffer.isBuffer(sourceBuffer)) {
    throw new Error(
      'IMG_SOURCE_INVALID: Source must be supplied as a Buffer.',
    );
  }

  if (sourceBuffer.length === 0) {
    throw new Error(
      'IMG_SOURCE_EMPTY: Source file is empty or unavailable.',
    );
  }

  if (sourceBuffer.length > MAX_SOURCE_BYTES) {
    throw new Error(
      'IMG_SOURCE_TOO_LARGE: Source exceeds 12 MB.',
    );
  }

  if (typeof bucket !== 'string' || bucket.trim().length === 0) {
    throw new Error(
      'IMG_BUCKET_MISSING: Source bucket is required.',
    );
  }

  if (
    typeof objectPath !== 'string' ||
    objectPath.trim().length === 0
  ) {
    throw new Error(
      'IMG_OBJECT_PATH_MISSING: Source object path is required.',
    );
  }

  if (
    generation === null ||
    generation === undefined ||
    String(generation).trim().length === 0
  ) {
    throw new Error(
      'IMG_GENERATION_MISSING: Source generation is required.',
    );
  }

  const normalizedContentType =
    typeof contentType === 'string'
      ? contentType.trim().toLowerCase()
      : '';

  if (
    normalizedContentType.length > 0 &&
    ![
      'image/jpeg',
      'image/png',
      'image/webp',
    ].includes(normalizedContentType)
  ) {
    throw new Error(
      `IMG_CONTENT_TYPE_UNSUPPORTED: ${normalizedContentType}`,
    );
  }
}

function sourceWarnings(metadata) {
  const warnings = [];

  if (!metadata.width || !metadata.height) {
    throw new Error(
      'IMG_DECODE_FAILED: Source dimensions are unavailable.',
    );
  }

  if (metadata.width < 256 || metadata.height < 256) {
    warnings.push('IMG_DIMENSIONS_TOO_SMALL');
  }

  const shortestEdge = Math.max(
    1,
    Math.min(metadata.width, metadata.height),
  );

  const ratio =
    Math.max(metadata.width, metadata.height) /
    shortestEdge;

  if (ratio > 8) {
    warnings.push('IMG_DIMENSIONS_EXTREME');
  }

  return warnings;
}

async function processCloudImage({
  sourceBuffer,
  bucket,
  objectPath,
  generation,
  contentType,
  outputPaths,
}) {
  validateInput({
    sourceBuffer,
    bucket,
    objectPath,
    generation,
    contentType,
  });

  if (
    !outputPaths ||
    !outputPaths.normalizedPath ||
    !outputPaths.thumbnailPath ||
    !outputPaths.manifestPath
  ) {
    throw new Error(
      'IMG_OUTPUT_PATHS_MISSING: Derived output paths are required.',
    );
  }

  const startedAt = new Date();

  let metadata;
  try {
    metadata = await sharp(sourceBuffer, {
      failOn: 'error',
    }).metadata();
  } catch (error) {
    throw new Error(
      `IMG_DECODE_FAILED: ${error.message}`,
    );
  }

  const warnings = sourceWarnings(metadata);
  const sourceSha256 = sha256(sourceBuffer);

  const runId = buildCloudRunId({
    bucket: bucket.trim(),
    objectPath: objectPath.trim(),
    generation: String(generation),
    sourceSha256,
  });

  const normalizedResult = await sharp(sourceBuffer, {
    failOn: 'error',
  })
    .rotate()
    .resize({
      width: config.normalized.maxLongEdge,
      height: config.normalized.maxLongEdge,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({
      quality: config.normalized.quality,
      effort: 4,
    })
    .toBuffer({ resolveWithObject: true });

  const thumbnailResult = await sharp(sourceBuffer, {
    failOn: 'error',
  })
    .rotate()
    .resize({
      width: config.thumbnail.width,
      height: config.thumbnail.height,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({
      quality: config.thumbnail.quality,
      effort: 4,
    })
    .toBuffer({ resolveWithObject: true });

  warnings.push('SVG_CONVERSION_SKIPPED');

  const completedAt = new Date();

  const manifest = {
    schemaVersion: config.schemaVersion,
    runId,
    profileCode: config.profileCode,
    processingEngine: config.processingEngine,
    processingVersion: '1.0.0-cloud-worker',
    source: {
      bucket: bucket.trim(),
      path: objectPath.trim(),
      generation: String(generation),
      contentType:
        contentType?.trim().toLowerCase() ||
        (metadata.format
          ? `image/${metadata.format}`
          : null),
      byteSize: sourceBuffer.length,
      width: metadata.width,
      height: metadata.height,
      space: metadata.space || null,
      hasAlpha: metadata.hasAlpha === true,
      orientation: metadata.orientation || null,
      sha256: sourceSha256,
    },
    normalized: {
      path: outputPaths.normalizedPath,
      contentType: 'image/webp',
      byteSize: normalizedResult.info.size,
      width: normalizedResult.info.width,
      height: normalizedResult.info.height,
      quality: config.normalized.quality,
      sha256: sha256(normalizedResult.data),
    },
    thumbnail: {
      path: outputPaths.thumbnailPath,
      contentType: 'image/webp',
      byteSize: thumbnailResult.info.size,
      width: thumbnailResult.info.width,
      height: thumbnailResult.info.height,
      quality: config.thumbnail.quality,
      sha256: sha256(thumbnailResult.data),
    },
    structured: {
      status: 'manualReviewRequired',
      path: null,
      contentType: 'image/svg+xml',
      byteSize: null,
      pathCount: null,
      presentLayers: [],
      missingLayers: [
        'outline',
        'bodyFill',
        'sleevesFill',
        'borderFill',
        'motifFill',
        'stitchGuides',
      ],
    },
    quality: {
      status: 'manualReviewRequired',
      score: null,
      warnings: [...new Set(warnings)],
    },
    timing: {
      startedAt: startedAt.toISOString(),
      completedAt: completedAt.toISOString(),
      durationMs:
        completedAt.getTime() - startedAt.getTime(),
    },
  };

  const manifestBuffer = Buffer.from(
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );

  return {
    runId,
    manifest,
    manifestBuffer,
    normalizedBuffer: normalizedResult.data,
    thumbnailBuffer: thumbnailResult.data,
  };
}

module.exports = {
  MAX_SOURCE_BYTES,
  sha256,
  buildCloudRunId,
  processCloudImage,
};
