"use strict";

const crypto = require("node:crypto");
const { GoogleAuth } = require("google-auth-library");
const sharp = require("sharp");

const IMAGE_MODEL = process.env.SUISAKHI_IMAGE_MODEL || "gemini-2.5-flash-image";
const IMAGE_LOCATION = process.env.SUISAKHI_IMAGE_LOCATION || "global";
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const CANDIDATE_COUNT = 3;

function imageApiUrl(projectId) {
  return `https://aiplatform.googleapis.com/v1/projects/${projectId}` +
    `/locations/${IMAGE_LOCATION}/publishers/google/models/${IMAGE_MODEL}:generateContent`;
}

async function generateImage({ projectId, prompt, inputs }) {
  const imageParts = await Promise.all(inputs.map(async (input) => {
    let image = sharp(input.buffer)
      .rotate()
      .flatten({ background: "#ffffff" })
      .resize({
        width: input.maxWidth || (input.preserveLineArt ? 2200 : 1600),
        height: input.maxHeight || (input.preserveLineArt ? 2200 : 2000),
        fit: "inside",
        withoutEnlargement: true,
      });
    const optimized = input.preserveLineArt
      ? await image.png({ compressionLevel: 9 }).toBuffer()
      : await image.jpeg({ quality: input.quality || 88, mozjpeg: true }).toBuffer();
    return {
      label: input.label || null,
      inlineData: {
        mimeType: input.preserveLineArt ? "image/png" : "image/jpeg",
        data: optimized.toString("base64"),
      },
    };
  }));
  const requestParts = [];
  for (const imagePart of imageParts) {
    if (imagePart.label) requestParts.push({ text: imagePart.label });
    requestParts.push({ inlineData: imagePart.inlineData });
  }
  requestParts.push({ text: prompt });
  const contents = [{
    role: "user",
    parts: requestParts,
  }];
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const response = await client.request({
    url: imageApiUrl(projectId),
    method: "POST",
    timeout: 180000,
    data: {
      contents,
      generationConfig: {
        responseModalities: ["TEXT", "IMAGE"],
      },
    },
  });
  const candidates = response.data && response.data.candidates;
  const parts = candidates && candidates[0] &&
    candidates[0].content && candidates[0].content.parts;
  const imagePart = Array.isArray(parts)
    ? parts.find((part) => part.inlineData && part.inlineData.data)
    : null;
  if (!imagePart) {
    throw new Error("AI_IMAGE_MISSING: The image model returned no image.");
  }
  return {
    buffer: Buffer.from(imagePart.inlineData.data, "base64"),
    text: parts.find((part) => part.text && part.text.trim())?.text || null,
  };
}

function reconstructionPrompt({ design, sourceType, targetType, candidateIndex }) {
  const target = targetType === "back" ? "BACK" : "FRONT";
  const source = sourceType === "back" ? "back" : "front";
  const variation = [
    "Use the most conservative, conventional construction that can be inferred.",
    "Use a balanced construction, preserving the source garment's silhouette and details.",
    "Offer a plausible alternative only for details hidden from the supplied view; keep all visible design details unchanged.",
  ][candidateIndex];
  return [
    `Create one monochrome technical flat of the missing ${target} view of this women's garment.`,
    `The supplied reference is its ${source} view. Garment type: ${design.garmentType || "women's garment"}.`,
    `Design title: ${design.title || "Untitled design"}.`,
    "Keep the same silhouette, garment length, sleeves, visible seams, trim, and proportions as the reference.",
    "Infer only construction details that cannot be seen from this view; do not add decorative features, labels, a person, mannequin, or a fabric pattern.",
    "Show a single centered, clean fashion technical drawing on a plain white background, black line art, matching scale and style of a production sketch.",
    variation,
    "This is a review candidate, not a verified sewing specification. Do not add text or multiple panels.",
  ].join(" ");
}

function fabricPreviewPrompt(viewType, design = {}) {
  const isCombined = viewType === "combinedFrontBack";
  const isSingleView = viewType === "singleView";
  const view = isCombined
    ? "combined front and back"
    : ({
      front: "front",
      back: "back",
      side: "side",
      detail: "detail",
    }[viewType] || "front");
  const metadata = design.constructionMetadata || {};
  const typeLabels = {
    blouse: "blouse",
    sareeBlouse: "saree blouse",
    kurti: "kurti",
    kurtaSet: "kurta set",
    salwarSuit: "salwar suit",
    anarkali: "Anarkali suit",
    lehengaCholi: "lehenga choli",
    gown: "gown",
    coat: "coat",
    topTunic: "top or tunic",
    shirt: "shirt",
    palazzoPant: "palazzo or trousers",
    skirt: "skirt",
    dress: "dress",
    other: "women's garment",
  };
  const typeCodes = Array.isArray(design.garmentTypeCodes)
    ? design.garmentTypeCodes
    : [];
  const garmentTypes = typeCodes
    .map((code) => typeLabels[String(code)] || String(code))
    .filter(Boolean);
  const garmentType = garmentTypes[0] || metadata.dressType || "women's garment";
  const title = String(design.title || "Untitled design").slice(0, 100);
  const constructionDetails = [
    metadata.silhouette && `silhouette: ${metadata.silhouette}`,
    metadata.neckType && `neckline: ${metadata.neckType}`,
    metadata.sleeveType && `sleeves: ${metadata.sleeveType}`,
    metadata.lengthType && `length: ${metadata.lengthType}`,
    metadata.complexity && `detail level: ${metadata.complexity}`,
  ].filter(Boolean);
  const isDetailedDesign = metadata.complexity === "high" ||
    /blouse|embroider|lace|ornate|intricate/i.test(`${garmentType} ${title}`);
  const targetViews = isCombined
    ? "combined front and back views"
    : isSingleView
    ? "single approved garment view"
    : `${view} view`;
  return [
    `Create one fabric visualization of the ${targetViews} of this exact women's ${garmentType}. Design title: ${title}.`,
    constructionDetails.length
      ? `Known construction details: ${constructionDetails.join(", ")}.`
      : "Use the supplied drawing as the authority for all construction details.",
    "Image 1 is the approved monochrome technical drawing and is the immutable garment template. Image 2 is only a fabric swatch; use it only to sample color, print, weave, and texture.",
    ...(isCombined
      ? [
        "Image 1 is a single combined sheet with the FRONT garment panel on the left and the BACK garment panel on the right. Return both panels together in the same left/right arrangement.",
        "Keep each panel's original position, orientation, crop, scale, silhouette, spacing, and visible construction details. Apply the fabric separately within the garment boundaries of both panels. Do not crop to one view, merge the garments, duplicate a panel, or omit either view.",
      ]
      : []),
    "Do not substitute another garment, reinterpret the design, redraw its silhouette, or add views. Keep image 1's canvas, orientation, crop, garment scale, outline, proportions, neckline, armholes, sleeves, seams, darts, closures, hems, and panel boundaries in their exact positions.",
    isDetailedDesign
      ? "This design has dense or complex monochrome details. Preserve every visible contour, seam, embroidery/lace motif, cutwork mark, pleat, trim, and small line-art detail. Do not simplify, blur, cover, or replace the decorative linework; keep its dark strokes visible above the applied fabric."
      : "Keep all visible technical linework crisp and visible above the applied fabric.",
    "Apply the swatch only within the existing garment panels. Do not invent new panel shapes, ornaments, stitching, or garment parts. If a panel boundary or detail is unclear, leave that small area as the original monochrome line art instead of guessing.",
    "Return one clean flat drawing on the same plain white background, without a model, body, mannequin, text, labels, or background objects.",
    "This is a visual approximation, not a tailoring specification or color-match guarantee. The original approved monochrome drawing remains the tailor's construction reference.",
  ].join(" ");
}

function downloadUrl(bucketName, objectPath, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
}

async function saveImageAsset({ bucket, path, buffer }) {
  const token = crypto.randomUUID();
  await bucket.file(path).save(buffer, {
    resumable: false,
    metadata: {
      contentType: "image/png",
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  const metadata = await sharp(buffer).metadata();
  return {
    assetType: "original",
    storagePath: path,
    downloadUrl: downloadUrl(bucket.name, path, token),
    mimeType: "image/png",
    byteSize: buffer.length,
    width: metadata.width || null,
    height: metadata.height || null,
    sha256: crypto.createHash("sha256").update(buffer).digest("hex"),
    createdAt: new Date(),
  };
}

function adminUidSet(snapshot) {
  const values = snapshot.exists ? snapshot.get("adminUids") : [];
  return new Set(Array.isArray(values) ? values.map(String) : []);
}

function createCatalogueAiFunctions({ functions, admin }) {
  if (!functions || !admin) {
    throw new Error("CATALOGUE_AI_DEPENDENCIES_MISSING");
  }
  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const projectId = process.env.GCLOUD_PROJECT || admin.app().options.projectId;

  async function consumeFabricPreviewAllowance(uid) {
    const usageRef = db.collection("catalogue_ai_usage").doc(uid);
    const now = Date.now();
    const windowMs = 60 * 60 * 1000;
    const maxRequests = 10;
    let exhausted = false;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(usageRef);
      const previousStart = snapshot.get("fabricPreviewWindowStartedAt");
      const previousMillis = previousStart && typeof previousStart.toMillis === "function"
        ? previousStart.toMillis()
        : 0;
      const currentWindow = previousMillis > 0 && now - previousMillis < windowMs;
      const count = currentWindow ? Number(snapshot.get("fabricPreviewCount") || 0) : 0;
      if (count >= maxRequests) {
        exhausted = true;
        return;
      }
      transaction.set(usageRef, {
        fabricPreviewWindowStartedAt: currentWindow
          ? previousStart
          : admin.firestore.Timestamp.fromMillis(now),
        fabricPreviewCount: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    if (exhausted) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "You have reached the temporary preview limit. Please try again later.",
      );
    }
  }

  const reconstructMissingView = functions
    .runWith({ timeoutSeconds: 540, memory: "2GB" })
    .firestore.document("designs/{designId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data() || {};
      const design = change.after.data() || {};
      const versionId = String(design.activeVersionId || "").trim();
      const activeVersionChanged = versionId &&
        versionId !== String(before.activeVersionId || "");
      const previousRetry = before.catalogueViewReconstructionRetryRequestedAt;
      const requestedRetry = design.catalogueViewReconstructionRetryRequestedAt;
      const retryChanged = Boolean(requestedRetry) && (
        !previousRetry ||
        typeof requestedRetry.isEqual !== "function" ||
        !requestedRetry.isEqual(previousRetry)
      );
      if (!versionId || (!activeVersionChanged && !retryChanged)) {
        return null;
      }

      const designId = context.params.designId;
      const designRef = db.collection("designs").doc(designId);
      const versionRef = designRef.collection("versions").doc(versionId);
      const viewsSnapshot = await versionRef.collection("views").get();
      const views = viewsSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      const hasFront = views.some((view) => view.viewType === "front");
      const hasBack = views.some((view) => view.viewType === "back");
      const combined = views.some((view) => view.viewType === "combinedFrontBack");
      let sourceType = null;
      let targetType = null;
      if (!combined && hasFront && !hasBack) {
        sourceType = "front";
        targetType = "back";
      } else if (!combined && hasBack && !hasFront) {
        sourceType = "back";
        targetType = "front";
      }
      if (!targetType) return null;

      const sourceView = views.find((view) => view.viewType === sourceType);
      const runId = `${versionId}_${targetType}`;
      const runRef = versionRef.collection("view_reconstruction_runs").doc(runId);
      const shouldStart = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(runRef);
        const state = snapshot.exists ? snapshot.get("status") : null;
        if (["processing", "needsSelection", "selectedForReview", "adminSelected", "notRequired"].includes(state)) {
          return false;
        }
        transaction.set(runRef, {
          runId,
          designId,
          versionId,
          sourceViewId: sourceView.id,
          sourceViewType: sourceType,
          targetViewType: targetType,
          status: "processing",
          provider: "vertex-ai",
          model: IMAGE_MODEL,
          candidateCount: 0,
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
      });
      if (!shouldStart) return null;

      try {
        const storagePath = sourceView.originalAsset && sourceView.originalAsset.storagePath;
        const mimeType = sourceView.originalAsset && sourceView.originalAsset.mimeType;
        if (!storagePath || !mimeType) throw new Error("SOURCE_VIEW_ASSET_MISSING");
        const [sourceBuffer] = await bucket.file(storagePath).download();
        if (!sourceBuffer.length || sourceBuffer.length > MAX_IMAGE_BYTES) {
          throw new Error("SOURCE_VIEW_SIZE_UNSUPPORTED");
        }
        const candidateRefs = [];
        for (let index = 0; index < CANDIDATE_COUNT; index += 1) {
          const generated = await generateImage({
            projectId,
            prompt: reconstructionPrompt({
              design: {
                title: design.title,
                garmentType: Array.isArray(design.garmentTypeCodes)
                  ? design.garmentTypeCodes.join(", ")
                  : "women's garment",
              },
              sourceType,
              targetType,
              candidateIndex: index,
            }),
            inputs: [{ buffer: sourceBuffer, mimeType }],
          });
          const candidateRef = versionRef.collection("generated_view_candidates").doc();
          const outputPath = `catalogue_designs/${designId}/versions/${versionId}` +
            `/generated_candidates/${candidateRef.id}.png`;
          const asset = await saveImageAsset({ bucket, path: outputPath, buffer: generated.buffer });
          await candidateRef.set({
            candidateId: candidateRef.id,
            reconstructionRunId: runId,
            designId,
            versionId,
            sourceViewId: sourceView.id,
            sourceViewType: sourceType,
            viewType: targetType,
            candidateIndex: index + 1,
            label: `Candidate ${String.fromCharCode(65 + index)}`,
            status: "pendingSelection",
            asset,
            provider: "vertex-ai",
            model: IMAGE_MODEL,
            promptVersion: "women-garment-counterpart-v1",
            generatedNote: generated.text,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          candidateRefs.push(candidateRef.id);
        }
        await runRef.set({
          status: "needsSelection",
          candidateIds: candidateRefs,
          candidateCount: candidateRefs.length,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return null;
      } catch (error) {
        functions.logger.error("Missing catalogue view generation failed", {
          designId,
          versionId,
          targetType,
          message: error.message,
        });
        await runRef.set({
          status: "failed",
          failureMessage: String(error.message || "Image generation failed").slice(0, 500),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return null;
      }
    });

  const retryReconstruction = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const designId = String(data && data.designId || "").trim();
    const versionId = String(data && data.versionId || "").trim();
    if (!designId || !versionId) {
      throw new functions.https.HttpsError("invalid-argument", "Design and version are required.");
    }
    const designRef = db.collection("designs").doc(designId);
    const versionRef = designRef.collection("versions").doc(versionId);
    const [designSnapshot, versionSnapshot, viewsSnapshot, adminSnapshot] = await Promise.all([
      designRef.get(),
      versionRef.get(),
      versionRef.collection("views").get(),
      db.doc("config/admin").get(),
    ]);
    if (!designSnapshot.exists || !versionSnapshot.exists) {
      throw new functions.https.HttpsError("not-found", "Catalogue design version not found.");
    }
    const design = designSnapshot.data() || {};
    const adminUids = adminUidSet(adminSnapshot);
    if (!adminUids.has(context.auth.uid) && design.submittedByUid !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the design partner or an Admin can retry generation.");
    }
    if (String(design.activeVersionId || "") !== versionId) {
      throw new functions.https.HttpsError("failed-precondition", "Only the active design version can be retried.");
    }
    let views = viewsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    const requestedSourceType = String(data && data.sourceViewType || "").trim();
    let sourceViewToClassify = null;
    if (requestedSourceType) {
      if (!adminUids.has(context.auth.uid)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only an Admin can classify a Single View source image.",
        );
      }
      if (!["front", "back"].includes(requestedSourceType)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Source view type must be front or back.",
        );
      }
      const singleViews = viewsSnapshot.docs.filter(
        (doc) => (doc.get("viewType") || "") === "singleView",
      );
      const hasClassifiedFrontOrBack = views.some(
        (view) => view.viewType === "front" || view.viewType === "back",
      );
      if (singleViews.length !== 1 || views.length !== 1 || hasClassifiedFrontOrBack) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Admin classification is available only when this version has one Single View image.",
        );
      }
      sourceViewToClassify = singleViews[0];
      views = views.map((view) => ({
        ...view,
        viewType: requestedSourceType,
      }));
    }
    const hasFront = views.some((view) => view.viewType === "front");
    const hasBack = views.some((view) => view.viewType === "back");
    const combined = views.some((view) => view.viewType === "combinedFrontBack");
    const targetType = !combined && hasFront && !hasBack
      ? "back"
      : !combined && hasBack && !hasFront
      ? "front"
      : null;
    if (!targetType) {
      throw new functions.https.HttpsError("failed-precondition", "This version does not need a counterpart view.");
    }
    const runRef = versionRef.collection("view_reconstruction_runs")
      .doc(`${versionId}_${targetType}`);
    const runSnapshot = await runRef.get();
    if (runSnapshot.exists && runSnapshot.get("status") !== "failed") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "View generation is already active or candidates are already available.",
      );
    }
    if (sourceViewToClassify) {
      await sourceViewToClassify.ref.update({
        viewType: requestedSourceType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await designRef.update({
      catalogueViewReconstructionRetryRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
  });

  const selectCandidate = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const designId = String(data && data.designId || "").trim();
    const versionId = String(data && data.versionId || "").trim();
    const candidateId = String(data && data.candidateId || "").trim();
    if (!designId || !versionId || !candidateId) {
      throw new functions.https.HttpsError("invalid-argument", "Design, version, and candidate are required.");
    }
    const designRef = db.collection("designs").doc(designId);
    const versionRef = designRef.collection("versions").doc(versionId);
    const candidateRef = versionRef.collection("generated_view_candidates").doc(candidateId);
    const [designSnapshot, versionSnapshot, candidateSnapshot, adminSnapshot] = await Promise.all([
      designRef.get(),
      versionRef.get(),
      candidateRef.get(),
      db.doc("config/admin").get(),
    ]);
    if (!designSnapshot.exists || !versionSnapshot.exists || !candidateSnapshot.exists) {
      throw new functions.https.HttpsError("not-found", "Generated candidate not found.");
    }
    const design = designSnapshot.data() || {};
    const candidate = candidateSnapshot.data() || {};
    const adminUids = adminUidSet(adminSnapshot);
    const isAdmin = adminUids.has(context.auth.uid);
    if (!isAdmin && design.submittedByUid !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the design partner or an Admin can select this candidate.");
    }
    if (design.activeVersionId !== versionId || candidate.status !== "pendingSelection") {
      throw new functions.https.HttpsError("failed-precondition", "This candidate is no longer available for selection.");
    }
    if (!candidate.asset || !candidate.asset.storagePath || !candidate.asset.downloadUrl) {
      throw new functions.https.HttpsError("failed-precondition", "The candidate image is unavailable.");
    }

    const viewsRef = versionRef.collection("views");
    const viewId = `ai_${candidate.viewType}_${candidateId}`;
    const viewRef = viewsRef.doc(viewId);
    const chosenStatus = isAdmin ? "adminSelected" : "partnerSelected";
    await db.runTransaction(async (transaction) => {
      const [freshCandidate, freshVersion, freshDesign, currentViews, allCandidates] = await Promise.all([
        transaction.get(candidateRef),
        transaction.get(versionRef),
        transaction.get(designRef),
        transaction.get(viewsRef),
        transaction.get(versionRef.collection("generated_view_candidates")),
      ]);
      if (!freshCandidate.exists || freshCandidate.get("status") !== "pendingSelection") {
        throw new functions.https.HttpsError("failed-precondition", "This candidate was already selected.");
      }
      if (!freshVersion.exists || !freshDesign.exists || freshDesign.get("activeVersionId") !== versionId) {
        throw new functions.https.HttpsError("failed-precondition", "This design version is no longer active.");
      }
      if (currentViews.docs.some((doc) => doc.get("viewType") === candidate.viewType)) {
        throw new functions.https.HttpsError("already-exists", `A ${candidate.viewType} view has already been added.`);
      }
      const makePrimary = candidate.viewType === "front" ||
        !currentViews.docs.some((doc) => doc.get("isPrimary") === true);
      if (makePrimary) {
        for (const currentView of currentViews.docs) {
          if (currentView.get("isPrimary") === true) {
            transaction.update(currentView.ref, {
              isPrimary: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }
      transaction.create(viewRef, {
        viewId,
        designId,
        versionId,
        viewType: candidate.viewType,
        displayOrder: currentViews.size + 1,
        isPrimary: makePrimary,
        title: `${candidate.label || "AI candidate"} · ${candidate.viewType}`,
        originalAsset: candidate.asset,
        processing: {
          status: "manualReviewRequired",
          profileCode: "aiGeneratedFlatReviewV1",
          presentLayers: [],
          missingLayers: [],
          qualityWarnings: ["AI_GENERATED_VIEW_REQUIRES_TAILOR_REVIEW"],
          processingEngine: "vertex-ai",
          processingVersion: IMAGE_MODEL,
          failureCode: null,
          failureMessage: null,
        },
        generatedView: {
          candidateId,
          reconstructionRunId: candidate.reconstructionRunId,
          sourceViewId: candidate.sourceViewId,
          selectedByUid: context.auth.uid,
          selectedByRole: isAdmin ? "admin" : "partner",
          selectedAt: admin.firestore.FieldValue.serverTimestamp(),
          approvalStatus: isAdmin ? "adminSelected" : "awaitingAdminReview",
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(versionRef, {
        viewCount: currentViews.size + 1,
        ...(makePrimary ? { primaryViewId: viewId } : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(candidateRef, {
        status: chosenStatus,
        selectedByUid: context.auth.uid,
        selectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      for (const sibling of allCandidates.docs) {
        if (
          sibling.id !== candidateId &&
          sibling.get("status") === "pendingSelection" &&
          sibling.get("viewType") === candidate.viewType
        ) {
          transaction.update(sibling.ref, {
            status: "notSelected",
            resolvedByCandidateId: candidateId,
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      const runRef = versionRef.collection("view_reconstruction_runs").doc(candidate.reconstructionRunId);
      transaction.set(runRef, {
        status: isAdmin ? "adminSelected" : "selectedForReview",
        selectedCandidateId: candidateId,
        selectedByUid: context.auth.uid,
        selectedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return { ok: true, viewId, status: chosenStatus };
  });

  const generateFabricPreviews = functions
    .runWith({ timeoutSeconds: 300, memory: "1GB" })
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
      }
      const designId = String(data && data.designId || "").trim();
      const versionId = String(data && data.versionId || "").trim();
      const mimeType = String(data && data.fabricMimeType || "").trim().toLowerCase();
      const encoded = String(data && data.fabricImageBase64 || "").trim();
      if (!designId || !versionId || !encoded || !["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
        throw new functions.https.HttpsError("invalid-argument", "Select a valid fabric image and catalogue design.");
      }
      if (encoded.length > 7 * 1024 * 1024) {
        throw new functions.https.HttpsError("invalid-argument", "Fabric sample image must be smaller than 5 MB.");
      }
      const designSnapshot = await db.collection("designs").doc(designId).get();
      if (!designSnapshot.exists) throw new functions.https.HttpsError("not-found", "Catalogue design not found.");
      const design = designSnapshot.data() || {};
      if (
        design.lifecycleStatus !== "approved" ||
        design.publicationStatus !== "published" ||
        design.activeVersionId !== versionId
      ) {
        throw new functions.https.HttpsError("permission-denied", "Fabric previews require the current published design version.");
      }
      const versionRef = db.collection("designs").doc(designId).collection("versions").doc(versionId);
      const viewsSnapshot = await versionRef.collection("views").orderBy("displayOrder").get();
      const publishedViewDocs = viewsSnapshot.docs
        .filter((doc) => doc.get("excludedFromVersion") !== true);
      const approvedViews = publishedViewDocs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .filter((view) => ["front", "back", "side", "detail", "combinedFrontBack", "singleView"].includes(view.viewType));
      if (!publishedViewDocs.length) {
        const versionSnapshot = await versionRef.get();
        const legacyAsset = versionSnapshot.get("originalAsset");
        if (legacyAsset && typeof legacyAsset.storagePath === "string" && legacyAsset.storagePath.trim()) {
          approvedViews.push({
            id: "legacy-single-view",
            viewType: "singleView",
            originalAsset: legacyAsset,
            displayOrder: 1,
          });
        }
      }
      const previewableViews = approvedViews.filter((view) =>
        typeof (view.originalAsset && view.originalAsset.storagePath) === "string" &&
        view.originalAsset.storagePath.trim()
      );
      if (!previewableViews.length) {
        if (approvedViews.length) {
          throw new functions.https.HttpsError("failed-precondition", "The approved design view is missing its original image. Ask an Admin to review the catalogue entry.");
        }
        throw new functions.https.HttpsError("failed-precondition", "This design has no approved Front, Back, Side, Detail, Combined Front + Back, or Single View image yet.");
      }
      const frontViews = previewableViews.filter((view) => view.viewType === "front");
      const backViews = previewableViews.filter((view) => view.viewType === "back");
      const combinedViews = previewableViews.filter((view) => view.viewType === "combinedFrontBack");
      const singleViews = previewableViews.filter((view) => view.viewType === "singleView");
      const supplementaryViews = previewableViews.filter((view) =>
        view.viewType === "side" || view.viewType === "detail"
      );
      // Prefer a complete separate pair. If only one separate side is published,
      // use the combined sheet when available so the customer still sees both.
      const primaryViews = frontViews.length && backViews.length
        ? [...frontViews, ...backViews]
        : combinedViews.length
        ? combinedViews
        : frontViews.length || backViews.length
        ? [...frontViews, ...backViews]
        : singleViews;
      const views = [...primaryViews, ...supplementaryViews];
      if (!primaryViews.length) throw new functions.https.HttpsError("failed-precondition", "This design has no approved Front, Back, Combined Front + Back, or Single View image yet.");
      const fabricBuffer = Buffer.from(encoded, "base64");
      if (!fabricBuffer.length || fabricBuffer.length > 5 * 1024 * 1024) {
        throw new functions.https.HttpsError("invalid-argument", "Fabric sample image must be smaller than 5 MB.");
      }
      await consumeFabricPreviewAllowance(context.auth.uid);
      const previews = [];
      for (const view of views) {
        const path = view.originalAsset && view.originalAsset.storagePath;
        const [designBuffer] = await bucket.file(path).download();
        const generated = await generateImage({
          projectId,
          prompt: fabricPreviewPrompt(view.viewType, design),
          inputs: [
            {
              buffer: designBuffer,
              mimeType: view.originalAsset.mimeType || "image/png",
              label: "IMAGE 1 — approved monochrome tailoring reference; preserve this drawing exactly.",
              preserveLineArt: true,
            },
            {
              buffer: fabricBuffer,
              mimeType,
              label: "IMAGE 2 — customer fabric sample; use only its material appearance.",
              maxWidth: 1200,
              maxHeight: 1200,
              quality: 90,
            },
          ],
        });
        const compressed = await sharp(generated.buffer)
          .resize({ width: 1100, height: 1400, fit: "inside", withoutEnlargement: true })
          .jpeg({ quality: 82, mozjpeg: true })
          .toBuffer();
        previews.push({ viewType: view.viewType, imageBase64: compressed.toString("base64"), mimeType: "image/jpeg" });
      }
      return {
        previews,
        disclaimer: "Visual approximation only. The approved design and tailor's confirmed construction remain the tailoring reference.",
      };
    });

  return {
    reconstructMissingCatalogueView: reconstructMissingView,
    retryCatalogueViewReconstruction: retryReconstruction,
    selectCatalogueViewCandidate: selectCandidate,
    generateCatalogueFabricPreviews: generateFabricPreviews,
  };
}

module.exports = {
  CANDIDATE_COUNT,
  IMAGE_MODEL,
  createCatalogueAiFunctions,
  fabricPreviewPrompt,
  generateImage,
  reconstructionPrompt,
};
