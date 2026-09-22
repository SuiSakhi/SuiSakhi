"use strict";

const {
  TARGET_BUCKET,
  TARGET_REGION,
  createCatalogueWorkerHandler,
} = require("./firebase_worker");

function createCatalogueStorageTrigger({ functions, admin }) {
  if (!functions || typeof functions.region !== "function") {
    throw new Error(
      "TRIGGER_FUNCTIONS_INVALID: Firebase Functions is required.",
    );
  }

  if (!admin) {
    throw new Error("TRIGGER_ADMIN_INVALID: Firebase Admin is required.");
  }

  const handler = createCatalogueWorkerHandler({
    admin,
    logger: functions.logger || console,
  });

  return functions
    .region(TARGET_REGION)
    .storage.bucket(TARGET_BUCKET)
    .object()
    .onFinalize(handler);
}

module.exports = {
  createCatalogueStorageTrigger,
};
