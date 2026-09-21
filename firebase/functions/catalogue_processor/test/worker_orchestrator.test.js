"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const sharp = require("sharp");

const { runCatalogueWorker } = require("../worker_orchestrator");

const ORIGINAL_PATH =
  "catalogue_designs/design-123/" +
  "versions/version-456/" +
  "views/view-789/" +
  "original/source.jpg";

async function sourceJpeg() {
  return sharp({
    create: {
      width: 736,
      height: 980,
      channels: 3,
      background: {
        r: 230,
        g: 220,
        b: 245,
      },
    },
  })
    .jpeg()
    .toBuffer();
}

function createTestAdapters({
  sourceBuffer,
  viewExists = true,
  originalStoragePath = ORIGINAL_PATH,
  viewStatuses = ["manualReviewRequired"],
  activeVersionId = "version-456",
  downloadError = null,
} = {}) {
  const calls = {
    downloads: [],
    uploads: [],
    viewUpdates: [],
    versionUpdates: [],
    designUpdates: [],
  };

  const storageAdapter = {
    async download(args) {
      calls.downloads.push(args);

      if (downloadError) {
        throw downloadError;
      }

      return sourceBuffer;
    },

    async upload(args) {
      calls.uploads.push(args);

      return {
        downloadUrl: `https://example.invalid/${encodeURIComponent(
          args.objectPath,
        )}`,
      };
    },
  };

  const firestoreAdapter = {
    async getView() {
      if (!viewExists) {
        return null;
      }

      return {
        originalAsset: {
          storagePath: originalStoragePath,
        },
      };
    },

    async updateView(args) {
      calls.viewUpdates.push(args);
    },

    async listViewStatuses() {
      return viewStatuses;
    },

    async updateVersion(args) {
      calls.versionUpdates.push(args);
    },

    async getDesign() {
      return {
        activeVersionId,
      };
    },

    async updateDesign(args) {
      calls.designUpdates.push(args);
    },
  };

  return {
    calls,
    storageAdapter,
    firestoreAdapter,
  };
}

test("ignores an event from another bucket", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const result = await runCatalogueWorker({
    event: {
      bucket: "another-bucket",
      name: ORIGINAL_PATH,
      generation: "4001",
      contentType: "image/jpeg",
    },
    ...adapters,
    logger: {
      info() {},
      error() {},
    },
  });

  assert.equal(result.ignored, true);
  assert.equal(result.reason, "BUCKET_NOT_TARGETED");

  assert.equal(adapters.calls.downloads.length, 0);
});

test("ignores derivative paths", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const result = await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name:
        "catalogue_designs/design-123/" +
        "versions/version-456/" +
        "views/view-789/" +
        "normalized/preview.webp",
      generation: "4002",
      contentType: "image/webp",
    },
    ...adapters,
    logger: {
      info() {},
      error() {},
    },
  });

  assert.equal(result.ignored, true);
  assert.equal(result.reason, "PATH_NOT_TARGETED");

  assert.equal(adapters.calls.downloads.length, 0);
});

test("processes an original and writes three derivatives", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const result = await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name: ORIGINAL_PATH,
      generation: "4003",
      contentType: "image/jpeg",
    },
    ...adapters,
    logger: {
      info() {},
      error() {},
    },
    now: () => new Date("2026-09-21T16:00:00.000Z"),
  });

  assert.equal(result.ok, true);
  assert.equal(result.ignored, false);
  assert.equal(result.status, "manualReviewRequired");

  assert.equal(adapters.calls.downloads.length, 1);

  assert.equal(adapters.calls.uploads.length, 3);

  assert.deepEqual(
    adapters.calls.uploads.map((call) => call.contentType),
    ["image/webp", "image/webp", "application/json"],
  );

  assert.equal(adapters.calls.viewUpdates.length, 2);

  assert.equal(
    adapters.calls.viewUpdates[0].patch.processing.status,
    "processing",
  );

  assert.equal(
    adapters.calls.viewUpdates[1].patch.processing.status,
    "manualReviewRequired",
  );

  assert.equal(adapters.calls.versionUpdates.length, 1);

  assert.equal(adapters.calls.designUpdates.length, 1);
});

test("does not update Design when Version is no longer active", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
    activeVersionId: "newer-version-999",
  });

  await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name: ORIGINAL_PATH,
      generation: "4004",
      contentType: "image/jpeg",
    },
    ...adapters,
    logger: {
      info() {},
      error() {},
    },
  });

  assert.equal(adapters.calls.versionUpdates.length, 1);

  assert.equal(adapters.calls.designUpdates.length, 0);
});

test("rejects a missing Firestore View", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
    viewExists: false,
  });

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4005",
        contentType: "image/jpeg",
      },
      ...adapters,
      logger: {
        info() {},
        error() {},
      },
    }),
    /WORKER_VIEW_NOT_FOUND/,
  );

  assert.equal(adapters.calls.downloads.length, 0);
});

test("rejects a mismatched registered original path", async () => {
  const sourceBuffer = await sourceJpeg();
  const adapters = createTestAdapters({
    sourceBuffer,
    originalStoragePath:
      "catalogue_designs/design-123/" +
      "versions/version-456/" +
      "views/view-789/" +
      "original/source.png",
  });

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4006",
        contentType: "image/jpeg",
      },
      ...adapters,
      logger: {
        info() {},
        error() {},
      },
    }),
    /WORKER_SOURCE_PATH_MISMATCH/,
  );

  assert.equal(adapters.calls.downloads.length, 0);
});

test("records governed failure state after processing failure", async () => {
  const sourceBuffer = await sourceJpeg();

  const adapters = createTestAdapters({
    sourceBuffer,
    downloadError: new Error("STORAGE_DOWNLOAD_FAILED: Test failure."),
    viewStatuses: ["failed"],
  });

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4007",
        contentType: "image/jpeg",
      },
      ...adapters,
      logger: {
        info() {},
        error() {},
      },
      now: () => new Date("2026-09-21T16:10:00.000Z"),
    }),
    /STORAGE_DOWNLOAD_FAILED/,
  );

  assert.equal(adapters.calls.viewUpdates.length, 2);

  assert.equal(adapters.calls.viewUpdates[1].patch.processing.status, "failed");

  assert.equal(
    adapters.calls.viewUpdates[1].patch.processing.failureCode,
    "STORAGE_DOWNLOAD_FAILED",
  );

  assert.equal(
    adapters.calls.versionUpdates[0].patch.processing.status,
    "failed",
  );

  assert.equal(
    adapters.calls.designUpdates[0].patch.processingStatus,
    "failed",
  );
});

test("retries until the Firestore View becomes available", async () => {
  let reads = 0;

  const firestoreAdapter = {
    async getView() {
      reads += 1;

      if (reads < 3) {
        return null;
      }

      return {
        originalAsset: {
          storagePath: ORIGINAL_PATH,
        },
      };
    },

    async updateView() {},
    async listViewStatuses() {
      return ["failed"];
    },
    async updateVersion() {},
    async getDesign() {
      return {
        activeVersionId: "version-456",
      };
    },
    async updateDesign() {},
  };

  const storageAdapter = {
    async download() {
      throw new Error("STORAGE_DOWNLOAD_FAILED: Expected test stop.");
    },

    async upload() {
      throw new Error("Upload should not be reached.");
    },
  };

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4010",
        contentType: "image/jpeg",
      },
      storageAdapter,
      firestoreAdapter,
      logger: {
        info() {},
        error() {},
      },
    }),
    /STORAGE_DOWNLOAD_FAILED/,
  );

  assert.equal(reads, 3);
});

test("stops after bounded retries when View remains unavailable", async () => {
  let reads = 0;

  const firestoreAdapter = {
    async getView() {
      reads += 1;
      return null;
    },

    async updateView() {
      throw new Error("View update should not be reached.");
    },

    async listViewStatuses() {
      return [];
    },

    async updateVersion() {},
    async getDesign() {
      return null;
    },
    async updateDesign() {},
  };

  const storageAdapter = {
    async download() {
      throw new Error("Download should not be reached.");
    },

    async upload() {
      throw new Error("Upload should not be reached.");
    },
  };

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4011",
        contentType: "image/jpeg",
      },
      storageAdapter,
      firestoreAdapter,
      logger: {
        info() {},
        error() {},
      },
    }),
    /WORKER_VIEW_NOT_FOUND/,
  );

  assert.equal(reads, 8);
});

function createProcessingRunStoreDouble({
  claimResult = {
    acquired: true,
    reason: "NEW_RUN",
    attemptCount: 1,
    claimToken: "claim-token-1",
  },
  renewErrorAtCall = null,
  completeError = null,
  failError = null,
} = {}) {
  const calls = {
    claims: [],
    renewals: [],
    completions: [],
    failures: [],
  };

  const processingRunStore = {
    async claim(identity) {
      calls.claims.push(identity);
      return claimResult;
    },

    async renew(args) {
      calls.renewals.push(args);

      if (
        renewErrorAtCall !== null &&
        calls.renewals.length === renewErrorAtCall
      ) {
        throw new Error(
          "RUN_CLAIM_LOST: Processing claim is owned by another invocation.",
        );
      }

      return {
        renewed: true,
        runId: args.identity.runId,
        claimToken: args.claimToken,
      };
    },

    async complete(args) {
      calls.completions.push(args);

      if (completeError) {
        throw completeError;
      }

      return {
        completed: true,
        runId: args.identity.runId,
      };
    },

    async fail(args) {
      calls.failures.push(args);

      if (failError) {
        throw failError;
      }

      return {
        failed: true,
        runId: args.identity.runId,
      };
    },
  };

  return {
    calls,
    processingRunStore,
  };
}

test("ignores a duplicate event whose run is already completed", async () => {
  const sourceBuffer = await sourceJpeg();

  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const runStore = createProcessingRunStoreDouble({
    claimResult: {
      acquired: false,
      reason: "ALREADY_COMPLETED",
      attemptCount: 1,
      claimToken: null,
    },
  });

  const result = await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name: ORIGINAL_PATH,
      generation: "4101",
      contentType: "image/jpeg",
    },
    ...adapters,
    processingRunStore: runStore.processingRunStore,
    logger: {
      info() {},
      error() {},
    },
  });

  assert.equal(result.ignored, true);

  assert.equal(result.reason, "ALREADY_COMPLETED");

  assert.match(result.eventRunId, /^[a-f0-9]{64}$/);

  assert.equal(runStore.calls.claims.length, 1);

  assert.equal(runStore.calls.renewals.length, 0);

  assert.equal(runStore.calls.completions.length, 0);

  assert.equal(adapters.calls.downloads.length, 0);

  assert.equal(adapters.calls.viewUpdates.length, 0);
});

test("ignores a duplicate event whose run has an active lease", async () => {
  const sourceBuffer = await sourceJpeg();

  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const runStore = createProcessingRunStoreDouble({
    claimResult: {
      acquired: false,
      reason: "ALREADY_PROCESSING",
      attemptCount: 1,
      claimToken: null,
    },
  });

  const result = await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name: ORIGINAL_PATH,
      generation: "4102",
      contentType: "image/jpeg",
    },
    ...adapters,
    processingRunStore: runStore.processingRunStore,
    logger: {
      info() {},
      error() {},
    },
  });

  assert.equal(result.ignored, true);

  assert.equal(result.reason, "ALREADY_PROCESSING");

  assert.equal(adapters.calls.downloads.length, 0);

  assert.equal(adapters.calls.uploads.length, 0);

  assert.equal(runStore.calls.completions.length, 0);
});

test("completes the owned processing claim after successful processing", async () => {
  const sourceBuffer = await sourceJpeg();

  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const runStore = createProcessingRunStoreDouble();

  const result = await runCatalogueWorker({
    event: {
      bucket: "suisakhitest.firebasestorage.app",
      name: ORIGINAL_PATH,
      generation: "4103",
      contentType: "image/jpeg",
    },
    ...adapters,
    processingRunStore: runStore.processingRunStore,
    logger: {
      info() {},
      error() {},
    },
    now: () => new Date("2026-09-21T18:00:00.000Z"),
  });

  assert.equal(result.ok, true);

  assert.equal(result.ignored, false);

  assert.equal(result.claimReason, "NEW_RUN");

  assert.equal(result.attemptCount, 1);

  assert.match(result.eventRunId, /^[a-f0-9]{64}$/);

  assert.equal(runStore.calls.claims.length, 1);

  assert.equal(runStore.calls.renewals.length, 2);

  assert.equal(runStore.calls.completions.length, 1);

  assert.equal(runStore.calls.failures.length, 0);

  assert.equal(runStore.calls.completions[0].claimToken, "claim-token-1");

  assert.equal(runStore.calls.completions[0].processorRunId, result.runId);

  assert.match(
    runStore.calls.completions[0].manifestPath,
    /structured\/manifest\.json$/,
  );
});

test("marks the owned processing claim failed after image-processing failure", async () => {
  const sourceBuffer = await sourceJpeg();

  const processingError = new Error(
    "STORAGE_DOWNLOAD_FAILED: Controlled integration failure.",
  );

  const adapters = createTestAdapters({
    sourceBuffer,
    downloadError: processingError,
    viewStatuses: ["failed"],
  });

  const runStore = createProcessingRunStoreDouble();

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4104",
        contentType: "image/jpeg",
      },
      ...adapters,
      processingRunStore: runStore.processingRunStore,
      logger: {
        info() {},
        error() {},
      },
      now: () => new Date("2026-09-21T18:05:00.000Z"),
    }),
    /STORAGE_DOWNLOAD_FAILED/,
  );

  assert.equal(runStore.calls.claims.length, 1);

  assert.equal(runStore.calls.renewals.length, 1);

  assert.equal(runStore.calls.completions.length, 0);

  assert.equal(runStore.calls.failures.length, 1);

  assert.equal(runStore.calls.failures[0].claimToken, "claim-token-1");

  assert.equal(runStore.calls.failures[0].error, processingError);

  assert.equal(
    adapters.calls.viewUpdates.at(-1).patch.processing.status,
    "failed",
  );
});

test("prevents stale governed writes after claim ownership is lost", async () => {
  const sourceBuffer = await sourceJpeg();

  const adapters = createTestAdapters({
    sourceBuffer,
  });

  const runStore = createProcessingRunStoreDouble({
    renewErrorAtCall: 2,
    failError: new Error(
      "RUN_CLAIM_LOST: Processing claim is owned by another invocation.",
    ),
  });

  await assert.rejects(
    runCatalogueWorker({
      event: {
        bucket: "suisakhitest.firebasestorage.app",
        name: ORIGINAL_PATH,
        generation: "4105",
        contentType: "image/jpeg",
      },
      ...adapters,
      processingRunStore: runStore.processingRunStore,
      logger: {
        info() {},
        error() {},
      },
      now: () => new Date("2026-09-21T18:10:00.000Z"),
    }),
    /RUN_CLAIM_LOST/,
  );

  assert.equal(runStore.calls.renewals.length, 2);

  assert.equal(runStore.calls.completions.length, 0);

  assert.equal(runStore.calls.failures.length, 1);

  assert.equal(adapters.calls.downloads.length, 1);

  assert.equal(adapters.calls.uploads.length, 0);

  assert.equal(adapters.calls.viewUpdates.length, 1);

  assert.equal(
    adapters.calls.viewUpdates[0].patch.processing.status,
    "processing",
  );

  assert.equal(adapters.calls.versionUpdates.length, 0);

  assert.equal(adapters.calls.designUpdates.length, 0);
});
