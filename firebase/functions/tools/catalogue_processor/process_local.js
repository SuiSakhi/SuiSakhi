#!/usr/bin/env node
const path = require('node:path');
const { processLocalImage } = require('./processor_core');

async function main() {
  const inputPath = process.argv[2];
  const outputDirectory = process.argv[3] ||
    path.join(process.cwd(), 'tmp', 'catalogue-processor-output');
  if (!inputPath) {
    console.error('Usage: npm run catalogue:process -- <input-image> [output-directory]');
    process.exitCode = 2;
    return;
  }
  const result = await processLocalImage({ inputPath, outputDirectory });
  console.log(JSON.stringify({
    ok: true,
    runId: result.manifest.runId,
    status: result.manifest.quality.status,
    warnings: result.manifest.quality.warnings,
    normalized: result.normalizedPath,
    thumbnail: result.thumbnailPath,
    manifest: result.manifestPath,
  }, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
  process.exitCode = 1;
});
