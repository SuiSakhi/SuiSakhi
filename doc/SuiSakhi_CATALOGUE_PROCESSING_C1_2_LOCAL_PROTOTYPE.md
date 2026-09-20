# SuiSakhi Catalogue Processing C1.2 Local Prototype

**Status:** Ready for local validation

## Scope

- Deterministic local JPEG/PNG/WebP processing
- EXIF orientation through Sharp auto-rotation
- 2048 px maximum-long-edge normalized WebP at quality 85
- 512 × 512 contain thumbnail WebP at quality 80
- No upscaling
- Manifest generation with checksums, dimensions, timings and warning codes
- Structured SVG explicitly deferred and recorded as `SVG_CONVERSION_SKIPPED`

## Non-Scope

- No Firebase trigger
- No Firestore writes
- No Storage writes
- No Flutter changes
- No rule changes
- No deployment

## Commands

From `firebase/functions`:

```bash
npm install
npm run catalogue:sample
npm run catalogue:process -- tmp/catalogue-sample.png tmp/catalogue-processor-output
npm run catalogue:verify -- tmp/catalogue-processor-output
```

## Expected Result

```text
tmp/catalogue-processor-output/
├── normalized/preview.webp
├── thumbnails/card.webp
└── structured/manifest.json
```

The verification command must return `ok: true`.
