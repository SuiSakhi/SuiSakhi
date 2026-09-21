'use strict';

const PROCESSING_VERSION = '1.0.0-cloud-worker';

const SVG_LAYERS = Object.freeze([
  'outline',
  'bodyFill',
  'sleevesFill',
  'borderFill',
  'motifFill',
  'stitchGuides',
]);

const STATUS_PRECEDENCE = Object.freeze([
  'failed',
  'processing',
  'queued',
  'manualReviewRequired',
  'completed',
  'approved',
  'rejected',
  'superseded',
  'notRequested',
]);

function requireManifest(manifest) {
  if (!manifest || typeof manifest !== 'object') {
    throw new Error(
      'MAPPER_MANIFEST_MISSING: Processing manifest is required.',
    );
  }

  if (!manifest.normalized || !manifest.thumbnail) {
    throw new Error(
      'MAPPER_DERIVATIVES_MISSING: Derived asset metadata is required.',
    );
  }

  if (!manifest.quality || !manifest.source) {
    throw new Error(
      'MAPPER_PROCESSING_MISSING: Processing metadata is required.',
    );
  }
}

function normalizeDate(value) {
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error(
        'MAPPER_DATE_INVALID: A valid processing date is required.',
      );
    }

    return value;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    throw new Error(
      'MAPPER_DATE_INVALID: A valid processing date is required.',
    );
  }

  return parsed;
}

function assetMap({
  assetType,
  section,
  downloadUrl = null,
  createdAt,
}) {
  if (!section || typeof section !== 'object') {
    throw new Error(
      `MAPPER_ASSET_MISSING: ${assetType} metadata is required.`,
    );
  }

  return {
    assetType,
    storagePath: String(section.path || '').trim(),
    mimeType: String(section.contentType || '').trim().toLowerCase(),
    byteSize: Number(section.byteSize || 0),
    downloadUrl:
      typeof downloadUrl === 'string' &&
      downloadUrl.trim().length > 0
        ? downloadUrl.trim()
        : null,
    width:
      Number.isInteger(section.width)
        ? section.width
        : null,
    height:
      Number.isInteger(section.height)
        ? section.height
        : null,
    sha256:
      typeof section.sha256 === 'string' &&
      section.sha256.trim().length > 0
        ? section.sha256.trim()
        : null,
    createdAt,
  };
}

function processingMap({
  manifest,
  processedAt,
}) {
  requireManifest(manifest);

  const warnings = Array.isArray(manifest.quality.warnings)
    ? [...new Set(
        manifest.quality.warnings
          .map((value) => String(value).trim())
          .filter(Boolean),
      )]
    : [];

  const missingLayers =
    Array.isArray(manifest.structured?.missingLayers)
      ? [...new Set(
          manifest.structured.missingLayers
            .map((value) => String(value).trim())
            .filter(Boolean),
        )]
      : [...SVG_LAYERS];

  const presentLayers =
    Array.isArray(manifest.structured?.presentLayers)
      ? [...new Set(
          manifest.structured.presentLayers
            .map((value) => String(value).trim())
            .filter(Boolean),
        )]
      : [];

  return {
    status: 'manualReviewRequired',
    profileCode:
      String(manifest.profileCode || 'suisakhiStructuredSvgV1').trim(),
    presentLayers,
    missingLayers,
    qualityWarnings: warnings,
    qualityScore:
      typeof manifest.quality.score === 'number'
        ? manifest.quality.score
        : null,
    pathCount:
      Number.isInteger(manifest.structured?.pathCount)
        ? manifest.structured.pathCount
        : null,
    svgByteSize:
      Number.isInteger(manifest.structured?.byteSize)
        ? manifest.structured.byteSize
        : null,
    processingEngine:
      String(
        manifest.processingEngine ||
        'suisakhi-catalogue-processor',
      ).trim(),
    processingVersion:
      String(
        manifest.processingVersion ||
        PROCESSING_VERSION,
      ).trim(),
    processedAt,
    failureCode: null,
    failureMessage: null,
  };
}

function buildSuccessfulViewPatch({
  manifest,
  normalizedDownloadUrl = null,
  thumbnailDownloadUrl = null,
  processedAt = new Date(),
}) {
  requireManifest(manifest);

  const date = normalizeDate(processedAt);

  return {
    normalizedPreviewAsset: assetMap({
      assetType: 'normalizedPreview',
      section: manifest.normalized,
      downloadUrl: normalizedDownloadUrl,
      createdAt: date,
    }),
    structuredSvgAsset: null,
    thumbnailAsset: assetMap({
      assetType: 'thumbnail',
      section: manifest.thumbnail,
      downloadUrl: thumbnailDownloadUrl,
      createdAt: date,
    }),
    processing: processingMap({
      manifest,
      processedAt: date,
    }),
    updatedAt: date,
  };
}

function failureIdentity(error) {
  const message =
    error instanceof Error
      ? error.message
      : String(error || 'Unknown processing failure.');

  const separator = message.indexOf(':');

  const code = separator > 0
    ? message.slice(0, separator).trim()
    : 'IMG_PROCESSING_FAILED';

  return {
    code: code || 'IMG_PROCESSING_FAILED',
    message: message.trim() || 'Unknown processing failure.',
  };
}

function buildFailedViewPatch({
  error,
  processedAt = new Date(),
}) {
  const date = normalizeDate(processedAt);
  const failure = failureIdentity(error);

  return {
    processing: {
      status: 'failed',
      profileCode: 'suisakhiStructuredSvgV1',
      presentLayers: [],
      missingLayers: [...SVG_LAYERS],
      qualityWarnings: [],
      qualityScore: null,
      pathCount: null,
      svgByteSize: null,
      processingEngine: 'suisakhi-catalogue-processor',
      processingVersion: PROCESSING_VERSION,
      processedAt: date,
      failureCode: failure.code,
      failureMessage: failure.message,
    },
    updatedAt: date,
  };
}

function aggregateProcessingStatus(statuses) {
  if (!Array.isArray(statuses) || statuses.length === 0) {
    return 'notRequested';
  }

  const normalized = statuses
    .map((status) => String(status || '').trim())
    .filter(Boolean);

  if (normalized.length === 0) {
    return 'notRequested';
  }

  for (const status of STATUS_PRECEDENCE) {
    if (normalized.includes(status)) {
      return status;
    }
  }

  return 'notRequested';
}

function buildVersionProcessingPatch({
  viewStatuses,
  processedAt = new Date(),
}) {
  const date = normalizeDate(processedAt);
  const status = aggregateProcessingStatus(viewStatuses);

  return {
    processing: {
      status,
      profileCode: 'suisakhiStructuredSvgV1',
      presentLayers: [],
      missingLayers:
        status === 'completed' || status === 'approved'
          ? []
          : [...SVG_LAYERS],
      qualityWarnings:
        status === 'manualReviewRequired'
          ? ['SVG_CONVERSION_SKIPPED']
          : [],
      qualityScore: null,
      pathCount: null,
      svgByteSize: null,
      processingEngine: 'suisakhi-catalogue-processor',
      processingVersion: PROCESSING_VERSION,
      processedAt: date,
      failureCode:
        status === 'failed'
          ? 'VIEW_PROCESSING_FAILED'
          : null,
      failureMessage:
        status === 'failed'
          ? 'One or more Catalogue Views failed processing.'
          : null,
    },
    updatedAt: date,
  };
}

function buildDesignProcessingPatch({
  versionStatus,
  activeVersionId,
  processedAt = new Date(),
}) {
  const date = normalizeDate(processedAt);

  return {
    processingStatus:
      typeof versionStatus === 'string' &&
      versionStatus.trim().length > 0
        ? versionStatus.trim()
        : 'notRequested',
    processingVersionId:
      typeof activeVersionId === 'string' &&
      activeVersionId.trim().length > 0
        ? activeVersionId.trim()
        : null,
    processingUpdatedAt: date,
    updatedAt: date,
  };
}

module.exports = {
  PROCESSING_VERSION,
  SVG_LAYERS,
  aggregateProcessingStatus,
  buildSuccessfulViewPatch,
  buildFailedViewPatch,
  buildVersionProcessingPatch,
  buildDesignProcessingPatch,
};
