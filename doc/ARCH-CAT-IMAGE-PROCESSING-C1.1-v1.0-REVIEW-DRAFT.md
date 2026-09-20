# SuiSakhi Catalogue Image Processing Foundation

**Document Version:** v1.0
**Milestone:** C1.1
**Status:** REVIEW DRAFT — Freeze Before Worker Coding
**Date:** 20 September 2026
**Recommended Repository Path:** `doc/ARCH-CAT-IMAGE-PROCESSING-C1.1-v1.0.md`

---

## 1. Purpose

Define the controlled server-side processing contract for every governed Catalogue Design View.

The pipeline converts an immutable uploaded original into safe derived assets without overwriting the source:

```text
Immutable Original
→ Source Validation
→ Normalized Preview
→ Thumbnail
→ Structured Conversion
→ Quality Evaluation
→ Admin Review
→ Publication Readiness
```

This foundation applies to SuiSakhi-owned and approved Partner-owned Catalogue submissions.

---

## 2. Confirmed Existing Baseline

The current Catalogue implementation already provides:

```text
Design
→ Version
→ 1 to 10 Views
→ Original asset per View
→ Per-View processing result
→ Version processing result
→ Admin review
→ Publication gate
```

The current immutable multi-view original path is:

```text
catalogue_designs/{designId}/versions/{versionId}/views/{viewId}/original/source.{ext}
```

The existing View model already supports:

```text
originalAsset
normalizedPreviewAsset
structuredSvgAsset
thumbnailAsset
processing
```

The existing backend folder is:

```text
firebase/functions
```

and currently contains the WhatsApp callable function only.

---

# ARCH-CAT-IMG-001: Immutable Source Asset

The uploaded original is immutable.

```text
Client may create original once.
Client may not update or delete original.
Backend-generated derivatives never replace original.
Historical Version originals remain preserved.
```

The original object generation and storage path are part of the processing identity.

---

# ARCH-CAT-IMG-002: Per-View Derived Asset Paths

Freeze the multi-view derived paths as:

```text
catalogue_designs/{designId}/
  versions/{versionId}/
    views/{viewId}/
      original/source.{ext}
      normalized/preview.webp
      thumbnails/card.webp
      structured/design.svg
      structured/manifest.json
```

Optional future artifacts may use:

```text
structured/design.json
quality/report.json
```

Legacy version-level paths remain readable for historical records but all new processing must use the View-level path contract.

---

# ARCH-CAT-IMG-003: Processing Trigger

The worker reacts only to a successfully finalized object whose path matches:

```text
catalogue_designs/{designId}/versions/{versionId}/views/{viewId}/original/{fileName}
```

The worker must ignore:

```text
normalized/
thumbnails/
structured/
legacy version-level original paths
non-Catalogue files
```

This prevents recursive processing when derivative objects are uploaded.

---

# ARCH-CAT-IMG-004: Idempotency

The processing run identity is derived from:

```text
bucket
original object path
original object generation
processor profile code
processor version
```

Recommended deterministic run key:

```text
SHA-256(bucket|objectPath|generation|profileCode|processorVersion)
```

A retried Storage event must reuse or safely complete the same run rather than creating duplicate events or conflicting assets.

Derivative names remain deterministic:

```text
normalized/preview.webp
thumbnails/card.webp
structured/design.svg
structured/manifest.json
```

A newer original generation or explicit Admin reprocess request creates a new processing run.

---

# ARCH-CAT-IMG-005: Normalized Preview Specification

## Input

```text
JPEG
PNG
WebP
Maximum source size: 12 MB, aligned with existing upload policy
```

## Processing

```text
Apply EXIF orientation
Convert embedded color profile to sRGB when available
Remove unnecessary private metadata
Preserve transparency where meaningful
Do not upscale small originals
Use contain-style resizing
```

## Output

```text
Path: normalized/preview.webp
Format: WebP
Maximum long edge: 2048 px
Quality target: 85
Purpose: Admin review and high-quality Catalogue preview
```

The normalized image must preserve the complete fashion drawing or garment image. Destructive center cropping is not permitted.

---

# ARCH-CAT-IMG-006: Thumbnail Specification

```text
Path: thumbnails/card.webp
Format: WebP
Bounding box: 512 × 512 px
Resize mode: contain
Quality target: 80
Purpose: Catalogue cards, filters and compact review lists
```

Transparent inputs may preserve transparency. Non-transparent inputs should retain their source background during C1.

Background removal is explicitly outside C1.

---

# ARCH-CAT-IMG-007: Structured Conversion Boundary

C1 does not promise perfect garment vectorization.

The structured stage shall:

```text
Produce structured/design.svg when safely possible
Produce structured/manifest.json for every processing attempt
Record detected/present SVG layers
Record missing layers
Record path count and SVG byte size
Record quality warnings
Record engine and processor version
```

If structured conversion is not reliable:

```text
Normalized preview may still succeed
Thumbnail may still succeed
Structured stage records a governed warning or failure
Admin may review the raster assets
Publication remains blocked unless Admin explicitly approves the processing result
```

C1 structured output may be a trace/vector foundation and is not yet a production sewing pattern.

---

# ARCH-CAT-IMG-008: Processing Lifecycle

The existing processing states remain the canonical persisted values for C1:

```text
notRequested
queued
processing
completed
manualReviewRequired
failed
approved
rejected
superseded
```

Interpretation:

```text
completed
→ All required C1 derivatives generated and quality checks passed.

manualReviewRequired
→ Raster derivatives succeeded, but structured output or quality checks produced warnings.

failed
→ Required normalization or thumbnail generation failed.

approved
→ Admin explicitly accepted a manual-review result for publication.

rejected
→ Admin rejected the processing result and reprocessing or correction is required.
```

`completedWithWarnings` will not be introduced as a new persisted enum in C1 because `manualReviewRequired` already represents that governed state.

`retryScheduled` will initially be represented through a processing event with `status = queued` and retry metadata. A new enum value may be added later if operational monitoring requires it.

---

# ARCH-CAT-IMG-009: Processing Event Contract

Each run creates or updates:

```text
designs/{designId}/processing_events/{runId}
```

Required fields:

```text
runId
designId
versionId
viewId
sourceBucket
sourcePath
sourceGeneration
sourceContentType
sourceByteSize
profileCode
processingEngine
processingVersion
status
attemptCount
startedAt
completedAt
failureCode
failureMessage
qualityWarnings
normalizedAssetPath
thumbnailAssetPath
structuredAssetPath
manifestAssetPath
createdAt
updatedAt
```

Optional diagnostic fields:

```text
sourceWidth
sourceHeight
normalizedWidth
normalizedHeight
thumbnailWidth
thumbnailHeight
qualityScore
pathCount
svgByteSize
presentLayers
missingLayers
```

The event is operational and auditable. The View document remains the active processing result consumed by the mobile application.

---

# ARCH-CAT-IMG-010: View Update Contract

After a successful or partially successful run, the worker updates only the targeted View document:

```text
designs/{designId}/versions/{versionId}/views/{viewId}
```

Permitted backend-generated updates:

```text
normalizedPreviewAsset
thumbnailAsset
structuredSvgAsset
processing
updatedAt
```

The worker must not modify:

```text
viewId
designId
versionId
viewType
displayOrder
isPrimary
title
originalAsset
sourceVersionId
sourceViewId
inherited
excludedFromVersion
replacedByViewId
```

---

# ARCH-CAT-IMG-011: Version Aggregation

The Version processing result is derived from active, non-excluded Views.

Recommended aggregation:

```text
Any active View failed
→ Version failed

Else any active View processing or queued
→ Version processing

Else any active View manualReviewRequired
→ Version manualReviewRequired

Else every active View completed
→ Version completed

Else every active View is completed or approved
→ Version approved or completed according to Admin decision
```

Excluded or superseded Views do not block the active Version.

The worker may update:

```text
designs/{designId}/versions/{versionId}.processing
```

only after reading all active Views.

---

# ARCH-CAT-IMG-012: Design-Level Processing Status

The Design root `processingStatus` mirrors the active Version status for list filtering and summary display.

The active Version remains the source of truth.

The worker must verify:

```text
design.activeVersionId == versionId
```

before updating the Design root. Processing a historical Version must never overwrite the current Design-level status.

---

# ARCH-CAT-IMG-013: Quality Checks and Warning Codes

Initial C1 warning and failure codes:

```text
IMG_SOURCE_UNSUPPORTED
IMG_SOURCE_EMPTY
IMG_SOURCE_TOO_LARGE
IMG_DECODE_FAILED
IMG_DIMENSIONS_TOO_SMALL
IMG_DIMENSIONS_EXTREME
IMG_EXIF_ORIENTATION_APPLIED
IMG_COLOR_PROFILE_CONVERTED
IMG_ALPHA_PRESERVED
IMG_NORMALIZATION_FAILED
IMG_THUMBNAIL_FAILED
SVG_CONVERSION_SKIPPED
SVG_CONVERSION_FAILED
SVG_EMPTY_OUTPUT
SVG_PATH_COUNT_LOW
SVG_PATH_COUNT_HIGH
SVG_REQUIRED_LAYER_MISSING
SVG_MANUAL_REVIEW_REQUIRED
PROCESSING_STALE_SOURCE
PROCESSING_VIEW_NOT_FOUND
PROCESSING_VERSION_NOT_FOUND
PROCESSING_DESIGN_NOT_FOUND
PROCESSING_DUPLICATE_EVENT
PROCESSING_INTERNAL_ERROR
```

Warnings are machine-readable codes. User-facing descriptions must be mapped centrally in Admin UI rather than storing arbitrary text only.

---

# ARCH-CAT-IMG-014: Publication Readiness

A Design may be published only when:

```text
Design lifecycle is approved
Publication status is unpublished
Active Version exists
Every active View has normalized preview and thumbnail
No active View is failed or processing
Version processing is completed or approved
```

Structured SVG requirements:

```text
If structured output is completed
→ Publish may proceed.

If structured output requires manual review
→ Admin must explicitly approve processing before publish.

If normalization or thumbnail failed
→ Publish remains blocked.
```

Publication readiness must be evaluated across all active Views, not only the Version status field.

---

# ARCH-CAT-IMG-015: Security Boundary

Client rules remain:

```text
Admin or owning Designer may create immutable originals according to lifecycle.
Clients cannot write normalized, thumbnail or structured derivative paths.
Admin may read derivative assets for review.
Published-customer derivative-read policy will be added with Customer Catalogue publication work.
```

The Cloud Functions Admin SDK writes derivatives and Firestore processing records server-side and is not authorized through client security rules.

No Storage rule broadening is required for the worker.

---

# ARCH-CAT-IMG-016: Processing Engine and Runtime

The existing Functions codebase uses:

```text
firebase/functions
Node.js 20
firebase-functions 5.x
firebase-admin 12.x
CommonJS index.js
```

C1 should preserve the current callable WhatsApp function and add processing as a separate exported function.

Recommended raster library:

```text
sharp
```

Recommended first worker export:

```text
processCatalogueViewOriginal
```

Recommended trigger region:

```text
Same region as the Cloud Storage bucket whenever possible
```

The exact region must be confirmed before deployment.

---

# ARCH-CAT-IMG-017: Deployment Slices

## C1.1 — Contract Freeze

```text
Architecture
Paths
States
Manifest
Quality codes
Publication readiness
```

## C1.2 — Local Deterministic Prototype

```text
Run normalization and thumbnail generation locally
Use representative JPEG, PNG and WebP samples
Verify orientation, transparency, dimensions, byte size and repeatability
No Firebase deployment
```

## C1.3 — Storage-Triggered Worker

```text
Add sharp dependency
Add finalized-object trigger
Process only immutable original paths
Write derivatives
Update View and processing event
Aggregate Version and Design status
```

## C1.4 — Admin Review UI

```text
Original preview
Normalized preview
Thumbnail preview
Structured SVG preview when available
Warnings and failure details
Processing engine/version
Retry or approve processing action
```

## C1.5 — Publication Readiness and Regression

```text
Per-View readiness validation
Admin approval of warning state
Idempotency test
Historical Version test
Correction Version test
Security regression
```

---

## 18. Explicitly Deferred

```text
Background removal
AI garment segmentation
Perfect vector reconstruction
Sewing pattern generation
Customer-visible published derivative rules
Bulk migration of all legacy records
Automatic commercial approval
Customer Catalogue recommendations
```

---

## 19. Freeze Recommendation

Freeze C1.1 before changing Functions code.

The first coding slice after freeze shall be C1.2, a local deterministic normalization and thumbnail prototype using the exact output contract defined here.
