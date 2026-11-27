const crypto = require("node:crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleAuth } = require("google-auth-library");

const MAX_TRANSCRIPTION_AUDIO_BYTES = 7 * 1024 * 1024;
const speechAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

async function consumeTranscriptionQuota(uid) {
  const userKey = crypto.createHash("sha256").update(uid).digest("hex");
  const db = admin.firestore();
  const ref = db.collection("instruction_transcription_limits").doc(userKey);
  const currentTime = Date.now();
  const currentDay = new Date(currentTime).toISOString().slice(0, 10);
  const windowMs = 10 * 60 * 1000;
  const windowLimit = 5;
  const dailyLimit = 30;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.exists ? snapshot.data() : {};
    const previousWindowStart = Number(current.windowStartMs || 0);
    const windowCount =
      currentTime - previousWindowStart < windowMs
        ? Number(current.windowCount || 0)
        : 0;
    const dailyCount =
      current.dayKey === currentDay ? Number(current.dailyCount || 0) : 0;
    if (windowCount >= windowLimit || dailyCount >= dailyLimit) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many voice-note transcriptions. Please try again later.",
      );
    }

    transaction.set(ref, {
      windowStartMs: windowCount === 0 ? currentTime : previousWindowStart,
      windowCount: windowCount + 1,
      dayKey: currentDay,
      dailyCount: dailyCount + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(
        currentTime + 24 * 60 * 60 * 1000,
      ),
    });
  });
}

function isTranscriptionFilePath(storagePath, uid) {
  const parts = storagePath.split("/");
  if (
    parts.length !== 5 ||
    parts[0] !== "order_instruction_media" ||
    parts[1] !== uid ||
    parts[2] !== "drafts" ||
    !/^audio_[0-9]+\.m4a$/.test(parts[4])
  ) {
    return false;
  }
  return /^transcription_[0-9]+$/.test(parts[3]) || parts[3].length > 0;
}

async function assertDraftOwnership(scopeId, uid) {
  if (/^transcription_[0-9]+$/.test(scopeId)) return;
  const draft = await admin.firestore().collection("order_drafts").doc(scopeId).get();
  if (!draft.exists || draft.data().customerUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "This voice note is not available for transcription.",
    );
  }
}

exports.transcribeOrderInstructionAudioV2 = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: true,
    invoker: "private",
    // This project disables Cloud Run's invoker IAM check manually because
    // domain-restricted sharing blocks public IAM bindings. Preserve that
    // service-level setting on later deployments.
    preserveExternalChanges: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      functions.logger.warn("order_instruction_transcription_auth_missing", {
        appCheckVerified: Boolean(request.app),
      });
      throw new HttpsError(
        "unauthenticated",
        "Sign in to transcribe a voice note.",
      );
    }

    const storagePath =
      typeof request.data?.storagePath === "string"
        ? request.data.storagePath.trim()
        : "";
    if (!isTranscriptionFilePath(storagePath, uid)) {
      throw new HttpsError(
        "invalid-argument",
        "Choose a customer voice note to transcribe.",
      );
    }

    const pathParts = storagePath.split("/");
    await assertDraftOwnership(pathParts[3], uid);
    await consumeTranscriptionQuota(uid);

    const file = admin.storage().bucket().file(storagePath);
    const isTemporaryUpload = /^transcription_[0-9]+$/.test(pathParts[3]);
    try {
      const [metadata] = await file.getMetadata();
      const fileSize = Number(metadata.size || 0);
      if (
        metadata.metadata?.customerUid !== uid ||
        metadata.contentType !== "audio/mp4" ||
        fileSize <= 0 ||
        fileSize > MAX_TRANSCRIPTION_AUDIO_BYTES
      ) {
        throw new HttpsError(
          "invalid-argument",
          "This voice note is too large or is not a supported recording.",
        );
      }

      const [audio] = await file.download();
      const projectId = process.env.GCLOUD_PROJECT;
      if (!projectId) throw new Error("Cloud project is unavailable.");
      const client = await speechAuth.getClient();
      const response = await client.request({
        url: `https://speech.googleapis.com/v2/projects/${projectId}/locations/global/recognizers/_:recognize`,
        method: "POST",
        timeout: 90000,
        data: {
          config: {
            explicitDecodingConfig: {
              encoding: "M4A_AAC",
              sampleRateHertz: 16000,
              audioChannelCount: 1,
            },
            languageCodes: ["en-IN", "hi-IN", "mr-IN"],
            model: "short",
          },
          content: audio.toString("base64"),
        },
      });
      const transcript = (response.data?.results || [])
        .map((result) => result.alternatives?.[0]?.transcript || "")
        .filter(Boolean)
        .join(" ")
        .trim()
        .slice(0, 4000);
      return { transcript };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      const providerError = error?.response?.data?.error;
      const providerMessage =
        typeof providerError?.message === "string"
          ? providerError.message
          : typeof error?.message === "string"
            ? error.message
            : "Unknown transcription error";
      functions.logger.warn("order_instruction_transcription_failed", {
        status: error?.response?.status,
        code: error?.code,
        providerStatus: providerError?.status,
        providerMessage: providerMessage.slice(0, 500),
      });
      throw new HttpsError(
        "unavailable",
        "Could not transcribe the voice note. Please try again or type your instructions.",
      );
    } finally {
      // Local recordings are uploaded only for this request. Remove them even
      // if the app closes before its own best-effort cleanup can run. Saved
      // draft recordings remain available for the customer and tailor.
      if (isTemporaryUpload) {
        await file.delete({ ignoreNotFound: true }).catch(() => {});
      }
    }
  },
);
