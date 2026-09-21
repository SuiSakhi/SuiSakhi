"use strict";

const { parseCatalogueOriginalPath } = require("./catalogue_path");

const { processCloudImage } = require("./cloud_processor");

const { buildEventIdentity } = require("./run_identity");

const {
  buildSuccessfulViewPatch,
  buildFailedViewPatch,
  buildVersionProcessingPatch,
  buildDesignProcessingPatch,
} = require("./firestore_mapper");

const EXPECTED_BUCKET = "suisakhitest.firebasestorage.app";

function requireAdapterMethod(adapter, methodName) {
  if (!adapter || typeof adapter[methodName] !== "function") {
    throw new Error(`WORKER_ADAPTER_INVALID: ${methodName} is required.`);
  }
}

function validateAdapters({ storageAdapter, firestoreAdapter }) {
  for (const methodName of ["download", "upload"]) {
    requireAdapterMethod(storageAdapter, methodName);
  }

  for (const methodName of [
    "getView",
    "updateView",
    "listViewStatuses",
    "updateVersion",
    "getDesign",
    "updateDesign",
  ]) {
    requireAdapterMethod(firestoreAdapter, methodName);
  }
}

function normalizeStorageEvent(event) {
  if (!event || typeof event !== "object") {
    throw new Error("WORKER_EVENT_MISSING: Storage event is required.");
  }

  const bucket = typeof event.bucket === "string" ? event.bucket.trim() : "";

  const objectPath = typeof event.name === "string" ? event.name.trim() : "";

  const generation =
    event.generation === null || event.generation === undefined
      ? ""
      : String(event.generation).trim();

  const contentType =
    typeof event.contentType === "string"
      ? event.contentType.trim().toLowerCase()
      : "";

  return {
    bucket,
    objectPath,
    generation,
    contentType,
  };
}

function sleep(milliseconds) {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

async function waitForRegisteredView({
  firestoreAdapter,
  designId,
  versionId,
  viewId,
  attempts = 8,
  delayMs = 750,
}) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const view = await firestoreAdapter.getView({
      designId,
      versionId,
      viewId,
    });

    if (view) {
      return view;
    }

    if (attempt < attempts) {
      await sleep(delayMs);
    }
  }

  return null;
}

function processingPatch(status, processedAt) {
  return {
    processing: {
      status,
      profileCode: "suisakhiStructuredSvgV1",
      presentLayers: [],
      missingLayers: [
        "outline",
        "bodyFill",
        "sleevesFill",
        "borderFill",
        "motifFill",
        "stitchGuides",
      ],
      qualityWarnings: [],
      qualityScore: null,
      pathCount: null,
      svgByteSize: null,
      processingEngine: "suisakhi-catalogue-processor",
      processingVersion: "1.0.0-cloud-worker",
      processedAt,
      failureCode: null,
      failureMessage: null,
    },
    updatedAt: processedAt,
  };
}

async function runCatalogueWorkerCore({
  event,
  storageAdapter,
  firestoreAdapter,
  logger = console,
  now = () => new Date(),
  afterViewRegistered = async () => {},
  beforeGovernedWrites = async () => {},
}) {
  validateAdapters({
    storageAdapter,
    firestoreAdapter,
  });

  const normalizedEvent = normalizeStorageEvent(event);

  if (normalizedEvent.bucket !== EXPECTED_BUCKET) {
    logger.info?.("Catalogue worker ignored non-target bucket.", {
      bucket: normalizedEvent.bucket,
    });

    return {
      ok: true,
      ignored: true,
      reason: "BUCKET_NOT_TARGETED",
    };
  }

  const parsed = parseCatalogueOriginalPath(normalizedEvent.objectPath);

  if (!parsed) {
    logger.info?.("Catalogue worker ignored non-original path.", {
      objectPath: normalizedEvent.objectPath,
    });

    return {
      ok: true,
      ignored: true,
      reason: "PATH_NOT_TARGETED",
    };
  }

  if (!normalizedEvent.generation) {
    throw new Error(
      "WORKER_GENERATION_MISSING: Storage generation is required.",
    );
  }

  const view = await waitForRegisteredView({
    firestoreAdapter,
    designId: parsed.designId,
    versionId: parsed.versionId,
    viewId: parsed.viewId,
  });

  if (!view) {
    throw new Error("WORKER_VIEW_NOT_FOUND: Catalogue View does not exist.");
  }

  await afterViewRegistered();

  const registeredOriginalPath =
    view.originalAsset && typeof view.originalAsset.storagePath === "string"
      ? view.originalAsset.storagePath.trim()
      : "";

  if (
    registeredOriginalPath &&
    registeredOriginalPath !== normalizedEvent.objectPath
  ) {
    throw new Error(
      "WORKER_SOURCE_PATH_MISMATCH: " +
        "Storage object does not match the View original asset.",
    );
  }

  const startedAt = now();

  await firestoreAdapter.updateView({
    designId: parsed.designId,
    versionId: parsed.versionId,
    viewId: parsed.viewId,
    patch: processingPatch("processing", startedAt),
  });

  try {
    const sourceBuffer = await storageAdapter.download({
      bucket: normalizedEvent.bucket,
      objectPath: normalizedEvent.objectPath,
      generation: normalizedEvent.generation,
    });

    const processed = await processCloudImage({
      sourceBuffer,
      bucket: normalizedEvent.bucket,
      objectPath: normalizedEvent.objectPath,
      generation: normalizedEvent.generation,
      contentType: normalizedEvent.contentType,
      outputPaths: {
        normalizedPath: parsed.normalizedPath,
        thumbnailPath: parsed.thumbnailPath,
        manifestPath: parsed.manifestPath,
      },
    });

    await beforeGovernedWrites();

    const normalizedUpload = await storageAdapter.upload({
      bucket: normalizedEvent.bucket,
      objectPath: parsed.normalizedPath,
      contentType: "image/webp",
      buffer: processed.normalizedBuffer,
      metadata: {
        sourceGeneration: normalizedEvent.generation,
        catalogueRunId: processed.runId,
      },
    });

    const thumbnailUpload = await storageAdapter.upload({
      bucket: normalizedEvent.bucket,
      objectPath: parsed.thumbnailPath,
      contentType: "image/webp",
      buffer: processed.thumbnailBuffer,
      metadata: {
        sourceGeneration: normalizedEvent.generation,
        catalogueRunId: processed.runId,
      },
    });

    await storageAdapter.upload({
      bucket: normalizedEvent.bucket,
      objectPath: parsed.manifestPath,
      contentType: "application/json",
      buffer: processed.manifestBuffer,
      metadata: {
        sourceGeneration: normalizedEvent.generation,
        catalogueRunId: processed.runId,
      },
    });

    const completedAt = now();

    const viewPatch = buildSuccessfulViewPatch({
      manifest: processed.manifest,
      normalizedDownloadUrl: normalizedUpload.downloadUrl,
      thumbnailDownloadUrl: thumbnailUpload.downloadUrl,
      processedAt: completedAt,
    });

    await firestoreAdapter.updateView({
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
      patch: viewPatch,
    });

    const viewStatuses = await firestoreAdapter.listViewStatuses({
      designId: parsed.designId,
      versionId: parsed.versionId,
    });

    const versionPatch = buildVersionProcessingPatch({
      viewStatuses,
      processedAt: completedAt,
    });

    await firestoreAdapter.updateVersion({
      designId: parsed.designId,
      versionId: parsed.versionId,
      patch: versionPatch,
    });

    const design = await firestoreAdapter.getDesign({
      designId: parsed.designId,
    });

    if (design && design.activeVersionId === parsed.versionId) {
      await firestoreAdapter.updateDesign({
        designId: parsed.designId,
        patch: buildDesignProcessingPatch({
          versionStatus: versionPatch.processing.status,
          activeVersionId: parsed.versionId,
          processedAt: completedAt,
        }),
      });
    }

    logger.info?.("Catalogue View processing completed.", {
      runId: processed.runId,
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
    });

    return {
      ok: true,
      ignored: false,
      runId: processed.runId,
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
      manifestPath: parsed.manifestPath,
      status: viewPatch.processing.status,
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);

    if (errorMessage.startsWith("RUN_CLAIM_LOST")) {
      throw error;
    }

    const failedAt = now();

    await firestoreAdapter.updateView({
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
      patch: buildFailedViewPatch({
        error,
        processedAt: failedAt,
      }),
    });

    const statuses = await firestoreAdapter.listViewStatuses({
      designId: parsed.designId,
      versionId: parsed.versionId,
    });

    const versionPatch = buildVersionProcessingPatch({
      viewStatuses: statuses,
      processedAt: failedAt,
    });

    await firestoreAdapter.updateVersion({
      designId: parsed.designId,
      versionId: parsed.versionId,
      patch: versionPatch,
    });

    const design = await firestoreAdapter.getDesign({
      designId: parsed.designId,
    });

    if (design && design.activeVersionId === parsed.versionId) {
      await firestoreAdapter.updateDesign({
        designId: parsed.designId,
        patch: buildDesignProcessingPatch({
          versionStatus: versionPatch.processing.status,
          activeVersionId: parsed.versionId,
          processedAt: failedAt,
        }),
      });
    }

    logger.error?.("Catalogue View processing failed.", {
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
      error: errorMessage,
    });

    throw error;
  }
}

async function runCatalogueWorker({
  event,
  storageAdapter,
  firestoreAdapter,
  processingRunStore = null,
  logger = console,
  now = () => new Date(),
}) {
  if (!processingRunStore) {
    return runCatalogueWorkerCore({
      event,
      storageAdapter,
      firestoreAdapter,
      logger,
      now,
    });
  }

  for (const methodName of ["claim", "renew", "complete", "fail"]) {
    requireAdapterMethod(processingRunStore, methodName);
  }

  const normalizedEvent = normalizeStorageEvent(event);

  if (normalizedEvent.bucket !== EXPECTED_BUCKET) {
    return runCatalogueWorkerCore({
      event,
      storageAdapter,
      firestoreAdapter,
      logger,
      now,
    });
  }

  const parsed = parseCatalogueOriginalPath(normalizedEvent.objectPath);

  if (!parsed) {
    return runCatalogueWorkerCore({
      event,
      storageAdapter,
      firestoreAdapter,
      logger,
      now,
    });
  }

  if (!normalizedEvent.generation) {
    throw new Error(
      "WORKER_GENERATION_MISSING: Storage generation is required.",
    );
  }

  const identity = buildEventIdentity({
    bucket: normalizedEvent.bucket,
    objectPath: normalizedEvent.objectPath,
    generation: normalizedEvent.generation,
  });

  const claim = await processingRunStore.claim(identity);

  if (!claim.acquired) {
    logger.info?.("Catalogue worker ignored duplicate event.", {
      eventRunId: identity.runId,
      reason: claim.reason,
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
    });

    return {
      ok: true,
      ignored: true,
      reason: claim.reason,
      eventRunId: identity.runId,
      designId: parsed.designId,
      versionId: parsed.versionId,
      viewId: parsed.viewId,
    };
  }

  try {
    const result = await runCatalogueWorkerCore({
      event,
      storageAdapter,
      firestoreAdapter,
      logger,
      now,
      afterViewRegistered: async () => {
        await processingRunStore.renew({
          identity,
          claimToken: claim.claimToken,
          renewedAt: now(),
        });
      },
      beforeGovernedWrites: async () => {
        await processingRunStore.renew({
          identity,
          claimToken: claim.claimToken,
          renewedAt: now(),
        });
      },
    });

    await processingRunStore.complete({
      identity,
      claimToken: claim.claimToken,
      processorRunId: result.runId,
      manifestPath: result.manifestPath || parsed.manifestPath,
      completedAt: now(),
    });

    return {
      ...result,
      eventRunId: identity.runId,
      claimReason: claim.reason,
      attemptCount: claim.attemptCount,
    };
  } catch (error) {
    try {
      await processingRunStore.fail({
        identity,
        claimToken: claim.claimToken,
        error,
        failedAt: now(),
      });
    } catch (claimError) {
      const claimMessage =
        claimError instanceof Error ? claimError.message : String(claimError);

      if (claimMessage.startsWith("RUN_CLAIM_LOST")) {
        logger.error?.("Catalogue worker lost processing ownership.", {
          eventRunId: identity.runId,
          designId: parsed.designId,
          versionId: parsed.versionId,
          viewId: parsed.viewId,
        });

        throw claimError;
      }

      logger.error?.("Catalogue worker could not record run failure.", {
        eventRunId: identity.runId,
        error: claimMessage,
      });
    }

    throw error;
  }
}

module.exports = {
  EXPECTED_BUCKET,
  normalizeStorageEvent,
  waitForRegisteredView,
  runCatalogueWorkerCore,
  runCatalogueWorker,
};
