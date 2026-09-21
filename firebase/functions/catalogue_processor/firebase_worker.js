"use strict";

const {
  createStorageAdapter,
  createFirestoreAdapter,
} = require("./firebase_adapter");

const { createProcessingRunStore } = require("./processing_run_store");

const { runCatalogueWorker } = require("./worker_orchestrator");

const TARGET_BUCKET = "suisakhitest.firebasestorage.app";

const TARGET_REGION = "us-east1";

function createCatalogueWorkerHandler({ admin, logger = console }) {
  if (
    !admin ||
    typeof admin.storage !== "function" ||
    typeof admin.firestore !== "function"
  ) {
    throw new Error("WORKER_ADMIN_INVALID: Firebase Admin is required.");
  }

  const bucket = admin.storage().bucket(TARGET_BUCKET);

  const db = admin.firestore();

  const storageAdapter = createStorageAdapter({
    bucket,
    bucketName: TARGET_BUCKET,
  });

  const firestoreAdapter = createFirestoreAdapter({
    db,
  });

  const processingRunStore = createProcessingRunStore({
    db,
  });

  return async function catalogueStorageHandler(object) {
    return runCatalogueWorker({
      event: {
        bucket: object?.bucket,
        name: object?.name,
        generation: object?.generation,
        contentType: object?.contentType,
      },
      storageAdapter,
      firestoreAdapter,
      processingRunStore,
      logger,
    });
  };
}

module.exports = {
  TARGET_BUCKET,
  TARGET_REGION,
  createCatalogueWorkerHandler,
};
