# Catalogue Processing C1.1 Review Checklist

## Paths

- [ ] Original path remains immutable.
- [ ] Normalized path is `normalized/preview.webp`.
- [ ] Thumbnail path is `thumbnails/card.webp`.
- [ ] Structured SVG path is `structured/design.svg`.
- [ ] Manifest path is `structured/manifest.json`.
- [ ] Legacy version-level assets remain supported but are not used for new processing.

## Raster Rules

- [ ] Apply EXIF orientation.
- [ ] Convert to sRGB when possible.
- [ ] Do not upscale.
- [ ] Normalized long edge is 2048 px.
- [ ] Normalized WebP quality is 85.
- [ ] Thumbnail bounding box is 512 × 512 px.
- [ ] Thumbnail uses contain, not destructive crop.
- [ ] Background removal is deferred.

## Lifecycle

- [ ] `manualReviewRequired` represents completed-with-warnings.
- [ ] Required raster failure results in `failed`.
- [ ] Admin may approve a manual-review result.
- [ ] Excluded and superseded Views do not block an active Version.
- [ ] Historical Version processing does not overwrite the active Design status.

## Security

- [ ] Client derivative writes remain denied.
- [ ] Designer original upload permissions remain unchanged.
- [ ] Admin derivative read remains available.
- [ ] Published-customer derivative reads are deferred.
- [ ] No Storage rule broadening is required for Functions Admin SDK writes.

## Deployment Prerequisites

- [ ] Confirm Firebase project is `suisakhitest`.
- [ ] Confirm Blaze plan.
- [ ] Confirm Storage bucket location.
- [ ] Select Functions region aligned with bucket location.
- [ ] Confirm local Node.js major version is compatible with Node 20 runtime.
- [ ] Preserve and smoke-test `sendUserWhatsApp` export.
