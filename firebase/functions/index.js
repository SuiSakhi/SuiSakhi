/**
 * WhatsApp Cloud API — sends an approved template to the signed-in user's phone.
 *
 * Setup:
 * 1. Meta Developer → WhatsApp → get permanent token, Phone number ID, verify template (e.g. hello_world).
 * 2. firebase functions:config:set whatsapp.token="EAAG..." whatsapp.phone_number_id="123456789"
 * 3. firebase deploy --only functions
 *
 * Optional override: whatsapp.template_default for template name (default hello_world).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const {
  createCatalogueStorageTrigger,
} = require("./catalogue_processor/catalogue_trigger");
const catalogueAi = require("./catalogue_ai");

const catalogueAiFunctions = catalogueAi.createCatalogueAiFunctions({
  functions,
  admin,
});
exports.reconstructMissingCatalogueView =
  catalogueAiFunctions.reconstructMissingCatalogueView;
exports.retryCatalogueViewReconstruction =
  catalogueAiFunctions.retryCatalogueViewReconstruction;
exports.selectCatalogueViewCandidate =
  catalogueAiFunctions.selectCatalogueViewCandidate;
exports.generateCatalogueFabricPreviews =
  catalogueAiFunctions.generateCatalogueFabricPreviews;

exports.processCatalogueViewOriginal = createCatalogueStorageTrigger({
  functions,
  admin,
});

const garmentCare = require("./garment_care");
exports.getAdminGarmentCarePricing = garmentCare.getAdminGarmentCarePricing;
exports.publishGarmentCarePricingVersion = garmentCare.publishGarmentCarePricingVersion;
exports.getGarmentCareInspectionTemplates = garmentCare.getGarmentCareInspectionTemplates;
exports.publishGarmentCareInspectionTemplates = garmentCare.publishGarmentCareInspectionTemplates;
exports.getGarmentCareCompletionTemplates = garmentCare.getGarmentCareCompletionTemplates;
exports.publishGarmentCareCompletionTemplates = garmentCare.publishGarmentCareCompletionTemplates;
exports.savePartnerGarmentCareCompletionTemplate = garmentCare.savePartnerGarmentCareCompletionTemplate;
exports.deletePartnerGarmentCareCompletionTemplate = garmentCare.deletePartnerGarmentCareCompletionTemplate;
exports.createGarmentCareOrder = garmentCare.createGarmentCareOrder;
exports.ensureGarmentCareSubOrderNumbers = garmentCare.ensureGarmentCareSubOrderNumbers;
exports.getCustomerGarmentCarePricing = garmentCare.getCustomerGarmentCarePricing;
exports.getGarmentCarePartnerCandidates = garmentCare.getGarmentCarePartnerCandidates;
exports.getGarmentCareDeliveryCandidates = garmentCare.getGarmentCareDeliveryCandidates;
exports.assignGarmentCareReturnPartner = garmentCare.assignGarmentCareReturnPartner;
exports.respondToGarmentCareDeliveryAssignment = garmentCare.respondToGarmentCareDeliveryAssignment;
exports.getGarmentCareDeliveryPaymentDetails = garmentCare.getGarmentCareDeliveryPaymentDetails;
exports.completeSandboxGarmentCarePayment = garmentCare.completeSandboxGarmentCarePayment;
exports.completeSandboxGarmentCarePaymentBatch = garmentCare.completeSandboxGarmentCarePaymentBatch;
exports.recordGarmentCarePaymentAtDelivery = garmentCare.recordGarmentCarePaymentAtDelivery;
exports.lookupGarmentCareOrderTag = garmentCare.lookupGarmentCareOrderTag;
exports.updateGarmentCarePartnerPreferences = garmentCare.updateGarmentCarePartnerPreferences;
exports.updateGarmentCareDeliveryPartnerAvailability = garmentCare.updateGarmentCareDeliveryPartnerAvailability;
exports.updateGarmentCarePartnerPriority = garmentCare.updateGarmentCarePartnerPriority;
exports.requestGarmentCareJobReassignment = garmentCare.requestGarmentCareJobReassignment;
exports.respondToGarmentCareItemRevision = garmentCare.respondToGarmentCareItemRevision;
exports.submitGarmentCareFeedback = garmentCare.submitGarmentCareFeedback;
exports.reportGarmentCareWarrantyIssue = garmentCare.reportGarmentCareWarrantyIssue;
exports.assignGarmentCarePickup = garmentCare.assignGarmentCarePickup;
exports.getGarmentCarePickupPartnerDetails = garmentCare.getGarmentCarePickupPartnerDetails;
exports.getGarmentCarePickupWorkDetails = garmentCare.getGarmentCarePickupWorkDetails;
exports.getGarmentCarePartnerServiceJobDetails = garmentCare.getGarmentCarePartnerServiceJobDetails;
exports.sendGarmentCarePartnerOrderNote = garmentCare.sendGarmentCarePartnerOrderNote;
exports.acceptGarmentCarePickup = garmentCare.acceptGarmentCarePickup;
exports.getGarmentCareServicePartnerDetails = garmentCare.getGarmentCareServicePartnerDetails;
exports.getGarmentCareInspectionContext = garmentCare.getGarmentCareInspectionContext;
exports.getGarmentCareOrderCustomerDetails = garmentCare.getGarmentCareOrderCustomerDetails;
exports.assignGarmentCareServiceJob = garmentCare.assignGarmentCareServiceJob;
exports.recordGarmentCareHandover = garmentCare.recordGarmentCareHandover;
exports.confirmGarmentCareCustomerDelivery = garmentCare.confirmGarmentCareCustomerDelivery;
exports.advanceGarmentCareServiceJob = garmentCare.advanceGarmentCareServiceJob;
exports.autoRouteGarmentCareOrders = garmentCare.autoRouteGarmentCareOrders;
exports.submitGarmentCareInspectionQuote = garmentCare.submitGarmentCareInspectionQuote;
exports.respondToGarmentCareConsent = garmentCare.respondToGarmentCareConsent;
exports.allocateGarmentCareCapturedPayment = garmentCare.allocateGarmentCareCapturedPayment;

/**
 * @param {string} raw E.164 or digits
 */
function whatsappToDigits(raw) {
  if (!raw || typeof raw !== "string") return "";
  return raw.replace(/\D/g, "");
}

exports.sendUserWhatsApp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }

  const tokenPhone = context.auth.token.phone_number;
  const digits = whatsappToDigits(tokenPhone || "");
  if (!digits || digits.length < 10) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "WhatsApp notifications require phone (OTP) sign-in so we know your number.",
    );
  }

  const cfg = functions.config().whatsapp || {};
  const graphToken = process.env.WHATSAPP_TOKEN || cfg.token;
  const phoneNumberId =
    process.env.WHATSAPP_PHONE_NUMBER_ID || cfg.phone_number_id;
  if (!graphToken || !phoneNumberId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "WhatsApp is not configured. Set whatsapp.token and whatsapp.phone_number_id (Firebase Functions config).",
    );
  }

  const templateName =
    (data && data.templateName) || cfg.template_default || "hello_world";
  const languageCode = (data && data.languageCode) || "en_US";

  const url = `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`;
  const body = {
    messaging_product: "whatsapp",
    to: digits,
    type: "template",
    template: {
      name: String(templateName),
      language: { code: String(languageCode) },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${graphToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    functions.logger.error("WhatsApp API error", { status: res.status, json });
    throw new functions.https.HttpsError(
      "internal",
      json.error && json.error.message
        ? json.error.message
        : `WhatsApp HTTP ${res.status}`,
    );
  }

  functions.logger.info("WhatsApp sent", {
    uid: context.auth.uid,
    kind: data && data.kind,
    dressType: data && data.dressType,
  });

  return {
    ok: true,
    messageId: json.messages && json.messages[0] && json.messages[0].id,
  };
});

/**
 * Updates a Tailor's order-availability signal on their common Partner profile.
 * Approved status alone never makes a Partner eligible for new order offers.
 */
exports.setTailorAvailability = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }

  const accountId = String((data && data.accountId) || "").trim();
  const profileId = String((data && data.profileId) || "").trim();
  const available = data && data.available;
  if (!accountId || !profileId || typeof available !== "boolean") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A Partner account, profile, and availability choice are required.",
    );
  }

  const accountRef = admin.firestore().collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnap, profileSnap] = await Promise.all([
    accountRef.get(),
    profileRef.get(),
  ]);
  if (!accountSnap.exists || !profileSnap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "The Partner profile could not be found.",
    );
  }

  const phone = context.auth.token.phone_number;
  if (!phone || accountSnap.get("mobileE164") !== phone) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You can update availability only for your own Partner account.",
    );
  }

  const profile = profileSnap.data() || {};
  if (
    (profile.accountId && profile.accountId !== accountId) ||
    (profile.profileId && profile.profileId !== profileId) ||
    profile.role !== "partner" ||
    profile.partnerType !== "tailor"
  ) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This profile is not a Tailor Partner profile.",
    );
  }

  const activeAndApproved =
    profile.status === "active" &&
    profile.operationalStatus === "active" &&
    profile.activationStatus === "active" &&
    profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified";
  if (available && !activeAndApproved) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Only an approved, active, verified Tailor can accept new order offers.",
    );
  }

  const availabilityStatus = available ? "available" : "unavailable";
  await profileRef.update({
    availabilityStatus,
    availabilityUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    availabilityUpdatedByUid: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { availabilityStatus };
});

// Production core-tailoring assignment lives separately from the legacy
// test-dashboard order list. Assignment, response deadlines, and finalization
// are server-owned so clients cannot claim or finalize an order directly.
const orderAssignment = require("./order_assignment");
exports.onCoreTailoringOrderCreated = orderAssignment.onCoreTailoringOrderCreated;
exports.onTailorAvailabilityChanged = orderAssignment.onTailorAvailabilityChanged;
exports.respondToTailorOrderOffer = orderAssignment.respondToTailorOrderOffer;
exports.declineAcceptedTailorOrder = orderAssignment.declineAcceptedTailorOrder;
exports.completeSandboxOrderAdvance = orderAssignment.completeSandboxOrderAdvance;
exports.cancelCoreTailoringOrder = orderAssignment.cancelCoreTailoringOrder;
exports.waiveOrderCancellationFee = orderAssignment.waiveOrderCancellationFee;
exports.completeSandboxOrderBalance = orderAssignment.completeSandboxOrderBalance;
exports.advanceProductionTailorOrderStatus = orderAssignment.advanceProductionTailorOrderStatus;
exports.saveTailorFabricRequirementReview = orderAssignment.saveTailorFabricRequirementReview;
exports.confirmCustomerFabricShortfall = orderAssignment.confirmCustomerFabricShortfall;
exports.confirmTailorProductionTask = orderAssignment.confirmTailorProductionTask;
exports.getMeasurementPartnerCandidates = orderAssignment.getMeasurementPartnerCandidates;
exports.saveTailorMeasurementPlan = orderAssignment.saveTailorMeasurementPlan;
exports.getMeasurementPartnerAssignments = orderAssignment.getMeasurementPartnerAssignments;
exports.setMeasurementPartnerAppointment = orderAssignment.setMeasurementPartnerAppointment;
exports.scheduleVideoMeasurementAppointment = orderAssignment.scheduleVideoMeasurementAppointment;
exports.scheduleCustomerFabricConsultation = orderAssignment.scheduleCustomerFabricConsultation;
exports.submitMeasurementPartnerMeasurements = orderAssignment.submitMeasurementPartnerMeasurements;
exports.getCustomerOrderPartnerContacts = orderAssignment.getCustomerOrderPartnerContacts;
exports.getCustomerOrderDeliveryPin = orderAssignment.getCustomerOrderDeliveryPin;
exports.saveTailorGarmentRecord = orderAssignment.saveTailorGarmentRecord;
exports.getGarmentRecordShareLink = orderAssignment.getGarmentRecordShareLink;
exports.viewPublicGarmentRecord = orderAssignment.viewPublicGarmentRecord;
exports.advanceProductionDeliveryOrder = orderAssignment.advanceProductionDeliveryOrder;
exports.submitOrderFeedback = orderAssignment.submitOrderFeedback;
exports.reportOrderWarrantyIssue = orderAssignment.reportOrderWarrantyIssue;
exports.resolveTailorWarrantyIssue = orderAssignment.resolveTailorWarrantyIssue;
exports.resolveOrderWarrantyIssue = orderAssignment.resolveOrderWarrantyIssue;
exports.getAdminOrderRoutingQueue = orderAssignment.getAdminOrderRoutingQueue;
exports.getAdminOrderRoutingCandidates = orderAssignment.getAdminOrderRoutingCandidates;
exports.getAdminInboundPickupCandidates = orderAssignment.getAdminInboundPickupCandidates;
exports.assignInboundPickupPartner = orderAssignment.assignInboundPickupPartner;
exports.getTailorInboundPickupCandidates = orderAssignment.getTailorInboundPickupCandidates;
exports.assignTailorInboundPickupPartner = orderAssignment.assignTailorInboundPickupPartner;
exports.getAdminOutboundHandoverCandidates = orderAssignment.getAdminOutboundHandoverCandidates;
exports.assignAdminOutboundHandoverPartner = orderAssignment.assignAdminOutboundHandoverPartner;
exports.getTailorOutboundHandoverCandidates = orderAssignment.getTailorOutboundHandoverCandidates;
exports.assignTailorOutboundHandoverPartner = orderAssignment.assignTailorOutboundHandoverPartner;
exports.updateTailorRoutingPriority = orderAssignment.updateTailorRoutingPriority;
exports.sendAdminTailorOrderOffer = orderAssignment.sendAdminTailorOrderOffer;
exports.sweepOrderAssignmentDeadlines = orderAssignment.sweepOrderAssignmentDeadlines;
