# Catalogue Processing C1.2 Test Checklist

## Installation
- [ ] Back up `firebase/functions/package.json`.
- [ ] Copy the `tools/catalogue_processor` directory.
- [ ] Run `npm install` from `firebase/functions`.
- [ ] Confirm existing `sendUserWhatsApp` remains exported from `index.js`.

## Generated Sample
- [ ] `npm run catalogue:sample` creates `tmp/catalogue-sample.png`.
- [ ] Local processing succeeds.
- [ ] Verification returns `ok: true`.
- [ ] Normalized output is WebP and long edge is at most 2048 px.
- [ ] Thumbnail is WebP and fits within 512 × 512 px.
- [ ] Manifest contains source and derivative SHA-256 checksums.
- [ ] Manifest contains `SVG_CONVERSION_SKIPPED`.

## Real Samples
Test at least:
- [ ] Portrait JPEG from mobile camera.
- [ ] PNG line drawing with transparency.
- [ ] WebP input.
- [ ] Small image below 512 px to confirm no upscaling.
- [ ] Invalid non-image file to confirm controlled failure.
- [ ] File above 12 MB to confirm rejection.

## Regression
- [ ] No Flutter file changed.
- [ ] No Firebase rule changed.
- [ ] No function deployed.
- [ ] `npm test` or existing Functions checks, if any, remain clean.
