#!/usr/bin/env node
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const config = require('./processor_config');

async function main() {
  const outputDirectory = process.argv[2] ||
    path.join(process.cwd(), 'tmp', 'catalogue-processor-output');
  const manifestPath = path.join(outputDirectory, 'structured', 'manifest.json');
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'));
  const normalizedPath = path.join(outputDirectory, manifest.normalized.path);
  const thumbnailPath = path.join(outputDirectory, manifest.thumbnail.path);
  const normalized = await sharp(normalizedPath).metadata();
  const thumbnail = await sharp(thumbnailPath).metadata();
  const failures = [];
  if (Math.max(normalized.width, normalized.height) > config.normalized.maxLongEdge) {
    failures.push('Normalized image exceeds configured long edge.');
  }
  if (normalized.format !== 'webp') failures.push('Normalized output is not WebP.');
  if (thumbnail.width > config.thumbnail.width || thumbnail.height > config.thumbnail.height) {
    failures.push('Thumbnail exceeds configured bounding box.');
  }
  if (thumbnail.format !== 'webp') failures.push('Thumbnail output is not WebP.');
  if (manifest.quality.status !== 'manualReviewRequired') {
    failures.push('C1.2 manifest should be manualReviewRequired while SVG is deferred.');
  }
  if (!manifest.quality.warnings.includes('SVG_CONVERSION_SKIPPED')) {
    failures.push('Manifest is missing SVG_CONVERSION_SKIPPED.');
  }
  if (failures.length) {
    console.error(JSON.stringify({ ok: false, failures }, null, 2));
    process.exitCode = 1;
    return;
  }
  console.log(JSON.stringify({
    ok: true,
    normalized: { width: normalized.width, height: normalized.height, format: normalized.format },
    thumbnail: { width: thumbnail.width, height: thumbnail.height, format: thumbnail.format },
    runId: manifest.runId,
  }, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
