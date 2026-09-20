# SuiSakhi Catalogue Processing Manifest Schema

**Version:** 1.0 Review Draft
**Milestone:** C1.1

## Storage Path

```text
catalogue_designs/{designId}/versions/{versionId}/views/{viewId}/structured/manifest.json
```

## JSON Contract

```json
{
  "schemaVersion": "1.0",
  "runId": "sha256-value",
  "profileCode": "suisakhiStructuredSvgV1",
  "processingEngine": "suisakhi-catalogue-processor",
  "processingVersion": "1.0.0",
  "source": {
    "bucket": "bucket-name",
    "path": "catalogue_designs/.../original/source.png",
    "generation": "1234567890",
    "contentType": "image/png",
    "byteSize": 245678,
    "width": 1600,
    "height": 2200,
    "sha256": "optional-source-checksum"
  },
  "normalized": {
    "path": "catalogue_designs/.../normalized/preview.webp",
    "contentType": "image/webp",
    "byteSize": 156789,
    "width": 1489,
    "height": 2048,
    "quality": 85
  },
  "thumbnail": {
    "path": "catalogue_designs/.../thumbnails/card.webp",
    "contentType": "image/webp",
    "byteSize": 26789,
    "width": 372,
    "height": 512,
    "quality": 80
  },
  "structured": {
    "status": "manualReviewRequired",
    "path": "catalogue_designs/.../structured/design.svg",
    "contentType": "image/svg+xml",
    "byteSize": 45678,
    "pathCount": 19,
    "presentLayers": ["outline", "bodyFill"],
    "missingLayers": ["sleevesFill", "borderFill", "motifFill", "stitchGuides"]
  },
  "quality": {
    "status": "manualReviewRequired",
    "score": 0.72,
    "warnings": ["SVG_REQUIRED_LAYER_MISSING"]
  },
  "timing": {
    "startedAt": "2026-09-20T07:00:00.000Z",
    "completedAt": "2026-09-20T07:00:04.250Z",
    "durationMs": 4250
  }
}
```

## Rules

- The manifest is backend-generated and immutable for one processing run.
- A deterministic derivative path may be replaced only by the backend when the source generation or processor version changes.
- `runId`, source path, source generation, profile code and processor version must agree with the Firestore processing event.
- Missing structured output must still produce a manifest describing the warning or failure.
- The manifest must not contain authentication tokens, local temporary paths or private EXIF data.
