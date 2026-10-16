const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

const db = admin.firestore();
const SERVER_TIMESTAMP = admin.firestore.FieldValue.serverTimestamp();
const CUSTOMER_DECISION_MS = 24 * 60 * 60 * 1000;
const DEFAULT_TAILOR_OFFER_MINUTES = 30;
const DEFAULT_DISPATCH_START_HOUR = 9;
const DEFAULT_DISPATCH_END_HOUR = 21;
const DEFAULT_DISPATCH_TIME_ZONE = "Asia/Kolkata";
const GOOGLE_CALENDAR_OAUTH_SECRET = "SUISAKHI_GOOGLE_CALENDAR_OAUTH_JSON";

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function asMap(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function normalizedCode(value) {
  return text(value).toUpperCase();
}

function normalizedPincode(value) {
  return text(value).replace(/\s+/g, "").toUpperCase();
}

function normalizedLocationName(value) {
  const normalized = text(value).toLowerCase().replace(/\s+/g, " ");
  return normalized === "aurangabad" ? "chhatrapati sambhajinagar" : normalized;
}

function legacyDeliveryCityState(order, deliveryLocation) {
  if (text(deliveryLocation.cityName || order.deliveryCityName || order.deliveryCity || order.cityName) &&
      text(deliveryLocation.stateName || order.deliveryStateName || order.deliveryState || order.stateName)) {
    return {};
  }

  // Older orders store the formatted address as lines, with its final line
  // formatted as "City, State, Pincode". Use it only when the PIN agrees.
  const lines = text(order.deliveryAddress).split(/\r?\n/)
      .map((line) => line.trim()).filter(Boolean);
  const parts = lines.length ? lines[lines.length - 1].split(",").map((part) => part.trim()) : [];
  const orderPincode = normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode);
  if (parts.length < 3 || !orderPincode || normalizedPincode(parts[parts.length - 1]) !== orderPincode) {
    return {};
  }
  return {
    cityName: parts[parts.length - 3],
    stateName: parts[parts.length - 2],
  };
}

function citywideCoverageMatches(workshop, order) {
  const deliveryLocation = asMap(order.deliveryLocation);
  const legacyLocation = legacyDeliveryCityState(order, deliveryLocation);
  const partnerCityCode = normalizedCode(workshop.cityCode);
  const partnerStateCode = normalizedCode(workshop.stateCode);
  const orderCityCode = normalizedCode(deliveryLocation.cityCode || order.deliveryCityCode || order.cityCode);
  const orderStateCode = normalizedCode(deliveryLocation.stateCode || order.deliveryStateCode || order.stateCode);

  if (partnerCityCode && partnerStateCode && orderCityCode && orderStateCode) {
    return partnerCityCode === orderCityCode && partnerStateCode === orderStateCode;
  }

  const partnerCity = normalizedLocationName(workshop.city || workshop.cityName);
  const partnerState = normalizedLocationName(workshop.state || workshop.stateName);
  const orderCity = normalizedLocationName(
      deliveryLocation.cityName || order.deliveryCityName || order.deliveryCity || order.cityName || legacyLocation.cityName);
  const orderState = normalizedLocationName(
      deliveryLocation.stateName || order.deliveryStateName || order.deliveryState || order.stateName || legacyLocation.stateName);
  return Boolean(partnerCity && partnerState && orderCity && orderState &&
      partnerCity === orderCity && partnerState === orderState);
}

function profileKey(accountId, profileId) {
  return `${accountId}__${profileId}`;
}

function capacityRefFor(accountId, profileId, dateKey) {
  return db.collection("tailor_capacity").doc(`${profileKey(accountId, profileId)}__${dateKey}`);
}

function reservationRefFor(orderId) {
  return db.collection("tailor_capacity_reservations").doc(orderId);
}

function offerRefFor(accountId, profileId, offerId) {
  return db.collection("accounts").doc(accountId)
      .collection("profiles").doc(profileId)
      .collection("order_offers").doc(offerId);
}

function eventRefFor(orderId) {
  return db.collection("orders").doc(orderId).collection("events").doc();
}

function eventData(type, actor, details = {}) {
  return {
    type,
    actor,
    details,
    occurredAt: SERVER_TIMESTAMP,
    createdAt: SERVER_TIMESTAMP,
  };
}

function partnerTailorData(profile) {
  const partnerData = asMap(profile.partnerData);
  const extensions = asMap(partnerData.extensions);
  return asMap(extensions.tailor);
}

function profileIsApprovedTailor(profile) {
  return Boolean(profile && profile.role === "partner" && profile.partnerType === "tailor" &&
    profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified");
}

function profileIsApprovedMeasurementPartner(profile) {
  return Boolean(profile && profile.role === "partner" && profile.partnerType === "measurementPartner" &&
    profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified");
}

function measurementPartnerDetails(profile) {
  const partnerData = asMap(profile && profile.partnerData);
  const extensions = asMap(partnerData.extensions);
  return asMap(extensions.measurementPartner);
}

function measurementPartnerCoversOrder(profile, order) {
  const details = measurementPartnerDetails(profile);
  const serviceLocation = asMap(details.serviceLocation);
  const declaredAreas = Array.isArray(serviceLocation.serviceAreaPincodes) ?
    serviceLocation.serviceAreaPincodes.map(normalizedPincode).filter(Boolean) : [];
  const orderLocation = asMap(order.deliveryLocation);
  const orderPincode = normalizedPincode(order.deliveryPincode || orderLocation.pincode || order.pincode);
  return declaredAreas.length === 0 || declaredAreas.includes("ANY") ||
    Boolean(orderPincode && declaredAreas.includes(orderPincode));
}

function measurementPartnerSupportsMethod(profile, method) {
  const details = measurementPartnerDetails(profile);
  const capabilities = asMap(details.capabilities);
  const codes = Array.isArray(capabilities.declaredCapabilityCodes) ?
    capabilities.declaredCapabilityCodes.map(text).filter(Boolean) : [];
  // Capabilities were optional during the initial application phase. Keep
  // approved profiles without declarations eligible, while honoring explicit
  // service selections.
  if (codes.length === 0) return true;
  if (method === "measurement_partner_home_visit" || method === "tailor_home_visit") {
    return codes.includes("measurement.homeVisit") || codes.includes("measurement.measurementAndPickup");
  }
  if (method === "video_appointment") return codes.includes("measurement.videoAssisted");
  return false;
}

function measurementCriteriaForOrder(order) {
  // Keep this catalogue aligned with the 22 numbered measurements in the
  // SuiSakhi Universal Women's Measurement Chart. Order-specific selections
  // can identify the garment type, but the Partner can leave every field blank.
  return [
    "01 · Neck (circumference)",
    "02 · Over Bust (upper bust)",
    "03 · Bust (full bust)",
    "04 · Under Bust",
    "05 · Waist",
    "06 · Hips",
    "07 · Neck to Heel (total height)",
    "08 · Neck to Above Knee (front)",
    "09 · Above Knee to Ankle",
    "10 · Arm Length (shoulder to wrist)",
    "11 · Shoulder Seam (neck to shoulder point)",
    "12 · Arm Hole (armpit circumference)",
    "13 · Bicep (upper arm)",
    "14 · Forearm",
    "15 · Wrist",
    "16 · V Neck Cut (front neck depth)",
    "17 · Shoulder to Waist (front)",
    "18 · Waist to Above Knee (kurti/top length)",
    "19 · Shoulder Width (left to right)",
    "20 · Upper Back",
    "21 · Mid Back (under bust line)",
    "22 · Waist Back",
  ];
}

function measurementHistoryEntry(order, reason) {
  const submittedValues = asMap(order.measurementSubmittedValues);
  if (order.measurementStatus !== "partner_completed" && order.measurementStatus !== "completed" &&
      !order.measurementConfirmedAt && Object.keys(submittedValues).length === 0) return null;
  return {
    reason,
    status: text(order.measurementStatus),
    method: text(order.measurementMethod),
    submittedValues,
    submittedUnit: text(order.measurementSubmittedUnit) || "in",
    partnerNote: text(order.measurementPartnerCompletionNote),
    partnerAccountId: text(order.measurementPartnerCompletedByAccountId || order.measurementPartnerAccountId),
    partnerProfileId: text(order.measurementPartnerCompletedByProfileId || order.measurementPartnerProfileId),
    partnerCompletedAt: order.measurementPartnerCompletedAt || null,
    confirmedAt: order.measurementConfirmedAt || null,
    confirmedByAccountId: text(order.measurementConfirmedByAccountId),
    confirmedByProfileId: text(order.measurementConfirmedByProfileId),
    recordedAt: admin.firestore.Timestamp.now(),
  };
}

function archiveMeasurementPartnerSubmission(transaction, order, orderId, accountId, profileId, measurement, fallbackMillis) {
  if (!accountId || !profileId || !measurement) return;
  const completedAt = measurement.partnerCompletedAt || order.measurementPartnerCompletedAt || null;
  const completedAtMillis = completedAt && typeof completedAt.toMillis === "function" ?
    completedAt.toMillis() : fallbackMillis;
  const deliveryLocation = asMap(order.deliveryLocation);
  const historyRef = db.collection("accounts").doc(accountId)
      .collection("measurement_history").doc(`measurement_${orderId}_${completedAtMillis}`);
  transaction.set(historyRef, {
    orderId,
    orderTrackingId: text(order.orderTrackingId),
    profileId,
    customerName: text(order.personName || order.clientName || order.customerName || "Customer"),
    customerPhone: text(order.customerPhone || order.phone || order.mobileE164),
    dressType: text(order.dressType || "Tailoring order"),
    designTemplateTitle: text(order.designTemplateTitle || order.designTitle),
    designImageUrl: text(order.designImageUrl || order.designTemplateImageUrl || order.designImage),
    fabricChoice: text(order.fabricChoice || order.fabricType || order.materialType || order.materialName),
    fabricDescription: text(order.fabricDescription || order.materialDescription || order.materialNotes),
    deliveryAddress: text(order.deliveryAddress || deliveryLocation.address || deliveryLocation.fullAddress),
    deliveryPincode: normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode),
    measurementMethod: text(order.measurementMethod),
    measurementAppointmentAt: order.measurementAppointmentAt || null,
    measurementNotes: text(order.measurementNotes),
    measurementCriteria: measurementCriteriaForOrder(order),
    measurementSubmittedValues: measurement.submittedValues || {},
    measurementSubmittedUnit: text(measurement.submittedUnit) || "in",
    measurementPartnerCompletionNote: text(measurement.partnerNote),
    measurementPartnerCompletedAt: completedAt,
    orderStatusAtCompletion: text(order.status),
    createdAt: measurement.recordedAt || completedAt || SERVER_TIMESTAMP,
  });
}

function profileServiceAreas(profile, partnerType) {
  const partnerData = asMap(profile && profile.partnerData);
  const extensions = asMap(partnerData.extensions);
  const extension = asMap(extensions[partnerType]);
  const workshop = asMap(extension.workshopDetails);
  const details = partnerType === "measurementPartner" ?
    asMap(extensions.measurementPartner) : extension;
  const serviceLocation = asMap(details.serviceLocation);
  const values = [
    ...(Array.isArray(workshop.serviceAreaPincodes) ? workshop.serviceAreaPincodes : []),
    ...(Array.isArray(serviceLocation.serviceAreaPincodes) ? serviceLocation.serviceAreaPincodes : []),
  ];
  if (typeof details.serviceArea === "string") values.push(...details.serviceArea.split(/[\s,;]+/));
  return Array.from(new Set(values.map(normalizedPincode).filter(Boolean)));
}

function profileServesOrderPin(profile, partnerType, order) {
  const areas = profileServiceAreas(profile, partnerType);
  const location = asMap(order.deliveryLocation);
  const orderPin = normalizedPincode(order.deliveryPincode || location.pincode || order.pincode);
  if (!orderPin) return false;
  if (areas.includes("ANY") || areas.includes(orderPin)) return true;
  const extension = asMap(asMap(profile.partnerData).extensions)[partnerType];
  const workshop = asMap(asMap(extension).workshopDetails);
  const serviceLocation = asMap(asMap(extension).serviceLocation);
  const address = asMap(serviceLocation.address);
  const addressPin = normalizedPincode(workshop.pincode || serviceLocation.pincode || address.pincode);
  return addressPin === orderPin;
}

function tailorCanFulfill(profile, direction) {
  if (!profileIsApprovedTailor(profile)) return false;
  const workshop = asMap(partnerTailorData(profile).workshopDetails);
  return direction === "inbound" ? workshop.pickupAvailable === true : workshop.deliveryAvailable === true;
}

function measurementPartnerCanFulfill(profile, direction, order) {
  if (!profileIsApprovedMeasurementPartner(profile) || !profileServesOrderPin(profile, "measurementPartner", order)) {
    return false;
  }
  const details = measurementPartnerDetails(profile);
  const capabilities = asMap(details.capabilities);
  const codes = Array.isArray(capabilities.declaredCapabilityCodes) ?
    capabilities.declaredCapabilityCodes.map(text).filter(Boolean) : [];
  const inboundCodes = [
    "measurement.measurementAndPickup",
    "measurement.pickupAndDrop",
    "measurement.referenceGarmentPickup",
    "measurementPartner.pickupDelivery",
  ];
  const outboundCodes = ["measurement.pickupAndDrop", "measurementPartner.pickupDelivery"];
  return (direction === "inbound" ? inboundCodes : outboundCodes).some((code) => codes.includes(code));
}

function deliveryPartnerCanFulfill(profile, direction, order) {
  if (!profileIsApprovedDeliveryPartner(profile) || !profileServesOrderPin(profile, "deliveryPartner", order)) {
    return false;
  }
  const partnerData = asMap(profile.partnerData);
  const extension = asMap(asMap(partnerData.extensions).deliveryPartner);
  const capabilities = asMap(extension.capabilities);
  const codes = Array.isArray(capabilities.declaredCapabilityCodes) ?
    capabilities.declaredCapabilityCodes.map(text).filter(Boolean) : [];
  const accepted = direction === "inbound" ?
    ["deliveryPartner.customerPickup", "deliveryPartner.pickupDelivery"] :
    ["deliveryPartner.customerDelivery", "deliveryPartner.pickupDelivery"];
  return codes.length === 0 || accepted.some((code) => codes.includes(code));
}

function deliveryPinHash(pin) {
  return crypto.createHash("sha256").update(pin).digest("hex");
}

function newDeliveryPin() {
  return String(crypto.randomInt(1000, 10000));
}

function outboundAssignmentIsAvailable(order) {
  return order.assignmentVersion === "v1" && order.orderModuleType === "coreTailoring" &&
    order.assignmentStatus === "finalized" && order.status === "readyForPickup" &&
    order.paymentStatus === "fullyPaid" &&
    ["awaiting_assignment", "assigned"].includes(text(order.outboundHandoverStatus)) &&
    !order.outboundHandoverAcceptedAt;
}

async function outboundHandoverCandidates(order) {
  const declinedKeys = new Set(Array.isArray(order.outboundHandoverDeclinedPartnerKeys) ?
    order.outboundHandoverDeclinedPartnerKeys.map(text) : []);
  const [tailors, measurementPartners, deliveryPartners] = await Promise.all([
    db.collectionGroup("profiles").where("partnerType", "==", "tailor").get(),
    db.collectionGroup("profiles").where("partnerType", "==", "measurementPartner").get(),
    db.collectionGroup("profiles").where("partnerType", "==", "deliveryPartner").get(),
  ]);
  const candidates = (await Promise.all([
    ...tailors.docs.map(async (snapshot) => {
      const profile = snapshot.data() || {};
      if (!tailorCanFulfill(profile, "outbound") || !profileCoversOrder(profile, order)) return null;
      return profileAdminSummary(snapshot);
    }),
    ...measurementPartners.docs.map(async (snapshot) => {
      if (!measurementPartnerCanFulfill(snapshot.data() || {}, "outbound", order)) return null;
      return profileAdminSummary(snapshot);
    }),
    ...deliveryPartners.docs.map(async (snapshot) => {
      if (!deliveryPartnerCanFulfill(snapshot.data() || {}, "outbound", order)) return null;
      return profileAdminSummary(snapshot);
    }),
  ])).filter((candidate) => candidate &&
    !declinedKeys.has(profileKey(candidate.accountId, candidate.profileId)));
  const pickupKey = profileKey(order.inboundPickupPartnerAccountId, order.inboundPickupPartnerProfileId);
  const assignedKey = profileKey(order.outboundHandoverPartnerAccountId, order.outboundHandoverPartnerProfileId);
  candidates.sort((left, right) => {
    const leftKey = profileKey(left.accountId, left.profileId);
    const rightKey = profileKey(right.accountId, right.profileId);
    const leftRank = leftKey === pickupKey ? 0 : leftKey === assignedKey ? 1 : 2;
    const rightRank = rightKey === pickupKey ? 0 : rightKey === assignedKey ? 1 : 2;
    return leftRank - rightRank || left.displayName.localeCompare(right.displayName);
  });
  return candidates;
}

function outboundPartnerCanFulfill(partnerType, profile, order) {
  return partnerType === "tailor" ?
    tailorCanFulfill(profile, "outbound") && profileCoversOrder(profile, order) :
    partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, "outbound", order) :
    partnerType === "deliveryPartner" ? deliveryPartnerCanFulfill(profile, "outbound", order) : false;
}

async function findFulfillmentPartner(order, direction) {
  const declinedKeys = new Set(Array.isArray(order[direction === "inbound" ? "inboundPickupDeclinedPartnerKeys" : "outboundHandoverDeclinedPartnerKeys"]) ?
    order[direction === "inbound" ? "inboundPickupDeclinedPartnerKeys" : "outboundHandoverDeclinedPartnerKeys"].map(text) : []);
  // On the return leg, prefer the partner who collected the garment when that
  // same profile is still approved, serves the order PIN, and can deliver.
  // If not, keep measurement and garment logistics with the same Partner,
  // followed by the Tailor's own Delivery Partner profile, the Tailor profile,
  // and finally an eligible Delivery Partner for the area.
  if (direction === "outbound") {
    const pickupAccountId = text(order.inboundPickupPartnerAccountId);
    const pickupProfileId = text(order.inboundPickupPartnerProfileId);
    if (pickupAccountId && pickupProfileId &&
        !declinedKeys.has(profileKey(pickupAccountId, pickupProfileId))) {
      const ref = db.collection("accounts").doc(pickupAccountId).collection("profiles").doc(pickupProfileId);
      const snapshot = await ref.get();
      const profile = snapshot.exists ? snapshot.data() || {} : {};
      const partnerType = text(order.inboundPickupPartnerType) || text(profile.partnerType);
      const eligible = partnerType === "tailor" ?
        tailorCanFulfill(profile, direction) && profileCoversOrder(profile, order) :
        partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, direction, order) :
        partnerType === "deliveryPartner" ? deliveryPartnerCanFulfill(profile, direction, order) : false;
      if (snapshot.exists && eligible) {
        return {accountId: pickupAccountId, profileId: pickupProfileId, partnerType};
      }
    }
  }

  const measurementAccountId = text(order.measurementPartnerAccountId);
  const measurementProfileId = text(order.measurementPartnerProfileId);
  if (measurementAccountId && measurementProfileId) {
    const ref = db.collection("accounts").doc(measurementAccountId).collection("profiles").doc(measurementProfileId);
    const snapshot = await ref.get();
    if (!declinedKeys.has(profileKey(measurementAccountId, measurementProfileId)) && snapshot.exists &&
        measurementPartnerCanFulfill(snapshot.data() || {}, direction, order)) {
      return {accountId: measurementAccountId, profileId: measurementProfileId, partnerType: "measurementPartner"};
    }
  }

  const tailorAccountId = text(order.assignedTailorAccountId);
  const tailorProfileId = text(order.assignedTailorProfileId);
  // If the Tailor also registered a separate Delivery Partner profile, prefer
  // that approved service profile before routing to another area partner.
  if (tailorAccountId) {
    const ownDeliveryProfiles = await db.collection("accounts").doc(tailorAccountId)
        .collection("profiles").where("partnerType", "==", "deliveryPartner").get();
    const ownDeliveryProfile = ownDeliveryProfiles.docs.find((snapshot) =>
      !declinedKeys.has(profileKey(tailorAccountId, snapshot.id)) &&
      deliveryPartnerCanFulfill(snapshot.data() || {}, direction, order));
    if (ownDeliveryProfile) {
      return {accountId: tailorAccountId, profileId: ownDeliveryProfile.id, partnerType: "deliveryPartner"};
    }
  }

  if (tailorAccountId && tailorProfileId) {
    const ref = db.collection("accounts").doc(tailorAccountId).collection("profiles").doc(tailorProfileId);
    const snapshot = await ref.get();
    if (!declinedKeys.has(profileKey(tailorAccountId, tailorProfileId)) && snapshot.exists &&
        tailorCanFulfill(snapshot.data() || {}, direction) && profileCoversOrder(snapshot.data() || {}, order)) {
      return {accountId: tailorAccountId, profileId: tailorProfileId, partnerType: "tailor"};
    }
  }

  const profiles = await db.collectionGroup("profiles").where("partnerType", "==", "deliveryPartner").get();
  const candidates = profiles.docs.filter((snapshot) => {
    const accountRef = snapshot.ref.parent.parent;
    const candidateKey = profileKey(accountRef ? accountRef.id : text(snapshot.get("accountId")), snapshot.id);
    return !declinedKeys.has(candidateKey) && deliveryPartnerCanFulfill(snapshot.data() || {}, direction, order);
  });
  candidates.sort((left, right) => {
    const leftTime = routingRegistrationTime(left.data() || {});
    const rightTime = routingRegistrationTime(right.data() || {});
    return leftTime - rightTime || left.id.localeCompare(right.id);
  });
  const selected = candidates[0];
  if (!selected) return null;
  const accountRef = selected.ref.parent.parent;
  return {accountId: accountRef ? accountRef.id : text(selected.get("accountId")), profileId: selected.id, partnerType: "deliveryPartner"};
}

async function assignInboundFulfillment(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  const snapshot = await orderRef.get();
  if (!snapshot.exists) return null;
  const order = snapshot.data() || {};
  if (order.assignmentVersion !== "v1" || order.assignmentStatus !== "finalized" ||
      !["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
      !["awaiting_assignment", "assigned"].includes(text(order.inboundPickupStatus)) ||
      (text(order.inboundPickupAssignedBy) && text(order.inboundPickupAssignedBy) !== "system")) return null;
  const partner = await findFulfillmentPartner(order, "inbound");
  if (!partner) return null;
  const previous = {
    partnerType: text(order.inboundPickupPartnerType),
    accountId: text(order.inboundPickupPartnerAccountId),
    profileId: text(order.inboundPickupPartnerProfileId),
  };
  if (previous.partnerType === partner.partnerType && previous.accountId === partner.accountId && previous.profileId === partner.profileId) {
    return partner;
  }
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(orderRef);
    if (!current.exists) return;
    const currentOrder = current.data() || {};
    if (currentOrder.assignmentStatus !== "finalized" ||
        !["advancePaid", "fullyPaid"].includes(currentOrder.paymentStatus) ||
        !["awaiting_assignment", "assigned"].includes(text(currentOrder.inboundPickupStatus)) ||
        (text(currentOrder.inboundPickupAssignedBy) && text(currentOrder.inboundPickupAssignedBy) !== "system")) return;
    const oldType = text(currentOrder.inboundPickupPartnerType);
    const oldAccount = text(currentOrder.inboundPickupPartnerAccountId);
    const oldProfile = text(currentOrder.inboundPickupPartnerProfileId);
    if (oldType === partner.partnerType && oldAccount === partner.accountId && oldProfile === partner.profileId) return;
    transaction.update(orderRef, {
      inboundPickupStatus: "assigned",
      inboundPickupPartnerType: partner.partnerType,
      inboundPickupPartnerAccountId: partner.accountId,
      inboundPickupPartnerProfileId: partner.profileId,
      inboundPickupAssignedAt: SERVER_TIMESTAMP,
      inboundPickupAssignedBy: "system",
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("inbound_pickup_assigned", "system", {
      partnerType: partner.partnerType,
      accountId: partner.accountId,
      profileId: partner.profileId,
      previousPartnerType: oldType || null,
      previousAccountId: oldAccount || null,
      previousProfileId: oldProfile || null,
    }));
  });
  return partner;
}

async function assignOutboundFulfillment(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  const snapshot = await orderRef.get();
  if (!snapshot.exists) return null;
  const order = snapshot.data() || {};
  if (order.assignmentVersion !== "v1" || order.assignmentStatus !== "finalized" ||
      order.status !== "readyForPickup" || order.paymentStatus !== "fullyPaid" ||
      order.outboundHandoverStatus === "delivered" || order.outboundHandoverAcceptedAt) return null;
  const partner = await findFulfillmentPartner(order, "outbound");
  if (!partner) return null;
  const previous = {
    partnerType: text(order.outboundHandoverPartnerType),
    accountId: text(order.outboundHandoverPartnerAccountId),
    profileId: text(order.outboundHandoverPartnerProfileId),
  };
  const deliveryPinRef = orderRef.collection("private").doc("delivery_pin");
  const existingPinSnapshot = await deliveryPinRef.get();
  if (previous.partnerType === partner.partnerType && previous.accountId === partner.accountId &&
      previous.profileId === partner.profileId && order.deliveryPinGeneratedAt &&
      !order.deliveryPinHash &&
      existingPinSnapshot.exists &&
      existingPinSnapshot.get("assignedPartnerAccountId") === partner.accountId &&
      existingPinSnapshot.get("assignedPartnerProfileId") === partner.profileId &&
      /^\d{4}$/.test(text(existingPinSnapshot.get("pin"))) &&
      text(existingPinSnapshot.get("pinHash"))) {
    return partner;
  }
  const deliveryPin = newDeliveryPin();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(orderRef);
    if (!current.exists) return;
    const currentOrder = current.data() || {};
    if (currentOrder.assignmentStatus !== "finalized" || currentOrder.status !== "readyForPickup" ||
        currentOrder.paymentStatus !== "fullyPaid" || currentOrder.outboundHandoverAcceptedAt) return;
    const oldType = text(currentOrder.outboundHandoverPartnerType);
    const oldAccount = text(currentOrder.outboundHandoverPartnerAccountId);
    const oldProfile = text(currentOrder.outboundHandoverPartnerProfileId);
    transaction.update(orderRef, {
      outboundHandoverStatus: "assigned",
      outboundHandoverPartnerType: partner.partnerType,
      outboundHandoverPartnerAccountId: partner.accountId,
      outboundHandoverPartnerProfileId: partner.profileId,
      outboundHandoverAssignedAt: SERVER_TIMESTAMP,
      deliveryPartnerAccountId: partner.accountId,
      deliveryPartnerProfileId: partner.profileId,
      deliveryPartnerType: partner.partnerType,
      // Older builds stored a low-entropy PIN hash on the customer-readable
      // order document. Keep the secret only in the denied /private subcollection.
      deliveryPinHash: admin.firestore.FieldValue.delete(),
      deliveryPinGeneratedAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(deliveryPinRef, {
      customerId: text(currentOrder.customerId),
      orderId,
      pin: deliveryPin,
      pinHash: deliveryPinHash(deliveryPin),
      assignedPartnerAccountId: partner.accountId,
      assignedPartnerProfileId: partner.profileId,
      createdAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("outbound_handover_assigned", "system", {
      partnerType: partner.partnerType,
      accountId: partner.accountId,
      profileId: partner.profileId,
      previousPartnerType: oldType || null,
      previousAccountId: oldAccount || null,
      previousProfileId: oldProfile || null,
    }));
  });
  return partner;
}

function profileCoversOrder(profile, order) {
  if (!profileIsApprovedTailor(profile)) return false;
  const deliveryLocation = asMap(order.deliveryLocation);
  const deliveryPincode = normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode);
  if (!deliveryPincode) return false;
  const workshop = asMap(partnerTailorData(profile).workshopDetails);
  const declaredAreas = Array.isArray(workshop.serviceAreaPincodes) ?
    workshop.serviceAreaPincodes.map(normalizedPincode).filter(Boolean) : [];
  const explicitPincodes = declaredAreas.filter((area) => area !== "ANY");
  if (explicitPincodes.length > 0) {
    // An explicit PIN list replaces citywide coverage, even if a stale list
    // also contains ANY.
    return explicitPincodes.includes(deliveryPincode);
  }
  // Blank coverage is the default ANY setting, including legacy profiles with
  // a stale serviceCoverageMode of "pincodes".
  return declaredAreas.includes("ANY") || declaredAreas.length === 0 ?
    citywideCoverageMatches(workshop, order) : false;
}

function candidateIsEligible(profile, order) {
  if (!profile || profile.role !== "partner" || profile.partnerType !== "tailor") return false;
  return profile.availabilityStatus === "available" && profileCoversOrder(profile, order);
}

function routingAreaId(order) {
  const location = asMap(order.deliveryLocation);
  const legacy = legacyDeliveryCityState(order, location);
  const pieces = [
    normalizedCode(location.countryCode || order.countryCode || "IN"),
    normalizedCode(location.stateCode || order.deliveryStateCode || order.stateCode || location.stateName || order.deliveryState || order.stateName || legacy.stateName),
    normalizedCode(location.cityCode || order.deliveryCityCode || order.cityCode || location.cityName || order.deliveryCity || order.cityName || legacy.cityName),
    normalizedPincode(order.deliveryPincode || location.pincode || order.pincode),
  ];
  return pieces.map((piece) => piece.replace(/[^A-Z0-9_-]/g, "_")).join("_");
}

function dateMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value && typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return 0;
}

function routingRegistrationTime(profile) {
  return dateMillis(profile.registeredAt) || dateMillis(profile.createdAt) ||
    dateMillis(profile.activatedAt) || dateMillis(profile.approvedAt);
}

function candidateKey(candidate) {
  return `${text(candidate.accountId)}__${text(candidate.profileId)}`;
}

function normalizedContactNumber(value) {
  const compact = text(value).trim().replace(/[\s().-]/g, "");
  if (/^\d{10}$/.test(compact)) return `+91${compact}`;
  return /^\+\d{8,15}$/.test(compact) ? compact : "";
}

function additionalContactPhones(profile, account, primaryPhone) {
  const sources = [
    profile.additionalContactNumbers,
    profile.alternateContactNumbers,
    profile.alternateMobileE164,
    profile.alternatePhone,
    account.additionalContactNumbers,
    account.alternateContactNumbers,
    account.alternateMobileE164,
    account.alternatePhone,
  ];
  const primaryDigits = normalizedContactNumber(primaryPhone).replace(/\D/g, "");
  const values = sources.flatMap((source) => Array.isArray(source) ? source : [source]);
  const seen = new Set(primaryDigits ? [primaryDigits] : []);
  return values.map(normalizedContactNumber).filter((number) => {
    if (!number) return false;
    const digits = number.replace(/\D/g, "");
    if (seen.has(digits)) return false;
    seen.add(digits);
    return true;
  });
}

function profileSummary(profileSnapshot) {
  const profile = profileSnapshot.data() || {};
  const accountRef = profileSnapshot.ref.parent.parent;
  const accountId = accountRef ? accountRef.id : text(profile.accountId);
  const profileId = profileSnapshot.id;
  const partnerData = asMap(profile.partnerData);
  const tailorData = partnerTailorData(profile);
  const capabilities = asMap(tailorData.capabilities);
  const workshop = asMap(tailorData.workshopDetails || partnerData.workshopDetails);
  const address = asMap(workshop.businessAddress || workshop.address || profile.businessAddress || profile.address);
  const serviceAreaPincodes = Array.isArray(workshop.serviceAreaPincodes)
    ? workshop.serviceAreaPincodes.map(text).filter(Boolean)
    : [];
  return {
    accountId,
    profileId,
    displayName: text(profile.businessName || profile.displayName || profile.name || profile.shopName || "Tailor"),
    businessName: text(profile.businessName || profile.shopName),
    contactName: text(profile.contactName),
    partnerType: text(profile.partnerType),
    email: text(profile.email),
    availabilityStatus: text(profile.availabilityStatus || "unavailable"),
    operationalStatus: text(profile.operationalStatus || profile.status),
    approvalStatus: text(profile.approvalStatus),
    kycStatus: text(profile.kycStatus),
    registrationAt: routingRegistrationTime(profile),
    serviceAreaPincodes,
    serviceCoverageMode: text(workshop.serviceCoverageMode) || (serviceAreaPincodes.length ? "explicit" : "any"),
    cityCode: text(workshop.cityCode),
    city: text(workshop.city || workshop.cityName),
    stateCode: text(workshop.stateCode),
    state: text(workshop.state || workshop.stateName),
    workshopType: text(workshop.workshopType || workshop.workshopTypeCode),
    experienceYears: Number(workshop.experienceYears || workshop.experience || 0),
    teamSize: Number(workshop.teamSize || 0),
    normalDailyCapacity: Number(workshop.normalDailyCapacity || 0),
    peakDailyCapacity: Number(workshop.peakDailyCapacity || 0),
    machineCodes: Array.isArray(workshop.machineCodes) ? workshop.machineCodes.map(text).filter(Boolean) : [],
    capabilityCodes: Array.isArray(capabilities.declaredCapabilityCodes) ? capabilities.declaredCapabilityCodes.map(text).filter(Boolean) : [],
    additionalCapabilityDescriptions: Array.isArray(capabilities.additionalCapabilityDescriptions) ? capabilities.additionalCapabilityDescriptions.map(text).filter(Boolean) : [],
    businessAddress: {
      addressLine1: text(address.addressLine1 || workshop.addressLine1 || profile.addressLine1),
      addressLine2: text(address.addressLine2 || workshop.addressLine2),
      locality: text(address.locality || workshop.locality),
      city: text(address.city || address.cityName || workshop.city || workshop.cityName),
      state: text(address.state || address.stateName || workshop.state || workshop.stateName),
      pincode: normalizedPincode(address.pincode || workshop.pincode),
    },
  };
}

async function profileAdminSummary(profileSnapshot) {
  if (!profileSnapshot || !profileSnapshot.exists) return null;
  const accountRef = profileSnapshot.ref.parent.parent;
  const profile = profileSnapshot.data() || {};
  const hasProfileAlternateNumbers = Array.isArray(profile.additionalContactNumbers) ||
    Array.isArray(profile.alternateContactNumbers) ||
    Boolean(profile.alternateMobileE164 || profile.alternatePhone);
  const hasProfilePrimaryNumber = Boolean(profile.mobileE164 || profile.phone);
  const accountSnapshot = accountRef && (!hasProfileAlternateNumbers || !hasProfilePrimaryNumber)
    ? await accountRef.get()
    : null;
  const account = accountSnapshot && accountSnapshot.exists ? accountSnapshot.data() || {} : {};
  const summary = profileSummary(profileSnapshot);
  summary.contactPhone = normalizedContactNumber(
    account.mobileE164 || account.phoneNumber || profile.mobileE164 || profile.phone,
  );
  summary.additionalContactPhones = additionalContactPhones(profile, account, summary.contactPhone);
  return summary;
}

async function offerSlaMinutes(order) {
  const configSnap = await db.doc("config/order_assignment").get();
  const config = configSnap.data() || {};
  const configured = Number(config.defaultTailorOfferMinutes || DEFAULT_TAILOR_OFFER_MINUTES);
  return Number.isFinite(configured) ? Math.max(5, Math.min(1440, Math.floor(configured))) : DEFAULT_TAILOR_OFFER_MINUTES;
}

async function dispatchConfig() {
  const configSnap = await db.doc("config/order_assignment").get();
  const config = configSnap.data() || {};
  const startHour = Number(config.dispatchStartHour ?? DEFAULT_DISPATCH_START_HOUR);
  const endHour = Number(config.dispatchEndHour ?? DEFAULT_DISPATCH_END_HOUR);
  return {
    startHour: Number.isInteger(startHour) ? Math.max(0, Math.min(23, startHour)) : DEFAULT_DISPATCH_START_HOUR,
    endHour: Number.isInteger(endHour) ? Math.max(1, Math.min(24, endHour)) : DEFAULT_DISPATCH_END_HOUR,
    timeZone: text(config.dispatchTimeZone) || DEFAULT_DISPATCH_TIME_ZONE,
  };
}

function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  return Object.fromEntries(parts.filter((part) => part.type !== "literal").map((part) => [part.type, Number(part.value)]));
}

function isDispatchOpen(date, config) {
  const parts = zonedParts(date, config.timeZone);
  const minuteOfDay = parts.hour * 60 + parts.minute;
  return minuteOfDay >= config.startHour * 60 && minuteOfDay < config.endHour * 60;
}

function localTimeToUtc(year, month, day, hour, minute, timeZone) {
  const targetAsUtc = Date.UTC(year, month - 1, day, hour, minute);
  let guess = targetAsUtc;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const parts = zonedParts(new Date(guess), timeZone);
    const representedAsUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute);
    guess += targetAsUtc - representedAsUtc;
  }
  return new Date(guess);
}

function nextDispatchOpening(date, config) {
  const parts = zonedParts(date, config.timeZone);
  const openToday = localTimeToUtc(parts.year, parts.month, parts.day, config.startHour, 0, config.timeZone);
  if (date < openToday) return openToday;
  const tomorrow = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + 1));
  return localTimeToUtc(tomorrow.getUTCFullYear(), tomorrow.getUTCMonth() + 1, tomorrow.getUTCDate(), config.startHour, 0, config.timeZone);
}

function customerDecisionDeadline(acceptedAt, config) {
  const deadline = new Date(acceptedAt.getTime() + CUSTOMER_DECISION_MS);
  return isDispatchOpen(deadline, config) ? deadline : nextDispatchOpening(deadline, config);
}

async function isConfiguredAdmin(context) {
  if (!context.auth) return false;
  const configSnap = await db.doc("config/admin").get();
  const adminUids = configSnap.get("adminUids");
  return Array.isArray(adminUids) && adminUids.includes(context.auth.uid);
}

async function requireConfiguredAdmin(context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  if (!await isConfiguredAdmin(context)) {
    throw new functions.https.HttpsError("permission-denied", "Configured Admin access is required.");
  }
}

async function priorityOrderFor(order) {
  const areaId = routingAreaId(order);
  if (!areaId) return [];
  const snap = await db.collection("tailor_routing_priorities").doc(areaId).get();
  const list = snap.exists ? snap.get("orderedTailors") : [];
  return Array.isArray(list) ? list.map((candidate) => ({
    accountId: text(candidate.accountId),
    profileId: text(candidate.profileId),
  })).filter((candidate) => candidate.accountId && candidate.profileId) : [];
}

async function loadRoutingCandidates(order, includeOutsideCoverage = false, includeContacts = false) {
  const profiles = await db.collectionGroup("profiles").where("partnerType", "==", "tailor").get();
  const matching = [];
  const overrides = [];
  const summaries = await Promise.all(profiles.docs.map(async (snapshot) => {
    const profile = snapshot.data() || {};
    if (!profileIsApprovedTailor(profile)) return null;
    const summary = profileSummary(snapshot);
    if (includeContacts) {
      const contactSummary = await profileAdminSummary(snapshot);
      summary.contactPhone = contactSummary.contactPhone;
      summary.additionalContactPhones = contactSummary.additionalContactPhones;
    }
    summary.coverageMatches = profileCoversOrder(profile, order);
    return summary;
  }));
  for (const summary of summaries) {
    if (!summary) continue;
    if (summary.coverageMatches) matching.push(summary);
    if (includeOutsideCoverage) overrides.push(summary);
  }
  const configuredOrder = await priorityOrderFor(order);
  const rank = new Map(configuredOrder.map((candidate, index) => [candidateKey(candidate), index]));
  const sortCandidates = (list) => list.sort((a, b) => {
    const aRank = rank.has(candidateKey(a)) ? rank.get(candidateKey(a)) : Number.MAX_SAFE_INTEGER;
    const bRank = rank.has(candidateKey(b)) ? rank.get(candidateKey(b)) : Number.MAX_SAFE_INTEGER;
    if (aRank !== bRank) return aRank - bRank;
    return a.registrationAt - b.registrationAt || a.profileId.localeCompare(b.profileId);
  });
  return {matching: sortCandidates(matching), overrides: includeOutsideCoverage ? sortCandidates(overrides) : [], configuredOrder};
}

async function appendEvent(orderId, type, actor, details) {
  await eventRefFor(orderId).set(eventData(type, actor, details));
}

async function ensureOrderTrackingId(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) return null;
    const savedCode = text(orderSnapshot.get("orderTrackingId"));
    if (savedCode) return savedCode;

    const trackingId = String(crypto.randomInt(100000000000, 1000000000000));
    const trackingRef = db.collection("order_tracking_codes").doc(trackingId);
    const trackingEventRef = eventRefFor(orderId);
    const result = await db.runTransaction(async (transaction) => {
      const [freshOrder, reservation] = await Promise.all([
        transaction.get(orderRef),
        transaction.get(trackingRef),
      ]);
      if (!freshOrder.exists) return null;
      const existingCode = text(freshOrder.get("orderTrackingId"));
      if (existingCode) return existingCode;
      if (reservation.exists) return null;
      transaction.create(trackingRef, {
        orderId,
        createdAt: SERVER_TIMESTAMP,
      });
      transaction.update(orderRef, {
        orderTrackingId: trackingId,
        orderQrPayload: trackingId,
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(trackingEventRef, eventData("order_tracking_id_created", "system", {
        orderTrackingId: trackingId,
      }));
      return trackingId;
    });
    if (result) return result;
  }
  throw new Error(`Could not allocate a unique tracking ID for order ${orderId}.`);
}

async function releaseHeldReservation(transaction, reservationSnapshot) {
  if (!reservationSnapshot.exists || !["held", "accepted"].includes(reservationSnapshot.get("status"))) return;
  const reservation = reservationSnapshot.data();
  // Older offers may still have a capacity counter. New standard offers only
  // use the reservation record to track the active offer/customer decision.
  if (reservation.dateKey) {
    const capRef = capacityRefFor(reservation.accountId, reservation.profileId, reservation.dateKey);
    const capSnapshot = await transaction.get(capRef);
    const heldCount = Number(capSnapshot.get("heldCount") || 0);
    if (capSnapshot.exists) {
      transaction.set(capRef, {heldCount: Math.max(0, heldCount - 1), updatedAt: SERVER_TIMESTAMP}, {merge: true});
    }
  }
  transaction.update(reservationSnapshot.ref, {
    status: "released",
    releasedAt: SERVER_TIMESTAMP,
    updatedAt: SERVER_TIMESTAMP,
  });
}

async function dispatchNextOffer(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const staleCandidateKeys = new Set();
  for (let attempts = 0; attempts < 100; attempts += 1) {
    const [stateSnapshot, orderSnapshot] = await Promise.all([stateRef.get(), orderRef.get()]);
    if (!stateSnapshot.exists || !orderSnapshot.exists) return {done: true};
    const state = stateSnapshot.data() || {};
    const order = orderSnapshot.data() || {};
    if (!["searching", "queued_for_dispatch"].includes(state.status) || state.currentOfferId) return {done: true};
    if (order.assignmentStatus === "finalized" || order.paymentStatus !== "unpaid") return {done: true};

    const slaMinutes = await offerSlaMinutes(order);

    const {matching} = await loadRoutingCandidates(order, false);
    const attempted = new Set(Array.isArray(state.attemptedCandidateKeys) ? state.attemptedCandidateKeys : []);
    const candidate = matching.find((item) => item.availabilityStatus === "available" &&
      !attempted.has(candidateKey(item)) && !staleCandidateKeys.has(candidateKey(item)));

    if (!candidate) {
      const allContacted = matching.length > 0 && matching.every((item) => attempted.has(candidateKey(item)));
      const status = allContacted ? "needs_admin_follow_up" : "queued_for_dispatch";
      const queueReason = allContacted ? "all_eligible_tailors_contacted" :
        (matching.length === 0 ? "no_tailor_in_coverage" : "no_online_tailor_in_coverage");
      await db.runTransaction(async (transaction) => {
        const [currentState, currentOrder] = await Promise.all([transaction.get(stateRef), transaction.get(orderRef)]);
        if (!currentState.exists || !currentOrder.exists || currentState.get("currentOfferId")) return;
        transaction.update(stateRef, {
          status,
          candidates: matching.map(({accountId, profileId}) => ({accountId, profileId})),
          adminQueueReason: queueReason,
          nextDispatchAt: admin.firestore.FieldValue.delete(),
          updatedAt: SERVER_TIMESTAMP,
        });
        transaction.update(orderRef, {
          assignmentStatus: status,
          adminQueueReason: queueReason,
          adminQueueUpdatedAt: SERVER_TIMESTAMP,
          nextDispatchAt: admin.firestore.FieldValue.delete(),
          updatedAt: SERVER_TIMESTAMP,
        });
      });
      if (status === "needs_admin_follow_up") {
        await appendEvent(orderId, "assignment_routed_to_operations", "system", {reason: queueReason});
      }
      return {done: true, queued: status === "queued_for_dispatch", reason: queueReason};
    }

    const accountId = candidate.accountId;
    const profileId = candidate.profileId;
    const profileRef = db.collection("accounts").doc(accountId).collection("profiles").doc(profileId);
    const reservationRef = reservationRefFor(orderId);
    const outcome = await db.runTransaction(async (transaction) => {
      const [currentState, currentOrder, profileSnapshot, reservationSnapshot] = await Promise.all([
        transaction.get(stateRef), transaction.get(orderRef), transaction.get(profileRef), transaction.get(reservationRef),
      ]);
      if (!currentState.exists || !currentOrder.exists || !profileSnapshot.exists) return {stale: true};
      const current = currentState.data() || {};
      const currentOrderData = currentOrder.data() || {};
      if (!['searching', 'queued_for_dispatch'].includes(current.status) || current.currentOfferId) return {done: true};
      if (!candidateIsEligible(profileSnapshot.data() || {}, currentOrderData)) return {stale: true};

      const offerId = `${orderId}_${Number(current.attempts || 0) + 1}`;
      const expiresAt = new Date(Date.now() + slaMinutes * 60 * 1000);
      const offerRef = offerRefFor(accountId, profileId, offerId);
      const eventRef = eventRefFor(orderId);
      const offer = {
        offerId,
        orderId,
        targetAccountId: accountId,
        targetProfileId: profileId,
        status: "offered",
        dressType: text(currentOrderData.dressType),
        orderPrice: Number(currentOrderData.price || 0),
        deliveryPincode: normalizedPincode(currentOrderData.deliveryPincode || asMap(currentOrderData.deliveryLocation).pincode || currentOrderData.pincode),
        designTemplateTitle: text(currentOrderData.designTemplateTitle),
        designImageUrl: text(currentOrderData.designImageUrl),
        fabricChoice: text(currentOrderData.fabricChoice),
        fabricDescription: text(currentOrderData.fabricDescription),
        createdAt: SERVER_TIMESTAMP,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      };
      transaction.set(offerRef, offer);
      transaction.set(reservationRef, {
        orderId,
        accountId,
        profileId,
        status: "held",
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.update(stateRef, {
        status: "offered",
        currentOfferId: offerId,
        activeCandidate: {accountId, profileId},
        candidates: matching.map(({accountId: candidateAccountId, profileId: candidateProfileId}) => ({accountId: candidateAccountId, profileId: candidateProfileId})),
        attempts: admin.firestore.FieldValue.increment(1),
        adminQueueReason: null,
        nextDispatchAt: admin.firestore.FieldValue.delete(),
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.update(orderRef, {
        assignmentStatus: "offered",
        adminQueueReason: admin.firestore.FieldValue.delete(),
        adminQueueUpdatedAt: admin.firestore.FieldValue.delete(),
        nextDispatchAt: admin.firestore.FieldValue.delete(),
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRef, eventData("tailor_offer_sent", "system", {
        targetAccountId: accountId,
        targetProfileId: profileId,
        offerId,
        priorityPosition: matching.findIndex((item) => candidateKey(item) === candidateKey(candidate)) + 1,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      }));
      return {offered: true, offerId};
    });
    if (outcome.stale) {
      staleCandidateKeys.add(candidateKey(candidate));
      continue;
    }
    return outcome;
  }
  return {done: true, queued: true};
}

async function initializeAssignment(orderId, order) {
  if (order.assignmentVersion !== "v1" || order.orderModuleType !== "coreTailoring") return;
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  await orderRef.set({
    inboundPickupRequired: true,
    inboundPickupStatus: text(order.inboundPickupStatus) || "notStarted",
    measurementStatus: text(order.measurementStatus) || "notStarted",
  }, {merge: true});
  const existingState = await stateRef.get();
  if (existingState.exists) return;

  // Catalogue price and version are checked from the canonical Admin-published
  // design before the order enters automatic Tailor routing. Older/manual
  // design orders have no catalogue version and keep their existing path.
  const catalogueValidation = await validateCatalogueOrderQuote(order);
  if (catalogueValidation) {
    const reason = "catalogue_quote_requires_validation";
    await stateRef.create({
      orderId,
      status: "needs_admin_follow_up",
      candidates: [],
      attemptedCandidateKeys: [],
      nextCandidateIndex: 0,
      attempts: 0,
      adminQueueReason: reason,
      catalogueValidationReason: catalogueValidation,
      createdAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    await orderRef.update({
      assignmentStatus: "needs_admin_follow_up",
      adminQueueReason: reason,
      adminQueueUpdatedAt: SERVER_TIMESTAMP,
      nextDispatchAt: admin.firestore.FieldValue.delete(),
    });
    await appendEvent(orderId, "catalogue_quote_held_for_admin_review", "system", {
      reason: catalogueValidation,
    });
    return;
  }

  const catalogueSnapshot = await validatedCatalogueOrderSnapshot(order);
  if (catalogueSnapshot) {
    await orderRef.update({
      catalogueDesignSnapshot: catalogueSnapshot,
      cataloguePriceValidatedAt: SERVER_TIMESTAMP,
    });
  }
  const pincode = normalizedPincode(order.deliveryPincode || asMap(order.deliveryLocation).pincode || order.pincode);
  const missingOrderData = Number(order.price || 0) <= 0 ? "order_price_required" : !pincode ? "delivery_pincode_required" : null;
  const {matching} = missingOrderData ? {matching: []} : await loadRoutingCandidates(order, false);
  const status = missingOrderData ? "needs_admin_follow_up" : matching.length === 0 ? "queued_for_dispatch" : "searching";
  const reason = missingOrderData || (matching.length === 0 ? "no_tailor_in_coverage" : null);
  await stateRef.create({
    orderId,
    status,
    candidates: matching.map(({accountId, profileId}) => ({accountId, profileId})),
    attemptedCandidateKeys: [],
    nextCandidateIndex: 0,
    attempts: 0,
    adminQueueReason: reason,
    createdAt: SERVER_TIMESTAMP,
    updatedAt: SERVER_TIMESTAMP,
  }).catch((error) => {
    if (error.code !== 6 && error.code !== "already-exists") throw error;
  });

  await orderRef.update({
    assignmentStatus: status,
    ...(reason ? {adminQueueReason: reason, adminQueueUpdatedAt: SERVER_TIMESTAMP} : {}),
    nextDispatchAt: admin.firestore.FieldValue.delete(),
  });
  await appendEvent(orderId, status === "queued_for_dispatch" ? "order_queued_for_tailor_dispatch" : "tailor_search_started", "system", {
    candidateCount: matching.length,
    reason,
  });
  if (status === "searching") await dispatchNextOffer(orderId);
}

async function validateCatalogueOrderQuote(order) {
  const designId = text(order && order.designTemplateId);
  const versionId = text(order && order.catalogueVersionId);
  if (!designId && !versionId) return null;
  if (!designId || !versionId) return "catalogue_design_or_version_missing";

  const designSnapshot = await db.collection("designs").doc(designId).get();
  if (!designSnapshot.exists) return "catalogue_design_not_found";
  const design = designSnapshot.data() || {};
  if (design.lifecycleStatus !== "approved" || design.publicationStatus !== "published") {
    return "catalogue_design_not_published";
  }
  if (text(design.activeVersionId) !== versionId) return "catalogue_version_not_active";
  const versionSnapshot = await db.collection("designs").doc(designId)
      .collection("versions").doc(versionId).get();
  if (!versionSnapshot.exists) return "catalogue_version_not_found";

  const commercial = asMap(design.commercial);
  const commercialType = text(commercial.commercialType);
  if (!new Set(["free", "paid", "premium"]).has(commercialType)) {
    return "catalogue_commercial_type_invalid";
  }
  const canonicalCharge = commercialType === "free" ? 0 : Number(commercial.approvedDesignCharge);
  const submittedCharge = Number(order.approvedDesignCharge);
  const total = Number(order.price);
  const baseCharge = Number(order.stitchingBaseCharge);
  const rateDocId = text(order.dressType).replaceAll("/", "_");
  const rateSnapshot = rateDocId
      ? await db.collection("rates").doc(rateDocId).get()
      : null;
  const canonicalBaseCharge = rateSnapshot && rateSnapshot.exists
      ? Number(rateSnapshot.get("basePrice"))
      : 350;
  if (!Number.isFinite(canonicalCharge) || canonicalCharge < 0 ||
      (commercialType !== "free" && canonicalCharge <= 0)) {
    return "catalogue_approved_price_missing";
  }
  if (text(order.catalogueCommercialType) !== commercialType ||
      !Number.isFinite(submittedCharge) ||
      Math.round(submittedCharge * 100) !== Math.round(canonicalCharge * 100)) {
    return "catalogue_approved_price_mismatch";
  }
  if (!Number.isFinite(canonicalBaseCharge) || canonicalBaseCharge < 0 ||
      Math.round(baseCharge * 100) !== Math.round(canonicalBaseCharge * 100)) {
    return "stitching_base_rate_mismatch";
  }
  if (!Number.isFinite(total) || total < canonicalCharge ||
      !Number.isFinite(baseCharge) || baseCharge < 0 ||
      Math.round(total * 100) !== Math.round((canonicalBaseCharge + canonicalCharge) * 100)) {
    return "order_total_does_not_match_quote_snapshot";
  }
  return null;
}

async function validatedCatalogueOrderSnapshot(order) {
  const designId = text(order && order.designTemplateId);
  const versionId = text(order && order.catalogueVersionId);
  if (!designId || !versionId) return null;
  const designSnapshot = await db.collection("designs").doc(designId).get();
  if (!designSnapshot.exists) return null;
  const design = designSnapshot.data() || {};
  const commercial = asMap(design.commercial);
  const charge = commercial.commercialType === "free" ? 0 : Number(commercial.approvedDesignCharge);
  return {
    designId,
    catalogueVersionId: versionId,
    commercialType: text(commercial.commercialType),
    approvedDesignCharge: charge,
    currency: text(commercial.currency) || "INR",
    cataloguePriceVersion: text(commercial.commercialVersion) || `version:${versionId}`,
    title: text(design.title),
    monochromeReferenceImageUrl: text(order.designImageUrl),
    verifiedAt: SERVER_TIMESTAMP,
  };
}

function summarizeOffer(offerSnapshot) {
  if (!offerSnapshot || !offerSnapshot.exists) return null;
  const offer = offerSnapshot.data() || {};
  return {
    offerId: offerSnapshot.id,
    status: text(offer.status),
    targetAccountId: text(offer.targetAccountId),
    targetProfileId: text(offer.targetProfileId),
    expiresAt: dateMillis(offer.expiresAt),
  };
}

async function getAdminOrderRoutingQueue(data, context) {
  await requireConfiguredAdmin(context);
  const limit = Math.max(1, Math.min(500, Number(data && data.limit) || 300));
  const snapshot = await db.collection("orders")
      .where("assignmentVersion", "==", "v1")
      .orderBy("orderDate", "desc")
      .limit(limit)
      .get();
  const assignedProfileCache = new Map();
  const rows = (await Promise.all(snapshot.docs.map(async (doc) => {
    const order = doc.data() || {};
    if (order.orderModuleType !== "coreTailoring") return null;
    const customerAccountId = text(order.customerAccountId);
    const [stateSnapshot, eventsSnapshot, customerAccountSnapshot] = await Promise.all([
      db.collection("order_assignment_state").doc(doc.id).get(),
      db.collection("orders").doc(doc.id).collection("events")
          .orderBy("occurredAt", "desc").limit(50).get(),
      customerAccountId ? db.collection("accounts").doc(customerAccountId).get() : Promise.resolve(null),
    ]);
    const state = stateSnapshot.data() || {};
    const assignedTailorAccountId = text(order.assignedTailorAccountId || asMap(state.assignedTailor).accountId);
    const assignedTailorProfileId = text(order.assignedTailorProfileId || asMap(state.assignedTailor).profileId);
    const measurementPartnerAccountId = text(order.measurementPartnerAccountId);
    const measurementPartnerProfileId = text(order.measurementPartnerProfileId);
    const inboundPickupPartnerAccountId = text(order.inboundPickupPartnerAccountId);
    const inboundPickupPartnerProfileId = text(order.inboundPickupPartnerProfileId);
    const outboundHandoverPartnerAccountId = text(order.outboundHandoverPartnerAccountId);
    const outboundHandoverPartnerProfileId = text(order.outboundHandoverPartnerProfileId);
    let assignedTailor = null;
    if (assignedTailorAccountId && assignedTailorProfileId) {
      const assignedProfileRef = db.collection("accounts").doc(assignedTailorAccountId)
          .collection("profiles").doc(assignedTailorProfileId);
      const cacheKey = assignedProfileRef.path;
      if (!assignedProfileCache.has(cacheKey)) {
        assignedProfileCache.set(cacheKey, (async () =>
          profileAdminSummary(await assignedProfileRef.get()))());
      }
      assignedTailor = await assignedProfileCache.get(cacheKey);
    }
    let measurementPartner = null;
    if (measurementPartnerAccountId && measurementPartnerProfileId) {
      const measurementProfileRef = db.collection("accounts").doc(measurementPartnerAccountId)
          .collection("profiles").doc(measurementPartnerProfileId);
      const cacheKey = measurementProfileRef.path;
      if (!assignedProfileCache.has(cacheKey)) {
        assignedProfileCache.set(cacheKey, (async () =>
          profileAdminSummary(await measurementProfileRef.get()))());
      }
      measurementPartner = await assignedProfileCache.get(cacheKey);
    }
    let inboundPickupPartner = null;
    if (inboundPickupPartnerAccountId && inboundPickupPartnerProfileId) {
      const pickupProfileRef = db.collection("accounts").doc(inboundPickupPartnerAccountId)
          .collection("profiles").doc(inboundPickupPartnerProfileId);
      const cacheKey = pickupProfileRef.path;
      if (!assignedProfileCache.has(cacheKey)) {
        assignedProfileCache.set(cacheKey, (async () =>
          profileAdminSummary(await pickupProfileRef.get()))());
      }
      inboundPickupPartner = await assignedProfileCache.get(cacheKey);
    }
    let outboundHandoverPartner = null;
    if (outboundHandoverPartnerAccountId && outboundHandoverPartnerProfileId) {
      const outboundProfileRef = db.collection("accounts").doc(outboundHandoverPartnerAccountId)
          .collection("profiles").doc(outboundHandoverPartnerProfileId);
      const cacheKey = outboundProfileRef.path;
      if (!assignedProfileCache.has(cacheKey)) {
        assignedProfileCache.set(cacheKey, (async () =>
          profileAdminSummary(await outboundProfileRef.get()))());
      }
      outboundHandoverPartner = await assignedProfileCache.get(cacheKey);
    }
    let currentOffer = null;
    if (state.currentOfferId && state.activeCandidate) {
      const offerRef = offerRefFor(state.activeCandidate.accountId, state.activeCandidate.profileId, state.currentOfferId);
      const profileRef = db.collection("accounts").doc(state.activeCandidate.accountId)
          .collection("profiles").doc(state.activeCandidate.profileId);
      const [offerSnapshot, profileSnapshot] = await Promise.all([offerRef.get(), profileRef.get()]);
      const summary = summarizeOffer(offerSnapshot);
      const targetProfile = await profileAdminSummary(profileSnapshot);
      currentOffer = summary ? {
        ...summary,
        targetDisplayName: text(targetProfile && targetProfile.displayName),
        targetContactPhone: text(targetProfile && targetProfile.contactPhone),
        targetProfile,
      } : null;
    }
    const deliveryLocation = asMap(order.deliveryLocation);
    return {
      orderId: doc.id,
      customerName: text(order.personName || order.clientName || order.customerName),
      customerPhone: text(order.customerPhone || order.phone || order.mobileE164 ||
          (customerAccountSnapshot && customerAccountSnapshot.get("mobileE164"))),
      dressType: text(order.dressType),
      occasionCategory: text(order.occasionCategory || order.occasion),
      fit: text(order.fit),
      price: Number(order.price || 0),
      orderDate: dateMillis(order.orderDate || order.assignmentRequestedAt),
      assignmentStatus: text(order.assignmentStatus || "searching"),
      adminQueueReason: text(order.adminQueueReason),
      paymentStatus: text(order.paymentStatus),
      orderStatus: text(order.status),
      orderTrackingId: text(order.orderTrackingId),
      measurementStatus: text(order.measurementStatus),
      measurementSubmissionStatus: text(order.measurementSubmissionStatus),
      measurementMethod: text(order.measurementMethod),
      measurementAppointmentAt: dateMillis(order.measurementAppointmentAt),
      measurementAppointmentLink: text(order.measurementAppointmentLink),
      measurementNotes: text(order.measurementNotes),
      measurementPartner,
      measurementSubmittedValues: asMap(order.measurementSubmittedValues),
      measurementSubmittedUnit: text(order.measurementSubmittedUnit) || "in",
      measurementPartnerCompletionNote: text(order.measurementPartnerCompletionNote),
      measurementPartnerCompletedAt: dateMillis(order.measurementPartnerCompletedAt),
      measurementConfirmedAt: dateMillis(order.measurementConfirmedAt),
      inboundPickupStatus: text(order.inboundPickupStatus),
      inboundPickupAssignedAt: dateMillis(order.inboundPickupAssignedAt),
      inboundPickupCollectedAt: dateMillis(order.inboundPickupCollectedAt),
      inboundPickupReceivedAt: dateMillis(order.inboundPickupReceivedAt),
      inboundPickupPhotoPath: text(order.inboundPickupPhotoPath),
      inboundPickupPartner,
      inboundPickupPartnerType: text(order.inboundPickupPartnerType),
      outboundHandoverStatus: text(order.outboundHandoverStatus),
      outboundHandoverAssignedAt: dateMillis(order.outboundHandoverAssignedAt),
      outboundHandoverAcceptedAt: dateMillis(order.outboundHandoverAcceptedAt),
      outboundHandoverDeliveredAt: dateMillis(order.outboundHandoverDeliveredAt),
      outboundHandoverPartnerType: text(order.outboundHandoverPartnerType),
      outboundHandoverPartner,
      designTemplateTitle: text(order.designTemplateTitle || order.designTitle),
      designImageUrl: text(order.designImageUrl || order.designTemplateImageUrl || order.designImage),
      designDescription: text(order.designDescription || order.designNotes || order.designBrief),
      fabricChoice: text(order.fabricChoice || order.fabricType || order.materialType || order.materialName),
      fabricDescription: text(order.fabricDescription || order.materialDescription || order.fabricNotes),
      fabricImageUrl: text(order.fabricImageUrl || order.materialImageUrl),
      accentColorHex: text(order.accentColorHex),
      notes: text(order.notes || order.customerNotes),
      measurements: asMap(order.measurements || order.measurementValues),
      deliveryAddress: text(order.deliveryAddress || deliveryLocation.address || deliveryLocation.fullAddress),
      expectedReadyAt: dateMillis(order.expectedReadyAt),
      deliveryFee: Number(order.deliveryFee || 0),
      amountPaid: Number(order.amountPaid || 0),
      balanceAmount: Number(order.balanceAmount || 0),
      cancellationFeeAmount: Number(order.cancellationFeeAmount || 0),
      cancellationFeePercent: Number(order.cancellationFeePercent || 0),
      cancellationRefundDue: Number(order.cancellationRefundDue || 0),
      cancellationFeeOutstanding: Number(order.cancellationFeeOutstanding || 0),
      cancellationFeeWaived: order.cancellationFeeWaived === true,
      warrantyClaimStatus: text(order.warrantyClaimStatus),
      warrantyIssueDescription: text(order.warrantyIssueDescription),
      warrantyResolution: text(order.warrantyResolution),
      warrantyEndsAt: dateMillis(order.warrantyEndsAt),
      feedbackRating: Number(order.feedbackRating || 0),
      deliveryPincode: normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode),
      cityName: text(deliveryLocation.cityName || order.deliveryCityName || order.deliveryCity || order.cityName),
      stateName: text(deliveryLocation.stateName || order.deliveryStateName || order.deliveryState || order.stateName),
      cityCode: text(deliveryLocation.cityCode || order.deliveryCityCode || order.cityCode),
      stateCode: text(deliveryLocation.stateCode || order.deliveryStateCode || order.stateCode),
      assignedTailorName: text((assignedTailor && assignedTailor.displayName) || order.assignedTailorName || order.tailorName),
      assignedTailor,
      nextDispatchAt: dateMillis(order.nextDispatchAt),
      currentOffer,
      stateStatus: text(state.status),
      recentEvents: eventsSnapshot.docs.map((event) => ({
        type: text(event.get("type")),
        actor: text(event.get("actor")),
        occurredAt: dateMillis(event.get("occurredAt")),
      })),
    };
  }))).filter(Boolean);
  return {orders: rows, dispatchTimeZone: (await dispatchConfig()).timeZone};
}

async function getAdminOrderRoutingCandidates(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderSnapshot = await db.collection("orders").doc(orderId).get();
  if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" || orderSnapshot.get("orderModuleType") !== "coreTailoring") {
    throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
  }
  const order = orderSnapshot.data() || {};
  const [{matching, overrides}, stateSnapshot] = await Promise.all([
    loadRoutingCandidates(order, true, true),
    db.collection("order_assignment_state").doc(orderId).get(),
  ]);
  const state = stateSnapshot.data() || {};
  let currentOffer = null;
  if (state.currentOfferId && state.activeCandidate) {
    currentOffer = summarizeOffer(await offerRefFor(
      state.activeCandidate.accountId,
      state.activeCandidate.profileId,
      state.currentOfferId,
    ).get());
  }
  return {
    orderId,
    deliveryPincode: normalizedPincode(order.deliveryPincode || asMap(order.deliveryLocation).pincode || order.pincode),
    cityName: text(asMap(order.deliveryLocation).cityName || order.deliveryCityName || order.deliveryCity || order.cityName),
    assignmentStatus: text(order.assignmentStatus),
    adminQueueReason: text(order.adminQueueReason),
    currentOffer,
    candidates: matching.map((candidate) => ({
      ...candidate,
      registrationAt: candidate.registrationAt,
    })),
    overrideCandidates: overrides,
    priorityOrder: await priorityOrderFor(order),
  };
}

async function getAdminInboundPickupCandidates(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderSnapshot = await db.collection("orders").doc(orderId).get();
  if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
      orderSnapshot.get("orderModuleType") !== "coreTailoring") {
    throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
  }
  const order = orderSnapshot.data() || {};
  return {orderId, candidates: await inboundPickupCandidates(order)};
}

async function inboundPickupCandidates(order) {
  const [tailors, measurementPartners, deliveryPartners] = await Promise.all([
    db.collectionGroup("profiles").where("partnerType", "==", "tailor").get(),
    db.collectionGroup("profiles").where("partnerType", "==", "measurementPartner").get(),
    db.collectionGroup("profiles").where("partnerType", "==", "deliveryPartner").get(),
  ]);
  const candidates = (await Promise.all([
    ...tailors.docs.map(async (snapshot) => {
      const profile = snapshot.data() || {};
      if (!tailorCanFulfill(profile, "inbound") || !profileCoversOrder(profile, order)) return null;
      return profileAdminSummary(snapshot);
    }),
    ...measurementPartners.docs.map(async (snapshot) => {
      if (!measurementPartnerCanFulfill(snapshot.data() || {}, "inbound", order)) return null;
      return profileAdminSummary(snapshot);
    }),
    ...deliveryPartners.docs.map(async (snapshot) => {
      if (!deliveryPartnerCanFulfill(snapshot.data() || {}, "inbound", order)) return null;
      return profileAdminSummary(snapshot);
    }),
  ])).filter(Boolean).sort((a, b) => a.displayName.localeCompare(b.displayName));
  return candidates;
}

async function getTailorInboundPickupCandidates(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  if (!orderId || !accountId || !profileId) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor and order are required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
    accountRef.get(), profileRef.get(), orderRef.get(),
  ]);
  if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
      !profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
    throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile to assign pickup.");
  }
  const order = orderSnapshot.data() || {};
  if (!orderSnapshot.exists || order.assignmentVersion !== "v1" ||
      order.orderModuleType !== "coreTailoring" || order.assignedTailorAccountId !== accountId ||
      order.assignedTailorProfileId !== profileId || order.assignmentStatus !== "finalized" ||
      !["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
      !["awaiting_assignment", "assigned"].includes(text(order.inboundPickupStatus))) {
    throw new functions.https.HttpsError("failed-precondition", "This paid order is not available for pickup assignment.");
  }
  return {orderId, candidates: await inboundPickupCandidates(order)};
}

async function assignInboundPickupPartner(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const partnerType = text(data && data.partnerType) || "deliveryPartner";
  if (!orderId || !accountId || !profileId) {
    throw new functions.https.HttpsError("invalid-argument", "Order and pickup Partner profile are required.");
  }
  if (!["tailor", "measurementPartner", "deliveryPartner"].includes(partnerType)) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a valid pickup Partner type.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  const profileRef = db.collection("accounts").doc(accountId).collection("profiles").doc(profileId);
  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, profileSnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(profileRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("orderModuleType") !== "coreTailoring") {
      throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
    }
    const order = orderSnapshot.data() || {};
    const profile = profileSnapshot.data() || {};
    const eligible = partnerType === "tailor" ?
      tailorCanFulfill(profile, "inbound") && profileCoversOrder(profile, order) :
      partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, "inbound", order) :
      deliveryPartnerCanFulfill(profile, "inbound", order);
    if (!profileSnapshot.exists || profile.partnerType !== partnerType || !eligible) {
      throw new functions.https.HttpsError("failed-precondition", "Choose an active, approved Partner that can collect pickup in this order's PIN.");
    }
    if (order.assignmentStatus !== "finalized" || !["advancePaid", "fullyPaid"].includes(order.paymentStatus)) {
      throw new functions.https.HttpsError("failed-precondition", "Inbound pickup can be assigned after the Customer pays the advance.");
    }
    if (!["awaiting_assignment", "assigned"].includes(text(order.inboundPickupStatus))) {
      throw new functions.https.HttpsError("failed-precondition", "This pickup has already started or is complete.");
    }
    transaction.update(orderRef, {
      inboundPickupStatus: "assigned",
      inboundPickupPartnerType: partnerType,
      inboundPickupPartnerAccountId: accountId,
      inboundPickupPartnerProfileId: profileId,
      inboundPickupAssignedAt: SERVER_TIMESTAMP,
      inboundPickupAssignedBy: context.auth.uid,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("inbound_pickup_assigned", "admin", {
      accountId, profileId, partnerType,
    }));
  });
  return {status: "assigned", accountId, profileId, partnerType};
}

async function assignTailorInboundPickupPartner(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const tailorAccountId = text(data && data.tailorAccountId);
  const tailorProfileId = text(data && data.tailorProfileId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const partnerType = text(data && data.partnerType);
  if (!orderId || !tailorAccountId || !tailorProfileId || !accountId || !profileId ||
      !["tailor", "measurementPartner", "deliveryPartner"].includes(partnerType)) {
    throw new functions.https.HttpsError("invalid-argument", "Order and pickup Partner profile are required.");
  }
  const tailorAccountRef = db.collection("accounts").doc(tailorAccountId);
  const tailorProfileRef = tailorAccountRef.collection("profiles").doc(tailorProfileId);
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const [tailorAccountSnapshot, tailorProfileSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(tailorAccountRef), transaction.get(tailorProfileRef),
      transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!tailorAccountSnapshot.exists ||
        tailorAccountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
        !tailorProfileSnapshot.exists || !profileIsApprovedTailor(tailorProfileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile to assign pickup.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("orderModuleType") !== "coreTailoring") {
      throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
    }
    const order = orderSnapshot.data() || {};
    if (order.assignedTailorAccountId !== tailorAccountId || order.assignedTailorProfileId !== tailorProfileId ||
        order.assignmentStatus !== "finalized" || !["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
        !["awaiting_assignment", "assigned"].includes(text(order.inboundPickupStatus))) {
      throw new functions.https.HttpsError("failed-precondition", "This order is not available for pickup assignment.");
    }
    const profile = profileSnapshot.data() || {};
    const eligible = partnerType === "tailor" ?
      tailorCanFulfill(profile, "inbound") && profileCoversOrder(profile, order) :
      partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, "inbound", order) :
      deliveryPartnerCanFulfill(profile, "inbound", order);
    if (!profileSnapshot.exists || profile.partnerType !== partnerType || !eligible) {
      throw new functions.https.HttpsError("failed-precondition", "Choose an active, approved Partner that can collect pickup in this order's PIN.");
    }
    transaction.update(orderRef, {
      inboundPickupStatus: "assigned",
      inboundPickupPartnerType: partnerType,
      inboundPickupPartnerAccountId: accountId,
      inboundPickupPartnerProfileId: profileId,
      inboundPickupAssignedAt: SERVER_TIMESTAMP,
      inboundPickupAssignedBy: "tailor",
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("inbound_pickup_assigned", "tailor", {
      accountId, profileId, partnerType,
    }));
  });
  return {status: "assigned", accountId, profileId, partnerType};
}

async function getAdminOutboundHandoverCandidates(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderSnapshot = await db.collection("orders").doc(orderId).get();
  if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
      orderSnapshot.get("orderModuleType") !== "coreTailoring") {
    throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
  }
  const order = orderSnapshot.data() || {};
  if (!outboundAssignmentIsAvailable(order)) {
    throw new functions.https.HttpsError("failed-precondition", "Return delivery can be assigned after the Customer pays the full balance and the order is ready.");
  }
  return {orderId, candidates: await outboundHandoverCandidates(order)};
}

async function getTailorOutboundHandoverCandidates(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  if (!orderId || !accountId || !profileId) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor and order are required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
    accountRef.get(), profileRef.get(), orderRef.get(),
  ]);
  if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
      !profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
    throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile to assign delivery.");
  }
  if (!orderSnapshot.exists || orderSnapshot.get("assignedTailorAccountId") !== accountId ||
      orderSnapshot.get("assignedTailorProfileId") !== profileId) {
    throw new functions.https.HttpsError("permission-denied", "This order is not assigned to your Tailor profile.");
  }
  const order = orderSnapshot.data() || {};
  if (!outboundAssignmentIsAvailable(order)) {
    throw new functions.https.HttpsError("failed-precondition", "Return delivery can be assigned after the Customer pays the full balance and the order is ready.");
  }
  return {orderId, candidates: await outboundHandoverCandidates(order)};
}

async function assignOutboundHandoverPartner(data, context, actor) {
  if (actor === "admin") await requireConfiguredAdmin(context);
  else if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const partnerType = text(data && data.partnerType);
  const tailorAccountId = text(data && data.tailorAccountId);
  const tailorProfileId = text(data && data.tailorProfileId);
  if (!orderId || !accountId || !profileId ||
      !["tailor", "measurementPartner", "deliveryPartner"].includes(partnerType) ||
      (actor === "tailor" && (!tailorAccountId || !tailorProfileId))) {
    throw new functions.https.HttpsError("invalid-argument", "Order and return delivery Partner profile are required.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  const targetProfileRef = db.collection("accounts").doc(accountId).collection("profiles").doc(profileId);
  const tailorAccountRef = actor === "tailor" ? db.collection("accounts").doc(tailorAccountId) : null;
  const assignedTailorProfileRef = actor === "tailor" ?
    tailorAccountRef.collection("profiles").doc(tailorProfileId) : null;
  const deliveryPin = newDeliveryPin();
  await db.runTransaction(async (transaction) => {
    const reads = [transaction.get(orderRef), transaction.get(targetProfileRef)];
    if (actor === "tailor") reads.push(transaction.get(tailorAccountRef), transaction.get(assignedTailorProfileRef));
    const [orderSnapshot, targetProfileSnapshot, tailorAccountSnapshot, tailorProfileSnapshot] = await Promise.all(reads);
    if (actor === "tailor" &&
        (!tailorAccountSnapshot.exists || tailorAccountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
         !tailorProfileSnapshot.exists || !profileIsApprovedTailor(tailorProfileSnapshot.data() || {}))) {
      throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile to assign delivery.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("orderModuleType") !== "coreTailoring") {
      throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
    }
    const order = orderSnapshot.data() || {};
    if (actor === "tailor" &&
        (order.assignedTailorAccountId !== tailorAccountId || order.assignedTailorProfileId !== tailorProfileId)) {
      throw new functions.https.HttpsError("permission-denied", "This order is not assigned to your Tailor profile.");
    }
    if (!outboundAssignmentIsAvailable(order)) {
      throw new functions.https.HttpsError("failed-precondition", "Return delivery can be assigned after the Customer pays the full balance and the order is ready.");
    }
    const declinedKeys = new Set(Array.isArray(order.outboundHandoverDeclinedPartnerKeys) ?
      order.outboundHandoverDeclinedPartnerKeys.map(text) : []);
    const partnerKey = profileKey(accountId, profileId);
    const profile = targetProfileSnapshot.data() || {};
    if (!targetProfileSnapshot.exists || profile.partnerType !== partnerType ||
        declinedKeys.has(partnerKey) || !outboundPartnerCanFulfill(partnerType, profile, order)) {
      throw new functions.https.HttpsError("failed-precondition", "Choose an active, approved Partner that can deliver to this order's PIN.");
    }
    transaction.update(orderRef, {
      outboundHandoverStatus: "assigned",
      outboundHandoverPartnerType: partnerType,
      outboundHandoverPartnerAccountId: accountId,
      outboundHandoverPartnerProfileId: profileId,
      outboundHandoverAssignedAt: SERVER_TIMESTAMP,
      deliveryPartnerAccountId: accountId,
      deliveryPartnerProfileId: profileId,
      deliveryPartnerType: partnerType,
      deliveryPinHash: admin.firestore.FieldValue.delete(),
      deliveryPinGeneratedAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(orderRef.collection("private").doc("delivery_pin"), {
      customerId: text(order.customerId),
      orderId,
      pin: deliveryPin,
      pinHash: deliveryPinHash(deliveryPin),
      assignedPartnerAccountId: accountId,
      assignedPartnerProfileId: profileId,
      createdAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("outbound_handover_assigned", actor, {
      partnerType, accountId, profileId,
      previousPartnerType: text(order.outboundHandoverPartnerType) || null,
      previousAccountId: text(order.outboundHandoverPartnerAccountId) || null,
      previousProfileId: text(order.outboundHandoverPartnerProfileId) || null,
    }));
  });
  return {status: "assigned", accountId, profileId, partnerType};
}

async function assignAdminOutboundHandoverPartner(data, context) {
  return assignOutboundHandoverPartner(data, context, "admin");
}

async function assignTailorOutboundHandoverPartner(data, context) {
  return assignOutboundHandoverPartner(data, context, "tailor");
}

async function getCustomerOrderDeliveryPin(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderRef = db.collection("orders").doc(orderId);
  const orderSnapshot = await orderRef.get();
  if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
    throw new functions.https.HttpsError("permission-denied", "This is not your order.");
  }
  const order = orderSnapshot.data() || {};
  if (!order.usesProductionAssignment && order.assignmentVersion !== "v1") {
    throw new functions.https.HttpsError("failed-precondition", "A delivery PIN is not available for this order.");
  }
  if (!order.deliveryPinGeneratedAt || !["assigned", "in_transit"].includes(text(order.outboundHandoverStatus)) ||
      !["readyForPickup", "outForDelivery"].includes(text(order.status)) || order.paymentStatus !== "fullyPaid") {
    throw new functions.https.HttpsError("failed-precondition", "The delivery PIN will be available after a Delivery Partner is assigned.");
  }
  const secret = await orderRef.collection("private").doc("delivery_pin").get();
  const pin = secret.exists ? text(secret.get("pin")) : "";
  if (!secret.exists || secret.get("customerId") !== context.auth.uid ||
      secret.get("assignedPartnerAccountId") !== order.outboundHandoverPartnerAccountId ||
      secret.get("assignedPartnerProfileId") !== order.outboundHandoverPartnerProfileId ||
      !/^\d{4}$/.test(pin) || !text(secret.get("pinHash"))) {
    throw new functions.https.HttpsError("failed-precondition", "The current delivery PIN is not available. Ask the Partner to assign the delivery again.");
  }
  return {pin};
}

async function updateTailorRoutingPriority(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  const supplied = Array.isArray(data && data.orderedTailors) ? data.orderedTailors : null;
  if (!orderId || !supplied) {
    throw new functions.https.HttpsError("invalid-argument", "An order and ordered Tailor list are required.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  const orderSnapshot = await orderRef.get();
  if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" || orderSnapshot.get("orderModuleType") !== "coreTailoring") {
    throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
  }
  const order = orderSnapshot.data() || {};
  const {matching} = await loadRoutingCandidates(order, false);
  const allowed = new Map(matching.map((candidate) => [candidateKey(candidate), candidate]));
  const orderedTailors = [];
  const seen = new Set();
  for (const item of supplied) {
    const candidate = {accountId: text(item && item.accountId), profileId: text(item && item.profileId)};
    const key = candidateKey(candidate);
    if (!candidate.accountId || !candidate.profileId || !allowed.has(key) || seen.has(key)) {
      throw new functions.https.HttpsError("invalid-argument", "Priority may include each approved Tailor covering this PIN once.");
    }
    seen.add(key);
    orderedTailors.push(candidate);
  }
  // Include eligible Tailors omitted by an older Admin roster at the end,
  // preserving the chronological default for the remaining profiles.
  for (const candidate of matching) {
    const key = candidateKey(candidate);
    if (!seen.has(key)) orderedTailors.push({accountId: candidate.accountId, profileId: candidate.profileId});
  }

  const priorityRef = db.collection("tailor_routing_priorities").doc(routingAreaId(order));
  await priorityRef.set({
    countryCode: text(asMap(order.deliveryLocation).countryCode || "IN"),
    stateCode: text(asMap(order.deliveryLocation).stateCode || order.deliveryStateCode || order.stateCode),
    cityCode: text(asMap(order.deliveryLocation).cityCode || order.deliveryCityCode || order.cityCode),
    deliveryPincode: normalizedPincode(order.deliveryPincode || asMap(order.deliveryLocation).pincode || order.pincode),
    orderedTailors,
    updatedByUid: context.auth.uid,
    updatedAt: SERVER_TIMESTAMP,
  }, {merge: true});
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const stateSnapshot = await stateRef.get();
  if (stateSnapshot.exists && !stateSnapshot.get("currentOfferId")) {
    await stateRef.update({candidates: orderedTailors, priorityUpdatedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
  }
  await appendEvent(orderId, "tailor_routing_priority_updated", "admin", {
    deliveryPincode: normalizedPincode(order.deliveryPincode || asMap(order.deliveryLocation).pincode || order.pincode),
    orderedTailors,
  });
  if (stateSnapshot.exists && !stateSnapshot.get("currentOfferId") &&
      ["queued_for_dispatch", "searching"].includes(text(stateSnapshot.get("status")))) {
    await dispatchNextOffer(orderId);
  }
  return {orderedTailors};
}

async function sendAdminTailorOffer(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const manualOverride = data && data.manualOverride === true;
  const reason = text(data && data.reason);
  if (!orderId || !accountId || !profileId) {
    throw new functions.https.HttpsError("invalid-argument", "An order and Tailor profile are required.");
  }
  if (manualOverride && reason.length < 5) {
    throw new functions.https.HttpsError("invalid-argument", "Add a short reason for the manual routing override.");
  }
  const slaMinutes = await offerSlaMinutes({});

  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const profileRef = db.collection("accounts").doc(accountId).collection("profiles").doc(profileId);
  const reservationRef = reservationRefFor(orderId);
  const outcome = await db.runTransaction(async (transaction) => {
    const [orderSnapshot, stateSnapshot, profileSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(stateRef), transaction.get(profileRef), transaction.get(reservationRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" || orderSnapshot.get("orderModuleType") !== "coreTailoring") {
      throw new functions.https.HttpsError("not-found", "The production tailoring order could not be found.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("failed-precondition", "Select an active, approved, verified Tailor profile.");
    }
    const order = orderSnapshot.data() || {};
    if (order.paymentStatus !== "unpaid" || ["awaiting_customer_decision", "finalized"].includes(order.assignmentStatus)) {
      throw new functions.https.HttpsError("failed-precondition", "This order is no longer waiting for a Tailor offer.");
    }
    if (Number(order.price || 0) <= 0) {
      throw new functions.https.HttpsError("failed-precondition", "Set a valid order price before sending a Tailor offer.");
    }
    const profile = profileSnapshot.data() || {};
    if (!manualOverride && !candidateIsEligible(profile, order)) {
      throw new functions.https.HttpsError("failed-precondition", "Automatic offers require this Tailor to be online and cover the Customer PIN.");
    }
    // The onCreate trigger only initializes assignment state for orders created
    // after that function was deployed. Older v1 orders can still be visible in
    // the Admin queue, so let Admin's explicit offer action initialize their
    // missing state atomically instead of silently stranding those orders.
    const stateExisted = stateSnapshot.exists;
    const state = stateSnapshot.data() || {
      status: text(order.assignmentStatus) || "searching",
      candidates: [],
      attemptedCandidateKeys: [],
      attempts: 0,
    };
    if (!stateExisted && reservationSnapshot.exists &&
        ["held", "accepted"].includes(reservationSnapshot.get("status"))) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "This older order has an active Tailor reservation but no assignment record. Refresh the Admin queue before routing it.",
      );
    }
    let oldOfferRef = null;
    if (state.currentOfferId && state.activeCandidate) {
      oldOfferRef = offerRefFor(state.activeCandidate.accountId, state.activeCandidate.profileId, state.currentOfferId);
    }
    const oldOfferSnapshot = oldOfferRef ? await transaction.get(oldOfferRef) : null;
    const currentOffer = oldOfferSnapshot && oldOfferSnapshot.exists && oldOfferSnapshot.get("status") === "offered";
    if (currentOffer && state.activeCandidate && candidateKey(state.activeCandidate) === profileKey(accountId, profileId)) {
      throw new functions.https.HttpsError("failed-precondition", "This Tailor already has the active offer.");
    }
    if (currentOffer) {
      await releaseHeldReservation(transaction, reservationSnapshot);
      transaction.update(oldOfferRef, {status: "withdrawn_by_admin", respondedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    }
    const attempt = Number(state.attempts || 0) + 1;
    const offerId = `${orderId}_${attempt}`;
    const offerRef = offerRefFor(accountId, profileId, offerId);
    const expiresAt = new Date(Date.now() + slaMinutes * 60 * 1000);
    transaction.set(offerRef, {
      offerId,
      orderId,
      targetAccountId: accountId,
      targetProfileId: profileId,
      status: "offered",
      dressType: text(order.dressType),
      orderPrice: Number(order.price || 0),
      deliveryPincode: normalizedPincode(order.deliveryPincode || asMap(order.deliveryLocation).pincode || order.pincode),
      designTemplateTitle: text(order.designTemplateTitle),
      designImageUrl: text(order.designImageUrl),
      fabricChoice: text(order.fabricChoice),
      fabricDescription: text(order.fabricDescription),
      createdAt: SERVER_TIMESTAMP,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });
    transaction.set(reservationRef, {orderId, accountId, profileId, status: "held", updatedAt: SERVER_TIMESTAMP});
    const attempted = Array.isArray(state.attemptedCandidateKeys) ? state.attemptedCandidateKeys : [];
    const attemptedCandidateKeys = currentOffer ? Array.from(new Set([...attempted, candidateKey(state.activeCandidate)])) : attempted;
    const stateUpdate = {
      status: "offered",
      currentOfferId: offerId,
      activeCandidate: {accountId, profileId},
      attempts: stateExisted ? admin.firestore.FieldValue.increment(1) : attempt,
      attemptedCandidateKeys,
      manualRoutingOverride: manualOverride,
      updatedAt: SERVER_TIMESTAMP,
    };
    if (stateExisted) {
      transaction.update(stateRef, {
        ...stateUpdate,
        nextDispatchAt: admin.firestore.FieldValue.delete(),
      });
    } else {
      transaction.set(stateRef, {
        orderId,
        candidates: [],
        attemptedCandidateKeys,
        nextCandidateIndex: 0,
        createdAt: SERVER_TIMESTAMP,
        ...stateUpdate,
      });
    }
    transaction.update(orderRef, {
      assignmentStatus: "offered",
      adminQueueReason: admin.firestore.FieldValue.delete(),
      adminQueueUpdatedAt: admin.firestore.FieldValue.delete(),
      nextDispatchAt: admin.firestore.FieldValue.delete(),
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("tailor_offer_sent", "admin", {
      targetAccountId: accountId,
      targetProfileId: profileId,
      offerId,
      manualOverride,
      reason: manualOverride ? reason : "Admin sent a standard Tailor offer.",
      replacedOfferId: currentOffer ? state.currentOfferId : null,
      adminUid: context.auth.uid,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    }));
    return {offerId, expiresAt: expiresAt.getTime(), status: "offered"};
  });
  return outcome;
}

async function resumeQueuedAssignments() {
  let processed = 0;
  let failed = 0;
  let cursor = null;
  while (true) {
    // Keep the retry query on Firestore's single-field index. Sorting by
    // orderDate requires a composite index and can strand the scheduled sweep.
    let query = db.collection("orders")
        .where("assignmentStatus", "==", "queued_for_dispatch")
        .limit(100);
    if (cursor) query = query.startAfter(cursor);
    const queued = await query.get();
    if (queued.empty) break;
    for (const snapshot of queued.docs) {
      if (snapshot.get("assignmentVersion") !== "v1" || snapshot.get("orderModuleType") !== "coreTailoring") continue;
      try {
        const stateRef = db.collection("order_assignment_state").doc(snapshot.id);
        const stateSnapshot = await stateRef.get();
        if (!stateSnapshot.exists) {
          // Older queued orders may predate creation of assignment state.
          // Rebuild it from the order, then immediately try the current queue.
          await initializeAssignment(snapshot.id, snapshot.data() || {});
        } else if (["searching", "queued_for_dispatch"].includes(text(stateSnapshot.get("status"))) &&
            !stateSnapshot.get("currentOfferId")) {
          await dispatchNextOffer(snapshot.id);
        }
        processed += 1;
      } catch (error) {
        failed += 1;
        console.error("Could not resume queued Tailor assignment", {
          orderId: snapshot.id,
          message: error && error.message ? error.message : String(error),
        });
      }
    }
    cursor = queued.docs[queued.docs.length - 1];
    if (queued.size < 100) break;
  }
  return {processed, failed};
}

async function handleTailorResponse(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const decision = text(data && data.decision);
  if (!accountId || !profileId || !orderId || !["accept", "decline"].includes(decision)) {
    throw new functions.https.HttpsError("invalid-argument", "A Partner profile, order, and accept/decline choice are required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);
  const now = new Date();
  const dispatchHours = await dispatchConfig();
  const expectedReadyAtMillis = Number(data && data.expectedReadyAtMillis);
  const expectedReadyAt = new Date(expectedReadyAtMillis);
  if (decision === "accept" && (!Number.isFinite(expectedReadyAtMillis) ||
      expectedReadyAt.getTime() <= now.getTime() ||
      expectedReadyAt.getTime() > now.getTime() + 366 * 24 * 60 * 60 * 1000)) {
    throw new functions.https.HttpsError("invalid-argument", "Choose an expected completion date within the next year before accepting.");
  }
  let shouldDispatch = false;
  let responseStatus = decision === "accept" ? "accepted" : "declined";

  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot, stateSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(accountRef),
      transaction.get(profileRef),
      transaction.get(orderRef),
      transaction.get(stateRef),
      transaction.get(reservationRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "You can respond only for your own Partner account.");
    }
    if (!profileSnapshot.exists || profileSnapshot.get("role") !== "partner" || profileSnapshot.get("partnerType") !== "tailor") {
      throw new functions.https.HttpsError("failed-precondition", "The selected profile is not a Tailor profile.");
    }
    if (!orderSnapshot.exists || !stateSnapshot.exists) throw new functions.https.HttpsError("not-found", "The order offer is no longer available.");
    const state = stateSnapshot.data();
    const offerId = state.currentOfferId;
    if (state.status !== "offered" || !offerId || state.activeCandidate.accountId !== accountId || state.activeCandidate.profileId !== profileId) {
      throw new functions.https.HttpsError("failed-precondition", "This offer is no longer active.");
    }
    const offerRef = offerRefFor(accountId, profileId, offerId);
    const offerSnapshot = await transaction.get(offerRef);
    if (!offerSnapshot.exists || offerSnapshot.get("status") !== "offered") {
      throw new functions.https.HttpsError("failed-precondition", "This offer is no longer active.");
    }
    const expiresAt = offerSnapshot.get("expiresAt");
    const expired = expiresAt && expiresAt.toDate() <= now;
    const order = orderSnapshot.data();
    if (order.assignmentStatus !== "offered" || order.paymentStatus !== "unpaid") {
      throw new functions.https.HttpsError("failed-precondition", "This order is no longer awaiting a Tailor response.");
    }
    if (expired || decision === "decline") {
      responseStatus = expired ? "expired" : "declined";
      // The reservation tracks the active offer; legacy capacity counters are
      // released only when an older reservation still carries a dateKey.
      await releaseHeldReservation(transaction, reservationSnapshot);
      transaction.update(offerRef, {status: responseStatus, respondedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
      const attempted = Array.isArray(state.attemptedCandidateKeys) ? state.attemptedCandidateKeys : [];
      const attemptedCandidateKeys = Array.from(new Set([...attempted, profileKey(accountId, profileId)]));
      transaction.update(stateRef, {
        status: "searching",
        currentOfferId: null,
        activeCandidate: null,
        attemptedCandidateKeys,
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.update(orderRef, {assignmentStatus: "searching", updatedAt: SERVER_TIMESTAMP});
      transaction.set(eventRefFor(orderId), eventData(
        expired ? "tailor_offer_timed_out" : "tailor_offer_declined",
        expired ? "system" : "tailor",
        {accountId, profileId, offerId},
      ));
      shouldDispatch = true;
      return;
    }

    const profile = profileSnapshot.data();
    if (!profileIsApprovedTailor(profile) || !reservationSnapshot.exists || reservationSnapshot.get("status") !== "held") {
      throw new functions.https.HttpsError("failed-precondition", "Your Partner profile or offer reservation is no longer eligible for this offer.");
    }
    const price = Number(order.price || 0);
    if (price <= 0) throw new functions.https.HttpsError("failed-precondition", "The order does not have an agreed price yet.");
    const customerDeadline = customerDecisionDeadline(now, dispatchHours);
    transaction.update(offerRef, {status: "accepted", respondedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    transaction.update(stateRef, {status: "awaiting_customer_decision", currentOfferId: null, activeCandidate: null, assignedTailor: {accountId, profileId}, updatedAt: SERVER_TIMESTAMP});
    transaction.update(reservationRef, {status: "accepted", acceptedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    transaction.update(orderRef, {
      assignmentStatus: "awaiting_customer_decision",
      assignedTailorAccountId: accountId,
      assignedTailorProfileId: profileId,
      assignedTailorName: admin.firestore.FieldValue.delete(),
      tailorName: admin.firestore.FieldValue.delete(),
      assignmentAcceptedAt: SERVER_TIMESTAMP,
      customerDecisionExpiresAt: admin.firestore.Timestamp.fromDate(customerDeadline),
      paymentStatus: "pending_payment",
      advancePercent: 50,
      advanceAmount: price * 0.5,
      balanceAmount: price * 0.5,
      expectedReadyAt: admin.firestore.Timestamp.fromDate(expectedReadyAt),
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("tailor_accepted_customer_decision_opened", "tailor", {
      accountId,
      profileId,
      customerDecisionExpiresAt: admin.firestore.Timestamp.fromDate(customerDeadline),
      expectedReadyAt: admin.firestore.Timestamp.fromDate(expectedReadyAt),
    }));
  });

  if (shouldDispatch) await dispatchNextOffer(orderId);
  return {status: responseStatus, nextOfferQueued: shouldDispatch};
}

async function declineCustomerDecision(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);

  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, stateSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(stateRef), transaction.get(reservationRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    if (orderSnapshot.get("assignmentStatus") !== "awaiting_customer_decision" || orderSnapshot.get("paymentStatus") !== "pending_payment") {
      throw new functions.https.HttpsError("failed-precondition", "This order is not waiting for your decision.");
    }
    const expiry = orderSnapshot.get("customerDecisionExpiresAt");
    if (expiry && expiry.toDate() <= new Date()) throw new functions.https.HttpsError("deadline-exceeded", "The decision window has expired; the request is being returned to support.");
    await releaseHeldReservation(transaction, reservationSnapshot);
    transaction.update(orderRef, {
      status: "cancelled",
      assignmentStatus: "cancelled",
      adminQueueReason: "customer_declined_before_finalization",
      paymentStatus: "unpaid",
      cancellationFeePercent: 0,
      cancellationFeeAmount: 0,
      cancellationRefundDue: 0,
      cancellationFeeOutstanding: 0,
      cancellationFeeWaived: false,
      cancelledAt: SERVER_TIMESTAMP,
      cancelledBy: "customer",
      updatedAt: SERVER_TIMESTAMP,
    });
    if (stateSnapshot.exists) transaction.update(stateRef, {status: "cancelled", currentOfferId: null, activeCandidate: null, updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData("customer_declined_before_finalization", "customer", {noCancellationFee: true}));
  });
  return {status: "cancelled", cancellationFee: 0};
}

async function completeSandboxPayment(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  const orderId = text(data && data.orderId);
  const method = text(data && data.paymentMethod);
  if (!orderId || !["card", "upi", "netbanking"].includes(method)) {
    throw new functions.https.HttpsError("invalid-argument", "A valid order and payment method are required.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);
  const configRef = db.doc("config/payouts");
  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, configSnapshot, stateSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(configRef), transaction.get(stateRef), transaction.get(reservationRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    if (configSnapshot.exists && configSnapshot.get("sandboxMode") === false) {
      throw new functions.https.HttpsError("failed-precondition", "Live payments are not enabled for this build.");
    }
    const order = orderSnapshot.data();
    if (order.assignmentStatus !== "awaiting_customer_decision" || order.paymentStatus !== "pending_payment") {
      throw new functions.https.HttpsError("failed-precondition", "This order is not ready for advance payment.");
    }
    const expectedReadyAt = order.expectedReadyAt;
    if (!expectedReadyAt || typeof expectedReadyAt.toDate !== "function" || expectedReadyAt.toDate() <= new Date()) {
      throw new functions.https.HttpsError("failed-precondition", "A valid Tailor completion date is required before advance payment.");
    }
    const expiry = order.customerDecisionExpiresAt;
    if (!expiry || expiry.toDate() <= new Date()) {
      throw new functions.https.HttpsError("deadline-exceeded", "The customer decision deadline has passed.");
    }
    const price = Number(order.price || 0);
    const advance = Number(order.advanceAmount || 0);
    if (price <= 0 || Math.abs(advance - price * 0.5) > 0.01 || !reservationSnapshot.exists || reservationSnapshot.get("status") !== "accepted") {
      throw new functions.https.HttpsError("failed-precondition", "The accepted order or 50% advance is invalid.");
    }
    transaction.update(orderRef, {
      paymentStatus: "advancePaid",
      assignmentStatus: "finalized",
      measurementStatus: "awaiting_arrangement",
      inboundPickupStatus: "awaiting_assignment",
      orderFinalizedAt: SERVER_TIMESTAMP,
      paidAt: SERVER_TIMESTAMP,
      paymentMethod: method,
      paymentProvider: "sandbox",
      amountPaid: advance,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.update(reservationRef, {status: "consumed", consumedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    if (stateSnapshot.exists) transaction.update(stateRef, {status: "finalized", finalizedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData("customer_advance_paid_order_finalized", "customer", {
      amount: advance,
      percent: 50,
      measurementStatus: "awaiting_arrangement",
      inboundPickupStatus: "awaiting_assignment",
    }));
  });
  const orderTrackingId = await ensureOrderTrackingId(orderId);
  await assignInboundFulfillment(orderId);
  return {status: "finalized", orderTrackingId};
}

function money(value) {
  return Math.round(Number(value || 0) * 100) / 100;
}

async function cancelCoreTailoringOrder(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);
  const policyRef = db.doc("config/order_lifecycle");
  let result = null;

  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, stateSnapshot, reservationSnapshot, policySnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(stateRef), transaction.get(reservationRef), transaction.get(policyRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    const order = orderSnapshot.data() || {};
    if (order.assignmentVersion !== "v1" || order.orderModuleType !== "coreTailoring") {
      throw new functions.https.HttpsError("failed-precondition", "This cancellation option is for production tailoring orders.");
    }
    if (!["pending", "pickedUp", "atTailor"].includes(text(order.status))) {
      throw new functions.https.HttpsError("failed-precondition", "Cancellation is unavailable once stitching starts or the order moves beyond that stage.");
    }
    if (order.status === "cancelled" || order.assignmentStatus === "cancelled") {
      throw new functions.https.HttpsError("failed-precondition", "This order is already cancelled.");
    }

    const state = stateSnapshot.data() || {};
    let activeOfferSnapshot = null;
    let activeOfferRef = null;
    if (state.currentOfferId && state.activeCandidate) {
      activeOfferRef = offerRefFor(state.activeCandidate.accountId, state.activeCandidate.profileId, state.currentOfferId);
      activeOfferSnapshot = await transaction.get(activeOfferRef);
    }

    const policy = policySnapshot.data() || {};
    const configuredPercent = Number(policy.cancellationFeePercent ?? 10);
    const policyPercent = Number.isFinite(configuredPercent) ? Math.max(0, Math.min(100, configuredPercent)) : 10;
    const finalized = order.assignmentStatus === "finalized" || ["advancePaid", "fullyPaid"].includes(order.paymentStatus);
    const feePercent = finalized ? policyPercent : 0;
    const total = Math.max(0, Number(order.price || 0));
    const paid = order.paymentStatus === "fullyPaid" ? total : Math.max(0, Number(order.amountPaid || 0));
    const fee = money(total * feePercent / 100);
    const refundDue = money(Math.max(0, paid - fee));
    const feeOutstanding = money(Math.max(0, fee - paid));

    await releaseHeldReservation(transaction, reservationSnapshot);
    if (activeOfferSnapshot && activeOfferSnapshot.exists && activeOfferSnapshot.get("status") === "offered") {
      transaction.update(activeOfferRef, {status: "withdrawn_by_customer", respondedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    }
    transaction.update(orderRef, {
      status: "cancelled",
      assignmentStatus: "cancelled",
      adminQueueReason: "customer_cancelled",
      cancellationFeePercent: feePercent,
      cancellationFeeAmount: fee,
      cancellationRefundDue: refundDue,
      cancellationFeeOutstanding: feeOutstanding,
      cancellationFeeWaived: false,
      cancelledAt: SERVER_TIMESTAMP,
      cancelledBy: "customer",
      updatedAt: SERVER_TIMESTAMP,
    });
    if (stateSnapshot.exists) {
      transaction.update(stateRef, {status: "cancelled", currentOfferId: null, activeCandidate: null, updatedAt: SERVER_TIMESTAMP});
    }
    transaction.set(eventRefFor(orderId), eventData("customer_cancelled_order", "customer", {
      cancellationFeePercent: feePercent,
      cancellationFeeAmount: fee,
      amountPaid: paid,
      refundDue,
      feeOutstanding,
      cancellationFeeWaived: false,
    }));
    result = {status: "cancelled", cancellationFeePercent: feePercent, cancellationFeeAmount: fee, refundDue, feeOutstanding};
  });
  return result;
}

async function waiveOrderCancellationFee(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderRef = db.collection("orders").doc(orderId);
  let outcome = null;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists || snapshot.get("status") !== "cancelled") {
      throw new functions.https.HttpsError("failed-precondition", "Only a cancelled order can have its fee waived.");
    }
    const order = snapshot.data() || {};
    const oldFee = Number(order.cancellationFeeAmount || 0);
    if (oldFee <= 0 || order.cancellationFeeWaived === true) {
      throw new functions.https.HttpsError("failed-precondition", "This order has no cancellation fee available to waive.");
    }
    const paid = order.paymentStatus === "fullyPaid" ? Number(order.price || 0) : Number(order.amountPaid || 0);
    transaction.update(orderRef, {
      cancellationFeeOriginalAmount: oldFee,
      cancellationFeeAmount: 0,
      cancellationFeeOutstanding: 0,
      cancellationRefundDue: money(Math.max(0, paid)),
      cancellationFeeWaived: true,
      cancellationFeeWaivedAt: SERVER_TIMESTAMP,
      cancellationFeeWaivedByUid: context.auth.uid,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("admin_waived_cancellation_fee", "admin", {
      originalFeeAmount: oldFee,
      refundDue: money(Math.max(0, paid)),
      adminUid: context.auth.uid,
    }));
    outcome = {status: "waived", refundDue: money(Math.max(0, paid))};
  });
  return outcome;
}

async function completeSandboxBalancePayment(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const method = text(data && data.paymentMethod);
  if (!orderId || !["card", "upi", "netbanking"].includes(method)) {
    throw new functions.https.HttpsError("invalid-argument", "A valid order and payment method are required.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  const policyRef = db.doc("config/payouts");
  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, paymentConfig] = await Promise.all([transaction.get(orderRef), transaction.get(policyRef)]);
    if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    if (paymentConfig.exists && paymentConfig.get("sandboxMode") === false) {
      throw new functions.https.HttpsError("failed-precondition", "Live payments are not enabled for this build.");
    }
    const order = orderSnapshot.data() || {};
    if (order.assignmentVersion !== "v1" || order.assignmentStatus !== "finalized" ||
        order.status !== "readyForPickup" || order.paymentStatus !== "advancePaid") {
      throw new functions.https.HttpsError("failed-precondition", "The remaining payment is available after the Tailor marks the order ready.");
    }
    const total = Math.max(0, Number(order.price || 0));
    const paid = Math.max(0, Number(order.amountPaid || order.advanceAmount || 0));
    const remaining = money(Math.max(0, total - paid));
    if (total <= 0 || remaining <= 0 || Math.abs(remaining - Number(order.balanceAmount || 0)) > 1) {
      throw new functions.https.HttpsError("failed-precondition", "The remaining payment amount is invalid.");
    }
    transaction.update(orderRef, {
      paymentStatus: "fullyPaid",
      amountPaid: total,
      balanceAmount: 0,
      balancePaidAt: SERVER_TIMESTAMP,
      balancePaymentMethod: method,
      paymentProvider: "sandbox",
      outboundHandoverStatus: "awaiting_assignment",
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("customer_balance_paid", "customer", {amount: remaining, paymentProvider: "sandbox"}));
  });
  await assignOutboundFulfillment(orderId);
  return {status: "fullyPaid"};
}

function profileIsApprovedDeliveryPartner(profile) {
  return Boolean(profile && profile.role === "partner" && profile.partnerType === "deliveryPartner" &&
    profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified");
}

async function advanceProductionTailorOrderStatus(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const nextStatus = text(data && data.nextStatus);
  if (!accountId || !profileId || !orderId || !nextStatus) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor profile, order, and next status are required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Tailor account to update this order.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "An active approved Tailor profile is required.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("assignmentStatus") !== "finalized" ||
        orderSnapshot.get("assignedTailorAccountId") !== accountId ||
        orderSnapshot.get("assignedTailorProfileId") !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "This order is not assigned to this Tailor profile.");
    }
    if (!["advancePaid", "fullyPaid"].includes(orderSnapshot.get("paymentStatus"))) {
      throw new functions.https.HttpsError("failed-precondition", "The Customer advance must be paid before work begins.");
    }
    const allowedNext = {
      atTailor: "inStitching",
      inStitching: "qcPending",
      qcPending: "qcPassed",
      qcPassed: "readyForPickup",
    }[text(orderSnapshot.get("status"))];
    if (allowedNext !== nextStatus) {
      throw new functions.https.HttpsError("failed-precondition", "Orders must move through the Tailor workflow in sequence.");
    }
    if (orderSnapshot.get("measurementStatus") !== "completed") {
      throw new functions.https.HttpsError("failed-precondition", "Confirm the measurements again before advancing this order.");
    }
    if (nextStatus === "inStitching") {
      const estimate = asMap(orderSnapshot.get("fabricPurchaseEstimate"));
      if (Number.isFinite(Number(estimate.estimatedMeters))) {
        const review = asMap(orderSnapshot.get("fabricRequirementReview"));
        if (!["verified_no_shortfall", "customer_confirmed"].includes(text(review.status))) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              text(review.status) === "shortfall_pending_customer"
                  ? "The Customer must confirm the additional fabric before cutting or stitching begins."
                  : "Check the actual fabric quantity with the Customer before cutting." );
        }
      }
    }
    if (nextStatus === "inStitching" &&
        orderSnapshot.get("inboundPickupStatus") !== "receivedAtTailor") {
      throw new functions.https.HttpsError("failed-precondition", "Confirm receipt of the Customer's item before stitching.");
    }
    transaction.update(orderRef, {
      status: nextStatus,
      ...(nextStatus === "readyForPickup" ? {readyAt: SERVER_TIMESTAMP} : {}),
      ...(nextStatus === "readyForPickup" ? {
        outboundHandoverStatus: orderSnapshot.get("paymentStatus") === "fullyPaid" ? "awaiting_assignment" : "awaiting_full_payment",
      } : {}),
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("tailor_order_status_updated", "tailor", {
      accountId, profileId, fromStatus: orderSnapshot.get("status"), toStatus: nextStatus,
    }));
  });
  if (nextStatus === "readyForPickup") await assignOutboundFulfillment(orderId);
  return {status: nextStatus};
}

async function saveTailorFabricRequirementReview(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const actualMeters = Number(data && data.actualRequiredMeters);
  const note = text(data && data.note).slice(0, 600);
  if (!accountId || !profileId || !orderId || !Number.isFinite(actualMeters) ||
      actualMeters <= 0 || actualMeters > 100) {
    throw new functions.https.HttpsError("invalid-argument", "Enter the Tailor's actual fabric requirement in metres.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  let reviewStatus = "verified_no_shortfall";
  let shortfallMeters = 0;
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Tailor account to update this order.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "An active approved Tailor profile is required.");
    }
    const order = orderSnapshot.data() || {};
    if (!orderSnapshot.exists || order.assignmentVersion !== "v1" ||
        order.assignmentStatus !== "finalized" || order.assignedTailorAccountId !== accountId ||
        order.assignedTailorProfileId !== profileId || order.status !== "atTailor" ||
        order.inboundPickupStatus !== "receivedAtTailor") {
      throw new functions.https.HttpsError("failed-precondition", "Fabric quantity must be checked by the assigned Tailor before stitching begins.");
    }
    const estimate = asMap(order.fabricPurchaseEstimate);
    const estimatedMeters = Number(estimate.estimatedMeters);
    if (Number.isFinite(estimatedMeters)) {
      shortfallMeters = Math.max(0, Number((actualMeters - estimatedMeters).toFixed(1)));
      if (shortfallMeters > 0) reviewStatus = "shortfall_pending_customer";
    }
    const review = {
      estimatedMeters: Number.isFinite(estimatedMeters) ? estimatedMeters : null,
      actualRequiredMeters: Number(actualMeters.toFixed(1)),
      shortfallMeters,
      status: reviewStatus,
      note,
      reviewedAt: SERVER_TIMESTAMP,
      reviewedByAccountId: accountId,
      reviewedByProfileId: profileId,
    };
    transaction.update(orderRef, {fabricRequirementReview: review, updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData(
        reviewStatus === "shortfall_pending_customer" ? "tailor_reported_fabric_shortfall" : "tailor_verified_fabric_quantity",
        "tailor",
        {accountId, profileId, estimatedMeters: review.estimatedMeters, actualRequiredMeters: review.actualRequiredMeters, shortfallMeters},
    ));
  });
  return {status: reviewStatus, shortfallMeters};
}

async function confirmCustomerFabricShortfall(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const uid = text(context.auth.uid);
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "Order ID is required.");
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    const order = snapshot.data() || {};
    const review = asMap(order.fabricRequirementReview);
    if (!snapshot.exists || order.customerId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "This order does not belong to your account.");
    }
    if (text(review.status) !== "shortfall_pending_customer" || order.status !== "atTailor") {
      throw new functions.https.HttpsError("failed-precondition", "There is no fabric shortfall waiting for your confirmation.");
    }
    transaction.update(orderRef, {
      "fabricRequirementReview.status": "customer_confirmed",
      "fabricRequirementReview.customerConfirmedAt": SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("customer_confirmed_fabric_shortfall", "customer", {
      customerUid: uid,
      shortfallMeters: Number(review.shortfallMeters || 0),
    }));
  });
  return {status: "customer_confirmed"};
}

async function confirmTailorProductionTask(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const action = text(data && data.action);
  const trackingCode = text(data && data.orderTrackingId);
  if (!accountId || !profileId || !orderId || !trackingCode ||
      !["confirmMeasurement", "reopenMeasurement", "receivePickup"].includes(action)) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor, order, action, and 12-digit order ID are required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const fallbackHistoryIdTimestamp = Date.now();
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Tailor account to update this order.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "An active approved Tailor profile is required.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("assignmentStatus") !== "finalized" ||
        orderSnapshot.get("assignedTailorAccountId") !== accountId ||
        orderSnapshot.get("assignedTailorProfileId") !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "This order is not assigned to this Tailor profile.");
    }
    const order = orderSnapshot.data() || {};
    if (order.orderTrackingId !== trackingCode || !/^\d{12}$/.test(trackingCode)) {
      throw new functions.https.HttpsError("invalid-argument", "The 12-digit order ID does not match this order.");
    }
    if (! ["advancePaid", "fullyPaid"].includes(order.paymentStatus)) {
      throw new functions.https.HttpsError("failed-precondition", "The Customer advance must be paid before work begins.");
    }
    if (order.status === "cancelled") {
      throw new functions.https.HttpsError("failed-precondition", "Tasks cannot be updated for a cancelled order.");
    }

    const updates = {updatedAt: SERVER_TIMESTAMP};
    let eventType;
    if (action === "confirmMeasurement") {
      if (order.measurementStatus === "completed") {
        throw new functions.https.HttpsError("failed-precondition", "Measurements are already confirmed.");
      }
      if (["measurement_partner_home_visit", "video_appointment"].includes(order.measurementMethod) &&
          order.measurementSubmissionStatus !== "completed") {
        throw new functions.https.HttpsError("failed-precondition", "Wait for the Measurement Partner to submit the collected measurements before final confirmation.");
      }
      updates.measurementStatus = "completed";
      updates.measurementConfirmedAt = SERVER_TIMESTAMP;
      updates.measurementConfirmedByAccountId = accountId;
      updates.measurementConfirmedByProfileId = profileId;
      eventType = "production_measurement_confirmed_by_tailor";
    } else if (action === "reopenMeasurement") {
      if (["readyForPickup", "outForDelivery", "delivered"].includes(order.status)) {
        throw new functions.https.HttpsError("failed-precondition", "Measurements cannot be re-initiated after the order is ready for delivery.");
      }
      // The assigned Tailor remains the final authority and may reopen the
      // measurement step through stitching and QC when a correction or second
      // confirmation is needed. Keep the prior confirmation in event history.
      updates.measurementStatus = "awaiting_arrangement";
      const priorMeasurement = measurementHistoryEntry(order, "tailor_reinitiated_measurement");
      if (priorMeasurement) {
        updates.measurementHistory = admin.firestore.FieldValue.arrayUnion(priorMeasurement);
        archiveMeasurementPartnerSubmission(
          transaction,
          order,
          orderId,
          text(order.measurementPartnerCompletedByAccountId),
          text(order.measurementPartnerCompletedByProfileId),
          priorMeasurement,
          fallbackHistoryIdTimestamp,
        );
      }
      updates.measurementMethod = admin.firestore.FieldValue.delete();
      updates.measurementAppointmentAt = admin.firestore.FieldValue.delete();
      updates.measurementAppointmentLink = admin.firestore.FieldValue.delete();
      updates.measurementAppointmentScheduledAt = admin.firestore.FieldValue.delete();
      updates.measurementNotes = admin.firestore.FieldValue.delete();
      updates.measurementSubmissionStatus = admin.firestore.FieldValue.delete();
      updates.measurementSubmittedValues = admin.firestore.FieldValue.delete();
      updates.measurementSubmittedUnit = admin.firestore.FieldValue.delete();
      updates.measurementPartnerCompletionNote = admin.firestore.FieldValue.delete();
      updates.measurementPartnerCompletedAt = admin.firestore.FieldValue.delete();
      updates.measurementPartnerCompletedByAccountId = admin.firestore.FieldValue.delete();
      updates.measurementPartnerCompletedByProfileId = admin.firestore.FieldValue.delete();
      updates.measurementPartnerAccountId = admin.firestore.FieldValue.delete();
      updates.measurementPartnerProfileId = admin.firestore.FieldValue.delete();
      updates.measurementPartnerName = admin.firestore.FieldValue.delete();
      if (order.measurementConfirmedAt) {
        updates.measurementPreviousConfirmedAt = order.measurementConfirmedAt;
      }
      updates.measurementConfirmedAt = admin.firestore.FieldValue.delete();
      updates.measurementConfirmedByAccountId = admin.firestore.FieldValue.delete();
      updates.measurementConfirmedByProfileId = admin.firestore.FieldValue.delete();
      updates.measurementReopenedAt = SERVER_TIMESTAMP;
      updates.measurementReopenedByAccountId = accountId;
      updates.measurementReopenedByProfileId = profileId;
      eventType = "production_measurement_reopened_by_tailor";
    } else {
      if (order.inboundPickupStatus !== "collectedFromCustomer") {
        throw new functions.https.HttpsError("failed-precondition", "The Delivery Partner must record collection before the Tailor can confirm receipt.");
      }
      updates.inboundPickupStatus = "receivedAtTailor";
      updates.inboundPickupReceivedAt = SERVER_TIMESTAMP;
      updates.inboundPickupReceivedByAccountId = accountId;
      updates.inboundPickupReceivedByProfileId = profileId;
      eventType = "inbound_pickup_received_at_tailor";
    }
    const measurementComplete = action === "confirmMeasurement" ||
      (action !== "reopenMeasurement" && order.measurementStatus === "completed");
    const pickupReceived = action === "receivePickup" || order.inboundPickupStatus === "receivedAtTailor";
    if (measurementComplete && pickupReceived && order.status === "pending") {
      updates.status = "atTailor";
      updates.atTailorAt = SERVER_TIMESTAMP;
    }
    transaction.update(orderRef, updates);
    transaction.set(eventRefFor(orderId), eventData(eventType, "tailor", {
      accountId, profileId, orderTrackingId: trackingCode,
    }));
    if (measurementComplete && pickupReceived && order.status === "pending") {
      transaction.set(eventRefFor(orderId), eventData("order_ready_for_stitching", "system", {
        orderTrackingId: trackingCode,
      }));
    }
  });
  return {status: action === "confirmMeasurement" ? "measurementCompleted" :
    action === "reopenMeasurement" ? "measurementReopened" : "receivedAtTailor"};
}

async function getMeasurementPartnerCandidates(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const method = text(data && data.method);
  if (!accountId || !profileId || !orderId ||
      !["measurement_partner_home_visit", "video_appointment"].includes(method)) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor, order, and partner-assisted measurement method are required.");
  }
  const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
    db.collection("accounts").doc(accountId).get(),
    db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get(),
    db.collection("orders").doc(orderId).get(),
  ]);
  if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
      !profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
    throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile to select a Measurement Partner.");
  }
  const order = orderSnapshot.data() || {};
  if (!orderSnapshot.exists || order.assignmentVersion !== "v1" ||
      order.assignmentStatus !== "finalized" || order.assignedTailorAccountId !== accountId ||
      order.assignedTailorProfileId !== profileId ||
      !["advancePaid", "fullyPaid"].includes(order.paymentStatus) || order.measurementStatus === "completed" ||
      order.status === "cancelled") {
    throw new functions.https.HttpsError("failed-precondition", "This paid order is not available for measurement partner assignment.");
  }
  const partnerProfiles = await db.collectionGroup("profiles")
      .where("partnerType", "==", "measurementPartner").get();
  const candidates = partnerProfiles.docs.filter((snapshot) => {
    const profile = snapshot.data() || {};
    const partnerAccountRef = snapshot.ref.parent.parent;
    const partnerAccountId = partnerAccountRef ? partnerAccountRef.id : text(profile.accountId);
    const isTailorSelfHomeVisit = method === "measurement_partner_home_visit" &&
      partnerAccountId === accountId;
    return profileIsApprovedMeasurementPartner(profile) &&
      (isTailorSelfHomeVisit || (measurementPartnerSupportsMethod(profile, method) &&
        (method === "video_appointment" || measurementPartnerCoversOrder(profile, order))));
  }).map((snapshot) => {
    const profile = snapshot.data() || {};
    const accountRef = snapshot.ref.parent.parent;
    return {
      accountId: accountRef ? accountRef.id : text(profile.accountId),
      profileId: snapshot.id,
      displayName: text(profile.businessName || profile.displayName || profile.contactName || "Measurement Partner"),
      contactName: text(profile.contactName),
      mobileE164: text(profile.mobileE164),
    };
  });
  candidates.sort((left, right) => {
    const leftIsTailorAccount = left.accountId === accountId;
    const rightIsTailorAccount = right.accountId === accountId;
    return Number(rightIsTailorAccount) - Number(leftIsTailorAccount) ||
      left.displayName.localeCompare(right.displayName);
  });
  return {candidates};
}

async function saveTailorMeasurementPlan(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const method = text(data && data.method);
  const notes = text(data && data.notes);
  const requestedMeasurementPartnerAccountId = text(data && data.measurementPartnerAccountId);
  const requestedMeasurementPartnerProfileId = text(data && data.measurementPartnerProfileId);
  const allowedMethods = new Set([
    "tailor_home_visit",
    "measurement_partner_home_visit",
    "previous_measurement",
    "old_garment_reference",
    "video_appointment",
  ]);
  if (!accountId || !profileId || !orderId || !allowedMethods.has(method)) {
    throw new functions.https.HttpsError("invalid-argument", "Tailor, order, and a supported measurement method are required.");
  }
  if (notes.length > 1200) {
    throw new functions.https.HttpsError("invalid-argument", "Measurement notes are too long.");
  }
  const partnerAssisted = ["measurement_partner_home_visit", "video_appointment"].includes(method);
  const selfTailorMeasurement = method === "tailor_home_visit";
  if (partnerAssisted && (!requestedMeasurementPartnerAccountId || !requestedMeasurementPartnerProfileId)) {
    throw new functions.https.HttpsError("invalid-argument", "Select an approved Measurement Partner for this method.");
  }
  const appointmentAtText = text(data && data.appointmentAt);
  const appointmentAtDate = appointmentAtText ? new Date(appointmentAtText) : null;
  const needsAppointment = method === "tailor_home_visit";
  if (needsAppointment && (!appointmentAtDate || Number.isNaN(appointmentAtDate.getTime()) || appointmentAtDate <= new Date())) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a future measurement appointment date and time.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  let measurementPartnerAccountId = partnerAssisted ? requestedMeasurementPartnerAccountId : "";
  let measurementPartnerProfileId = partnerAssisted ? requestedMeasurementPartnerProfileId : "";
  let measurementPartnerProfileRef = partnerAssisted ?
    db.collection("accounts").doc(measurementPartnerAccountId).collection("profiles").doc(measurementPartnerProfileId) : null;
  if (selfTailorMeasurement) {
    // A Tailor who also has an approved Measurement Partner profile should see
    // their self-assigned home visit in the same workspace and complete it with
    // the same measurement form as an external Measurement Partner.
    const [orderForEligibility, ownMeasurementProfiles] = await Promise.all([
      orderRef.get(),
      accountRef.collection("profiles").where("partnerType", "==", "measurementPartner").get(),
    ]);
    const orderForCoverage = orderForEligibility.data() || {};
    const eligibleSelfProfile = ownMeasurementProfiles.docs.find((snapshot) => {
      const partnerProfile = snapshot.data() || {};
      return profileIsApprovedMeasurementPartner(partnerProfile) &&
        measurementPartnerSupportsMethod(partnerProfile, method) &&
        measurementPartnerCoversOrder(partnerProfile, orderForCoverage);
    });
    if (eligibleSelfProfile) {
      measurementPartnerAccountId = accountId;
      measurementPartnerProfileId = eligibleSelfProfile.id;
      measurementPartnerProfileRef = eligibleSelfProfile.ref;
    }
  }
  const fallbackHistoryIdTimestamp = Date.now();
  await db.runTransaction(async (transaction) => {
    const snapshots = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
      ...(measurementPartnerProfileRef ? [transaction.get(measurementPartnerProfileRef)] : []),
    ]);
    const [accountSnapshot, profileSnapshot, orderSnapshot, measurementPartnerSnapshot] = snapshots;
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Tailor account to update this order.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "An active approved Tailor profile is required.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("assignmentStatus") !== "finalized" ||
        orderSnapshot.get("assignedTailorAccountId") !== accountId ||
        orderSnapshot.get("assignedTailorProfileId") !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "This order is not assigned to this Tailor profile.");
    }
    const order = orderSnapshot.data() || {};
    if (!["advancePaid", "fullyPaid"].includes(order.paymentStatus) || order.measurementStatus === "completed") {
      throw new functions.https.HttpsError("failed-precondition", "A paid order with measurements still to arrange is required.");
    }
    if (order.status === "cancelled") {
      throw new functions.https.HttpsError("failed-precondition", "Measurement arrangements cannot be changed for a cancelled order.");
    }
    let linkedMeasurementPartner = partnerAssisted;
    if (partnerAssisted) {
      const partnerProfile = measurementPartnerSnapshot && measurementPartnerSnapshot.data() || {};
      const selfTailorHomeVisit = method === "measurement_partner_home_visit" &&
        measurementPartnerAccountId === accountId;
      if (!measurementPartnerSnapshot || !measurementPartnerSnapshot.exists ||
          !profileIsApprovedMeasurementPartner(partnerProfile) ||
          (!selfTailorHomeVisit && (!measurementPartnerSupportsMethod(partnerProfile, method) ||
            (method === "measurement_partner_home_visit" && !measurementPartnerCoversOrder(partnerProfile, order))))) {
        throw new functions.https.HttpsError("failed-precondition", "Choose an active, approved Measurement Partner who serves this order's area.");
      }
    } else if (selfTailorMeasurement && measurementPartnerSnapshot && measurementPartnerSnapshot.exists) {
      const partnerProfile = measurementPartnerSnapshot.data() || {};
      linkedMeasurementPartner = profileIsApprovedMeasurementPartner(partnerProfile) &&
        measurementPartnerSupportsMethod(partnerProfile, method) &&
        measurementPartnerCoversOrder(partnerProfile, order);
    }
    const measurementStatus = partnerAssisted ? "awaiting_appointment" :
      selfTailorMeasurement ? "appointment_scheduled" : "awaiting_arrangement";
    const updates = {
      measurementMethod: method,
      measurementStatus,
      measurementSubmissionStatus: admin.firestore.FieldValue.delete(),
      measurementSubmittedValues: admin.firestore.FieldValue.delete(),
      measurementSubmittedUnit: admin.firestore.FieldValue.delete(),
      measurementPartnerCompletionNote: admin.firestore.FieldValue.delete(),
      measurementPartnerCompletedAt: admin.firestore.FieldValue.delete(),
      measurementPartnerCompletedByAccountId: admin.firestore.FieldValue.delete(),
      measurementPartnerCompletedByProfileId: admin.firestore.FieldValue.delete(),
      measurementAppointmentAt: appointmentAtDate ? admin.firestore.Timestamp.fromDate(appointmentAtDate) : null,
      measurementAppointmentLink: null,
      measurementAppointmentScheduledAt: admin.firestore.FieldValue.delete(),
      measurementNotes: notes || null,
      measurementPartnerAccountId: linkedMeasurementPartner ? measurementPartnerAccountId : admin.firestore.FieldValue.delete(),
      measurementPartnerProfileId: linkedMeasurementPartner ? measurementPartnerProfileId : admin.firestore.FieldValue.delete(),
      measurementPartnerName: linkedMeasurementPartner ? text(
        measurementPartnerSnapshot.get("businessName") ||
        measurementPartnerSnapshot.get("displayName") ||
        measurementPartnerSnapshot.get("contactName") || "Measurement Partner",
      ) : admin.firestore.FieldValue.delete(),
      measurementPlanUpdatedAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    };
    const priorMeasurement = measurementHistoryEntry(order, "tailor_updated_measurement_plan");
    if (priorMeasurement) {
      updates.measurementHistory = admin.firestore.FieldValue.arrayUnion(priorMeasurement);
      const historyAccountId = text(order.measurementPartnerCompletedByAccountId);
      const historyProfileId = text(order.measurementPartnerCompletedByProfileId);
      archiveMeasurementPartnerSubmission(
        transaction,
        order,
        orderId,
        historyAccountId,
        historyProfileId,
        priorMeasurement,
        fallbackHistoryIdTimestamp,
      );
    }
    transaction.update(orderRef, updates);
    transaction.set(eventRefFor(orderId), eventData("tailor_measurement_plan_saved", "tailor", {
      accountId,
      profileId,
      method,
      measurementPartnerAccountId: linkedMeasurementPartner ? measurementPartnerAccountId : null,
      measurementPartnerProfileId: linkedMeasurementPartner ? measurementPartnerProfileId : null,
      appointmentAt: appointmentAtDate ? admin.firestore.Timestamp.fromDate(appointmentAtDate) : null,
    }));
  });
  await assignInboundFulfillment(orderId);
  return {status: "saved", method};
}

async function getMeasurementPartnerAssignments(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  if (!accountId || !profileId) {
    throw new functions.https.HttpsError("invalid-argument", "Measurement Partner profile is required.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnapshot, profileSnapshot] = await Promise.all([accountRef.get(), profileRef.get()]);
  if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
      !profileSnapshot.exists || !profileIsApprovedMeasurementPartner(profileSnapshot.data() || {})) {
    throw new functions.https.HttpsError("permission-denied", "Use your own active Measurement Partner profile to view assignments.");
  }
  const [measurementOrders, completedOrders, inboundOrders, outboundOrders, measurementHistorySnapshot] = await Promise.all([
    db.collection("orders").where("measurementPartnerAccountId", "==", accountId).get(),
    db.collection("orders").where("measurementPartnerCompletedByAccountId", "==", accountId).get(),
    db.collection("orders").where("inboundPickupPartnerAccountId", "==", accountId).get(),
    db.collection("orders").where("outboundHandoverPartnerAccountId", "==", accountId).get(),
    accountRef.collection("measurement_history").where("profileId", "==", profileId).get(),
  ]);
  const orderMap = new Map();
  for (const snapshot of [
    ...measurementOrders.docs,
    ...completedOrders.docs,
    ...inboundOrders.docs,
    ...outboundOrders.docs,
  ]) {
    orderMap.set(snapshot.id, snapshot);
  }
  const assignedOrders = Array.from(orderMap.values()).filter((snapshot) => {
    const order = snapshot.data() || {};
    if (order.assignmentStatus !== "finalized" || order.status === "cancelled") return false;
    const measurementTask = order.measurementPartnerProfileId === profileId &&
      order.measurementStatus !== "completed" && order.measurementSubmissionStatus !== "completed";
    const completedMeasurement = order.measurementPartnerCompletedByProfileId === profileId &&
      order.measurementSubmissionStatus === "completed";
    const inboundTask = order.inboundPickupPartnerType === "measurementPartner" &&
      order.inboundPickupPartnerProfileId === profileId && order.inboundPickupStatus === "assigned";
    const outboundTask = order.outboundHandoverPartnerType === "measurementPartner" &&
      order.outboundHandoverPartnerProfileId === profileId &&
      ["assigned", "in_transit"].includes(text(order.outboundHandoverStatus));
    return measurementTask || completedMeasurement || inboundTask || outboundTask;
  });
  const customerAccounts = new Map();
  await Promise.all(assignedOrders.map(async (snapshot) => {
    const order = snapshot.data() || {};
    const customerAccountId = text(order.customerAccountId || order.customerId);
    if (customerAccountId && !customerAccounts.has(customerAccountId)) {
      customerAccounts.set(customerAccountId, db.collection("accounts").doc(customerAccountId).get());
    }
  }));
  const customerSnapshots = new Map();
  await Promise.all(Array.from(customerAccounts.entries()).map(async ([id, promise]) => {
    customerSnapshots.set(id, await promise);
  }));
  const assignments = assignedOrders.map((snapshot) => {
    const order = snapshot.data() || {};
    const customerAccountId = text(order.customerAccountId || order.customerId);
    const customerSnapshot = customerSnapshots.get(customerAccountId);
    const appointmentAt = order.measurementAppointmentAt;
    const measurementCompletedAt = order.measurementPartnerCompletedAt;
    const deliveryLocation = asMap(order.deliveryLocation);
    return {
      orderId: snapshot.id,
      orderTrackingId: text(order.orderTrackingId),
      dressType: text(order.dressType || "Tailoring order"),
      customerName: text(order.personName || order.clientName || order.customerName || "Customer"),
      customerPhone: text(order.customerPhone || order.phone || order.mobileE164 ||
        (customerSnapshot && customerSnapshot.exists && customerSnapshot.get("mobileE164"))),
      designTemplateTitle: text(order.designTemplateTitle || order.designTitle),
      designImageUrl: text(order.designImageUrl || order.designTemplateImageUrl || order.designImage),
      fabricChoice: text(order.fabricChoice || order.fabricType || order.materialType || order.materialName),
      fabricDescription: text(order.fabricDescription || order.materialDescription || order.materialNotes),
      deliveryAddress: text(order.deliveryAddress || deliveryLocation.address || deliveryLocation.fullAddress),
      deliveryPincode: normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode),
      measurementMethod: text(order.measurementMethod),
      measurementStatus: text(order.measurementStatus),
      measurementSubmissionStatus: text(order.measurementSubmissionStatus),
      measurementPartnerCompletedByProfileId: text(order.measurementPartnerCompletedByProfileId),
      measurementPartnerCompletedAt: measurementCompletedAt && typeof measurementCompletedAt.toDate === "function" ?
        measurementCompletedAt.toDate().toISOString() : null,
      measurementPartnerCompletionNote: text(order.measurementPartnerCompletionNote),
      measurementSubmittedValues: asMap(order.measurementSubmittedValues),
      measurementSubmittedUnit: text(order.measurementSubmittedUnit || "in"),
      measurementTask: order.measurementPartnerProfileId === profileId &&
        order.measurementStatus !== "completed" && order.measurementSubmissionStatus !== "completed",
      measurementPartnerAccountId: text(order.measurementPartnerAccountId),
      measurementPartnerProfileId: text(order.measurementPartnerProfileId),
      measurementAppointmentAt: appointmentAt && typeof appointmentAt.toDate === "function" ?
        appointmentAt.toDate().toISOString() : null,
      measurementAppointmentLink: text(order.measurementAppointmentLink),
      measurementNotes: text(order.measurementNotes),
      measurementCriteria: measurementCriteriaForOrder(order),
      inboundPickupStatus: text(order.inboundPickupStatus),
      inboundPickupCollectedAt: order.inboundPickupCollectedAt &&
        typeof order.inboundPickupCollectedAt.toDate === "function" ?
        order.inboundPickupCollectedAt.toDate().toISOString() : null,
      inboundPickupPartnerType: text(order.inboundPickupPartnerType),
      inboundPickupPartnerProfileId: text(order.inboundPickupPartnerProfileId),
      outboundHandoverStatus: text(order.outboundHandoverStatus),
      outboundHandoverPartnerType: text(order.outboundHandoverPartnerType),
      outboundHandoverPartnerProfileId: text(order.outboundHandoverPartnerProfileId),
      paymentStatus: text(order.paymentStatus),
      orderStatus: text(order.status),
    };
  });
  const currentMeasurementKeys = new Set(assignments
      .filter((assignment) => assignment.measurementPartnerCompletedByProfileId === profileId &&
        assignment.measurementSubmissionStatus === "completed")
      .map((assignment) => `${assignment.orderId}:${assignment.measurementPartnerCompletedAt || ""}`));
  for (const historySnapshot of measurementHistorySnapshot.docs) {
    const history = historySnapshot.data() || {};
    const completedAt = history.measurementPartnerCompletedAt &&
      typeof history.measurementPartnerCompletedAt.toDate === "function" ?
      history.measurementPartnerCompletedAt.toDate().toISOString() : null;
    const key = `${text(history.orderId)}:${completedAt || ""}`;
    if (currentMeasurementKeys.has(key)) continue;
    assignments.push({
      ...history,
      orderId: text(history.orderId),
      measurementHistoryId: historySnapshot.id,
      measurementPartnerCompletedByProfileId: text(history.profileId),
      measurementPartnerCompletedAt: completedAt,
      measurementTask: false,
      measurementSubmissionStatus: "completed",
      measurementStatus: "partner_completed",
      inboundPickupStatus: "",
      outboundHandoverStatus: "",
      measurementAppointmentAt: history.measurementAppointmentAt &&
        typeof history.measurementAppointmentAt.toDate === "function" ?
        history.measurementAppointmentAt.toDate().toISOString() : null,
    });
  }
  assignments.sort((left, right) => {
    const leftTime = left.measurementAppointmentAt ? Date.parse(left.measurementAppointmentAt) : Number.MAX_SAFE_INTEGER;
    const rightTime = right.measurementAppointmentAt ? Date.parse(right.measurementAppointmentAt) : Number.MAX_SAFE_INTEGER;
    return leftTime - rightTime;
  });
  return {assignments};
}

async function setMeasurementPartnerAppointment(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const appointmentAtText = text(data && data.appointmentAt);
  const appointmentLink = text(data && data.appointmentLink);
  const appointmentAt = appointmentAtText ? new Date(appointmentAtText) : null;
  if (!accountId || !profileId || !orderId || !appointmentAt || Number.isNaN(appointmentAt.getTime()) ||
      appointmentAt <= new Date()) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a future appointment date and time.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
        !profileSnapshot.exists || !profileIsApprovedMeasurementPartner(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "Use your own active Measurement Partner profile to schedule this appointment.");
    }
    const order = orderSnapshot.data() || {};
    const selfAssignedTailorVisit = ["tailor_home_visit", "measurement_partner_home_visit"].includes(order.measurementMethod) &&
      order.assignedTailorAccountId === accountId;
    if (!orderSnapshot.exists || order.measurementPartnerAccountId !== accountId ||
        order.measurementPartnerProfileId !== profileId ||
        (!["measurement_partner_home_visit", "video_appointment"].includes(order.measurementMethod) &&
          !selfAssignedTailorVisit)) {
      throw new functions.https.HttpsError("permission-denied", "This measurement request is not assigned to this Partner profile.");
    }
    const partnerProfile = profileSnapshot.data() || {};
    const selfAssignedPartnerVisit = order.measurementMethod === "measurement_partner_home_visit" &&
      order.assignedTailorAccountId === accountId;
    if (order.measurementStatus === "completed" || order.measurementSubmissionStatus === "completed" ||
        order.assignmentStatus !== "finalized" ||
        !["advancePaid", "fullyPaid"].includes(order.paymentStatus) || order.status === "cancelled" ||
        (!selfAssignedPartnerVisit && !measurementPartnerSupportsMethod(partnerProfile, order.measurementMethod)) ||
        (["measurement_partner_home_visit", "tailor_home_visit"].includes(order.measurementMethod) &&
          !selfAssignedPartnerVisit && !measurementPartnerCoversOrder(partnerProfile, order))) {
      throw new functions.https.HttpsError("failed-precondition", "This order no longer needs a measurement appointment.");
    }
    if (order.measurementMethod === "video_appointment" && !/^https:\/\//i.test(appointmentLink)) {
      throw new functions.https.HttpsError("invalid-argument", "Add a secure video meeting link.");
    }
    if (appointmentLink.length > 2048) {
      throw new functions.https.HttpsError("invalid-argument", "The video meeting link is too long.");
    }
    transaction.update(orderRef, {
      measurementAppointmentAt: admin.firestore.Timestamp.fromDate(appointmentAt),
      measurementAppointmentLink: order.measurementMethod === "video_appointment" ? appointmentLink : null,
      measurementStatus: "appointment_scheduled",
      measurementAppointmentScheduledAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("measurement_partner_appointment_scheduled", "measurementPartner", {
      accountId,
      profileId,
      method: order.measurementMethod,
      appointmentAt: admin.firestore.Timestamp.fromDate(appointmentAt),
    }));
  });
  return {status: "appointmentScheduled"};
}

function videoAppointmentEventId(orderId) {
  // Google Calendar accepts lower-case base32hex characters for caller-chosen
  // event IDs. A stable ID makes retries update the same event instead of
  // creating duplicate invitations.
  return `suisakhi${crypto.createHash("sha256").update(orderId).digest("hex").slice(0, 40)}`;
}

function videoAppointmentRequestId(orderId, appointmentAt) {
  return crypto.createHash("sha256")
      .update(`${orderId}:${appointmentAt.toISOString()}:meet`)
      .digest("hex").slice(0, 40);
}

function appointmentMeetLink(event) {
  const entryPoints = asMap(event && event.conferenceData).entryPoints;
  if (text(event && event.hangoutLink)) return text(event.hangoutLink);
  if (!Array.isArray(entryPoints)) return "";
  const videoEntry = entryPoints.find((entry) => text(asMap(entry).entryPointType) === "video");
  return text(videoEntry && videoEntry.uri);
}

async function googleCalendarRequest(url, method, accessToken, body) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    ...(body ? {body: JSON.stringify(body)} : {}),
  });
  const responseBody = await response.json().catch(() => ({}));
  if (response.status === 404 && method === "GET") return null;
  if (!response.ok) {
    const error = new Error(`Google Calendar API returned HTTP ${response.status}.`);
    error.status = response.status;
    error.apiMessage = text(asMap(responseBody.error).message);
    throw error;
  }
  return responseBody;
}

async function googleCalendarAccessToken() {
  let oauth;
  try {
    oauth = JSON.parse(process.env[GOOGLE_CALENDAR_OAUTH_SECRET] || "{}");
  } catch (_) {
    throw new Error("Google Calendar OAuth secret must contain valid JSON.");
  }
  const clientId = text(oauth.clientId);
  const clientSecret = text(oauth.clientSecret);
  const refreshToken = text(oauth.refreshToken);
  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("Google Calendar OAuth secret is missing clientId, clientSecret, or refreshToken.");
  }
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  const tokenBody = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !text(tokenBody.access_token)) {
    console.error("Google Calendar OAuth refresh failed", {status: tokenResponse.status});
    throw new Error("Could not authorize the SuiSakhi Google Calendar account.");
  }
  return {accessToken: text(tokenBody.access_token), calendarId: text(oauth.calendarId) || "primary"};
}

async function createOrUpdateVideoMeasurementCalendarEvent({
  orderId,
  order,
  appointmentAt,
  attendeeEmails,
}) {
  const {accessToken, calendarId} = await googleCalendarAccessToken();
  const eventsUrl = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`;
  const eventUrl = `${eventsUrl}/${videoAppointmentEventId(orderId)}`;
  const trackingId = text(order.orderTrackingId) || orderId;
  const endAt = new Date(appointmentAt.getTime() + 30 * 60 * 1000);
  const baseEvent = {
    summary: `SuiSakhi video measurement · ${trackingId}`,
    description: "SuiSakhi video measurement appointment. Open the SuiSakhi app order to view the appointment.",
    start: {dateTime: appointmentAt.toISOString(), timeZone: DEFAULT_DISPATCH_TIME_ZONE},
    end: {dateTime: endAt.toISOString(), timeZone: DEFAULT_DISPATCH_TIME_ZONE},
    attendees: attendeeEmails.map((email) => ({email})),
    reminders: {useDefault: true},
  };
  const requestId = videoAppointmentRequestId(orderId, appointmentAt);
  const conferenceRequest = {
    createRequest: {
      requestId,
      conferenceSolutionKey: {type: "hangoutsMeet"},
    },
  };

  let event = await googleCalendarRequest(eventUrl, "GET", accessToken);
  if (!event) {
    try {
      event = await googleCalendarRequest(`${eventsUrl}?conferenceDataVersion=1&sendUpdates=all`, "POST", accessToken, {
        ...baseEvent,
        id: videoAppointmentEventId(orderId),
        conferenceData: conferenceRequest,
      });
    } catch (error) {
      // A concurrent/retried callable may have created the stable event first.
      if (error.status !== 409) throw error;
      event = await googleCalendarRequest(eventUrl, "GET", accessToken);
      if (!event) throw error;
    }
  } else {
    const patch = {...baseEvent};
    const createStatus = text(asMap(asMap(event.conferenceData).createRequest).status &&
      asMap(asMap(event.conferenceData).createRequest.status).statusCode);
    if (!appointmentMeetLink(event) && createStatus !== "pending") {
      patch.conferenceData = conferenceRequest;
    }
    event = await googleCalendarRequest(`${eventUrl}?conferenceDataVersion=1&sendUpdates=all`, "PATCH", accessToken, patch);
  }

  for (let attempt = 0; attempt < 12; attempt += 1) {
    const link = appointmentMeetLink(event);
    if (link) return {eventId: videoAppointmentEventId(orderId), link};
    await new Promise((resolve) => setTimeout(resolve, 1000));
    event = await googleCalendarRequest(eventUrl, "GET", accessToken);
  }
  throw new Error("Google Calendar has not finished creating the Meet link yet. Please retry shortly.");
}

async function createCustomerConsultationCalendarEvent({
  requestId,
  customerName,
  topicLabel,
  notes,
  appointmentAt,
  attendeeEmails,
}) {
  const {accessToken, calendarId} = await googleCalendarAccessToken();
  const eventsUrl = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`;
  const stableHash = crypto.createHash("sha256").update(requestId).digest("hex");
  const eventId = `sshelp${stableHash.slice(0, 38)}`;
  const eventUrl = `${eventsUrl}/${eventId}`;
  const endAt = new Date(appointmentAt.getTime() + 30 * 60 * 1000);
  const baseEvent = {
    summary: `SuiSakhi fabric & design help · ${topicLabel}`,
    description: [
      "Customer consultation scheduled in SuiSakhi.",
      `Customer: ${text(customerName) || "SuiSakhi customer"}`,
      text(notes) ? `Question: ${text(notes)}` : "",
      "The Tailor confirms final fabric requirements before cutting.",
    ].filter(Boolean).join("\n"),
    start: {dateTime: appointmentAt.toISOString(), timeZone: DEFAULT_DISPATCH_TIME_ZONE},
    end: {dateTime: endAt.toISOString(), timeZone: DEFAULT_DISPATCH_TIME_ZONE},
    attendees: attendeeEmails.map((email) => ({email})),
    reminders: {useDefault: true},
  };
  const conferenceRequest = {
    createRequest: {
      requestId: `sshelp${stableHash.slice(0, 22)}`,
      conferenceSolutionKey: {type: "hangoutsMeet"},
    },
  };
  let event = await googleCalendarRequest(eventUrl, "GET", accessToken);
  if (!event) {
    try {
      event = await googleCalendarRequest(`${eventsUrl}?conferenceDataVersion=1&sendUpdates=all`, "POST", accessToken, {
        ...baseEvent,
        id: eventId,
        conferenceData: conferenceRequest,
      });
    } catch (error) {
      if (error.status !== 409) throw error;
      event = await googleCalendarRequest(eventUrl, "GET", accessToken);
      if (!event) throw error;
    }
  }
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const link = appointmentMeetLink(event);
    if (link) return {eventId, link};
    await new Promise((resolve) => setTimeout(resolve, 1000));
    event = await googleCalendarRequest(eventUrl, "GET", accessToken);
  }
  throw new Error("Google Calendar has not finished creating the Meet link yet. Please retry shortly.");
}

async function scheduleCustomerFabricConsultation(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const uid = text(context.auth.uid);
  const topic = text(data && data.topic);
  const topicLabels = {
    fabric_estimate: "Estimate fabric required",
    fabric_guidance: "Help identify fabric / width",
    design_question: "Design question",
    helpdesk: "General helpdesk",
  };
  const topicLabel = topicLabels[topic];
  const appointmentAt = new Date(text(data && data.appointmentAt));
  const now = Date.now();
  if (!topicLabel || Number.isNaN(appointmentAt.getTime()) ||
      appointmentAt.getTime() <= now || appointmentAt.getTime() > now + 90 * 24 * 60 * 60 * 1000) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a valid future consultation time within the next 90 days.");
  }
  const orderId = text(data && data.orderId);
  const customerRef = db.collection("users").doc(uid);
  const requestRef = db.collection("customer_consultations").doc(uid).collection("requests").doc();
  const customerSnapshot = await customerRef.get();
  const customer = customerSnapshot.data() || {};
  let partnerEmail = "";
  if (orderId) {
    const orderSnapshot = await db.collection("orders").doc(orderId).get();
    const order = orderSnapshot.data() || {};
    if (!orderSnapshot.exists || order.customerId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "That order does not belong to your account.");
    }
    const accountId = text(order.assignedTailorAccountId);
    const profileId = text(order.assignedTailorProfileId);
    if (accountId && profileId) {
      const [account, profile] = await Promise.all([
        db.collection("accounts").doc(accountId).get(),
        db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get(),
      ]);
      const profileData = profile.data() || {};
      partnerEmail = text(profileData.email || (account.exists && account.get("email")));
    }
  }
  const customerEmail = text(customer.email || context.auth.token.email);
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const attendeeEmails = Array.from(new Set([customerEmail, partnerEmail]
      .map((value) => value.trim().toLowerCase())
      .filter((value) => emailPattern.test(value))));
  let meeting;
  try {
    meeting = await createCustomerConsultationCalendarEvent({
      requestId: requestRef.id,
      customerName: text(customer.name || context.auth.token.name),
      topicLabel,
      notes: text(data && data.notes).slice(0, 1000),
      appointmentAt,
      attendeeEmails,
    });
  } catch (error) {
    console.error("Could not create SuiSakhi fabric consultation", {
      uid,
      requestId: requestRef.id,
      message: error && error.message ? error.message : String(error),
      status: error && error.status,
    });
    throw new functions.https.HttpsError("failed-precondition", "SuiSakhi could not create the video consultation link. Please retry or contact support.");
  }
  await requestRef.set({
    requestId: requestRef.id,
    customerUid: uid,
    orderId: orderId || null,
    topic,
    topicLabel,
    notes: text(data && data.notes).slice(0, 1000),
    status: "scheduled",
    appointmentAt: admin.firestore.Timestamp.fromDate(appointmentAt),
    meetingLink: meeting.link,
    calendarEventId: meeting.eventId,
    invitedCustomerEmail: attendeeEmails.includes(customerEmail.trim().toLowerCase()) ? customerEmail : null,
    invitedPartnerEmail: partnerEmail && attendeeEmails.includes(partnerEmail.trim().toLowerCase()) ? partnerEmail : null,
    createdAt: SERVER_TIMESTAMP,
    updatedAt: SERVER_TIMESTAMP,
  });
  return {
    requestId: requestRef.id,
    status: "scheduled",
    meetingLink: meeting.link,
    partnerInvited: Boolean(partnerEmail && attendeeEmails.includes(partnerEmail.trim().toLowerCase())),
  };
}

function appointmentTimeLabel(appointmentAt) {
  return `${new Intl.DateTimeFormat("en-IN", {
    timeZone: DEFAULT_DISPATCH_TIME_ZONE,
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(appointmentAt)} IST`;
}

async function sendMeasurementAppointmentWhatsApp({to, recipientName, appointmentAt, meetLink}) {
  const whatsapp = asMap(functions.config().whatsapp);
  const token = text(process.env.WHATSAPP_TOKEN || whatsapp.token);
  const phoneNumberId = text(process.env.WHATSAPP_PHONE_NUMBER_ID || whatsapp.phone_number_id);
  const templateName = text(whatsapp.measurement_appointment_template);
  const digits = text(to).replace(/\D/g, "");
  if (!token || !phoneNumberId || !templateName || digits.length < 10) return "not_configured";
  const response = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: digits,
      type: "template",
      template: {
        name: templateName,
        language: {code: text(whatsapp.measurement_appointment_language) || "en_US"},
        components: [{
          type: "body",
          parameters: [
            {type: "text", text: text(recipientName) || "there"},
            {type: "text", text: appointmentTimeLabel(appointmentAt)},
            {type: "text", text: meetLink},
          ],
        }],
      },
    }),
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    console.error("Video measurement WhatsApp notification failed", {
      status: response.status,
      message: text(asMap(body.error).message),
    });
    return "failed";
  }
  return "sent";
}

async function loadVideoMeasurementRecipients(order, partnerAccount, partnerProfile) {
  const customerId = text(order.customerId);
  const customerRef = customerId ? db.collection("users").doc(customerId) : null;
  const customerSnapshot = customerRef ? await customerRef.get() : null;
  const customer = customerSnapshot && customerSnapshot.exists ? customerSnapshot.data() || {} : {};
  const customerPhone = text(order.customerPhone || order.phone || customer.phoneNumber);
  const customerEmail = text(order.customerEmail || customer.email);
  const partnerEmail = text(partnerProfile.email || partnerAccount.email);
  const attendeeEmails = Array.from(new Set([customerEmail, partnerEmail]
      .map((email) => email.trim().toLowerCase())
      .filter((email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))));
  return {customer, customerPhone, attendeeEmails};
}

async function sendVideoMeasurementNotifications({order, partnerAccount, partnerProfile, recipients, appointmentAt, meetLink}) {
  const customer = recipients.customer;
  const customerPhone = recipients.customerPhone;
  const waCustomer = customer.notifyWhatsApp === false ? "opted_out" :
    await sendMeasurementAppointmentWhatsApp({
      to: customerPhone,
      recipientName: text(customer.name || order.personName || order.customerName),
      appointmentAt,
      meetLink,
    }).catch((error) => {
      console.error("Customer appointment WhatsApp notification failed", {message: error.message});
      return "failed";
    });
  const waPartner = partnerAccount.notifyWhatsApp === false || partnerProfile.notifyWhatsApp === false ? "opted_out" :
    await sendMeasurementAppointmentWhatsApp({
      to: text(partnerAccount.mobileE164 || partnerProfile.mobileE164 || partnerProfile.phone),
      recipientName: text(partnerProfile.businessName || partnerProfile.displayName || "Measurement Partner"),
      appointmentAt,
      meetLink,
    }).catch((error) => {
      console.error("Partner appointment WhatsApp notification failed", {message: error.message});
      return "failed";
  });
  return {waCustomer, waPartner};
}

async function scheduleVideoMeasurementAppointment(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const appointmentAtText = text(data && data.appointmentAt);
  const appointmentAt = appointmentAtText ? new Date(appointmentAtText) : null;
  if (!accountId || !profileId || !orderId || !appointmentAt || Number.isNaN(appointmentAt.getTime()) ||
      appointmentAt <= new Date()) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a future appointment date and time.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
    accountRef.get(), profileRef.get(), orderRef.get(),
  ]);
  if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
      !profileSnapshot.exists || !profileIsApprovedMeasurementPartner(profileSnapshot.data() || {})) {
    throw new functions.https.HttpsError("permission-denied", "Use your own active Measurement Partner profile to schedule this appointment.");
  }
  const order = orderSnapshot.data() || {};
  const partnerProfile = profileSnapshot.data() || {};
  if (!orderSnapshot.exists || order.measurementMethod !== "video_appointment" ||
      order.measurementPartnerAccountId !== accountId || order.measurementPartnerProfileId !== profileId) {
    throw new functions.https.HttpsError("permission-denied", "This video measurement request is not assigned to this Partner profile.");
  }
  if (order.measurementStatus === "completed" || order.measurementSubmissionStatus === "completed" ||
      order.assignmentStatus !== "finalized" || !["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
      order.status === "cancelled" || !measurementPartnerSupportsMethod(partnerProfile, "video_appointment")) {
    throw new functions.https.HttpsError("failed-precondition", "This order no longer needs a video measurement appointment.");
  }
  const oldAppointmentAt = dateMillis(order.measurementAppointmentAt);
  if (oldAppointmentAt === appointmentAt.getTime() && text(order.measurementAppointmentLink) &&
      text(order.measurementAppointmentCalendarEventId)) {
    return {status: "appointmentScheduled", appointmentLink: text(order.measurementAppointmentLink), alreadyScheduled: true};
  }

  const partnerAccount = accountSnapshot.data() || {};
  const recipients = await loadVideoMeasurementRecipients(order, partnerAccount, partnerProfile);
  let calendarResult;
  try {
    calendarResult = await createOrUpdateVideoMeasurementCalendarEvent({
      orderId,
      order,
      appointmentAt,
      attendeeEmails: recipients.attendeeEmails,
    });
  } catch (error) {
    console.error("Could not create SuiSakhi video measurement meeting", {
      orderId,
      message: error && error.message ? error.message : String(error),
      status: error && error.status,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SuiSakhi could not create the video meeting link. Please retry or contact support.",
    );
  }

  let latestOrder;
  try {
    await db.runTransaction(async (transaction) => {
      const [latestAccount, latestProfile, latestSnapshot] = await Promise.all([
        transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
      ]);
      const latest = latestSnapshot.data() || {};
      if (!latestAccount.exists || latestAccount.get("mobileE164") !== context.auth.token.phone_number ||
          !latestProfile.exists || !profileIsApprovedMeasurementPartner(latestProfile.data() || {}) ||
          !latestSnapshot.exists || latest.measurementMethod !== "video_appointment" ||
          latest.measurementPartnerAccountId !== accountId || latest.measurementPartnerProfileId !== profileId ||
          latest.assignmentStatus !== "finalized" || latest.status === "cancelled" ||
          !["advancePaid", "fullyPaid"].includes(latest.paymentStatus) ||
          latest.measurementStatus === "completed" || latest.measurementSubmissionStatus === "completed") {
        throw new functions.https.HttpsError("failed-precondition", "This video measurement request changed before the appointment could be saved.");
      }
      transaction.update(orderRef, {
        measurementAppointmentAt: admin.firestore.Timestamp.fromDate(appointmentAt),
        measurementAppointmentLink: calendarResult.link,
        measurementAppointmentCalendarEventId: calendarResult.eventId,
        measurementAppointmentStatus: "scheduled",
        measurementAppointmentScheduledAt: SERVER_TIMESTAMP,
        measurementStatus: "appointment_scheduled",
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRefFor(orderId), eventData("measurement_partner_appointment_scheduled", "measurementPartner", {
        accountId,
        profileId,
        method: "video_appointment",
        appointmentAt: admin.firestore.Timestamp.fromDate(appointmentAt),
        googleCalendarEventId: calendarResult.eventId,
      }));
      latestOrder = latest;
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error("Could not save SuiSakhi video measurement appointment", {orderId, message: error.message});
    throw new functions.https.HttpsError("internal", "The meeting was created, but the appointment could not be saved. Please retry.");
  }

  const notificationResult = await sendVideoMeasurementNotifications({
    order: latestOrder || order,
    partnerAccount,
    partnerProfile,
    recipients,
    appointmentAt,
    meetLink: calendarResult.link,
  });
  return {
    status: "appointmentScheduled",
    appointmentLink: calendarResult.link,
    whatsappCustomer: notificationResult.waCustomer,
    whatsappPartner: notificationResult.waPartner,
  };
}

async function submitMeasurementPartnerMeasurements(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const submitted = asMap(data && data.measurements);
  const measurementUnit = text(data && data.measurementUnit);
  const note = text(data && data.note);
  if (!accountId || !profileId || !orderId || !["in", "cm"].includes(measurementUnit) ||
      note.length > 1200) {
    throw new functions.https.HttpsError("invalid-argument", "Choose inches or centimeters and keep the Tailor note under 1,200 characters.");
  }

  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const measurementCompletedAt = admin.firestore.Timestamp.now();
  const measurementHistoryRef = accountRef.collection("measurement_history")
      .doc(`measurement_${orderId}_${measurementCompletedAt.toMillis()}`);
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
        !profileSnapshot.exists || !profileIsApprovedMeasurementPartner(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "Use your own active Measurement Partner profile to submit measurements.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("measurementPartnerAccountId") !== accountId ||
        orderSnapshot.get("measurementPartnerProfileId") !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "This measurement request is not assigned to this Partner profile.");
    }
    const order = orderSnapshot.data() || {};
    const partnerProfile = profileSnapshot.data() || {};
    const selfAssignedTailorVisit = order.measurementMethod === "tailor_home_visit" &&
      order.assignedTailorAccountId === accountId;
    const selfAssignedPartnerVisit = order.measurementMethod === "measurement_partner_home_visit" &&
      order.assignedTailorAccountId === accountId;
    if (order.assignmentStatus !== "finalized" || order.status === "cancelled" ||
        !["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
        (!["measurement_partner_home_visit", "video_appointment"].includes(order.measurementMethod) &&
          !selfAssignedTailorVisit) ||
        (!measurementPartnerSupportsMethod(partnerProfile, order.measurementMethod) &&
          !selfAssignedPartnerVisit && !selfAssignedTailorVisit) ||
        (["measurement_partner_home_visit", "tailor_home_visit"].includes(order.measurementMethod) &&
          !selfAssignedPartnerVisit && !selfAssignedTailorVisit &&
          !measurementPartnerCoversOrder(partnerProfile, order))) {
      throw new functions.https.HttpsError("failed-precondition", "This order is not ready for Measurement Partner completion.");
    }
    if (order.measurementStatus === "completed" || order.measurementSubmissionStatus === "completed") {
      throw new functions.https.HttpsError("failed-precondition", "Measurements have already been submitted. Ask the Tailor to re-initiate measurement if another visit is needed.");
    }
    if (order.measurementStatus !== "appointment_scheduled" || !order.measurementAppointmentAt ||
        typeof order.measurementAppointmentAt.toDate !== "function") {
      throw new functions.https.HttpsError("failed-precondition", "Schedule the measurement appointment before submitting collected measurements.");
    }

    const criteria = measurementCriteriaForOrder(order);
    const values = {};
    for (const criterion of criteria) {
      const raw = submitted[criterion];
      if (raw == null || (typeof raw === "string" && raw.trim() === "")) continue;
      const value = typeof raw === "number" ? raw : Number(text(raw));
      const maximum = measurementUnit === "in" ? 200 : 500;
      if (!Number.isFinite(value) || value <= 0 || value > maximum) {
        const unitLabel = measurementUnit === "in" ? "inches" : "centimeters";
        throw new functions.https.HttpsError("invalid-argument", `Enter a valid measurement for ${criterion} in ${unitLabel}.`);
      }
      values[criterion] = Math.round(value * 10) / 10;
    }
    if (Object.keys(submitted).some((key) => !criteria.includes(key))) {
      throw new functions.https.HttpsError("invalid-argument", "Only the measurement criteria shown for this garment can be submitted.");
    }

    transaction.update(orderRef, {
      measurementStatus: "partner_completed",
      measurementSubmissionStatus: "completed",
      measurementSubmittedValues: values,
      measurementSubmittedUnit: measurementUnit,
      measurementPartnerCompletionNote: note || null,
      measurementPartnerCompletedAt: measurementCompletedAt,
      measurementPartnerCompletedByAccountId: accountId,
      measurementPartnerCompletedByProfileId: profileId,
      updatedAt: SERVER_TIMESTAMP,
    });
    const deliveryLocation = asMap(order.deliveryLocation);
    transaction.set(measurementHistoryRef, {
      orderId,
      orderTrackingId: text(order.orderTrackingId),
      profileId,
      customerName: text(order.personName || order.clientName || order.customerName || "Customer"),
      customerPhone: text(order.customerPhone || order.phone || order.mobileE164),
      dressType: text(order.dressType || "Tailoring order"),
      designTemplateTitle: text(order.designTemplateTitle || order.designTitle),
      designImageUrl: text(order.designImageUrl || order.designTemplateImageUrl || order.designImage),
      fabricChoice: text(order.fabricChoice || order.fabricType || order.materialType || order.materialName),
      fabricDescription: text(order.fabricDescription || order.materialDescription || order.materialNotes),
      deliveryAddress: text(order.deliveryAddress || deliveryLocation.address || deliveryLocation.fullAddress),
      deliveryPincode: normalizedPincode(order.deliveryPincode || deliveryLocation.pincode || order.pincode),
      measurementMethod: text(order.measurementMethod),
      measurementAppointmentAt: order.measurementAppointmentAt || null,
      measurementNotes: text(order.measurementNotes),
      measurementCriteria: criteria,
      measurementSubmittedValues: values,
      measurementSubmittedUnit: measurementUnit,
      measurementPartnerCompletionNote: note,
      measurementPartnerCompletedAt: measurementCompletedAt,
      orderStatusAtCompletion: text(order.status),
      createdAt: measurementCompletedAt,
    });
    transaction.set(eventRefFor(orderId), eventData("measurement_partner_measurements_submitted", "measurementPartner", {
      accountId,
      profileId,
      measurementCount: Object.keys(values).length,
      hasNote: Boolean(note),
    }));
  });
  await assignInboundFulfillment(orderId);
  return {status: "measurementSubmitted"};
}

async function getCustomerOrderPartnerContacts(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");

  const orderSnapshot = await db.collection("orders").doc(orderId).get();
  if (!orderSnapshot.exists || orderSnapshot.get("customerId") !== context.auth.uid) {
    throw new functions.https.HttpsError("permission-denied", "This is not your order.");
  }
  const order = orderSnapshot.data() || {};
  if (order.assignmentStatus !== "finalized" || order.status === "cancelled") {
    throw new functions.https.HttpsError("failed-precondition", "Partner contacts are available after the order is confirmed.");
  }

  const tailorTarget = {
    accountId: text(order.assignedTailorAccountId),
    profileId: text(order.assignedTailorProfileId),
  };
  const measurementTarget = {
    accountId: text(order.measurementPartnerAccountId || order.measurementPartnerCompletedByAccountId),
    profileId: text(order.measurementPartnerProfileId || order.measurementPartnerCompletedByProfileId),
  };
  const hasOutboundPartner = Boolean(order.outboundHandoverPartnerAccountId &&
    order.outboundHandoverPartnerProfileId &&
    ["assigned", "in_transit", "delivered"].includes(text(order.outboundHandoverStatus)));
  const deliveryTarget = hasOutboundPartner ? {
    accountId: text(order.outboundHandoverPartnerAccountId),
    profileId: text(order.outboundHandoverPartnerProfileId),
  } : {accountId: "", profileId: ""};
  const hasInboundPartner = Boolean(order.inboundPickupPartnerAccountId &&
    order.inboundPickupPartnerProfileId && text(order.inboundPickupStatus) === "assigned");
  const pickupTarget = hasInboundPartner ? {
    accountId: text(order.inboundPickupPartnerAccountId),
    profileId: text(order.inboundPickupPartnerProfileId),
  } : {accountId: "", profileId: ""};
  const [tailorPhone, measurementPartnerPhone, pickupPartnerPhone, deliveryPartnerPhone] = await Promise.all([
    partnerProfilePhone(tailorTarget.accountId, tailorTarget.profileId),
    partnerProfilePhone(measurementTarget.accountId, measurementTarget.profileId),
    partnerProfilePhone(pickupTarget.accountId, pickupTarget.profileId),
    partnerProfilePhone(deliveryTarget.accountId, deliveryTarget.profileId),
  ]);
  return {
    tailorPhone,
    measurementPartnerPhone,
    pickupPartnerPhone,
    deliveryPartnerPhone,
  };
}

function defaultGarmentCareGuidance(materialName, materialDescription) {
  const source = `${text(materialName)} ${text(materialDescription)}`.toLowerCase();
  const baseline = "Fibre composition and care label have not been verified. Follow the garment's verified care label when available. Until confirmed, avoid bleach and high heat; test colourfastness on a hidden area. For delicate, structured, embellished, or colour-sensitive garments, consult a textile-care professional before cleaning.";
  if (/silk|velvet|georgette|chiffon|organza|net|zari|embroider|bridal|sequins|bead/.test(source)) {
    return `${baseline} This selected material or finish needs gentle handling; do not assume machine-washability.`;
  }
  if (/cotton|linen/.test(source)) {
    return `${baseline} Shrinkage, dye-fastness, and ironing needs depend on the fabric finish.`;
  }
  return baseline;
}

async function partnerProfilePhone(accountId, profileId) {
  if (!accountId || !profileId) return "";
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnapshot, profileSnapshot] = await Promise.all([accountRef.get(), profileRef.get()]);
  const account = accountSnapshot.exists ? accountSnapshot.data() || {} : {};
  const profile = profileSnapshot.exists ? profileSnapshot.data() || {} : {};
  return normalizedContactNumber(
    profile.mobileE164 || profile.phone || profile.contactPhone ||
    account.mobileE164 || account.phoneNumber,
  );
}

function buildGarmentRecordSnapshot(orderId, order, publishedAt) {
  const draft = asMap(order.garmentRecordDraft);
  const orderMeasurements = asMap(order.measurements);
  const submittedMeasurements = asMap(order.measurementSubmittedValues);
  const composition = text(draft.fiberComposition);
  const compositionSource = composition ? text(draft.compositionSource) || "not_provided" : "not_provided";
  const careInstructions = text(draft.careInstructions) || defaultGarmentCareGuidance(
      order.fabricChoice || order.fabricType || order.materialType || order.materialName,
      order.fabricDescription || order.materialDescription || order.fabricNotes,
  );
  const deliveryLocation = asMap(order.deliveryLocation);
  return {
    schemaVersion: "1.0",
    recordId: text(order.orderTrackingId) || orderId,
    garmentType: text(order.dressType) || "Tailored garment",
    occasion: text(order.occasionCategory || order.occasion),
    designTitle: text(order.designTemplateTitle || order.designTitle),
    designDescription: text(order.designDescription || order.designNotes || order.designBrief),
    designImageUrl: text(order.designImageUrl || order.designTemplateImageUrl || order.designImage),
    fit: text(order.fit),
    accentColorHex: text(order.accentColorHex),
    material: {
      customerSelection: text(order.fabricChoice || order.fabricType || order.materialType || order.materialName),
      customerDescription: text(order.fabricDescription || order.materialDescription || order.fabricNotes),
      customerReferenceImageUrl: text(order.fabricImageUrl || order.materialImageUrl),
      fiberComposition: composition,
      compositionSource,
      careInstructions,
      careInstructionsSource: text(draft.careInstructions) ? "tailor_qc" : "conservative_template",
      careGuidanceVersion: "care-v1",
      pickupPhotoPath: text(order.inboundPickupPhotoPath),
    },
    constructionNotes: text(draft.constructionNotes),
    qualityCheckNotes: text(draft.qualityCheckNotes),
    measurements: Object.keys(orderMeasurements).length ? orderMeasurements : submittedMeasurements,
    measurementUnit: text(order.measurementSubmittedUnit || order.measurementUnit) || "in",
    traceability: {
      orderedAt: order.orderDate || order.assignmentRequestedAt || null,
      collectedAt: order.inboundPickupCollectedAt || null,
      receivedAtTailorAt: order.inboundPickupReceivedAt || null,
      deliveredAt: admin.firestore.Timestamp.fromDate(publishedAt),
      deliveryArea: text(order.deliveryPincode || deliveryLocation.pincode),
    },
    status: "published",
    publishedAt: admin.firestore.Timestamp.fromDate(publishedAt),
    evidenceNote: "Customer selections, photos, and Tailor-entered notes are recorded with their stated source. Fibre composition is unknown unless a label or other source is documented. General care guidance is conservative and is not a verified care label, laboratory test, or certification.",
  };
}

function escapeHtml(value) {
  return String(value == null ? "" : value).replace(/[&<>\"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
  })[character]);
}

function publicReportImage(value) {
  try {
    const imageUrl = new URL(text(value));
    return imageUrl.protocol === "https:" ? imageUrl.toString() : "";
  } catch (_) {
    return "";
  }
}

function publicReportDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate().toLocaleString("en-IN", {timeZone: "Asia/Kolkata"});
  if (value instanceof Date) return value.toLocaleString("en-IN", {timeZone: "Asia/Kolkata"});
  return text(value);
}

function publicGarmentRecordHtml(order, pickupPhotoUrl) {
  const record = asMap(order.garmentRecord);
  const material = asMap(record.material);
  const trace = asMap(record.traceability);
  const measurements = asMap(record.measurements);
  const unit = text(record.measurementUnit);
  const orderedMeasurements = Object.entries(measurements).sort(([a], [b]) => {
    const number = (key) => Number((key.match(/^\s*(\d+)/) || [])[1] || 999);
    return number(a) - number(b);
  });
  const row = (label, value) => text(value) ? `<div class="row"><strong>${escapeHtml(label)}</strong><span>${escapeHtml(value)}</span></div>` : "";
  const image = (label, rawUrl) => {
    const url = publicReportImage(rawUrl);
    return url ? `<figure><img src="${escapeHtml(url)}" alt="${escapeHtml(label)}"><figcaption>${escapeHtml(label)}</figcaption></figure>` : "";
  };
  const measuredRows = orderedMeasurements.map(([key, value]) => row(key, `${value} ${unit}`)).join("");
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>SuiSakhi Garment DNA Report</title><style>
    :root{color-scheme:light;font-family:Arial,sans-serif;color:#201b31;background:#f7f6fc}body{margin:0;padding:24px 14px 40px}.page{max-width:760px;margin:auto}.brand{color:#5c35e5;font-weight:700;letter-spacing:.04em}.card{background:#fff;border:1px solid #e7e3f2;border-radius:18px;padding:20px;margin:14px 0;box-shadow:0 3px 14px #21143d0a}h1{font-size:25px;margin:8px 0}h2{font-size:19px;margin:0 0 12px}.muted{color:#706b80}.row{display:grid;grid-template-columns:minmax(145px, .7fr) 1.3fr;gap:12px;padding:9px 0;border-bottom:1px solid #f0eef5}.row:last-child{border:0}.row span{overflow-wrap:anywhere}figure{margin:14px 0 0}img{display:block;width:100%;max-height:300px;object-fit:contain;border-radius:12px;background:#f7f6fc}figcaption{font-size:13px;color:#706b80;margin-top:5px}.note{font-size:13px;line-height:1.55;color:#706b80}.badge{display:inline-block;background:#eeeafe;color:#5430cc;padding:7px 11px;border-radius:99px;font-size:13px}@media(max-width:480px){body{padding:16px 10px 28px}.card{padding:16px}.row{grid-template-columns:1fr;gap:4px}}
    </style></head><body><main class="page"><div class="brand">SuiSakhi · GARMENT DNA REPORT</div><h1>${escapeHtml(text(record.garmentType) || "Tailored garment")}</h1><span class="badge">Order ${escapeHtml(text(record.recordId) || "")}</span>
    <section class="card"><h2>Garment and design</h2>${row("Occasion", record.occasion)}${row("Selected design", record.designTitle)}${row("Design notes", record.designDescription)}${image("Selected design reference", record.designImageUrl)}</section>
    <section class="card"><h2>Material and care</h2>${row("Customer material selection", material.customerSelection)}${row("Customer material details", material.customerDescription)}${row("Fibre composition", material.fiberComposition)}${row("Composition source", material.compositionSource)}${row("Care guidance", material.careInstructions)}${image("Customer material reference", material.customerReferenceImageUrl)}${image("Optional pickup material photo", pickupPhotoUrl)}</section>
    <section class="card"><h2>Tailor quality check</h2>${row("Fit", record.fit)}${row("Construction / finishing", record.constructionNotes)}${row("Quality check", record.qualityCheckNotes)}${measuredRows || `<p class="muted">No measurements were recorded.</p>`}</section>
    <section class="card"><h2>Order traceability</h2>${row("Ordered", publicReportDate(trace.orderedAt))}${row("Collected", publicReportDate(trace.collectedAt))}${row("Received by Tailor", publicReportDate(trace.receivedAtTailorAt))}${row("Delivered", publicReportDate(trace.deliveredAt))}</section>
    <p class="note">${escapeHtml(text(record.evidenceNote))}</p></main></body></html>`;
}

async function getGarmentRecordShareLink(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in to share this report.");
  const orderId = text(data && data.orderId);
  if (!orderId) throw new functions.https.HttpsError("invalid-argument", "An order is required.");
  const orderRef = db.collection("orders").doc(orderId);
  const accessToken = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists || snapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    const order = snapshot.data() || {};
    const record = asMap(order.garmentRecord);
    if (!order.garmentRecordPublishedAt || record.status !== "published") {
      throw new functions.https.HttpsError("failed-precondition", "The Tailor has not published this report yet.");
    }
    const existing = text(order.garmentRecordAccessToken);
    if (existing) return existing;
    const nextToken = crypto.randomBytes(32).toString("hex");
    transaction.update(orderRef, {
      garmentRecordAccessToken: nextToken,
      garmentRecordAccessTokenCreatedAt: SERVER_TIMESTAMP,
    });
    return nextToken;
  });
  const projectId = admin.app().options.projectId;
  if (!projectId) throw new functions.https.HttpsError("internal", "The report link is unavailable.");
  return {url: `https://us-central1-${projectId}.cloudfunctions.net/viewPublicGarmentRecord?token=${accessToken}`};
}

async function viewPublicGarmentRecord(req, res) {
  res.set("Cache-Control", "no-store, max-age=0");
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "no-referrer");
  if (req.method !== "GET") return res.status(405).send("Method not allowed");
  const token = text(req.query && req.query.token);
  if (!/^[a-f0-9]{64}$/.test(token)) return res.status(404).send("Report not found");
  try {
    const result = await db.collection("orders")
        .where("garmentRecordAccessToken", "==", token).limit(1).get();
    const snapshot = result.docs[0];
    const order = snapshot && snapshot.data();
    const record = asMap(order && order.garmentRecord);
    if (!order || !order.garmentRecordPublishedAt || record.status !== "published") {
      return res.status(404).send("Report not found");
    }
    const material = asMap(record.material);
    const photoPath = text(material.pickupPhotoPath);
    let pickupPhotoUrl = "";
    if (photoPath.startsWith(`order_pickup_photos/${snapshot.id}/`) && !photoPath.includes("..")) {
      try {
        const bucket = admin.storage().bucket();
        const file = bucket.file(photoPath);
        const [metadata] = await file.getMetadata();
        const tokens = text(asMap(metadata.metadata).firebaseStorageDownloadTokens);
        if (tokens) {
          pickupPhotoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(photoPath)}?alt=media&token=${encodeURIComponent(tokens.split(",")[0])}`;
        } else {
          const [signedUrl] = await file.getSignedUrl({action: "read", expires: Date.now() + 5 * 60 * 1000});
          pickupPhotoUrl = signedUrl;
        }
      } catch (error) {
        console.warn("Optional pickup photo could not be added to the public report", error);
      }
    }
    return res.status(200).set("Content-Type", "text/html; charset=utf-8").send(publicGarmentRecordHtml(order, pickupPhotoUrl));
  } catch (error) {
    console.error("Public garment record lookup failed", error);
    return res.status(500).send("The report could not be loaded. Please try again later.");
  }
}

async function saveTailorGarmentRecord(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const fiberComposition = text(data && data.fiberComposition);
  const compositionSource = text(data && data.compositionSource) || "not_provided";
  const careInstructions = text(data && data.careInstructions);
  const constructionNotes = text(data && data.constructionNotes);
  const qualityCheckNotes = text(data && data.qualityCheckNotes);
  const validSources = ["not_provided", "supplier_label", "customer_label", "visual_only"];
  if (!accountId || !profileId || !orderId || !validSources.includes(compositionSource) ||
      fiberComposition.length > 240 || careInstructions.length > 600 ||
      constructionNotes.length > 800 || qualityCheckNotes.length > 1200) {
    throw new functions.https.HttpsError("invalid-argument", "Review the garment record fields and keep each note within its limit.");
  }
  if (!fiberComposition && compositionSource !== "not_provided") {
    throw new functions.https.HttpsError("invalid-argument", "Add a composition value or choose ‘Not provided’ as its source.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Tailor account to update this record.");
    }
    if (!profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "An active approved Tailor profile is required.");
    }
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentVersion") !== "v1" ||
        orderSnapshot.get("assignmentStatus") !== "finalized" ||
        orderSnapshot.get("assignedTailorAccountId") !== accountId ||
        orderSnapshot.get("assignedTailorProfileId") !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "This order is not assigned to this Tailor profile.");
    }
    const order = orderSnapshot.data() || {};
    if (!["qcPending", "qcPassed", "readyForPickup"].includes(text(order.status)) ||
        order.garmentRecordLockedAt || order.outboundHandoverAcceptedAt) {
      throw new functions.https.HttpsError("failed-precondition", "The garment record can be edited during QC and before return delivery begins.");
    }
    transaction.update(orderRef, {
      garmentRecordDraft: {
        fiberComposition,
        compositionSource,
        careInstructions,
        constructionNotes,
        qualityCheckNotes,
      },
      garmentRecordDraftUpdatedAt: SERVER_TIMESTAMP,
      garmentRecordDraftUpdatedByAccountId: accountId,
      garmentRecordDraftUpdatedByProfileId: profileId,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("tailor_garment_record_updated", "tailor", {
      accountId,
      profileId,
      hasComposition: Boolean(fiberComposition),
      hasCareInstructions: Boolean(careInstructions),
      hasConstructionNotes: Boolean(constructionNotes),
      hasQualityCheckNotes: Boolean(qualityCheckNotes),
    }));
  });
  return {status: "saved"};
}

async function advanceProductionDeliveryOrder(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const orderId = text(data && data.orderId);
  const action = text(data && data.action);
  const suppliedDeliveryPin = text(data && data.deliveryPin);
  const pickupPhotoPath = text(data && data.pickupPhotoPath);
  if (!accountId || !profileId || !orderId || !["accept", "delivered", "collectInbound", "declineInbound", "declineOutbound"].includes(action)) {
    throw new functions.https.HttpsError("invalid-argument", "Partner profile, order, and handover action are required.");
  }
  if (pickupPhotoPath && action !== "collectInbound") {
    throw new functions.https.HttpsError("invalid-argument", "A pickup photo can only be attached when collecting an inbound order.");
  }
  if (pickupPhotoPath) {
    const expectedPrefix = `order_pickup_photos/${orderId}/${context.auth.uid}/`;
    const filename = pickupPhotoPath.startsWith(expectedPrefix) ? pickupPhotoPath.slice(expectedPrefix.length) : "";
    if (!filename || filename.includes("/") || !/^[A-Za-z0-9_.-]+\.(jpg|jpeg|png|heic|webp)$/i.test(filename)) {
      throw new functions.https.HttpsError("invalid-argument", "The pickup photo path is invalid.");
    }
    try {
      const [metadata] = await admin.storage().bucket().file(pickupPhotoPath).getMetadata();
      const fileSize = Number(metadata.size || 0);
      if (!text(metadata.contentType).toLowerCase().startsWith("image/") || fileSize <= 0 || fileSize > 10 * 1024 * 1024) {
        throw new functions.https.HttpsError("failed-precondition", "Choose an image smaller than 10 MB for the pickup photo.");
      }
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError("failed-precondition", "The pickup photo could not be verified. Please retry.");
    }
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  const deliveryPinRef = orderRef.collection("private").doc("delivery_pin");
  const policyRef = db.doc("config/order_lifecycle");
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot, policySnapshot, deliveryPinSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef), transaction.get(policyRef),
      transaction.get(deliveryPinRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number) {
      throw new functions.https.HttpsError("permission-denied", "Use your own Delivery Partner account.");
    }
    const profile = profileSnapshot.data() || {};
    const partnerDisplayName = text(profile.businessName || profile.displayName || profile.contactName || profile.name || profile.shopName || accountSnapshot.get("displayName") || accountSnapshot.get("name")) || "Partner";
    const partnerContactPhone = normalizedContactNumber(
      profile.mobileE164 || profile.phone || profile.contactPhone ||
      accountSnapshot.get("mobileE164") || accountSnapshot.get("phoneNumber"),
    );
    const partnerType = text(profile.partnerType);
    const partnerIsActive = partnerType === "tailor" ? profileIsApprovedTailor(profile) :
      partnerType === "measurementPartner" ? profileIsApprovedMeasurementPartner(profile) :
      partnerType === "deliveryPartner" ? profileIsApprovedDeliveryPartner(profile) : false;
    if (!profileSnapshot.exists || !partnerIsActive) {
      throw new functions.https.HttpsError("permission-denied", "An active, approved Partner profile is required.");
    }
    const order = orderSnapshot.data() || {};
    if (!orderSnapshot.exists || order.assignmentVersion !== "v1" || order.assignmentStatus !== "finalized") {
      throw new functions.https.HttpsError("failed-precondition", "This is not a finalized production order.");
    }
    if (action === "declineInbound") {
      if (!["advancePaid", "fullyPaid"].includes(order.paymentStatus) ||
          order.inboundPickupStatus !== "assigned" || order.inboundPickupPartnerType !== partnerType ||
          order.inboundPickupPartnerAccountId !== accountId || order.inboundPickupPartnerProfileId !== profileId) {
        throw new functions.https.HttpsError("permission-denied", "This pickup is not assigned to your Partner profile.");
      }
      transaction.update(orderRef, {
        inboundPickupStatus: "awaiting_assignment",
        inboundPickupPartnerType: admin.firestore.FieldValue.delete(),
        inboundPickupPartnerAccountId: admin.firestore.FieldValue.delete(),
        inboundPickupPartnerProfileId: admin.firestore.FieldValue.delete(),
        inboundPickupAssignedAt: admin.firestore.FieldValue.delete(),
        inboundPickupAssignedBy: "system",
        inboundPickupDeclinedPartnerKeys: admin.firestore.FieldValue.arrayUnion(profileKey(accountId, profileId)),
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRefFor(orderId), eventData("inbound_pickup_declined", partnerType, {accountId, profileId}));
      return;
    }
    if (action === "declineOutbound") {
      if (order.status !== "readyForPickup" || order.paymentStatus !== "fullyPaid" ||
          order.outboundHandoverStatus !== "assigned" ||
          order.outboundHandoverPartnerType !== partnerType ||
          order.outboundHandoverPartnerAccountId !== accountId ||
          order.outboundHandoverPartnerProfileId !== profileId) {
        throw new functions.https.HttpsError("permission-denied", "This return handover is not assigned to your Partner profile.");
      }
      transaction.update(orderRef, {
        outboundHandoverStatus: "awaiting_assignment",
        outboundHandoverPartnerType: admin.firestore.FieldValue.delete(),
        outboundHandoverPartnerAccountId: admin.firestore.FieldValue.delete(),
        outboundHandoverPartnerProfileId: admin.firestore.FieldValue.delete(),
        outboundHandoverAssignedAt: admin.firestore.FieldValue.delete(),
        deliveryPartnerType: admin.firestore.FieldValue.delete(),
        deliveryPartnerAccountId: admin.firestore.FieldValue.delete(),
        deliveryPartnerProfileId: admin.firestore.FieldValue.delete(),
        outboundHandoverDeclinedPartnerKeys: admin.firestore.FieldValue.arrayUnion(profileKey(accountId, profileId)),
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRefFor(orderId), eventData("outbound_handover_declined", partnerType, {accountId, profileId}));
      return;
    }
    if (action === "collectInbound") {
      if (order.paymentStatus !== "advancePaid" && order.paymentStatus !== "fullyPaid") {
        throw new functions.https.HttpsError("failed-precondition", "The Customer advance must be paid before pickup.");
      }
      if (order.inboundPickupStatus !== "assigned" ||
          order.inboundPickupPartnerType !== partnerType ||
          order.inboundPickupPartnerAccountId !== accountId ||
          order.inboundPickupPartnerProfileId !== profileId) {
        throw new functions.https.HttpsError("permission-denied", "This pickup is not assigned to your Partner profile.");
      }
      const eligible = partnerType === "tailor" ?
        tailorCanFulfill(profile, "inbound") && profileCoversOrder(profile, order) :
        partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, "inbound", order) :
        deliveryPartnerCanFulfill(profile, "inbound", order);
      if (!eligible) {
        throw new functions.https.HttpsError("failed-precondition", "This Partner profile is no longer eligible for the pickup area or service.");
      }
      const directToTailor = partnerType === "tailor";
      transaction.update(orderRef, {
        inboundPickupStatus: directToTailor ? "receivedAtTailor" : "collectedFromCustomer",
        inboundPickupCollectedAt: SERVER_TIMESTAMP,
        inboundPickupCollectedByAccountId: accountId,
        inboundPickupCollectedByProfileId: profileId,
        inboundPickupPartnerName: partnerDisplayName,
        inboundPickupPartnerPhone: partnerContactPhone,
        ...(pickupPhotoPath ? {
          inboundPickupPhotoPath: pickupPhotoPath,
          inboundPickupPhotoAttachedAt: SERVER_TIMESTAMP,
          inboundPickupPhotoAttachedByAccountId: accountId,
          inboundPickupPhotoAttachedByProfileId: profileId,
        } : {}),
        ...(directToTailor ? {
          inboundPickupReceivedAt: SERVER_TIMESTAMP,
          inboundPickupReceivedByAccountId: accountId,
          inboundPickupReceivedByProfileId: profileId,
          ...(order.measurementStatus === "completed" && order.status === "pending" ? {
            status: "atTailor",
            atTailorAt: SERVER_TIMESTAMP,
          } : {}),
        } : {}),
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRefFor(orderId), eventData(
        directToTailor ? "inbound_pickup_received_at_tailor" : "inbound_pickup_collected_from_customer",
        partnerType,
        {
          accountId,
          profileId,
          orderTrackingId: text(order.orderTrackingId) || null,
          directToTailor,
          pickupPhotoAttached: Boolean(pickupPhotoPath),
        },
      ));
      if (directToTailor && order.measurementStatus === "completed" && order.status === "pending") {
        transaction.set(eventRefFor(orderId), eventData("order_ready_for_stitching", "system", {
          orderTrackingId: text(order.orderTrackingId) || null,
        }));
      }
      return;
    }
    if (order.paymentStatus !== "fullyPaid") {
      throw new functions.https.HttpsError("failed-precondition", "The Customer must pay the full order amount before outbound dispatch.");
    }
    if (action === "accept") {
      if (order.status !== "readyForPickup") {
        throw new functions.https.HttpsError("failed-precondition", "This order is not ready for dispatch.");
      }
      if (order.outboundHandoverStatus !== "assigned" ||
          order.outboundHandoverPartnerType !== partnerType ||
          order.outboundHandoverPartnerAccountId !== accountId ||
          order.outboundHandoverPartnerProfileId !== profileId) {
        throw new functions.https.HttpsError("permission-denied", "This return handover is not assigned to your Partner profile.");
      }
      const eligible = partnerType === "tailor" ?
        tailorCanFulfill(profile, "outbound") && profileCoversOrder(profile, order) :
        partnerType === "measurementPartner" ? measurementPartnerCanFulfill(profile, "outbound", order) :
        deliveryPartnerCanFulfill(profile, "outbound", order);
      if (!eligible) {
        throw new functions.https.HttpsError("failed-precondition", "This Partner profile is no longer eligible for the delivery area or service.");
      }
      transaction.update(orderRef, {
        status: "outForDelivery",
        deliveryPartnerId: context.auth.uid,
        deliveryPartnerAccountId: accountId,
        deliveryPartnerProfileId: profileId,
        deliveryPartnerType: partnerType,
        deliveryPartnerName: partnerDisplayName,
        deliveryPartnerPhone: partnerContactPhone,
        outboundHandoverStatus: "in_transit",
        outboundHandoverAcceptedAt: SERVER_TIMESTAMP,
        deliveryAcceptedAt: SERVER_TIMESTAMP,
        garmentRecordLockedAt: SERVER_TIMESTAMP,
        updatedAt: SERVER_TIMESTAMP,
      });
      transaction.set(eventRefFor(orderId), eventData("outbound_handover_started", partnerType, {accountId, profileId}));
      return;
    }
    if (order.status !== "outForDelivery" || order.deliveryPartnerId !== context.auth.uid ||
        order.deliveryPartnerType !== partnerType || order.deliveryPartnerAccountId !== accountId ||
        order.deliveryPartnerProfileId !== profileId ||
        order.outboundHandoverPartnerType !== partnerType ||
        order.outboundHandoverPartnerAccountId !== accountId ||
        order.outboundHandoverPartnerProfileId !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "Only the assigned Partner can complete this delivery handover.");
    }
    const pinSecret = deliveryPinSnapshot.data() || {};
    const expectedPinHash = text(pinSecret.pinHash);
    const suppliedPinHash = /^\d{4}$/.test(suppliedDeliveryPin) ?
      deliveryPinHash(suppliedDeliveryPin) : "";
    const expectedBytes = Buffer.from(expectedPinHash, "hex");
    const suppliedBytes = Buffer.from(suppliedPinHash, "hex");
    if (!deliveryPinSnapshot.exists ||
        pinSecret.assignedPartnerAccountId !== accountId ||
        pinSecret.assignedPartnerProfileId !== profileId ||
        !expectedPinHash || expectedBytes.length !== suppliedBytes.length ||
        !crypto.timingSafeEqual(expectedBytes, suppliedBytes)) {
      throw new functions.https.HttpsError("failed-precondition", "Enter the correct 4-digit Customer delivery PIN to complete the handover.");
    }
    const policy = policySnapshot.data() || {};
    const configuredDays = Number(policy.warrantyDays ?? 15);
    const warrantyDays = Number.isFinite(configuredDays) ? Math.max(1, Math.min(365, Math.floor(configuredDays))) : 15;
    const deliveredAt = new Date();
    const warrantyEndsAt = new Date(deliveredAt.getTime() + warrantyDays * 24 * 60 * 60 * 1000);
    const garmentRecord = buildGarmentRecordSnapshot(orderId, order, deliveredAt);
    transaction.update(orderRef, {
      status: "delivered",
      outboundHandoverStatus: "delivered",
      outboundHandoverDeliveredAt: admin.firestore.Timestamp.fromDate(deliveredAt),
      deliveredAt: admin.firestore.Timestamp.fromDate(deliveredAt),
      closedAt: admin.firestore.Timestamp.fromDate(deliveredAt),
      warrantyDays,
      warrantyEndsAt: admin.firestore.Timestamp.fromDate(warrantyEndsAt),
      warrantyClaimStatus: "available",
      garmentRecord,
      garmentRecordPublishedAt: admin.firestore.Timestamp.fromDate(deliveredAt),
      garmentRecordAccessToken: crypto.randomBytes(32).toString("hex"),
      garmentRecordAccessTokenCreatedAt: admin.firestore.Timestamp.fromDate(deliveredAt),
      garmentRecordLockedAt: order.garmentRecordLockedAt || admin.firestore.Timestamp.fromDate(deliveredAt),
      deliveryPinGeneratedAt: admin.firestore.FieldValue.delete(),
      deliveryPinUsedAt: SERVER_TIMESTAMP,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.delete(orderRef.collection("private").doc("delivery_pin"));
    transaction.set(eventRefFor(orderId), eventData("order_delivered_and_closed", partnerType, {accountId, profileId, warrantyDays, warrantyEndsAt: admin.firestore.Timestamp.fromDate(warrantyEndsAt)}));
  });
  if (action === "declineInbound") {
    await assignInboundFulfillment(orderId);
    return {status: "reassigned"};
  }
  if (action === "declineOutbound") {
    await assignOutboundFulfillment(orderId);
    return {status: "reassigned"};
  }
  return {status: action === "accept" ? "outForDelivery" : action === "collectInbound" ? "collected" : "delivered"};
}

async function submitOrderFeedback(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const rating = Number(data && data.rating);
  const feedback = text(data && data.feedback);
  if (!orderId || !Number.isInteger(rating) || rating < 1 || rating > 5 || feedback.length > 1000) {
    throw new functions.https.HttpsError("invalid-argument", "Choose a rating from 1 to 5 and keep feedback under 1,000 characters.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists || snapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    if (snapshot.get("status") !== "delivered" || snapshot.get("feedbackSubmittedAt")) {
      throw new functions.https.HttpsError("failed-precondition", "Feedback is available once after delivery.");
    }
    transaction.update(orderRef, {feedbackRating: rating, feedbackText: feedback, feedbackSubmittedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData("customer_submitted_order_feedback", "customer", {rating}));
  });
  return {status: "submitted"};
}

async function reportOrderWarrantyIssue(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const description = text(data && data.description);
  if (!orderId || description.length < 5 || description.length > 1500) {
    throw new functions.https.HttpsError("invalid-argument", "Describe the issue in 5 to 1,500 characters.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists || snapshot.get("customerId") !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "This is not your order.");
    }
    const warrantyEndsAt = snapshot.get("warrantyEndsAt");
    if (snapshot.get("status") !== "delivered" || !warrantyEndsAt || warrantyEndsAt.toDate() < new Date()) {
      throw new functions.https.HttpsError("failed-precondition", "The 15-day warranty window for this order is closed.");
    }
    if (["open", "underReview"].includes(text(snapshot.get("warrantyClaimStatus")))) {
      throw new functions.https.HttpsError("failed-precondition", "A warranty issue has already been reported for this order.");
    }
    transaction.update(orderRef, {
      warrantyClaimStatus: "open",
      warrantyIssueDescription: description,
      warrantyIssueReportedAt: SERVER_TIMESTAMP,
      warrantyCustomerPhone: text(context.auth.token.phone_number),
      warrantyResolution: admin.firestore.FieldValue.delete(),
      warrantyResolvedAt: admin.firestore.FieldValue.delete(),
      warrantyResolvedByUid: admin.firestore.FieldValue.delete(),
      warrantyResolvedByRole: admin.firestore.FieldValue.delete(),
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("customer_reported_warranty_issue", "customer", {description}));
  });
  return {status: "open"};
}

async function resolveTailorWarrantyIssue(data, context) {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  const orderId = text(data && data.orderId);
  const accountId = text(data && data.accountId);
  const profileId = text(data && data.profileId);
  const resolution = text(data && data.resolution);
  if (!orderId || !accountId || !profileId || resolution.length < 3 || resolution.length > 1000) {
    throw new functions.https.HttpsError("invalid-argument", "Enter a follow-up note between 3 and 1,000 characters.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const [accountSnapshot, profileSnapshot, orderSnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(profileRef), transaction.get(orderRef),
    ]);
    if (!accountSnapshot.exists || accountSnapshot.get("mobileE164") !== context.auth.token.phone_number ||
        !profileSnapshot.exists || !profileIsApprovedTailor(profileSnapshot.data() || {})) {
      throw new functions.https.HttpsError("permission-denied", "Use your own active Tailor profile.");
    }
    const order = orderSnapshot.data() || {};
    if (!orderSnapshot.exists || order.status !== "delivered" || order.warrantyClaimStatus !== "open") {
      throw new functions.https.HttpsError("failed-precondition", "Only an open warranty request on a delivered order can be updated.");
    }
    if (order.assignedTailorAccountId !== accountId || order.assignedTailorProfileId !== profileId) {
      throw new functions.https.HttpsError("permission-denied", "Only the Tailor who completed this order can handle its warranty request.");
    }
    transaction.update(orderRef, {
      warrantyClaimStatus: "resolved",
      warrantyResolution: resolution,
      warrantyResolvedAt: SERVER_TIMESTAMP,
      warrantyResolvedByUid: context.auth.uid,
      warrantyResolvedByRole: "tailor",
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("tailor_resolved_warranty_issue", "tailor", {
      accountId, profileId, resolution,
    }));
  });
  return {status: "resolved"};
}

async function resolveOrderWarrantyIssue(data, context) {
  await requireConfiguredAdmin(context);
  const orderId = text(data && data.orderId);
  const resolution = text(data && data.resolution);
  if (!orderId || resolution.length < 3 || resolution.length > 1000) {
    throw new functions.https.HttpsError("invalid-argument", "Enter a resolution note between 3 and 1,000 characters.");
  }
  const orderRef = db.collection("orders").doc(orderId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists || snapshot.get("status") !== "delivered" || snapshot.get("warrantyClaimStatus") !== "open") {
      throw new functions.https.HttpsError("failed-precondition", "Only an open warranty issue can be resolved.");
    }
    transaction.update(orderRef, {
      warrantyClaimStatus: "resolved",
      warrantyResolution: resolution,
      warrantyResolvedAt: SERVER_TIMESTAMP,
      warrantyResolvedByUid: context.auth.uid,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.set(eventRefFor(orderId), eventData("admin_resolved_warranty_issue", "admin", {resolution, adminUid: context.auth.uid}));
  });
  return {status: "resolved"};
}

async function expireTailorOffer(offerSnapshot) {
  const offer = offerSnapshot.data();
  const {orderId, targetAccountId: accountId, targetProfileId: profileId} = offer;
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);
  let expired = false;
  await db.runTransaction(async (transaction) => {
    const [currentOffer, orderSnapshot, stateSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(offerSnapshot.ref), transaction.get(orderRef), transaction.get(stateRef), transaction.get(reservationRef),
    ]);
    if (!currentOffer.exists || currentOffer.get("status") !== "offered" || !orderSnapshot.exists || !stateSnapshot.exists) return;
    const expiry = currentOffer.get("expiresAt");
    if (!expiry || expiry.toDate() > new Date()) return;
    if (stateSnapshot.get("currentOfferId") !== currentOffer.id || stateSnapshot.get("status") !== "offered") return;
    await releaseHeldReservation(transaction, reservationSnapshot);
    transaction.update(currentOffer.ref, {status: "expired", respondedAt: SERVER_TIMESTAMP, updatedAt: SERVER_TIMESTAMP});
    const state = stateSnapshot.data() || {};
    const attempted = Array.isArray(state.attemptedCandidateKeys) ? state.attemptedCandidateKeys : [];
    const attemptedCandidateKeys = Array.from(new Set([...attempted, profileKey(accountId, profileId)]));
    transaction.update(stateRef, {
      status: "searching",
      currentOfferId: null,
      activeCandidate: null,
      attemptedCandidateKeys,
      updatedAt: SERVER_TIMESTAMP,
    });
    transaction.update(orderRef, {assignmentStatus: "searching", updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData("tailor_offer_timed_out", "system", {accountId, profileId, offerId: currentOffer.id}));
    expired = true;
  });
  if (expired) await dispatchNextOffer(orderId);
}

async function expireCustomerDecision(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  const stateRef = db.collection("order_assignment_state").doc(orderId);
  const reservationRef = reservationRefFor(orderId);
  await db.runTransaction(async (transaction) => {
    const [orderSnapshot, stateSnapshot, reservationSnapshot] = await Promise.all([
      transaction.get(orderRef), transaction.get(stateRef), transaction.get(reservationRef),
    ]);
    if (!orderSnapshot.exists || orderSnapshot.get("assignmentStatus") !== "awaiting_customer_decision" || orderSnapshot.get("paymentStatus") !== "pending_payment") return;
    const expiry = orderSnapshot.get("customerDecisionExpiresAt");
    if (!expiry || expiry.toDate() > new Date()) return;
    await releaseHeldReservation(transaction, reservationSnapshot);
    transaction.update(orderRef, {assignmentStatus: "needs_admin_follow_up", adminQueueReason: "customer_decision_expired", paymentStatus: "unpaid", updatedAt: SERVER_TIMESTAMP});
    if (stateSnapshot.exists) transaction.update(stateRef, {status: "needs_admin_follow_up", updatedAt: SERVER_TIMESTAMP});
    transaction.set(eventRefFor(orderId), eventData("customer_decision_window_expired", "system", {noCancellationFee: true}));
  });
}

exports.onCoreTailoringOrderCreated = functions.runWith({failurePolicy: true})
    .firestore.document("orders/{orderId}").onCreate(async (snapshot, context) => {
  const orderId = context.params.orderId;
  await initializeAssignment(orderId, snapshot.data() || {});
});

exports.onTailorAvailabilityChanged = functions.firestore
    .document("accounts/{accountId}/profiles/{profileId}")
    .onUpdate(async (change) => {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (after.role !== "partner" || after.partnerType !== "tailor" ||
          before.availabilityStatus === "available" || after.availabilityStatus !== "available") {
        return null;
      }
      await resumeQueuedAssignments();
      return null;
    });

exports.respondToTailorOrderOffer = functions.https.onCall(handleTailorResponse);
exports.declineAcceptedTailorOrder = functions.https.onCall(declineCustomerDecision);
exports.completeSandboxOrderAdvance = functions.https.onCall(completeSandboxPayment);
exports.cancelCoreTailoringOrder = functions.https.onCall(cancelCoreTailoringOrder);
exports.waiveOrderCancellationFee = functions.https.onCall(waiveOrderCancellationFee);
exports.completeSandboxOrderBalance = functions.https.onCall(completeSandboxBalancePayment);
exports.advanceProductionTailorOrderStatus = functions.https.onCall(advanceProductionTailorOrderStatus);
exports.saveTailorFabricRequirementReview = functions.https.onCall(saveTailorFabricRequirementReview);
exports.confirmCustomerFabricShortfall = functions.https.onCall(confirmCustomerFabricShortfall);
exports.confirmTailorProductionTask = functions.https.onCall(confirmTailorProductionTask);
exports.getMeasurementPartnerCandidates = functions.https.onCall(getMeasurementPartnerCandidates);
exports.saveTailorMeasurementPlan = functions.https.onCall(saveTailorMeasurementPlan);
exports.getMeasurementPartnerAssignments = functions.https.onCall(getMeasurementPartnerAssignments);
exports.setMeasurementPartnerAppointment = functions.https.onCall(setMeasurementPartnerAppointment);
exports.scheduleVideoMeasurementAppointment = functions
    .runWith({timeoutSeconds: 120, secrets: [GOOGLE_CALENDAR_OAUTH_SECRET]})
    .https.onCall(scheduleVideoMeasurementAppointment);
exports.scheduleCustomerFabricConsultation = functions
    .runWith({timeoutSeconds: 120, secrets: [GOOGLE_CALENDAR_OAUTH_SECRET]})
    .https.onCall(scheduleCustomerFabricConsultation);
exports.submitMeasurementPartnerMeasurements = functions.https.onCall(submitMeasurementPartnerMeasurements);
exports.getCustomerOrderPartnerContacts = functions.https.onCall(getCustomerOrderPartnerContacts);
exports.getCustomerOrderDeliveryPin = functions.https.onCall(getCustomerOrderDeliveryPin);
exports.saveTailorGarmentRecord = functions.https.onCall(saveTailorGarmentRecord);
exports.getGarmentRecordShareLink = functions.https.onCall(getGarmentRecordShareLink);
exports.viewPublicGarmentRecord = functions.https.onRequest(viewPublicGarmentRecord);
exports.advanceProductionDeliveryOrder = functions.https.onCall(advanceProductionDeliveryOrder);
exports.submitOrderFeedback = functions.https.onCall(submitOrderFeedback);
exports.reportOrderWarrantyIssue = functions.https.onCall(reportOrderWarrantyIssue);
exports.resolveTailorWarrantyIssue = functions.https.onCall(resolveTailorWarrantyIssue);
exports.resolveOrderWarrantyIssue = functions.https.onCall(resolveOrderWarrantyIssue);
exports.getAdminOrderRoutingQueue = functions.https.onCall(getAdminOrderRoutingQueue);
exports.getAdminOrderRoutingCandidates = functions.https.onCall(getAdminOrderRoutingCandidates);
exports.getAdminInboundPickupCandidates = functions.https.onCall(getAdminInboundPickupCandidates);
exports.assignInboundPickupPartner = functions.https.onCall(assignInboundPickupPartner);
exports.getTailorInboundPickupCandidates = functions.https.onCall(getTailorInboundPickupCandidates);
exports.assignTailorInboundPickupPartner = functions.https.onCall(assignTailorInboundPickupPartner);
exports.getAdminOutboundHandoverCandidates = functions.https.onCall(getAdminOutboundHandoverCandidates);
exports.assignAdminOutboundHandoverPartner = functions.https.onCall(assignAdminOutboundHandoverPartner);
exports.getTailorOutboundHandoverCandidates = functions.https.onCall(getTailorOutboundHandoverCandidates);
exports.assignTailorOutboundHandoverPartner = functions.https.onCall(assignTailorOutboundHandoverPartner);
exports.updateTailorRoutingPriority = functions.https.onCall(updateTailorRoutingPriority);
exports.sendAdminTailorOrderOffer = functions.https.onCall(sendAdminTailorOffer);
exports.resumeQueuedAssignments = resumeQueuedAssignments;

exports.sweepOrderAssignmentDeadlines = functions.pubsub.schedule("every 5 minutes").onRun(async () => {
  const offers = await db.collectionGroup("order_offers").where("status", "==", "offered").get();
  for (const offer of offers.docs) {
    const expiry = offer.get("expiresAt");
    if (expiry && expiry.toDate() <= new Date()) await expireTailorOffer(offer);
  }
  const orders = await db.collection("orders").where("assignmentStatus", "==", "awaiting_customer_decision").get();
  for (const order of orders.docs) {
    const expiry = order.get("customerDecisionExpiresAt");
    if (expiry && expiry.toDate() <= new Date()) await expireCustomerDecision(order.id);
  }
  await resumeQueuedAssignments();
  return null;
});
