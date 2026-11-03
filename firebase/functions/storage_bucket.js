const admin = require("firebase-admin");

function getDefaultStorageBucket() {
  let runtimeConfig = {};
  try {
    runtimeConfig = JSON.parse(process.env.FIREBASE_CONFIG || "{}");
  } catch (_) {
    runtimeConfig = {};
  }

  const appOptions = admin.app().options || {};
  const projectId = appOptions.projectId || runtimeConfig.projectId ||
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  const bucketName = appOptions.storageBucket || runtimeConfig.storageBucket ||
    process.env.FIREBASE_STORAGE_BUCKET ||
    (projectId ? `${projectId}.firebasestorage.app` : "");
  if (!bucketName) {
    throw new Error("Firebase Storage bucket is not configured for this project.");
  }
  return admin.storage().bucket(bucketName);
}

module.exports = {getDefaultStorageBucket};
