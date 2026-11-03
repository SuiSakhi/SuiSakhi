const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getDefaultStorageBucket} = require("./storage_bucket");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const {FieldValue} = admin.firestore;

function fail(code, message) {
  throw new functions.https.HttpsError(code, message);
}

function text(value, limit = 500) {
  return String(value == null ? "" : value).trim().slice(0, limit);
}

function orderPincode(order) {
  const raw = order.deliveryPincode ||
    (order.deliveryLocation && order.deliveryLocation.pincode) || "";
  const direct = String(raw).replace(/\D/g, "");
  if (/^\d{6}$/.test(direct)) return direct;
  const address = [order.deliveryAddress, order.serviceVisitAddress,
    order.address, order.serviceAddress].filter(Boolean).join(" ");
  const match = String(address).match(/(?:^|\D)(\d{6})(?:\D|$)/);
  return match ? match[1] : "";
}

function quickCareData(profile) {
  const partnerData = profile.partnerData && typeof profile.partnerData === "object"
    ? profile.partnerData : {};
  const extensions = partnerData.extensions && typeof partnerData.extensions === "object"
    ? partnerData.extensions : {};
  const category = extensions.doorstepServices && typeof extensions.doorstepServices === "object"
    ? extensions.doorstepServices : {};
  const capabilities = category.capabilities && typeof category.capabilities === "object"
    ? category.capabilities : {};
  const workshop = category.workshopDetails && typeof category.workshopDetails === "object"
    ? category.workshopDetails : {};
  const operational = category.operational && typeof category.operational === "object"
    ? category.operational : {};
  const pins = new Set();
  const collectPins = (value) => {
    if (Array.isArray(value)) {
      for (const item of value) collectPins(item);
    } else if (typeof value === "string" || typeof value === "number") {
      for (const pin of String(value).match(/\d{6}/g) || []) pins.add(pin);
    }
  };
  collectPins(workshop.serviceAreaPincodes);
  collectPins(category.serviceAreaPincodes);
  collectPins(category.serviceArea);
  collectPins(workshop.pincode);
  collectPins(partnerData.serviceAreaPincodes);
  const rawAvailabilitySlots = Array.isArray(operational.availabilitySlots)
    ? operational.availabilitySlots
    : [];
  const availabilitySlots = rawAvailabilitySlots.length > 0
    ? rawAvailabilitySlots
      .map((slot) => ({
        day: text(slot && slot.day, 20).toLowerCase(),
        start: text(slot && slot.start, 5),
        end: text(slot && slot.end, 5),
      }))
      .filter((slot) => DAY_CODES.includes(slot.day) &&
        validTime(slot.start) && validTime(slot.end) && slot.start < slot.end)
    : (Array.isArray(workshop.operatingDays) ? workshop.operatingDays : [])
      .map((day) => ({
        day: text(day, 20).toLowerCase(),
        start: text(workshop.openingTime, 5),
        end: text(workshop.closingTime, 5),
      }))
      .filter((slot) => DAY_CODES.includes(slot.day) &&
        validTime(slot.start) && validTime(slot.end) && slot.start < slot.end);
  return {
    capabilities: Array.isArray(capabilities.declaredCapabilityCodes)
      ? capabilities.declaredCapabilityCodes.map((item) => text(item, 120)).filter(Boolean)
      : [],
    pins: [...pins],
    available: operational.availableForOrders !== false,
    availabilitySlots,
  };
}

const DAY_CODES = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

function validTime(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value || ""));
}

function quickCareKeepsEvidencePermanently(order) {
  const serviceIds = Array.isArray(order.quickFixServiceIds)
    ? order.quickFixServiceIds.map((value) => text(value, 80).toLowerCase())
    : [];
  const description = [order.quickCareTitle, order.title, order.serviceName, order.dressType]
      .filter(Boolean).join(" ").toLowerCase();
  return serviceIds.includes("wardrobe") || description.includes("wardrobe");
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "string" || value instanceof Date) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

exports.expireQuickCareEvidence = onSchedule({
  schedule: "every day 03:00",
  timeZone: "UTC",
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => {
  const bucket = getDefaultStorageBucket();
  const retentionMs = 7 * 24 * 60 * 60 * 1000;
  const now = Date.now();
  let cursor = null;
  let expiredCount = 0;
  const pageSize = 200;

  while (true) {
    let query = db.collection("orders")
        .where("orderModuleType", "==", "quickFix")
        .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;

    for (const orderSnapshot of page.docs) {
      const order = orderSnapshot.data() || {};
      if (quickCareKeepsEvidencePermanently(order)) continue;
      const workflow = text(order.quickCareWorkflowStatus, 40);
      if (!["paymentPending", "completed", "cancelled"].includes(workflow)) continue;
      const evidence = Array.isArray(order.quickCareEvidence) ? order.quickCareEvidence : [];
      const expiredPaths = new Set();
      const closedAt = timestampMillis(
          order.quickCareServiceCompletedAt || order.quickCareCompletedAt ||
          order.closedAt || order.paidAt || order.updatedAt,
      );

      for (const item of evidence) {
        if (!item || item.expired === true) continue;
        const path = text(item.storagePath, 500);
        if (!path.startsWith(`quickcare_evidence/${orderSnapshot.id}/`)) continue;
        const file = bucket.file(path);
        let addedAt = timestampMillis(item.addedAt);
        if (!addedAt) {
          try {
            const [metadata] = await file.getMetadata();
            addedAt = timestampMillis(metadata.timeCreated);
          } catch (error) {
            if (error && error.code === 404) {
              expiredPaths.add(path);
              continue;
            }
            functions.logger.warn("Could not check Quick Care evidence age", {
              orderId: orderSnapshot.id,
              path,
              message: error && error.message,
            });
            continue;
          }
        }
        if (!addedAt) continue;
        const retentionBase = Math.max(addedAt, closedAt || addedAt);
        if (now < retentionBase + retentionMs) continue;
        try {
          await file.delete({ignoreNotFound: true});
          expiredPaths.add(path);
        } catch (error) {
          functions.logger.warn("Could not expire Quick Care evidence", {
            orderId: orderSnapshot.id,
            path,
            message: error && error.message,
          });
        }
      }

      if (expiredPaths.size > 0) {
        const expiredAt = new Date(now).toISOString();
        await db.runTransaction(async (tx) => {
          const currentSnapshot = await tx.get(orderSnapshot.ref);
          if (!currentSnapshot.exists) return;
          const currentEvidence = Array.isArray(currentSnapshot.get("quickCareEvidence"))
            ? currentSnapshot.get("quickCareEvidence") : [];
          tx.update(orderSnapshot.ref, {
            quickCareEvidence: currentEvidence.map((item) => {
              const path = text(item && item.storagePath, 500);
              return expiredPaths.has(path)
                ? {...item, expired: true, expiredAt}
                : item;
            }),
            updatedAt: FieldValue.serverTimestamp(),
          });
        });
        expiredCount += expiredPaths.size;
      }
    }

    cursor = page.docs[page.docs.length - 1];
    if (page.docs.length < pageSize) break;
  }

  functions.logger.info("Quick Care evidence retention sweep completed", {
    expiredCount,
  });
});

function appointmentWindow(order) {
  const slotLabel = text(order.pickupSlot, 100).toLowerCase();
  const match = slotLabel.match(/(\d{1,2})(am|pm)\s*(?:-|–|—|to)\s*(\d{1,2})(am|pm)/i);
  if (!match) return null;
  const toMinutes = (hourText, meridiem) => {
    let hour = Number(hourText) % 12;
    if (meridiem.toLowerCase() === "pm") hour += 12;
    return hour * 60;
  };
  return {
    start: toMinutes(match[1], match[2]),
    end: toMinutes(match[3], match[4]),
  };
}

function isWithinAvailability(profile, order) {
  const quickcare = quickCareData(profile);
  if (!quickcare.available) return false;
  const scheduledAt = order.quickCareScheduledAt;
  // "Choose later" orders have no confirmed appointment yet. They can be
  // discovered while online; confirmed requests must fit a configured slot.
  if (!scheduledAt || typeof scheduledAt.toDate !== "function") return true;
  if (quickcare.availabilitySlots.length === 0) return false;

  // Customer appointment times are entered in India local time. Convert the
  // Firestore instant back to India local time before comparing weekly hours.
  const local = new Date(scheduledAt.toDate().getTime() + 330 * 60 * 1000);
  const day = ["sunday", ...DAY_CODES.slice(0, 6)][local.getUTCDay()];
  const appointment = appointmentWindow(order);
  const startMinutes = local.getUTCHours() * 60 + local.getUTCMinutes();
  const requestedStart = appointment ? appointment.start : startMinutes;
  const requestedEnd = appointment ? appointment.end : startMinutes;
  return quickcare.availabilitySlots.some((slot) => {
    if (slot.day !== day) return false;
    const [startHour, startMinute] = slot.start.split(":").map(Number);
    const [endHour, endMinute] = slot.end.split(":").map(Number);
    const availableStart = startHour * 60 + startMinute;
    const availableEnd = endHour * 60 + endMinute;
    return requestedStart >= availableStart && requestedEnd <= availableEnd;
  });
}

function cleanAvailabilitySlots(value, allowEmpty = false) {
  if (!Array.isArray(value) || value.length > 7 || (!allowEmpty && value.length < 1)) {
    fail("invalid-argument", "Choose at least one QuickCare availability day and time.");
  }
  const slots = value.map((item) => ({
    day: text(item && item.day, 20).toLowerCase(),
    start: text(item && item.start, 5),
    end: text(item && item.end, 5),
  }));
  if (slots.some((slot) => !DAY_CODES.includes(slot.day) || !validTime(slot.start) ||
      !validTime(slot.end) || slot.start >= slot.end) ||
      new Set(slots.map((slot) => slot.day)).size !== slots.length) {
    fail("invalid-argument", "Each availability day needs a valid start and end time.");
  }
  return slots;
}

const SERVICE_CAPABILITIES = {
  pico_fall: ["doorstepServices.picoFall"],
  rafu: ["doorstepServices.raffu", "doorstepServices.minorTearRepair"],
  zip: ["doorstepServices.zipRepair"],
  button: ["doorstepServices.buttonReplacement", "doorstepServices.hookRepair"],
  minor_alt: ["doorstepServices.minorAlteration", "doorstepServices.minorStitchRepair"],
  express_stitch: ["doorstepServices.emergencyStitchRepair", "doorstepServices.minorStitchRepair"],
  wardrobe: ["doorstepServices.wardrobeAssistance", "doorstepServices.wardrobeReorganization"],
  saree_draping: ["doorstepServices.sareeDraping"],
};
const SERVICE_POINT_VALUES = {
  pico_fall: 4,
  rafu: 6,
  zip: 4,
  button: 3,
  minor_alt: 6,
  express_stitch: 7,
  wardrobe: 8,
  saree_draping: 7,
  other_quote: 3,
};
const ALL_QUICKCARE_CAPABILITIES = [
  ...new Set(Object.values(SERVICE_CAPABILITIES).flat()),
];

function hasRequestedSkills(profile, serviceIds) {
  const declared = new Set(quickCareData(profile).capabilities);
  const repairBundle = declared.has("doorstepServices.garmentRepair");
  const assistanceBundle = declared.has("doorstepServices.garmentAssistance");
  return serviceIds.every((serviceId) => {
    if (serviceId === "other_quote") {
      return ALL_QUICKCARE_CAPABILITIES.some((capability) => declared.has(capability)) ||
        repairBundle || assistanceBundle;
    }
    const directMatch = (SERVICE_CAPABILITIES[serviceId] || [])
      .some((capability) => declared.has(capability));
    const repairService = ["pico_fall", "rafu", "zip", "button", "minor_alt", "express_stitch"]
      .includes(serviceId);
    const assistanceService = ["wardrobe", "saree_draping"].includes(serviceId);
    return directMatch || (repairService && repairBundle) ||
      (assistanceService && assistanceBundle);
  });
}

function quickCareMatch(profile, order) {
  const quickcare = quickCareData(profile);
  const services = Array.isArray(order.quickFixServiceIds)
    ? order.quickFixServiceIds.map((item) => text(item, 80)).filter(Boolean)
    : [];
  const pin = orderPincode(order);
  const serviceSkillsMatch = services.length > 0 && hasRequestedSkills(profile, services);
  const areaMatch = !!pin && quickcare.pins.includes(pin);
  const availabilityMatch = isWithinAvailability(profile, order);
  const reasons = [];
  if (!quickcare.available) reasons.push("Partner is offline");
  if (!serviceSkillsMatch) reasons.push("Service skills do not match");
  if (!areaMatch) reasons.push(pin ? `Outside service area ${pin}` : "Order has no valid PIN code");
  if (quickcare.available && !availabilityMatch) reasons.push("Outside partner hours for this slot");
  return {
    eligible: quickcare.available && serviceSkillsMatch && areaMatch && availabilityMatch,
    availableForOrders: quickcare.available,
    serviceSkillsMatch,
    areaMatch,
    availabilityMatch,
    orderPincode: pin,
    reasons,
  };
}

function partnerCoversOrder(profile, order) {
  return quickCareMatch(profile, order).eligible;
}

function isApprovedQuickCare(profile) {
  return profile && profile.role === "partner" && profile.partnerType === "doorstepServices" &&
    profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified";
}

async function requirePartner(context, accountId, profileId) {
  if (!context.auth) fail("unauthenticated", "Sign in to open Quick Care Partner jobs.");
  accountId = text(accountId, 128);
  profileId = text(profileId, 128);
  if (!accountId || !profileId) fail("invalid-argument", "Partner profile is required.");
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [account, profile] = await Promise.all([accountRef.get(), profileRef.get()]);
  const profileData = profile.data() || {};
  if (!account.exists || account.get("mobileE164") !== context.auth.token.phone_number ||
      !profile.exists || !isApprovedQuickCare(profileData)) {
    fail("permission-denied", "An active, approved QuickCare Partner profile is required.");
  }
  return {accountId, profileId, accountRef, profileRef, profile: profileData, account: account.data() || {}};
}

async function requireHelpdesk(context) {
  if (!context.auth) fail("unauthenticated", "Sign in with your verified phone number.");
  const [adminSnapshot, supportSnapshot] = await Promise.all([
    db.doc("config/admin").get(), db.doc("config/support").get(),
  ]);
  const adminUids = adminSnapshot.get("adminUids");
  const supportUids = supportSnapshot.get("supportUids");
  const supportPhones = supportSnapshot.get("supportPhones");
  const uid = context.auth.uid;
  const phone = context.auth.token.phone_number;
  const isAdmin = Array.isArray(adminUids) && adminUids.includes(uid);
  const isSupport = (Array.isArray(supportUids) && supportUids.includes(uid)) ||
    (typeof phone === "string" && Array.isArray(supportPhones) && supportPhones.includes(phone));
  if (!isAdmin && !isSupport) fail("permission-denied", "Configured Helpdesk access is required.");
  return {uid, role: isAdmin ? "admin" : "support"};
}

function partnerSummary(accountId, profileId, profile, account = {}) {
  const partnerData = profile.partnerData && typeof profile.partnerData === "object"
    ? profile.partnerData : {};
  return {
    accountId,
    profileId,
    name: text(profile.businessName || profile.shopName || profile.displayName ||
      partnerData.businessName || profile.contactName || "QuickCare Partner", 120),
    phone: text(account.mobileE164 || profile.mobileE164 || profile.contactPhone, 32),
    capabilities: quickCareData(profile).capabilities,
    serviceAreaPincodes: quickCareData(profile).pins,
    availableForOrders: quickCareData(profile).available,
    availabilitySlots: quickCareData(profile).availabilitySlots,
  };
}

async function getOrder(orderId) {
  const ref = db.collection("orders").doc(orderId);
  const snapshot = await ref.get();
  if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
  const order = snapshot.data() || {};
  if (order.orderModuleType !== "quickFix") fail("failed-precondition", "This is not a Quick Care booking.");
  return {ref, order, snapshot};
}

function serializedValue(value) {
  if (value && typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serializedValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serializedValue(item)]));
  }
  return value;
}

function partnerOrderSummary(snapshot, assigned, match = null) {
  const order = snapshot.data() || {};
  const result = {
    id: snapshot.id,
    orderNumber: text(order.orderNumber || order.orderTrackingId || snapshot.id, 80),
    quickFixServiceIds: Array.isArray(order.quickFixServiceIds) ? order.quickFixServiceIds : [],
    serviceNotes: text(order.notes, 1000),
    quickCareScheduledAt: serializedValue(order.quickCareScheduledAt || null),
    orderDate: serializedValue(order.orderDate || null),
    pickupSlot: text(order.pickupSlot, 80),
    estimatedPrice: Number(order.estimatedPrice || 0),
    price: Number(order.price || 0),
    deliveryPincode: orderPincode(order),
    quickCareWorkflowStatus: text(order.quickCareWorkflowStatus, 60),
    quickCareAssignmentStatus: text(order.quickCareAssignmentStatus, 40),
    quickCareQuoteStatus: text(order.quickCareQuoteStatus, 60) || null,
    quickCarePauseReason: text(order.quickCarePauseReason, 1000) || null,
    quickCareAssignmentOverride: order.quickCareAssignmentOverride === true,
    quickCareAssignmentOverrideReasons: Array.isArray(order.quickCareAssignmentOverrideReasons)
      ? order.quickCareAssignmentOverrideReasons.map((reason) => text(reason, 120))
      : [],
    quickCarePilotFallback: !!(match && match.pilotFallback),
    quickCarePilotFallbackReasons: match && Array.isArray(match.reasons)
      ? match.reasons.map((reason) => text(reason, 120))
      : [],
    quickCareEvidence: Array.isArray(order.quickCareEvidence) ? serializedValue(order.quickCareEvidence) : [],
    quickCareExtraChargeStatus: text(order.quickCareExtraChargeStatus, 60) || null,
    quickCareExtraChargeAmount: Number(order.quickCareExtraChargeAmount || 0),
    quickCareExtraChargeReason: text(order.quickCareExtraChargeReason, 1000) || null,
    quickCareFinalAmount: Number(order.quickCareFinalAmount || 0),
    quickCarePaymentStatus: text(order.quickCarePaymentStatus, 40) || null,
    quickCarePaymentFollowupRequired: order.quickCarePaymentFollowupRequired === true,
    paymentStatus: text(order.paymentStatus, 40) || null,
    quickCarePointsPending: Number(order.quickCarePointsPending || 0),
  };
  if (assigned) {
    result.deliveryAddress = text(order.deliveryAddress, 500);
    result.serviceVisitLandmark = text(order.serviceVisitLandmark, 300);
  }
  return result;
}

exports.getQuickCarePartnerJobs = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  const partnerAvailability = quickCareData(partner.profile);
  const snapshot = await db.collection("orders").where("orderModuleType", "==", "quickFix").limit(300).get();
  const availableJobs = [];
  const myJobs = [];
  const fallbackJobs = [];
  for (const doc of snapshot.docs) {
    const order = doc.data() || {};
    const workflow = text(order.quickCareWorkflowStatus, 60).toLowerCase();
    if (workflow === "cancelled" || text(order.status, 40).toLowerCase() === "cancelled") continue;
    const assignedAccountId = text(order.quickCareAssignedPartnerAccountId || order.assignedQuickCarePartnerAccountId || order.quickCarePartnerAccountId, 128);
    const assignedProfileId = text(order.quickCareAssignedPartnerProfileId || order.assignedQuickCarePartnerProfileId || order.quickCarePartnerProfileId, 128);
    if (assignedAccountId === partner.accountId && assignedProfileId === partner.profileId) {
      myJobs.push(partnerOrderSummary(doc, true));
      continue;
    }
    if (workflow === "completed") continue;
    const assignment = text(order.quickCareAssignmentStatus, 40).toLowerCase();
    if (["searching", "available", "unassigned", "reassigning"].includes(assignment)) {
      const match = quickCareMatch(partner.profile, order);
      if (match.eligible) {
        availableJobs.push(partnerOrderSummary(doc, false, match));
      } else if (match.availableForOrders && match.availabilityMatch) {
        fallbackJobs.push({doc, match});
      }
    }
  }
  // Pilot fallback: when exactly one approved QuickCare profile exists, keep
  // requests visible to that online partner during their configured hours,
  // even if the pilot profile is missing a capability or service-area PIN.
  // The card displays the mismatch and acceptance records the override.
  if (fallbackJobs.length > 0 && partnerAvailability.available &&
      await isOnlyApprovedQuickCarePartner(partner.accountId, partner.profileId)) {
    for (const {doc, match} of fallbackJobs) {
      availableJobs.push(partnerOrderSummary(doc, false, {
        ...match,
        pilotFallback: true,
      }));
    }
  }
  const byDate = (a, b) => Date.parse(a.quickCareScheduledAt || a.orderDate || 0) -
    Date.parse(b.quickCareScheduledAt || b.orderDate || 0);
  return {
    availableJobs: availableJobs.sort(byDate),
    myJobs: myJobs.sort(byDate),
    availability: {
      availableForOrders: partnerAvailability.available,
      slots: partnerAvailability.availabilitySlots,
    },
  };
});

exports.setQuickCarePartnerAvailability = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  if (typeof (data && data.availableForOrders) !== "boolean") {
    fail("invalid-argument", "Choose whether to accept new QuickCare requests.");
  }
  const slots = cleanAvailabilitySlots(
    data && data.availabilitySlots,
    data.availableForOrders === false,
  );
  await partner.profileRef.update({
    "partnerData.extensions.doorstepServices.operational": {
      ...((partner.profile.partnerData || {}).extensions || {}).doorstepServices?.operational,
      availableForOrders: data.availableForOrders,
      availabilitySlots: slots,
    },
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {
    availableForOrders: data.availableForOrders,
    slots,
  };
});

exports.acceptQuickCareJob = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  const orderId = text(data && data.orderId, 128);
  if (!orderId) fail("invalid-argument", "Choose a Quick Care request.");
  const orderRef = db.collection("orders").doc(orderId);
  const initialOrder = await orderRef.get();
  if (!initialOrder.exists || initialOrder.get("orderModuleType") !== "quickFix") {
    fail("not-found", "Quick Care request not found.");
  }
  const initialMatch = quickCareMatch(partner.profile, initialOrder.data() || {});
  const pilotFallbackAvailable = !initialMatch.eligible &&
    initialMatch.availableForOrders && initialMatch.availabilityMatch &&
    await isOnlyApprovedQuickCarePartner(partner.accountId, partner.profileId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care request not found.");
    const order = snapshot.data() || {};
    const currentStatus = text(order.quickCareAssignmentStatus, 40).toLowerCase();
    const assignedToThisPartner =
      text(order.quickCareAssignedPartnerAccountId || order.assignedQuickCarePartnerAccountId || order.quickCarePartnerAccountId, 128) === partner.accountId &&
      text(order.quickCareAssignedPartnerProfileId || order.assignedQuickCarePartnerProfileId || order.quickCarePartnerProfileId, 128) === partner.profileId;
    const match = quickCareMatch(partner.profile, order);
    const continuingManualAssignment = assignedToThisPartner &&
      (order.quickCareAssignmentOverride === true ||
        (match.reasons.length === 1 && match.reasons[0] === "Partner is offline"));
    const pilotFallbackAllowed = pilotFallbackAvailable && !match.eligible &&
      match.availableForOrders && match.availabilityMatch;
    if (!match.eligible && !continuingManualAssignment && !pilotFallbackAllowed) {
      fail("permission-denied", `This request does not currently match: ${match.reasons.join(", ")}.`);
    }
    if (!["searching", "available", "unassigned", "reassigning"].includes(currentStatus) &&
        !(currentStatus === "assigned" && assignedToThisPartner)) {
      fail("failed-precondition", "This request has already been accepted or assigned.");
    }
    if (["cancelled", "completed"].includes(text(order.quickCareWorkflowStatus, 40).toLowerCase())) {
      fail("failed-precondition", "This request is already closed.");
    }
    const summary = partnerSummary(partner.accountId, partner.profileId, partner.profile, partner.account);
    const assignmentOverride = order.quickCareAssignmentOverride === true || pilotFallbackAllowed;
    const assignmentOverrideReasons = !match.eligible && assignmentOverride
      ? match.reasons
      : (Array.isArray(order.quickCareAssignmentOverrideReasons)
        ? order.quickCareAssignmentOverrideReasons
        : []);
    tx.update(orderRef, {
      quickCareAssignedPartnerAccountId: partner.accountId,
      quickCareAssignedPartnerProfileId: partner.profileId,
      quickCareAssignedPartnerName: summary.name,
      quickCareAssignedPartnerPhone: summary.phone,
      quickCareAssignmentStatus: "accepted",
      quickCareWorkflowStatus: "accepted",
      quickCareAcceptedAt: FieldValue.serverTimestamp(),
      quickCareAssignmentOverride: assignmentOverride,
      quickCareAssignmentOverrideReasons: assignmentOverrideReasons.length > 0
        ? assignmentOverrideReasons
        : FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(orderRef.collection("events").doc(), {
      type: "quick_care_partner_accepted",
      actorType: "partner",
      actorUid: context.auth.uid,
      partnerAccountId: partner.accountId,
      partnerProfileId: partner.profileId,
      override: assignmentOverride,
      overrideReasons: assignmentOverrideReasons,
      occurredAt: FieldValue.serverTimestamp(),
    });
  });
  return {accepted: true};
});

exports.startQuickCareJob = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  const orderId = text(data && data.orderId, 128);
  const pin = text(data && data.pin, 4).replace(/\D/g, "");
  if (!orderId || !/^\d{4}$/.test(pin)) fail("invalid-argument", "Enter the customer's four-digit verification PIN.");
  const orderRef = db.collection("orders").doc(orderId);
  const snapshot = await orderRef.get();
  if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
  const order = snapshot.data() || {};
  if (text(order.quickCareAssignedPartnerAccountId, 128) !== partner.accountId ||
      text(order.quickCareAssignedPartnerProfileId, 128) !== partner.profileId) {
    fail("permission-denied", "This job is not assigned to your Partner profile.");
  }
  if (text(order.quickCareWorkflowStatus, 40) !== "accepted") fail("failed-precondition", "Accept the booking before starting the work.");
  if (["partnerQuoteRequired", "customerDeclined"].includes(text(order.quickCareQuoteStatus, 60))) {
    fail("failed-precondition", "Send the customer a service quote and wait for approval before starting this custom service.");
  }
  const customerUid = text(order.customerId || order.customerUid, 128);
  if (!customerUid) fail("failed-precondition", "Customer phone verification is not available for this order.");
  let customerPhone = "";
  try {
    const customer = await admin.auth().getUser(customerUid);
    customerPhone = text(customer.phoneNumber, 32);
  } catch (_) {}
  if (!customerPhone && order.customerAccountId) {
    const account = await db.collection("accounts").doc(text(order.customerAccountId, 128)).get();
    customerPhone = text(account.get("mobileE164"), 32);
  }
  const digits = customerPhone.replace(/\D/g, "");
  if (digits.length < 4 || digits.slice(-4) !== pin) fail("permission-denied", "The PIN does not match the customer's registered mobile number.");
  await db.runTransaction(async (tx) => {
    const current = await tx.get(orderRef);
    if (!current.exists || current.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
    if (text(current.get("quickCareAssignedPartnerAccountId"), 128) !== partner.accountId ||
        text(current.get("quickCareAssignedPartnerProfileId"), 128) !== partner.profileId) fail("permission-denied", "This job is no longer assigned to your Partner profile.");
    if (text(current.get("quickCareWorkflowStatus"), 40) !== "accepted") fail("failed-precondition", "Accept the booking before starting the work.");
    const evidence = Array.isArray(current.get("quickCareEvidence")) ? current.get("quickCareEvidence") : [];
    if (!evidence.some((item) => item && item.kind === "photo" && item.note === "before_work")) {
      fail("failed-precondition", "Capture and attach a before-work photo before starting this service.");
    }
    tx.update(orderRef, {
      quickCareWorkflowStatus: "inProgress",
      quickCareStartedAt: FieldValue.serverTimestamp(),
      quickCarePinVerifiedAt: FieldValue.serverTimestamp(),
      quickCarePinVerifiedByUid: context.auth.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(orderRef.collection("events").doc(), {
      type: "quick_care_work_started",
      actorType: "partner",
      actorUid: context.auth.uid,
      partnerAccountId: partner.accountId,
      partnerProfileId: partner.profileId,
      occurredAt: FieldValue.serverTimestamp(),
    });
  });
  return {started: true};
});

exports.updateQuickCareJob = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  const orderId = text(data && data.orderId, 128);
  const action = text(data && data.action, 40);
  const reason = text(data && data.reason, 1000);
  if (!orderId) fail("invalid-argument", "Choose a Quick Care booking.");
  if (["pause", "proposeExtra", "proposeServiceQuote"].includes(action) && reason.length < 3) fail("invalid-argument", "Add a short reason.");
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
    const order = snapshot.data() || {};
    if (text(order.quickCareAssignedPartnerAccountId, 128) !== partner.accountId ||
        text(order.quickCareAssignedPartnerProfileId, 128) !== partner.profileId) fail("permission-denied", "This job is not assigned to your Partner profile.");
    const workflow = text(order.quickCareWorkflowStatus, 40);
    const common = {updatedAt: FieldValue.serverTimestamp()};
    if (action === "pause") {
      if (workflow !== "inProgress") fail("failed-precondition", "Only work in progress can be paused.");
      tx.update(orderRef, {...common, quickCareWorkflowStatus: "paused", quickCarePausedAt: FieldValue.serverTimestamp(), quickCarePauseReason: reason});
    } else if (action === "resume") {
      if (workflow !== "paused") fail("failed-precondition", "This job is not paused.");
      tx.update(orderRef, {...common, quickCareWorkflowStatus: "inProgress", quickCareResumedAt: FieldValue.serverTimestamp()});
    } else if (action === "proposeExtra") {
      if (!["inProgress", "paused"].includes(workflow)) fail("failed-precondition", "Additional work can only be quoted after the job has started.");
      const amount = Number(data && data.amount);
      if (!Number.isFinite(amount) || amount <= 0 || amount > 50000) fail("invalid-argument", "Enter an additional amount between ₹1 and ₹50,000.");
      tx.update(orderRef, {...common, quickCareExtraChargeStatus: "pendingCustomerApproval", quickCareExtraChargeType: "additionalWork", quickCareExtraChargeAmount: Math.round(amount), quickCareExtraChargeReason: reason, quickCareWorkflowBeforeExtraCharge: workflow, quickCareWorkflowStatus: "awaitingCustomerApproval", quickCareExtraChargeProposedAt: FieldValue.serverTimestamp()});
    } else if (action === "proposeServiceQuote") {
      if (workflow !== "accepted") fail("failed-precondition", "A custom service quote must be agreed before work starts.");
      if (!(Array.isArray(order.quickFixServiceIds) && order.quickFixServiceIds.includes("other_quote")) ||
          !["partnerQuoteRequired", "customerDeclined"].includes(text(order.quickCareQuoteStatus, 60))) {
        fail("failed-precondition", "This booking does not need an initial custom-service quote.");
      }
      const amount = Number(data && data.amount);
      if (!Number.isFinite(amount) || amount <= 0 || amount > 50000) fail("invalid-argument", "Enter a service quote between ₹1 and ₹50,000.");
      tx.update(orderRef, {...common, quickCareExtraChargeStatus: "pendingCustomerApproval", quickCareExtraChargeType: "serviceQuote", quickCareExtraChargeAmount: Math.round(amount), quickCareExtraChargeReason: reason, quickCareWorkflowBeforeExtraCharge: workflow, quickCareWorkflowStatus: "awaitingCustomerApproval", quickCareExtraChargeProposedAt: FieldValue.serverTimestamp()});
    } else if (action === "complete") {
      if (workflow !== "inProgress") fail("failed-precondition", "Resume the job before marking it complete.");
      const evidence = Array.isArray(order.quickCareEvidence) ? order.quickCareEvidence : [];
      if (!evidence.some((item) => item && item.kind === "photo" && item.note === "after_work")) {
        fail("failed-precondition", "Capture and attach an after-work photo before completing this service.");
      }
      if (order.quickCareExtraChargeStatus === "pendingCustomerApproval") fail("failed-precondition", "Wait for the customer to approve or decline the additional work amount.");
      const amount = Number(data && data.finalAmount);
      if (!Number.isFinite(amount) || amount < 0 || amount > 100000) fail("invalid-argument", "Enter a valid final amount.");
      const extra = order.quickCareExtraChargeStatus === "approved" &&
        order.quickCareExtraChargeType !== "serviceQuote"
        ? Number(order.quickCareExtraChargeAmount || 0)
        : 0;
      const base = Number(order.estimatedPrice || order.price || 0);
      const minimum = Math.max(0, base + extra);
      if (amount < minimum) fail("failed-precondition", "Final amount cannot be less than the estimate and customer-approved extra work.");
      if (amount > minimum) fail("failed-precondition", "The final amount cannot exceed the customer-approved quote. Request approval for any additional work first.");
      const roundedAmount = Math.round(amount);
      tx.update(orderRef, {
        ...common,
        quickCareWorkflowStatus: "paymentPending",
        quickCareServiceCompletedAt: FieldValue.serverTimestamp(),
        quickCarePaymentStatus: "pending",
        quickCarePaymentFollowupRequired: true,
        quickCareFinalAmount: roundedAmount,
        price: roundedAmount,
        amountPaid: 0,
        balanceAmount: roundedAmount,
        paymentStatus: "unpaid",
        quickCarePartnerAccountId: partner.accountId,
        quickCarePartnerProfileId: partner.profileId,
      });
    } else if (action === "confirmPayment") {
      fail("permission-denied", "Partners cannot confirm customer payments. The customer must pay through the app checkout.");
    } else {
      fail("invalid-argument", "Choose pause, resume, proposeExtra, proposeServiceQuote or complete.");
    }
    tx.create(orderRef.collection("events").doc(), {type: `quick_care_${action}`, actorType: "partner", actorUid: context.auth.uid, partnerAccountId: partner.accountId, partnerProfileId: partner.profileId, reason: reason || null, amount: data && data.amount || data && data.finalAmount || null, occurredAt: FieldValue.serverTimestamp()});
  });
  return {updated: true};
});

function quickCarePaymentWasGatewayVerified(order) {
  if (order.paymentStatus !== "fullyPaid") return false;
  return (order.paymentProvider === "razorpay" && Boolean(order.quickCareGatewayPaymentId)) ||
    (order.paymentProvider === "sandbox" && Boolean(order.quickCarePaymentMethod));
}

function quickCarePaymentDue(order) {
  const total = Math.round(Number(order.quickCareFinalAmount || order.price || 0));
  const verifiedPaid = quickCarePaymentWasGatewayVerified(order)
    ? Math.max(0, Number(order.amountPaid || 0))
    : 0;
  return {total, due: Math.max(0, total - verifiedPaid)};
}

function recordQuickCareCustomerPayment(tx, orderRef, order, payment) {
  const total = Math.round(Number(order.quickCareFinalAmount || order.price || 0));
  const servicePoints = [...new Set(Array.isArray(order.quickFixServiceIds) ? order.quickFixServiceIds : [])]
    .reduce((sum, serviceId) => sum + (SERVICE_POINT_VALUES[serviceId] || 0), 0);
  const amountPoints = Math.floor(total / 100);
  const points = servicePoints + amountPoints;
  const accountId = text(order.quickCareAssignedPartnerAccountId || order.quickCarePartnerAccountId, 128);
  const profileId = text(order.quickCareAssignedPartnerProfileId || order.quickCarePartnerProfileId, 128);
  tx.update(orderRef, {
    quickCareWorkflowStatus: "completed",
    quickCarePaymentStatus: "paid",
    quickCarePaymentFollowupRequired: false,
    quickCareCompletedAt: FieldValue.serverTimestamp(),
    amountPaid: total,
    balanceAmount: 0,
    paymentStatus: "fullyPaid",
    paidAt: FieldValue.serverTimestamp(),
    paymentMethod: payment.method,
    quickCarePaymentMethod: payment.method,
    paymentProvider: payment.provider,
    ...(payment.provider === "razorpay" ? {
      quickCareGatewayPaymentId: payment.paymentId,
      quickCareGatewayOrderId: payment.gatewayOrderId,
      quickCareGatewayStatus: "captured",
    } : {}),
    quickCarePointsBase: points,
    quickCarePointsPending: points,
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (accountId && profileId) {
    const ledgerRef = db.collection("quickcare_partner_points").doc(`${accountId}_${orderRef.id}`);
    tx.set(ledgerRef, {
      accountId, profileId, orderId: orderRef.id, servicePoints, amountPoints,
      basePoints: points, ratingBonusPoints: 0,
      status: "pendingReview", createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  tx.create(orderRef.collection("events").doc(), {
    type: "quick_care_payment_completed",
    actorType: payment.provider === "razorpay" ? "payment_gateway" : "customer",
    actorUid: payment.actorUid || null,
    amount: payment.amount,
    finalAmount: total,
    paymentMethod: payment.method,
    paymentProvider: payment.provider,
    paymentId: payment.paymentId || null,
    occurredAt: FieldValue.serverTimestamp(),
  });
}

async function callRazorpay(path, {method = "GET", body, keyId, keySecret}) {
  let response;
  try {
    response = await fetch(`https://api.razorpay.com/v1/${path}`, {
      method,
      headers: {
        Authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString("base64")}`,
        "Content-Type": "application/json",
      },
      ...(body ? {body: JSON.stringify(body)} : {}),
    });
  } catch (_) {
    fail("unavailable", "Could not reach Razorpay. Please retry shortly.");
  }
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error("Razorpay API error", response.status, result && result.error && result.error.code);
    fail("unavailable", "Razorpay could not process this payment request. Please retry or contact Helpdesk.");
  }
  return result;
}

function quickCareLegacyPartnerPaymentClaim(order) {
  const workflow = text(order.quickCareWorkflowStatus, 40);
  return order.orderModuleType === "quickFix" &&
    order.paymentStatus === "fullyPaid" &&
    ["completed", "paymentPending"].includes(workflow) &&
    !quickCarePaymentWasGatewayVerified(order);
}

async function createQuickCareGatewayOrder(data, context) {
  if (!context.auth) fail("unauthenticated", "Sign in to pay.");
  const orderId = text(data && data.orderId, 128);
  if (!orderId) fail("invalid-argument", "Choose a Quick Care booking.");
  const keySecret = text(process.env.RAZORPAY_KEY_SECRET, 500);
  if (!keySecret) fail("failed-precondition", "Razorpay is not configured. Contact Helpdesk.");

  const orderRef = db.collection("orders").doc(orderId);
  const [snapshot, config] = await Promise.all([
    orderRef.get(), db.doc("config/payouts").get(),
  ]);
  if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
  const order = snapshot.data() || {};
  if (order.customerId !== context.auth.uid && order.customerUid !== context.auth.uid) {
    fail("permission-denied", "This is not your Quick Care booking.");
  }
  if (order.orderModuleType !== "quickFix") fail("failed-precondition", "This payment option is only for Quick Care bookings.");
  if (!config.exists || config.get("sandboxMode") !== false) {
    fail("failed-precondition", "Turn off test payments after Razorpay credentials are configured.");
  }
  if (!config.exists) fail("failed-precondition", "Add Razorpay settings in Owner → Payments & payouts.");
  const keyId = text(config.get("razorpayKeyId"), 200);
  if (!keyId || !keyId.startsWith("rzp_")) fail("failed-precondition", "Add the Razorpay Key ID in Owner → Payments & payouts.");
  const workflow = text(order.quickCareWorkflowStatus, 40);
  const legacyClaim = quickCareLegacyPartnerPaymentClaim(order);
  if (workflow !== "paymentPending" && !legacyClaim) fail("failed-precondition", "This service is not waiting for customer payment.");
  const {total, due} = quickCarePaymentDue(order);
  if (!Number.isFinite(total) || total <= 0 || due <= 0) fail("failed-precondition", "The final Quick Care payment amount is invalid.");
  const amountPaise = Math.round(due * 100);
  if (!Number.isSafeInteger(amountPaise) || amountPaise <= 0) fail("invalid-argument", "The Quick Care payment amount is invalid.");

  if (order.quickCareGatewayOrderId &&
      Number(order.quickCareGatewayAmountPaise) === amountPaise &&
      order.quickCareGatewayStatus === "created") {
    return {keyId, razorpayOrderId: order.quickCareGatewayOrderId, amountPaise, currency: "INR"};
  }

  const gatewayOrder = await callRazorpay("orders", {
    method: "POST", keyId, keySecret,
    body: {
      amount: amountPaise,
      currency: "INR",
      receipt: `qc_${orderId}`.slice(0, 40),
      notes: {quickCareOrderId: orderId, customerUid: context.auth.uid},
    },
  });
  if (!gatewayOrder.id || Number(gatewayOrder.amount) !== amountPaise || gatewayOrder.currency !== "INR") {
    fail("internal", "Razorpay returned an unexpected order amount.");
  }

  await db.runTransaction(async (tx) => {
    const currentSnapshot = await tx.get(orderRef);
    if (!currentSnapshot.exists) fail("not-found", "Quick Care booking not found.");
    const current = currentSnapshot.data() || {};
    const currentLegacyClaim = quickCareLegacyPartnerPaymentClaim(current);
    if ((current.quickCareWorkflowStatus !== "paymentPending" && !currentLegacyClaim) ||
        (current.customerId !== context.auth.uid && current.customerUid !== context.auth.uid)) {
      fail("failed-precondition", "This service changed while checkout was opening. Refresh and try again.");
    }
    const currentAmount = quickCarePaymentDue(current);
    if (Math.round(currentAmount.due * 100) !== amountPaise) fail("failed-precondition", "The approved amount changed. Refresh before paying.");
    tx.update(orderRef, {
      ...(currentLegacyClaim ? {
        quickCarePartnerReportedPaidAmount: Number(current.amountPaid || current.quickCareFinalAmount || 0),
        quickCarePartnerPaymentUnverified: true,
        quickCareWorkflowStatus: "paymentPending",
        quickCarePaymentStatus: "pending",
        quickCarePaymentFollowupRequired: true,
        amountPaid: 0,
        balanceAmount: total,
        paymentStatus: "unpaid",
      } : {}),
      quickCareGatewayOrderId: gatewayOrder.id,
      quickCareGatewayAmountPaise: amountPaise,
      quickCareGatewayStatus: "created",
      quickCareGatewayOrderCreatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {keyId, razorpayOrderId: gatewayOrder.id, amountPaise, currency: "INR"};
}

async function verifyQuickCareGatewayPayment(data, context) {
  if (!context.auth) fail("unauthenticated", "Sign in to verify payment.");
  const orderId = text(data && data.orderId, 128);
  const gatewayOrderId = text(data && data.razorpayOrderId, 128);
  const paymentId = text(data && data.razorpayPaymentId, 128);
  const signature = text(data && data.razorpaySignature, 256);
  const keySecret = text(process.env.RAZORPAY_KEY_SECRET, 500);
  if (!orderId || !gatewayOrderId || !paymentId || !signature) fail("invalid-argument", "Razorpay payment verification details are incomplete.");
  if (!keySecret) fail("failed-precondition", "Razorpay is not configured. Contact Helpdesk.");
  const orderRef = db.collection("orders").doc(orderId);
  const snapshot = await orderRef.get();
  if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
  const order = snapshot.data() || {};
  if (order.customerId !== context.auth.uid && order.customerUid !== context.auth.uid) fail("permission-denied", "This is not your Quick Care booking.");
  if (order.quickCareGatewayOrderId !== gatewayOrderId) fail("permission-denied", "This Razorpay order does not match your booking.");

  const expected = crypto.createHmac("sha256", keySecret).update(`${gatewayOrderId}|${paymentId}`).digest();
  let supplied;
  try { supplied = Buffer.from(signature, "hex"); } catch (_) { supplied = Buffer.alloc(0); }
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) {
    fail("permission-denied", "Razorpay could not verify this payment. Do not retry a second payment; contact Helpdesk.");
  }
  const config = await db.doc("config/payouts").get();
  if (!config.exists) fail("failed-precondition", "Razorpay settings are not configured. Contact Helpdesk.");
  const keyId = text(config.get("razorpayKeyId"), 200);
  if (!keyId) fail("failed-precondition", "Razorpay settings are not configured. Contact Helpdesk.");
  const payment = await callRazorpay(`payments/${encodeURIComponent(paymentId)}`, {keyId, keySecret});
  if (payment.order_id !== gatewayOrderId ||
      Number(payment.amount) !== Number(order.quickCareGatewayAmountPaise) ||
      payment.currency !== "INR" || payment.status !== "captured") {
    fail("failed-precondition", "Payment is not captured yet. The booking will close after Razorpay confirms capture.");
  }

  await db.runTransaction(async (tx) => {
    const currentSnapshot = await tx.get(orderRef);
    if (!currentSnapshot.exists) fail("not-found", "Quick Care booking not found.");
    const current = currentSnapshot.data() || {};
    if (current.quickCareGatewayPaymentId === paymentId && current.paymentStatus === "fullyPaid") return;
    if (current.quickCareGatewayOrderId !== gatewayOrderId || current.quickCareWorkflowStatus !== "paymentPending") {
      fail("failed-precondition", "This booking is no longer waiting for payment.");
    }
    recordQuickCareCustomerPayment(tx, orderRef, current, {
      provider: "razorpay", method: payment.method || "unknown", paymentId,
      gatewayOrderId, amount: Number(payment.amount) / 100, actorUid: context.auth.uid,
    });
  });
  return {status: "fullyPaid"};
}

async function quickCareRazorpayWebhook(request, response) {
  const secret = text(process.env.RAZORPAY_WEBHOOK_SECRET, 500);
  const signature = text(request.get("x-razorpay-signature"), 256);
  const rawBody = Buffer.isBuffer(request.rawBody) ? request.rawBody : Buffer.from("");
  if (!secret || !signature || rawBody.length === 0) {
    response.status(400).send("Invalid webhook configuration or body.");
    return;
  }
  const expected = crypto.createHmac("sha256", secret).update(rawBody).digest();
  let supplied;
  try { supplied = Buffer.from(signature, "hex"); } catch (_) { supplied = Buffer.alloc(0); }
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) {
    response.status(401).send("Invalid signature.");
    return;
  }
  let event;
  try { event = JSON.parse(rawBody.toString("utf8")); } catch (_) {
    response.status(400).send("Invalid JSON.");
    return;
  }
  const payment = event && event.payload && event.payload.payment && event.payload.payment.entity;
  if (event.event !== "payment.captured" || !payment || !payment.order_id) {
    response.status(200).send("Ignored.");
    return;
  }
  const matches = await db.collection("orders")
      .where("quickCareGatewayOrderId", "==", payment.order_id).limit(1).get();
  if (matches.empty) {
    response.status(200).send("No matching Quick Care order.");
    return;
  }
  const orderRef = matches.docs[0].ref;
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists) return;
    const order = snapshot.data() || {};
    if (order.quickCareGatewayPaymentId === payment.id && order.paymentStatus === "fullyPaid") return;
    if (order.quickCareWorkflowStatus !== "paymentPending" ||
        order.quickCareGatewayOrderId !== payment.order_id ||
        Number(order.quickCareGatewayAmountPaise) !== Number(payment.amount) ||
        payment.currency !== "INR" || payment.status !== "captured") return;
    recordQuickCareCustomerPayment(tx, orderRef, order, {
      provider: "razorpay", method: payment.method || "unknown",
      paymentId: payment.id, gatewayOrderId: payment.order_id,
      amount: Number(payment.amount) / 100, actorUid: null,
    });
  });
  response.status(200).send("OK");
}

exports.createQuickCareGatewayOrder = functions
    .runWith({secrets: ["RAZORPAY_KEY_SECRET"]})
    .https.onCall(createQuickCareGatewayOrder);
exports.verifyQuickCareGatewayPayment = functions
    .runWith({secrets: ["RAZORPAY_KEY_SECRET"]})
    .https.onCall(verifyQuickCareGatewayPayment);
exports.quickCareRazorpayWebhook = functions
    .runWith({secrets: ["RAZORPAY_WEBHOOK_SECRET"]})
    .https.onRequest(quickCareRazorpayWebhook);

exports.completeSandboxQuickCarePayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) fail("unauthenticated", "Sign in to pay.");
  const orderId = text(data && data.orderId, 128);
  const method = text(data && data.paymentMethod, 40);
  if (!orderId || !["card", "upi", "netbanking"].includes(method)) {
    fail("invalid-argument", "A valid booking and payment method are required.");
  }

  const orderRef = db.collection("orders").doc(orderId);
  const configRef = db.doc("config/payouts");
  let paidAmount = 0;
  await db.runTransaction(async (tx) => {
    const [snapshot, config] = await Promise.all([
      tx.get(orderRef), tx.get(configRef),
    ]);
    if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
    const order = snapshot.data() || {};
    if (order.customerId !== context.auth.uid && order.customerUid !== context.auth.uid) {
      fail("permission-denied", "This is not your Quick Care booking.");
    }
    if (order.orderModuleType !== "quickFix") {
      fail("failed-precondition", "This payment option is only for Quick Care bookings.");
    }
    if (config.exists && config.get("sandboxMode") === false) {
      fail("failed-precondition", "Live Quick Care payments are not enabled for this build.");
    }
    const workflow = text(order.quickCareWorkflowStatus, 40);
    if (quickCarePaymentWasGatewayVerified(order) && workflow === "completed" && order.paymentStatus === "fullyPaid") {
      paidAmount = Math.round(Number(order.quickCareFinalAmount || order.price || 0));
      return;
    }
    const legacyClaim = quickCareLegacyPartnerPaymentClaim(order);
    if (workflow !== "paymentPending" && !legacyClaim) {
      fail("failed-precondition", "This booking is not waiting for payment.");
    }

    const {total, due} = quickCarePaymentDue(order);
    if (!Number.isFinite(total) || total <= 0 || due <= 0) {
      fail("failed-precondition", "The final Quick Care amount is invalid.");
    }
    paidAmount = due;
    recordQuickCareCustomerPayment(tx, orderRef, order, {
      provider: "sandbox", method, amount: due, actorUid: context.auth.uid,
    });
    if (legacyClaim) {
      tx.update(orderRef, {
        quickCarePartnerReportedPaidAmount: Number(order.amountPaid || total),
        quickCarePartnerPaymentUnverified: true,
      });
    }
  });
  return {status: "fullyPaid", orderId, amountPaid: paidAmount};
});

exports.attachQuickCareEvidence = functions.https.onCall(async (data, context) => {
  const partner = await requirePartner(context, data && data.partnerAccountId, data && data.partnerProfileId);
  const orderId = text(data && data.orderId, 128);
  const storagePath = text(data && data.storagePath, 500);
  const kind = text(data && data.kind, 20);
  const note = text(data && data.note, 300);
  if (!orderId || !storagePath || !["photo", "audio"].includes(kind)) fail("invalid-argument", "Attach a photo or voice note to this booking.");
  const expectedPrefix = `quickcare_evidence/${orderId}/${context.auth.uid}/`;
  if (!storagePath.startsWith(expectedPrefix)) fail("invalid-argument", "The evidence file path is not valid for this booking.");
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
    const order = snapshot.data() || {};
    if (text(order.quickCareAssignedPartnerAccountId, 128) !== partner.accountId ||
        text(order.quickCareAssignedPartnerProfileId, 128) !== partner.profileId) fail("permission-denied", "Only the assigned QuickCare Partner can attach work evidence.");
    if (!["accepted", "inProgress", "paused", "awaitingCustomerApproval"].includes(text(order.quickCareWorkflowStatus, 40))) fail("failed-precondition", "Evidence can only be added to an active QuickCare booking.");
    if (kind === "photo" && note === "before_work" && text(order.quickCareWorkflowStatus, 40) !== "accepted") {
      fail("failed-precondition", "Before-work photos must be captured after accepting and before starting the work.");
    }
    if (kind === "photo" && note === "after_work" && !["inProgress", "paused"].includes(text(order.quickCareWorkflowStatus, 40))) {
      fail("failed-precondition", "After-work photos can be attached after work has started.");
    }
    if (kind === "photo" && !["before_work", "after_work"].includes(note)) {
      fail("invalid-argument", "Choose whether this is a before-work or after-work photo.");
    }
    const evidence = Array.isArray(order.quickCareEvidence) ? [...order.quickCareEvidence] : [];
    const keepPermanently = quickCareKeepsEvidencePermanently(order);
    const addedAt = new Date();
    evidence.push({
      kind,
      storagePath,
      note: note || null,
      addedAt: addedAt.toISOString(),
      keepPermanently,
      addedByUid: context.auth.uid,
    });
    tx.update(orderRef, {quickCareEvidence: evidence, updatedAt: FieldValue.serverTimestamp()});
    tx.create(orderRef.collection("events").doc(), {type: `quick_care_${kind}_evidence_added`, actorType: "partner", actorUid: context.auth.uid, storagePath, note: note || null, occurredAt: FieldValue.serverTimestamp()});
  });
  return {attached: true};
});

async function approvedQuickCarePartners() {
  const snapshot = await db.collectionGroup("profiles").where("role", "==", "partner").get();
  const partners = [];
  for (const doc of snapshot.docs) {
    const profile = doc.data() || {};
    if (!isApprovedQuickCare(profile)) continue;
    const accountId = doc.ref.parent.parent.id;
    const account = await db.collection("accounts").doc(accountId).get();
    partners.push({accountId, profileId: doc.id, profile, account: account.data() || {}});
  }
  return partners;
}

async function isOnlyApprovedQuickCarePartner(accountId, profileId) {
  const snapshot = await db.collectionGroup("profiles").where("role", "==", "partner").get();
  let approvedCount = 0;
  let isCurrentPartner = false;
  for (const doc of snapshot.docs) {
    if (!isApprovedQuickCare(doc.data() || {})) continue;
    approvedCount += 1;
    if (doc.id === profileId && doc.ref.parent.parent.id === accountId) {
      isCurrentPartner = true;
    }
    if (approvedCount > 1) return false;
  }
  return approvedCount === 1 && isCurrentPartner;
}

exports.getQuickCareAssignmentCandidates = functions.https.onCall(async (data, context) => {
  await requireHelpdesk(context);
  const orderId = text(data && data.orderId, 128);
  const {order} = await getOrder(orderId);
  const candidates = (await approvedQuickCarePartners())
    .map((candidate) => ({
      ...partnerSummary(candidate.accountId, candidate.profileId, candidate.profile, candidate.account),
      ...quickCareMatch(candidate.profile, order),
    }))
    .sort((a, b) => Number(b.eligible) - Number(a.eligible) ||
      Number(b.availableForOrders) - Number(a.availableForOrders) ||
      Number(b.areaMatch) - Number(a.areaMatch) || a.name.localeCompare(b.name));
  return {candidates};
});

exports.assignQuickCarePartner = functions.https.onCall(async (data, context) => {
  const actor = await requireHelpdesk(context);
  const orderId = text(data && data.orderId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const {ref: orderRef} = await getOrder(orderId);
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [account, profile] = await Promise.all([accountRef.get(), profileRef.get()]);
  if (!account.exists || !profile.exists || !isApprovedQuickCare(profile.data() || {})) fail("permission-denied", "Choose an active, approved QuickCare Partner.");
  const partner = {accountId, profileId, profile: profile.data()};
  const match = quickCareMatch(partner.profile, (await getOrder(orderId)).order);
  const allowOverride = data && data.allowOverride === true;
  if (!match.eligible && !allowOverride) {
    fail("failed-precondition", `Partner does not currently match: ${match.reasons.join(", ")}.`);
  }
  await db.runTransaction(async (tx) => {
    const orderSnapshot = await tx.get(orderRef);
    if (!orderSnapshot.exists) fail("not-found", "Quick Care booking not found.");
    const order = orderSnapshot.data() || {};
    const workflow = text(order.quickCareWorkflowStatus, 40);
    if (!["requestSubmitted", "partnerAssigned", "accepted", "paused", "inProgress"].includes(workflow)) fail("failed-precondition", "This booking cannot be reassigned in its current state.");
    if (workflow === "inProgress") fail("failed-precondition", "Pause the current job before reassigning it.");
    const currentMatch = quickCareMatch(partner.profile, order);
    if (!currentMatch.eligible && !allowOverride) fail("failed-precondition", `Partner does not currently match: ${currentMatch.reasons.join(", ")}.`);
    const summary = partnerSummary(accountId, profileId, partner.profile, account.data() || {});
    tx.update(orderRef, {quickCareAssignedPartnerAccountId: accountId, quickCareAssignedPartnerProfileId: profileId, quickCareAssignedPartnerName: summary.name, quickCareAssignedPartnerPhone: summary.phone, quickCareAssignmentStatus: "assigned", quickCareWorkflowStatus: "partnerAssigned", quickCareAssignedAt: FieldValue.serverTimestamp(), quickCareAssignedByUid: actor.uid, quickCareAssignmentOverride: !currentMatch.eligible, quickCareAssignmentOverrideReasons: !currentMatch.eligible ? currentMatch.reasons : FieldValue.delete(), quickCareReassignedAt: workflow === "paused" ? FieldValue.serverTimestamp() : null, updatedAt: FieldValue.serverTimestamp()});
    tx.create(orderRef.collection("events").doc(), {type: "quick_care_partner_assigned", actorType: actor.role, actorUid: actor.uid, partnerAccountId: accountId, partnerProfileId: profileId, override: !currentMatch.eligible, overrideReasons: !currentMatch.eligible ? currentMatch.reasons : [], occurredAt: FieldValue.serverTimestamp()});
  });
  return {assigned: true, partnerName: partnerSummary(accountId, profileId, partner.profile, account.data() || {}).name};
});

exports.respondQuickCareExtraCharge = functions.https.onCall(async (data, context) => {
  if (!context.auth) fail("unauthenticated", "Sign in to respond to the Quick Care quote.");
  const orderId = text(data && data.orderId, 128);
  const approve = data && data.approve === true;
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
    if (text(snapshot.get("customerId") || snapshot.get("customerUid"), 128) !== context.auth.uid) fail("permission-denied", "This is not your Quick Care booking.");
    if (snapshot.get("quickCareExtraChargeStatus") !== "pendingCustomerApproval") fail("failed-precondition", "There is no additional charge waiting for approval.");
    const previousWorkflow = snapshot.get("quickCareWorkflowBeforeExtraCharge");
    const restoredWorkflow = ["paused", "accepted"].includes(previousWorkflow) ? previousWorkflow : "inProgress";
    const isServiceQuote = snapshot.get("quickCareExtraChargeType") === "serviceQuote";
    const updates = {
      quickCareExtraChargeStatus: approve ? "approved" : "declined",
      ...(isServiceQuote ? {quickCareQuoteStatus: approve ? "customerAccepted" : "customerDeclined"} : {}),
      quickCareWorkflowStatus: restoredWorkflow,
      quickCareWorkflowBeforeExtraCharge: FieldValue.delete(),
      quickCareExtraChargeRespondedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (isServiceQuote && approve) {
      const acceptedQuote = Math.round(Number(snapshot.get("quickCareExtraChargeAmount") || 0));
      updates.estimatedPrice = acceptedQuote;
      updates.price = acceptedQuote;
    }
    tx.update(orderRef, updates);
    tx.create(orderRef.collection("events").doc(), {type: approve ? "quick_care_extra_charge_approved" : "quick_care_extra_charge_declined", actorType: "customer", actorUid: context.auth.uid, occurredAt: FieldValue.serverTimestamp()});
  });
  return {approved: approve};
});

exports.submitQuickCareRating = functions.https.onCall(async (data, context) => {
  if (!context.auth) fail("unauthenticated", "Sign in to rate this Quick Care service.");
  const orderId = text(data && data.orderId, 128);
  const rating = Number(data && data.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) fail("invalid-argument", "Choose a rating from 1 to 5 stars.");
  const orderRef = db.collection("orders").doc(orderId);
  const ledgerId = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists || snapshot.get("orderModuleType") !== "quickFix") fail("not-found", "Quick Care booking not found.");
    if (text(snapshot.get("customerId") || snapshot.get("customerUid"), 128) !== context.auth.uid) fail("permission-denied", "This is not your Quick Care booking.");
    if (snapshot.get("quickCareWorkflowStatus") !== "completed") fail("failed-precondition", "Rate the service after it is complete.");
    if (snapshot.get("quickCareCustomerRating") != null) fail("already-exists", "You have already rated this service.");
    const order = snapshot.data() || {};
    const accountId = text(order.quickCareAssignedPartnerAccountId, 128);
    const pointsId = `${accountId}_${orderId}`;
    const pointsRef = db.collection("quickcare_partner_points").doc(pointsId);
    const pointsSnapshot = await tx.get(pointsRef);
    const basePoints = Number(order.quickCarePointsBase || 0);
    const ratingBonusPoints = rating >= 5 ? 10 : rating >= 4 ? 5 : 0;
    const totalPoints = basePoints + ratingBonusPoints;
    tx.update(orderRef, {quickCareCustomerRating: rating, quickCareRatedAt: FieldValue.serverTimestamp(), quickCareRatingBonusPoints: ratingBonusPoints, quickCarePointsPending: totalPoints, updatedAt: FieldValue.serverTimestamp()});
    tx.set(pointsRef, {accountId, profileId: text(order.quickCareAssignedPartnerProfileId, 128), orderId, basePoints, ratingBonusPoints, totalPoints, rating, status: "pendingReview", ratedAt: FieldValue.serverTimestamp(), ...(pointsSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()})}, {merge: true});
    tx.create(orderRef.collection("events").doc(), {type: "quick_care_customer_rated", actorType: "customer", actorUid: context.auth.uid, rating, occurredAt: FieldValue.serverTimestamp()});
    return pointsId;
  });
  return {submitted: true, pointsId: ledgerId};
});
