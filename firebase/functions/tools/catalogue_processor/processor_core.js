const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const config = require('./processor_config');

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function localRunId(sourcePath, sourceSha256) {
  return sha256([
    'local',
    path.resolve(sourcePath),
    sourceSha256,
    config.profileCode,
    config.processingVersion,
  ].join('|'));
}

async function fileSha256(filePath) {
  const bytes = await fs.readFile(filePath);
  return sha256(bytes);
}

function validateSourceMetadata(metadata) {
  const warnings = [];
  if (!metadata.width || !metadata.height) {
    throw new Error('IMG_DECODE_FAILED: Source dimensions are unavailable.');
  }
  if (metadata.width < 256 || metadata.height < 256) {
    warnings.push('IMG_DIMENSIONS_TOO_SMALL');
  }
  const ratio = Math.max(metadata.width, metadata.height) /
    Math.max(1, Math.min(metadata.width, metadata.height));
  if (ratio > 8) warnings.push('IMG_DIMENSIONS_EXTREME');
  return warnings;
}

async function processLocalImage({ inputPath, outputDirectory }) {
  const startedAt = new Date();
  await fs.mkdir(outputDirectory, { recursive: true });
  const normalizedDirectory = path.join(outputDirectory, 'normalized');
  const thumbnailDirectory = path.join(outputDirectory, 'thumbnails');
  const structuredDirectory = path.join(outputDirectory, 'structured');
  await Promise.all([
    fs.mkdir(normalizedDirectory, { recursive: true }),
    fs.mkdir(thumbnailDirectory, { recursive: true }),
    fs.mkdir(structuredDirectory, { recursive: true }),
  ]);

  const inputStat = await fs.stat(inputPath);
  if (!inputStat.isFile() || inputStat.size === 0) {
    throw new Error('IMG_SOURCE_EMPTY: Source file is empty or unavailable.');
  }
  if (inputStat.size > 12 * 1024 * 1024) {
    throw new Error('IMG_SOURCE_TOO_LARGE: Source exceeds 12 MB.');
  }

  const metadata = await sharp(inputPath, { failOn: 'error' }).metadata();
  const warnings = validateSourceMetadata(metadata);
  const sourceSha256 = await fileSha256(inputPath);
  const runId = localRunId(inputPath, sourceSha256);
  const normalizedPath = path.join(normalizedDirectory, config.normalized.fileName);
  const thumbnailPath = path.join(thumbnailDirectory, config.thumbnail.fileName);
  const manifestPath = path.join(structuredDirectory, 'manifest.json');

  const normalizedInfo = await sharp(inputPath, { failOn: 'error' })
    .rotate()
    .resize({
      width: config.normalized.maxLongEdge,
      height: config.normalized.maxLongEdge,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({ quality: config.normalized.quality, effort: 4 })
    .toFile(normalizedPath);

  const thumbnailInfo = await sharp(inputPath, { failOn: 'error' })
    .rotate()
    .resize({
      width: config.thumbnail.width,
      height: config.thumbnail.height,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({ quality: config.thumbnail.quality, effort: 4 })
    .toFile(thumbnailPath);

  // Structured SVG is deliberately deferred in C1.2. The manifest records
  // this as a governed warning while raster-derived assets remain usable.
  warnings.push('SVG_CONVERSION_SKIPPED');
  const completedAt = new Date();
  const manifest = {
    schemaVersion: config.schemaVersion,
    runId,
    profileCode: config.profileCode,
    processingEngine: config.processingEngine,
    processingVersion: config.processingVersion,
    source: {
      bucket: 'local-prototype',
      path: path.resolve(inputPath),
      generation: sourceSha256.slice(0, 16),
      contentType: metadata.format ? `image/${metadata.format}` : null,
      byteSize: inputStat.size,
      width: metadata.width,
      height: metadata.height,
      space: metadata.space || null,
      hasAlpha: metadata.hasAlpha === true,
      orientation: metadata.orientation || null,
      sha256: sourceSha256,
    },
    normalized: {
      path: path.relative(outputDirectory, normalizedPath),
      contentType: 'image/webp',
      byteSize: normalizedInfo.size,
      width: normalizedInfo.width,
      height: normalizedInfo.height,
      quality: config.normalized.quality,
      sha256: await fileSha256(normalizedPath),
    },
    thumbnail: {
      path: path.relative(outputDirectory, thumbnailPath),
      contentType: 'image/webp',
      byteSize: thumbnailInfo.size,
      width: thumbnailInfo.width,
      height: thumbnailInfo.height,
      quality: config.thumbnail.quality,
      sha256: await fileSha256(thumbnailPath),
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
      durationMs: completedAt.getTime() - startedAt.getTime(),
    },
  };
  await fs.writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  return { manifest, manifestPath, normalizedPath, thumbnailPath };
}

module.exports = { processLocalImage, fileSha256 };
