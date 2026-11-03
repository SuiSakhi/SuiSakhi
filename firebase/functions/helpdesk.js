const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {getDefaultStorageBucket} = require("./storage_bucket");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const {FieldValue} = admin.firestore;

function fail(code, message) {
  throw new functions.https.HttpsError(code, message);
}

function clean(value) {
  if (value == null) return value;
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) return value.map(clean);
  if (typeof value === "object") {
    if (typeof value.path === "string" && value.constructor &&
        value.constructor.name === "DocumentReference") return value.path;
    const result = {};
    for (const [key, item] of Object.entries(value)) result[key] = clean(item);
    return result;
  }
  return value;
}

function docData(snapshot) {
  return snapshot && snapshot.exists
    ? {id: snapshot.id, ...clean(snapshot.data() || {})}
    : null;
}

function millis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

async function requireHelpdesk(context) {
  if (!context.auth) fail("unauthenticated", "Sign in with your verified phone number.");
  const uid = context.auth.uid;
  const phone = context.auth.token.phone_number;
  const [adminSnapshot, supportSnapshot] = await Promise.all([
    db.doc("config/admin").get(),
    db.doc("config/support").get(),
  ]);
  const adminUids = adminSnapshot.get("adminUids");
  if (Array.isArray(adminUids) && adminUids.includes(uid)) return {uid, role: "admin"};
  const supportUids = supportSnapshot.get("supportUids");
  const supportPhones = supportSnapshot.get("supportPhones");
  if ((Array.isArray(supportUids) && supportUids.includes(uid)) ||
      (typeof phone === "string" && Array.isArray(supportPhones) && supportPhones.includes(phone))) {
    return {uid, role: "support"};
  }
  fail("permission-denied", "Configured Helpdesk access is required.");
}

async function requireAdmin(context) {
  if (!context.auth) fail("unauthenticated", "Sign in as an Admin.");
  const adminSnapshot = await db.doc("config/admin").get();
  const adminUids = adminSnapshot.get("adminUids");
  if (!Array.isArray(adminUids) || !adminUids.includes(context.auth.uid)) {
    fail("permission-denied", "Configured Admin access is required.");
  }
  return {uid: context.auth.uid, role: "admin"};
}

async function aggregateCount(query) {
  const snapshot = await query.count().get();
  return Number(snapshot.data().count || 0);
}

exports.getMyHelpdeskAccess = functions.https.onCall(async (_data, context) => {
  if (!context.auth) return {allowed: false};
  const uid = context.auth.uid;
  const phone = context.auth.token.phone_number;
  const [adminSnapshot, supportSnapshot] = await Promise.all([
    db.doc("config/admin").get(),
    db.doc("config/support").get(),
  ]);
  const adminUids = adminSnapshot.get("adminUids");
  const supportUids = supportSnapshot.get("supportUids");
  const supportPhones = supportSnapshot.get("supportPhones");
  const isAdmin = Array.isArray(adminUids) && adminUids.includes(uid);
  const isSupport = (Array.isArray(supportUids) && supportUids.includes(uid)) ||
    (typeof phone === "string" && Array.isArray(supportPhones) && supportPhones.includes(phone));
  return {
    allowed: isAdmin || isSupport,
    isAdmin,
    isSupport,
  };
});

async function loadAdminHelpdeskOverview() {
  const statuses = ["Open", "In Progress", "Waiting Customer", "Escalated", "Resolved", "Closed"];
  // Pilot reporting follows the business timezone (India Standard Time).
  const now = new Date();
  const indiaNow = new Date(now.getTime() + 330 * 60 * 1000);
  const monthStart = new Date(Date.UTC(
    indiaNow.getUTCFullYear(),
    indiaNow.getUTCMonth(),
    1,
  ) - 330 * 60 * 1000);
  const ticketCollection = db.collection("support_tickets");
  const [statusCounts, helpdeskClosures, adminClosures] = await Promise.all([
    Promise.all(statuses.map(async (status) => [
      status,
      await aggregateCount(ticketCollection.where("status", "==", status)),
    ])),
    aggregateCount(db.collection("support_ticket_activity")
        .where("action", "==", "closed")
        .where("actorRole", "==", "support")
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(monthStart))),
    aggregateCount(db.collection("support_ticket_activity")
        .where("action", "==", "closed")
        .where("actorRole", "==", "admin")
        .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(monthStart))),
  ]);
  return {
    statuses: Object.fromEntries(statusCounts),
    closedByHelpdeskThisMonth: helpdeskClosures,
    closedByAdminThisMonth: adminClosures,
    attributionTrackedFrom: "feature rollout",
  };
}

exports.getAdminHelpdeskOverview = functions.runWith({invoker: "public"})
    .https.onCall(async (_data, context) => {
      await requireAdmin(context);
      return loadAdminHelpdeskOverview();
    });

async function updateHelpdeskTicketAction(data, context) {
  const actor = await requireHelpdesk(context);
  const ticketId = String(data && data.ticketId || "").trim();
  const status = String(data && data.status || "").trim();
  const assignedTeam = String(data && data.assignedTeam || "").trim();
  const response = String(data && data.response || "").trim();
  const statuses = new Set(["Open", "In Progress", "Escalated", "Waiting Customer", "Resolved", "Closed"]);
  const teams = new Set([
    "orders", "measurements", "design_and_fabric", "payments",
    "garment_care", "quick_care", "delivery", "customer_support",
  ]);
  if (!ticketId || !statuses.has(status) || !teams.has(assignedTeam) || response.length > 2000) {
    fail("invalid-argument", "Choose a valid ticket status and team, and keep the reply under 2,000 characters.");
  }

  const ticketRef = db.collection("support_tickets").doc(ticketId);
  const activityRef = db.collection("support_ticket_activity").doc();
  const now = admin.firestore.Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ticketRef);
    if (!snapshot.exists) fail("not-found", "Support request not found.");
    const current = snapshot.data() || {};
    const oldStatus = String(current.status || "Open");
    const wasClosed = ["Resolved", "Closed"].includes(oldStatus);
    const isClosed = ["Resolved", "Closed"].includes(status);
    const changed = oldStatus !== status || current.assignedTeam !== assignedTeam ||
        current.response !== response;
    if (!changed) return;

    transaction.update(ticketRef, {
      status,
      assignedTeam,
      response,
      updatedAt: now,
      lastUpdatedByUid: actor.uid,
      lastUpdatedByRole: actor.role,
      resolvedAt: isClosed ? (wasClosed ? current.resolvedAt || now : now) : null,
      ...(isClosed && !wasClosed
        ? {lastClosedByUid: actor.uid, lastClosedByRole: actor.role, lastClosedAt: now}
        : {}),
    });
    const action = isClosed && !wasClosed
      ? "closed"
      : wasClosed && !isClosed
        ? "reopened"
        : "updated";
    transaction.set(activityRef, {
      ticketId,
      customerUid: String(current.customerUid || ""),
      action,
      oldStatus,
      newStatus: status,
      assignedTeam,
      actorUid: actor.uid,
      actorRole: actor.role,
      createdAt: now,
    });
  });
  return {ticketId, status};
}

exports.updateHelpdeskTicket = functions.runWith({invoker: "public"})
    .https.onCall(updateHelpdeskTicketAction);

function classifyOrder(data) {
  if (data.orderModuleType === "quickFix") return "quick_care";
  if (["measurement", "measurementVisit", "measurementOrder"].includes(data.orderModuleType)) return "measurements";
  if (data.orderModuleType === "coreTailoring" || data.assignmentVersion === "v1") return "tailoring";
  return data.orderModuleType ? "other" : "tailoring";
}

function orderServicePincode(data) {
  const direct = String(data.deliveryPincode || data.pincode ||
    (data.deliveryLocation && data.deliveryLocation.pincode) ||
    (data.serviceLocation && data.serviceLocation.pincode) || "").replace(/\D/g, "");
  if (/^\d{6}$/.test(direct)) return direct;
  const addressText = [data.deliveryAddress, data.serviceAddress,
    data.pickupAddress, data.address].filter(Boolean).join(" ");
  const match = String(addressText).match(/(?:^|\D)(\d{6})(?:\D|$)/);
  return match ? match[1] : "";
}

function quickCareCancellation(order) {
  if (order.orderModuleType !== "quickFix") {
    return {allowed: false, reason: "Only Quick Care bookings can be cancelled from this Helpdesk action."};
  }
  if (["cancelled", "delivered", "completed"].includes(String(order.status || "").toLowerCase())) {
    return {allowed: false, reason: "This booking is already closed."};
  }
  const assigned = [
    "quickCarePartnerAccountId", "assignedQuickCarePartnerAccountId",
    "quickCareAssignedPartnerAccountId", "assignedPartnerAccountId",
  ].some((key) => Boolean(order[key]));
  const workflow = String(order.quickCareWorkflowStatus || "")
      .replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase().replace(/[\s-]+/g, "_");
  const orderStatus = String(order.status || "")
      .replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase().replace(/[\s-]+/g, "_");
  if (order.quickCareQuoteStatus === "customerAccepted" ||
      order.quickCareExtraChargeStatus === "approved") {
    return {allowed: false, reason: "The service quote has been approved; cancellation is no longer available."};
  }
  const activeStates = ["in_progress", "started", "service_started", "work_started", "paused", "payment_pending", "completed", "service_completed", "picked_up", "at_tailor", "ready_for_pickup", "out_for_delivery"];
  if (activeStates.includes(workflow) || activeStates.includes(orderStatus)) {
    return {allowed: false, reason: "Service work has started or is awaiting payment; cancellation is no longer available."};
  }
  const appointment = order.quickCareScheduledAt;
  if (!appointment || typeof appointment.toDate !== "function") {
    return {allowed: false, reason: "The appointment time is not confirmed; review the cancellation with the customer first."};
  }
  const requestTime = order.quickCareCancellationRequestedAt;
  const checkedAt = requestTime && typeof requestTime.toDate === "function"
    ? requestTime.toDate().getTime()
    : Date.now();
  if (appointment.toDate().getTime() - checkedAt <= 2 * 60 * 60 * 1000) {
    return {allowed: false, reason: "This booking is within two hours. Review any applicable fee with the customer before cancelling."};
  }
  return {
    allowed: true,
    reason: assigned
      ? "Future Quick Care booking; coordinate with the assigned Partner and cancel with no fee."
      : "Future Quick Care booking; cancellation will be recorded with no fee.",
  };
}

async function createQuickCareCancellationRequest(data, context) {
  if (!context.auth) fail("unauthenticated", "Sign in to request cancellation.");
  const orderId = String(data && data.orderId || "").trim();
  if (!orderId) fail("invalid-argument", "Choose a Quick Care booking.");

  const orderRef = db.collection("orders").doc(orderId);
  const ticketRef = db.collection("support_tickets").doc();
  let ticketId = ticketRef.id;
  let alreadySubmitted = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
    const order = snapshot.data() || {};
    if (order.customerId !== context.auth.uid && order.customerUid !== context.auth.uid) {
      fail("permission-denied", "This is not your Quick Care booking.");
    }
    if (order.orderModuleType !== "quickFix") {
      fail("failed-precondition", "This cancellation option is for Quick Care bookings.");
    }
    if (["cancelled", "delivered", "completed"].includes(String(order.status || "").toLowerCase())) {
      fail("failed-precondition", "This booking is already closed.");
    }
    const workflow = String(order.quickCareWorkflowStatus || "")
        .replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase().replace(/[\s-]+/g, "_");
    const orderStatus = String(order.status || "")
        .replace(/([a-z])([A-Z])/g, "$1_$2").toLowerCase().replace(/[\s-]+/g, "_");
    if (order.quickCareQuoteStatus === "customerAccepted" ||
        order.quickCareExtraChargeStatus === "approved") {
      fail("failed-precondition", "The service quote has been approved; cancellation is no longer available.");
    }
    const activeStates = ["in_progress", "started", "service_started", "work_started", "paused", "payment_pending", "completed", "service_completed", "picked_up", "at_tailor", "ready_for_pickup", "out_for_delivery"];
    if (activeStates.includes(workflow) || activeStates.includes(orderStatus)) {
      fail("failed-precondition", "Service work has started or is awaiting payment; cancellation is no longer available.");
    }
    if (order.quickCareCancellationRequestStatus === "pending_admin" &&
        typeof order.quickCareCancellationRequestTicketId === "string" &&
        order.quickCareCancellationRequestTicketId.trim()) {
      ticketId = order.quickCareCancellationRequestTicketId;
      alreadySubmitted = true;
      return;
    }
    const scheduledAt = order.quickCareScheduledAt;
    if (!scheduledAt || typeof scheduledAt.toDate !== "function" ||
        scheduledAt.toDate().getTime() - Date.now() <= 2 * 60 * 60 * 1000) {
      fail("failed-precondition", "Only bookings more than two hours away qualify for a no-fee cancellation request.");
    }

    const customerName = String(order.customerName || order.customerDisplayName || "Customer").slice(0, 100);
    const subject = `Cancellation request for Quick Care booking ${order.orderNumber || orderId}`.slice(0, 100);
    const message = "The customer requested cancellation more than two hours before the appointment. No cancellation fee should apply. Please review and cancel this booking from Helpdesk.";
    transaction.update(orderRef, {
      quickCareCancellationRequestStatus: "pending_admin",
      quickCareCancellationRequestTicketId: ticketId,
      quickCareCancellationRequestedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(orderRef.collection("events").doc(), {
      type: "customer_requested_quick_care_cancellation",
      actorType: "customer",
      actorUid: context.auth.uid,
      noCancellationFee: true,
      supportTicketId: ticketId,
      occurredAt: FieldValue.serverTimestamp(),
    });
    transaction.set(ticketRef, {
      customerUid: context.auth.uid,
      customerName,
      category: "Quick Care Issue",
      subject,
      message,
      linkedOrderId: orderId,
      linkedOrderType: "quick_care",
      assignedTeam: "quick_care",
      status: "Open",
      source: "customer_helpdesk",
      languageCode: "en",
      noCancellationFee: true,
      requestType: "quick_care_cancellation",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {status: "pending_admin", ticketId, noCancellationFee: true, alreadySubmitted};
}

exports.createQuickCareCancellationRequest = createQuickCareCancellationRequest;
exports.requestQuickCareCancellation = functions.https.onCall(
  createQuickCareCancellationRequest,
);

exports.createCustomerSupportTicket = functions.https.onCall(async (data, context) => {
  if (!context.auth) fail("unauthenticated", "Sign in to contact support.");
  const categories = new Set([
    "Order Issue", "Measurement Issue", "Fabric Issue", "Designer Issue",
    "Payment Issue", "Garment Care Issue", "Quick Care Issue",
    "Delivery Issue", "Other",
  ]);
  const category = String(data && data.category || "").trim();
  const subject = String(data && data.subject || "").trim();
  const message = String(data && data.message || "").trim();
  const customerName = String(data && data.customerName || "Customer").trim().slice(0, 100);
  const linkedOrderId = String(data && data.linkedOrderId || "").trim();
  const linkedOrderType = String(data && data.linkedOrderType || "").trim();
  const requestType = String(data && data.requestType || "").trim();
  const rawRequestDetails = data && data.requestDetails;

  if (!categories.has(category)) fail("invalid-argument", "Choose a valid support topic.");
  if (!subject || subject.length > 100) fail("invalid-argument", "Add a subject up to 100 characters.");
  if (message.length < 5 || message.length > 2000) fail("invalid-argument", "Describe the issue in 5 to 2,000 characters.");
  if (requestType && !["bulk_order", "dress_rental"].includes(requestType)) {
    fail("invalid-argument", "Choose a supported service request type.");
  }
  if (requestType && (linkedOrderId || category !== "Other")) {
    fail("invalid-argument", "Service requests must be submitted without a linked order.");
  }

  let requestDetails = null;
  if (requestType) {
    if (!rawRequestDetails || typeof rawRequestDetails !== "object" ||
        Array.isArray(rawRequestDetails) || Object.keys(rawRequestDetails).length > 30) {
      fail("invalid-argument", "Add valid service request details.");
    }
    requestDetails = {};
    for (const [key, value] of Object.entries(rawRequestDetails)) {
      if (!/^[A-Za-z][A-Za-z0-9_]{0,39}$/.test(key)) {
        fail("invalid-argument", "A service request detail is invalid.");
      }
      if (typeof value === "string") {
        requestDetails[key] = value.trim().slice(0, 500);
      } else if (typeof value === "number" && Number.isFinite(value)) {
        requestDetails[key] = value;
      } else if (typeof value === "boolean") {
        requestDetails[key] = value;
      } else {
        fail("invalid-argument", "Service request details must be simple values.");
      }
    }
    if (JSON.stringify(requestDetails).length > 7000) {
      fail("invalid-argument", "Service request details are too large.");
    }
  }

  if (linkedOrderId) {
    if (linkedOrderType === "garment_care") {
      const order = await db.collection("garment_care_orders").doc(linkedOrderId).get();
      if (!order.exists) fail("not-found", "The selected Garment Care order was not found.");
      if (order.get("customerUid") !== context.auth.uid) fail("permission-denied", "This is not your Garment Care order.");
    } else if (linkedOrderType === "quick_care") {
      const order = await db.collection("orders").doc(linkedOrderId).get();
      if (!order.exists) fail("not-found", "The selected Quick Care booking was not found.");
      const orderData = order.data() || {};
      if ((orderData.customerId !== context.auth.uid && orderData.customerUid !== context.auth.uid) ||
          orderData.orderModuleType !== "quickFix") {
        fail("permission-denied", "This is not your Quick Care booking.");
      }
    } else if (linkedOrderType === "tailoring") {
      const order = await db.collection("orders").doc(linkedOrderId).get();
      if (!order.exists) fail("not-found", "The selected tailoring order was not found.");
      if (order.get("customerId") !== context.auth.uid) fail("permission-denied", "This is not your tailoring order.");
    } else {
      fail("invalid-argument", "Choose a supported order type.");
    }
  } else if (linkedOrderType) {
    fail("invalid-argument", "Choose an order before selecting its type.");
  }

  const assignedTeam = ({
    "Order Issue": "orders",
    "Measurement Issue": "measurements",
    "Fabric Issue": "design_and_fabric",
    "Designer Issue": "design_and_fabric",
    "Payment Issue": "payments",
    "Garment Care Issue": "garment_care",
    "Quick Care Issue": "quick_care",
    "Delivery Issue": "delivery",
  })[category] || "customer_support";
  const ticketRef = db.collection("support_tickets").doc();
  await ticketRef.set({
    customerUid: context.auth.uid,
    customerName: customerName || "Customer",
    category,
    subject,
    message,
    ...(requestType ? {requestType, requestDetails} : {}),
    linkedOrderId: linkedOrderId || null,
    linkedOrderType: linkedOrderId ? linkedOrderType : null,
    assignedTeam,
    status: "Open",
    source: "customer_helpdesk",
    languageCode: "en",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ticketId: ticketRef.id, status: "Open"};
});

exports.updateCustomerServiceRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) fail("unauthenticated", "Sign in to update this request.");
  const ticketId = String(data && data.ticketId || "").trim();
  const action = String(data && data.action || "").trim();
  const comment = String(data && data.comment || "").trim();
  if (!ticketId || !["comment", "completed", "cancel"].includes(action)) {
    fail("invalid-argument", "Choose a valid request update.");
  }
  if (action === "comment" && (comment.length < 2 || comment.length > 1000)) {
    fail("invalid-argument", "Comments must be between 2 and 1,000 characters.");
  }

  const ticketRef = db.collection("support_tickets").doc(ticketId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ticketRef);
    if (!snapshot.exists) fail("not-found", "This Helpdesk request was not found.");
    const ticket = snapshot.data() || {};
    if (ticket.customerUid !== context.auth.uid ||
        !["bulk_order", "dress_rental"].includes(ticket.requestType)) {
      fail("permission-denied", "This is not your service request.");
    }
    if (String(ticket.status || "") === "Closed") {
      fail("failed-precondition", "This request is already closed.");
    }

    const now = FieldValue.serverTimestamp();
    if (action === "comment") {
      const comments = Array.isArray(ticket.customerComments)
        ? ticket.customerComments.slice(-19)
        : [];
      comments.push({
        text: comment,
        actorUid: context.auth.uid,
        occurredAt: admin.firestore.Timestamp.now(),
      });
      transaction.update(ticketRef, {
        customerComments: comments,
        ...(ticket.status === "Resolved" ? {status: "In Progress"} : {}),
        updatedAt: now,
      });
      return {ticketId, status: ticket.status === "Resolved" ? "In Progress" : ticket.status || "Open"};
    }

    transaction.update(ticketRef, {
      status: "Closed",
      customerResolution: action === "completed" ? "completed" : "cancelled",
      resolvedAt: now,
      updatedAt: now,
    });
    return {ticketId, status: "Closed"};
  });
});

function orderSummary(snapshot, orderType) {
  const data = snapshot.data() || {};
  const isQuickCare = data.orderModuleType === "quickFix";
  const timestamp = orderType === "garment_care" ? data.createdAt : data.orderDate || data.createdAt;
  const itemCount = Number(data.itemCount || data.packageCount || 0);
  const serviceGroup = String(data.serviceGroupCode || "")
      .replace(/[_-]+/g, " ").trim()
      .replace(/\b\w/g, (letter) => letter.toUpperCase());
  const fallbackSummary = orderType === "garment_care"
    ? ["Garment Care", serviceGroup, itemCount > 0 ? `${itemCount} ${itemCount === 1 ? "item" : "items"}` : ""]
        .filter(Boolean).join(" · ")
    : orderType === "tailoring" ? "Tailoring order"
      : orderType === "measurements" ? "Measurement request" : "Customer order";
  const rawStatus = isQuickCare
    ? data.quickCareWorkflowStatus || data.status || "Status unavailable"
    : orderType === "garment_care"
      ? data.statusProjection || data.workflowStatus || data.status ||
        data.orderStatus || data.estimateStatus || data.pricingState ||
        "Status unavailable"
      : data.status || data.orderStatus || data.estimateStatus ||
        data.statusProjection || data.pricingState || "Status unavailable";
  const displayStatus = String(rawStatus)
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/[_-]+/g, " ")
      .replace(/\b\w/g, (letter) => letter.toUpperCase());
  return {
    orderId: snapshot.id,
    orderType,
    orderNumber: data.orderNumber || data.orderTrackingId || snapshot.id,
    customerName: data.customerName || data.customerDisplayName || data.customerNameSnapshot || "Customer",
    customerPhone: data.customerPhone || data.customerMobileE164 || data.mobileE164 || data.phone || "",
    customerUid: data.customerUid || data.customerId || "",
    status: displayStatus,
    workflowStatus: isQuickCare ? data.quickCareWorkflowStatus || "requestSubmitted" : displayStatus,
    assignmentStatus: isQuickCare ? data.quickCareAssignmentStatus || "searching" : null,
    paymentStatus: data.paymentStatus || "",
    servicePincode: orderServicePincode(data),
    deliveryAddress: data.deliveryAddress || data.serviceAddress || data.pickupAddress || data.address || "",
    total: Number(data.totalAmount || data.price || data.grandTotal || 0),
    createdAt: clean(timestamp),
    summary: data.orderModuleType === "quickFix"
      ? (data.quickCareTitle || data.title || data.serviceName || data.dressType || "Quick Care booking")
      : (data.orderTitle || data.garmentCareTitle || data.serviceName ||
        data.dressType || data.title || fallbackSummary),
  };
}

const PARTNER_GROUP_LABELS = {
  tailor: "Tailoring",
  measurementPartner: "Measurements",
  garmentCare: "Garment Care",
  boutique: "Boutique",
  designer: "Designer",
  fabricSupplier: "Fabric Supplier",
  printing: "Printing",
  embroidery: "Embroidery",
  rental: "Rental",
  accessories: "Accessories",
  brand: "Brand",
  deliveryPartner: "Delivery",
  doorstepServices: "Quick Care",
  other: "Other",
};

function partnerSchedule(profile) {
  const partnerType = String(profile.partnerType || "other");
  const partnerData = profile.partnerData && typeof profile.partnerData === "object"
    ? profile.partnerData : {};
  const extensions = partnerData.extensions && typeof partnerData.extensions === "object"
    ? partnerData.extensions : {};
  const category = extensions[partnerType] && typeof extensions[partnerType] === "object"
    ? extensions[partnerType] : {};
  const workshop = category.workshopDetails && typeof category.workshopDetails === "object"
    ? category.workshopDetails : {};
  const operational = category.operational && typeof category.operational === "object"
    ? category.operational : {};
  const slots = Array.isArray(operational.availabilitySlots)
    ? operational.availabilitySlots
        .map((slot) => ({
          day: String(slot && slot.day || "").toLowerCase(),
          start: String(slot && slot.start || ""),
          end: String(slot && slot.end || ""),
        }))
        .filter((slot) => DAY_CODES.includes(slot.day) && validTime(slot.start) &&
          validTime(slot.end) && slot.start < slot.end)
    : [];
  const schedule = slots.length ? slots :
    (Array.isArray(workshop.operatingDays) ? workshop.operatingDays : [])
        .map((day) => ({
          day: String(day || "").toLowerCase(),
          start: String(workshop.openingTime || ""),
          end: String(workshop.closingTime || ""),
        }))
        .filter((slot) => DAY_CODES.includes(slot.day) && validTime(slot.start) &&
          validTime(slot.end) && slot.start < slot.end);
  const available = partnerType === "tailor"
    ? profile.availabilityStatus === "available"
    : partnerType === "doorstepServices"
      ? operational.availableForOrders !== false
      : profile.availabilityStatus === "available" || profile.availableForOrders === true;
  return {
    slots: schedule,
    available,
    availabilityTracked: partnerType === "tailor" || partnerType === "doorstepServices" ||
      typeof profile.availabilityStatus === "string" ||
      typeof profile.availableForOrders === "boolean",
    display: schedule.length
      ? [...new Set(schedule.map((slot) => slot.day))].join(", ")
      : "",
  };
}

const DAY_CODES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

function validTime(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value || ""));
}

function timeMinutes(value) {
  const [hours, minutes] = String(value || "0:0").split(":").map(Number);
  return hours * 60 + minutes;
}

// Application and partner availability schedules are recorded in Indian local time.
// Count only time inside the partner's configured opening slots so overnight closing
// hours do not generate a false Admin inactivity alert.
function openTimeSince(schedule, fromMillis, toMillis) {
  if (!schedule.length || !fromMillis || toMillis <= fromMillis) return null;
  const istOffset = 330 * 60 * 1000;
  const start = Math.max(fromMillis, toMillis - 370 * 24 * 60 * 60 * 1000);
  let total = 0;
  const firstDay = new Date(start + istOffset);
  const dayCursor = Date.UTC(firstDay.getUTCFullYear(), firstDay.getUTCMonth(), firstDay.getUTCDate());
  const lastDay = new Date(toMillis + istOffset);
  const lastDayUtc = Date.UTC(lastDay.getUTCFullYear(), lastDay.getUTCMonth(), lastDay.getUTCDate());
  const slotsByDay = new Map();
  for (const slot of schedule) {
    if (!slotsByDay.has(slot.day)) slotsByDay.set(slot.day, []);
    slotsByDay.get(slot.day).push(slot);
  }
  for (let dateUtc = dayCursor; dateUtc <= lastDayUtc; dateUtc += 24 * 60 * 60 * 1000) {
    const weekday = new Date(dateUtc).getUTCDay();
    const daySlots = slotsByDay.get(DAY_CODES[weekday]) || [];
    const localDayStartUtc = dateUtc - istOffset;
    for (const slot of daySlots) {
      const opening = localDayStartUtc + timeMinutes(slot.start) * 60 * 1000;
      const closing = localDayStartUtc + timeMinutes(slot.end) * 60 * 1000;
      total += Math.max(0, Math.min(toMillis, closing) - Math.max(start, opening));
    }
  }
  return total;
}

function isClosedStage(value) {
  return ["completed", "service_completed", "delivered", "cancelled", "canceled", "closed", "resolved", "rejected", "returned", "failed"]
      .includes(String(value || "").replace(/([a-z])([A-Z])/g, "$1_$2")
          .toLowerCase().replace(/[\s-]+/g, "_").trim());
}

function addPartnerWork(workByKey, accountId, profileId, work) {
  if (!accountId || !profileId || isClosedStage(work.stage)) return;
  const key = `${accountId}/${profileId}`;
  const list = workByKey.get(key);
  if (list) list.push(work);
}

async function loadAdminPartnerManagement() {
  const [profileSnapshot, ordersSnapshot, careOrdersSnapshot, jobsSnapshot, shipmentsSnapshot] = await Promise.all([
    db.collectionGroup("profiles").where("role", "==", "partner").limit(1500).get(),
    db.collection("orders").limit(2500).get(),
    db.collection("garment_care_orders").limit(1500).get(),
    db.collection("garment_care_service_jobs").limit(2500).get(),
    db.collection("garment_care_shipments").limit(2000).get(),
  ]);

  const profiles = profileSnapshot.docs.map((snapshot) => ({
    id: snapshot.id,
    accountId: snapshot.ref.parent.parent && snapshot.ref.parent.parent.id || "",
    data: snapshot.data() || {},
  }));
  const workByKey = new Map(profiles.map((partner) => [
    `${partner.accountId}/${partner.id}`, [],
  ]));
  const careOrders = new Map(careOrdersSnapshot.docs.map((snapshot) => [snapshot.id, snapshot.data() || {}]));

  for (const snapshot of ordersSnapshot.docs) {
    const order = snapshot.data() || {};
    const id = snapshot.id;
    const type = classifyOrder(order);
    const orderNumber = String(order.orderNumber || order.orderTrackingId || id);
    const createdAt = clean(order.orderDate || order.createdAt);
    const base = {orderId: id, orderNumber, createdAt};
    const assignments = [
      ["assignedTailorAccountId", "assignedTailorProfileId", "Tailoring", order.workflowStatus || order.statusProjection || order.status || order.assignmentStatus],
      ["measurementPartnerAccountId", "measurementPartnerProfileId", "Measurement", order.measurementStatus || order.measurementWorkflowStatus || order.status],
      ["quickCareAssignedPartnerAccountId", "quickCareAssignedPartnerProfileId", "Quick Care", order.quickCareWorkflowStatus || order.status],
      ["assignedQuickCarePartnerAccountId", "assignedQuickCarePartnerProfileId", "Quick Care", order.quickCareWorkflowStatus || order.status],
      ["quickCarePartnerAccountId", "quickCarePartnerProfileId", "Quick Care", order.quickCareWorkflowStatus || order.status],
      ["assignedPartnerAccountId", "assignedPartnerProfileId", type === "quick_care" ? "Quick Care" : type === "garment_care" ? "Garment Care" : type === "measurements" ? "Measurement" : type === "tailoring" ? "Tailoring" : "Partner order", order.statusProjection || order.workflowStatus || order.status],
      ["deliveryPartnerAccountId", "deliveryPartnerProfileId", "Delivery", order.deliveryStatus || order.status],
      ["inboundPickupPartnerAccountId", "inboundPickupPartnerProfileId", "Inbound pickup", order.inboundPickupStatus || order.status],
      ["outboundHandoverPartnerAccountId", "outboundHandoverPartnerProfileId", "Outbound delivery", order.outboundHandoverStatus || order.status],
    ];
    const seen = new Set();
    for (const [accountField, profileField, workType, stage] of assignments) {
      const accountId = String(order[accountField] || "");
      const profileId = String(order[profileField] || "");
      const key = `${accountId}/${profileId}/${workType}`;
      if (!accountId || !profileId || seen.has(key)) continue;
      seen.add(key);
      addPartnerWork(workByKey, accountId, profileId, {
        ...base,
        orderType: type,
        workType,
        title: String(order.quickCareTitle || order.orderTitle || order.serviceName || order.dressType || type.replace(/_/g, " ")),
        stage: String(stage || "Status unavailable"),
      });
    }
  }

  for (const snapshot of jobsSnapshot.docs) {
    const job = snapshot.data() || {};
    const orderId = String(job.orderId || "");
    const order = careOrders.get(orderId) || {};
    addPartnerWork(workByKey,
        String(job.assignedPartnerAccountId || ""), String(job.assignedPartnerProfileId || ""), {
          orderId,
          orderNumber: String(job.subOrderNumber || order.orderNumber || orderId),
          orderType: "garment_care",
          workType: String(job.serviceName || job.serviceGroupCode || "Garment Care"),
          title: String(job.serviceName || job.title || job.serviceGroupCode || "Garment Care job"),
          stage: String(job.status || "Status unavailable"),
          createdAt: clean(job.createdAt || order.createdAt),
        });
  }

  for (const snapshot of shipmentsSnapshot.docs) {
    const shipment = snapshot.data() || {};
    const orderId = String(shipment.orderId || "");
    const order = careOrders.get(orderId) || {};
    const shipmentAssignments = [
      ["assignedPartnerAccountId", "assignedPartnerProfileId", "Garment Care shipment"],
      ["fromPartnerAccountId", "fromPartnerProfileId", "Shipment handoff"],
      ["toPartnerAccountId", "toPartnerProfileId", "Shipment handoff"],
      ["deliveryPartnerAccountId", "deliveryPartnerProfileId", "Garment Care delivery"],
    ];
    const seen = new Set();
    for (const [accountField, profileField, workType] of shipmentAssignments) {
      const accountId = String(shipment[accountField] || "");
      const profileId = String(shipment[profileField] || "");
      const key = `${accountId}/${profileId}`;
      if (!accountId || !profileId || seen.has(key)) continue;
      seen.add(key);
      addPartnerWork(workByKey, accountId, profileId, {
        orderId,
        orderNumber: String(shipment.subOrderNumber || shipment.orderNumber || order.orderNumber || orderId),
        orderType: "garment_care",
        workType,
        title: String(shipment.serviceName || order.serviceGroupCode || "Garment Care shipment"),
        stage: String(shipment.status || shipment.deliveryStatus || "Status unavailable"),
        createdAt: clean(shipment.createdAt || order.createdAt),
      });
    }
  }

  const applicationIds = [...new Set(profiles.map(({data}) => String(data.sourceApplicationId || "")).filter(Boolean))];
  const applicationDocs = applicationIds.length
    ? await db.getAll(...applicationIds.slice(0, 500).map((id) => db.collection("partner_applications").doc(id)))
    : [];
  const applications = new Map(applicationDocs.filter((snapshot) => snapshot.exists)
      .map((snapshot) => [snapshot.id, snapshot.data() || {}]));
  const now = Date.now();
  const partners = profiles.map(({id, accountId, data}) => {
    const type = String(data.partnerType || "other");
    const key = `${accountId}/${id}`;
    const work = (workByKey.get(key) || []).sort((a, b) => millis(b.createdAt) - millis(a.createdAt));
    const schedule = partnerSchedule(data);
    const appId = String(data.sourceApplicationId || "");
    const application = applications.get(appId) || {};
    const lastSeenAt = millis(data.lastSeenAt);
    const openMillis = openTimeSince(schedule.slots, lastSeenAt, now);
    const scheduleHoursByDay = new Map();
    for (const slot of schedule.slots) {
      const duration = timeMinutes(slot.end) * 60000 - timeMinutes(slot.start) * 60000;
      scheduleHoursByDay.set(slot.day, (scheduleHoursByDay.get(slot.day) || 0) + duration);
    }
    const scheduleDayMillis = Math.max(0, ...scheduleHoursByDay.values());
    const isActive = data.status === "active" && data.operationalStatus === "active" &&
      data.activationStatus === "active" && data.approvalStatus === "approved" &&
      data.kycStatus === "verified";
    return {
      accountId,
      profileId: id,
      partnerType: type,
      groupLabel: PARTNER_GROUP_LABELS[type] || "Other",
      name: String(data.businessName || data.shopName || data.displayName || data.name || data.contactName || "Partner"),
      contactName: String(data.contactName || ""),
      phone: String(data.mobileE164 || ""),
      status: String(data.status || "unknown"),
      operationalStatus: String(data.operationalStatus || "unknown"),
      activationStatus: String(data.activationStatus || "unknown"),
      approvalStatus: String(data.approvalStatus || "unknown"),
      kycStatus: String(data.kycStatus || "unknown"),
      isActive,
      isAvailable: schedule.available,
      availabilityTracked: schedule.availabilityTracked,
      availabilityStatus: String(data.availabilityStatus || ""),
      joinedAt: clean(data.approvedAt || data.createdAt || data.registeredAt),
      applicationSubmittedAt: clean(application.submittedAt || application.createdAt),
      sourceApplicationId: appId,
      joinedVia: appId ? "Partner application" : "Legacy or manual profile",
      applicationStatus: String(application.status || (appId ? "unknown" : "legacy")),
      applicantCustomerProfileId: String(application.customerProfileId || ""),
      referralSource: String(application.referralSource || application.source || ""),
      lastSeenAt: clean(data.lastSeenAt),
      lastSeenMillis: lastSeenAt || null,
      seenRecently: lastSeenAt > 0 && now - lastSeenAt <= 15 * 60 * 1000,
      operatingSchedule: schedule.slots,
      scheduleConfigured: schedule.slots.length > 0,
      inactivityOpenMillis: openMillis,
      followUpAfterOpenMillis: scheduleDayMillis,
      needsAttention: isActive && lastSeenAt > 0 && openMillis !== null &&
        scheduleDayMillis > 0 && openMillis >= scheduleDayMillis,
      openWorkCount: work.length,
      work: work.slice(0, 100),
    };
  });
  partners.sort((a, b) => a.groupLabel.localeCompare(b.groupLabel) || a.name.localeCompare(b.name));
  return {
    generatedAt: new Date().toISOString(),
    partners,
    truncated: profileSnapshot.size >= 1500 || ordersSnapshot.size >= 2500 ||
      careOrdersSnapshot.size >= 1500 || jobsSnapshot.size >= 2500 || shipmentsSnapshot.size >= 2000,
  };
}

function normalizedLookupPhone(value) {
  const raw = String(value || "").trim();
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (raw.startsWith("+") && digits.length >= 10) return `+${digits}`;
  if (digits.length > 10) return `+${digits}`;
  return "";
}

async function searchAdminCustomer360(data, context) {
  await requireAdmin(context);
  const query = String(data && data.query || "").trim();
  if (query.length < 3 || query.length > 140) {
    fail("invalid-argument", "Enter a phone number, account/customer ID, or order reference.");
  }

  const accountIds = new Set();
  const userIds = new Set();
  const phone = normalizedLookupPhone(query);
  const orderMatches = [];

  if (phone) {
    const digits = phone.replace(/\D/g, "");
    const [lookupSnapshot, accountSnapshot, accountByPhoneSnapshot,
      userSnapshot, userByPhoneSnapshot, profileSnapshot, authUser] = await Promise.all([
      db.collection("mobile_accounts").doc(`m_${digits}`).get(),
      db.collection("accounts").where("mobileE164", "==", phone).limit(10).get(),
      db.collection("accounts").where("phoneNumber", "==", phone).limit(10).get(),
      db.collection("users").where("mobileE164", "==", phone).limit(20).get(),
      db.collection("users").where("phoneNumber", "==", phone).limit(20).get(),
      db.collectionGroup("profiles").where("mobileE164", "==", phone).limit(30).get(),
      admin.auth().getUserByPhoneNumber(phone).catch(() => null),
    ]);
    const linkedAccountId = String(lookupSnapshot.get("accountId") || "").trim();
    if (linkedAccountId) accountIds.add(linkedAccountId);
    for (const doc of accountSnapshot.docs) accountIds.add(doc.id);
    for (const doc of accountByPhoneSnapshot.docs) accountIds.add(doc.id);
    for (const doc of [...userSnapshot.docs, ...userByPhoneSnapshot.docs]) {
      userIds.add(doc.id);
      const accountId = String(doc.get("accountId") || "").trim();
      if (accountId) accountIds.add(accountId);
    }
    if (authUser) userIds.add(authUser.uid);
    for (const doc of profileSnapshot.docs) {
      const accountId = doc.ref.parent.parent && doc.ref.parent.parent.id;
      if (accountId) accountIds.add(accountId);
    }
  }

  const [userById, accountById] = await Promise.all([
    db.collection("users").doc(query).get(),
    db.collection("accounts").doc(query).get(),
  ]);
  if (userById.exists) {
    userIds.add(userById.id);
    const accountId = String(userById.get("accountId") || "").trim();
    if (accountId) accountIds.add(accountId);
  }
  if (accountById.exists) accountIds.add(accountById.id);

  const orderCollection = db.collection("orders");
  const careCollection = db.collection("garment_care_orders");
  const [directOrder, directCare, orderByNumber, orderByTracking, careByNumber] = await Promise.all([
    orderCollection.doc(query).get(),
    careCollection.doc(query).get(),
    orderCollection.where("orderNumber", "==", query).limit(10).get(),
    orderCollection.where("orderTrackingId", "==", query).limit(10).get(),
    careCollection.where("orderNumber", "==", query).limit(10).get(),
  ]);
  if (directOrder.exists) orderMatches.push({doc: directOrder, type: classifyOrder(directOrder.data() || {})});
  if (directCare.exists) orderMatches.push({doc: directCare, type: "garment_care"});
  for (const doc of orderByNumber.docs) orderMatches.push({doc, type: classifyOrder(doc.data() || {})});
  for (const doc of orderByTracking.docs) orderMatches.push({doc, type: classifyOrder(doc.data() || {})});
  for (const doc of careByNumber.docs) orderMatches.push({doc, type: "garment_care"});
  for (const match of orderMatches) {
    const order = match.doc.data() || {};
    const uid = String(order.customerUid || order.customerId || "").trim();
    const accountId = String(order.customerAccountId || "").trim();
    if (uid) userIds.add(uid);
    if (accountId) accountIds.add(accountId);
  }

  for (const accountId of accountIds) {
    const linkedUsers = await db.collection("users").where("accountId", "==", accountId).limit(20).get();
    for (const doc of linkedUsers.docs) userIds.add(doc.id);
  }
  if (!userIds.size && !accountIds.size) return {customers: []};

  const customers = await Promise.all([...userIds].slice(0, 20).map(async (uid) => {
    const [userSnapshot, authRecord] = await Promise.all([
      db.collection("users").doc(uid).get(),
      admin.auth().getUser(uid).catch(() => null),
    ]);
    const user = userSnapshot.data() || {};
    const accountId = String(user.accountId || [...accountIds][0] || "").trim();
    if (accountId) accountIds.add(accountId);
    return {
      uid,
      accountId,
      name: String(user.displayName || user.fullName || user.name ||
        (authRecord && authRecord.displayName) || "Customer"),
      phone: String(user.mobileE164 || (authRecord && authRecord.phoneNumber) || phone || ""),
      email: String(user.email || (authRecord && authRecord.email) || ""),
      user: docData(userSnapshot),
    };
  }));

  if (!customers.length) {
    for (const accountId of accountIds) {
      const accountSnapshot = await db.collection("accounts").doc(accountId).get();
      const account = accountSnapshot.data() || {};
      customers.push({
        uid: "",
        accountId,
        name: String(account.displayName || account.fullName || account.name || "Customer"),
        phone: String(account.mobileE164 || phone || ""),
        email: "",
        user: null,
      });
    }
  }

  const records = await Promise.all(customers.map(async (customer) => {
    const [accountSnapshot, profilesSnapshot, addressesSnapshot, ordersByUid, ordersByCustomerUid, ordersByAccount, careOrders, tickets] = await Promise.all([
      customer.accountId ? db.collection("accounts").doc(customer.accountId).get() : Promise.resolve(null),
      customer.accountId
        ? db.collection("accounts").doc(customer.accountId).collection("profiles").limit(100).get()
        : Promise.resolve(null),
      customer.accountId
        ? db.collection("accounts").doc(customer.accountId).collection("addresses").limit(100).get()
        : Promise.resolve(null),
      customer.uid
        ? orderCollection.where("customerId", "==", customer.uid).limit(100).get()
        : Promise.resolve(null),
      customer.uid
        ? orderCollection.where("customerUid", "==", customer.uid).limit(100).get()
        : Promise.resolve(null),
      customer.accountId
        ? orderCollection.where("customerAccountId", "==", customer.accountId).limit(100).get()
        : Promise.resolve(null),
      customer.uid
        ? careCollection.where("customerUid", "==", customer.uid).limit(100).get()
        : Promise.resolve(null),
      customer.uid
        ? db.collection("support_tickets").where("customerUid", "==", customer.uid).limit(100).get()
        : Promise.resolve(null),
    ]);
    const orders = new Map();
    for (const doc of [
      ...((ordersByUid && ordersByUid.docs) || []),
      ...((ordersByCustomerUid && ordersByCustomerUid.docs) || []),
      ...((ordersByAccount && ordersByAccount.docs) || []),
    ]) {
      orders.set(doc.id, orderSummary(doc, classifyOrder(doc.data() || {})));
    }
    const garmentCareOrders = (careOrders && careOrders.docs || []).map((doc) => orderSummary(doc, "garment_care"));
    const allOrders = [...orders.values(), ...garmentCareOrders]
        .sort((a, b) => millis(b.createdAt) - millis(a.createdAt));
    return {
      ...customer,
      account: docData(accountSnapshot),
      profiles: profilesSnapshot ? profilesSnapshot.docs.map(docData) : [],
      addresses: addressesSnapshot ? addressesSnapshot.docs.map(docData) : [],
      orders: allOrders,
      tickets: tickets ? tickets.docs.map(docData).sort((a, b) => millis(b.updatedAt) - millis(a.updatedAt)) : [],
    };
  }));

  return {customers: records};
}

exports.searchAdminCustomer360 = functions.runWith({invoker: "public"})
    .https.onCall(searchAdminCustomer360);

async function loadCustomerDetails(order) {
  const uid = String(order.customerUid || order.customerId || "").trim();
  const accountId = String(order.customerAccountId || "").trim();
  const profileId = String(order.customerProfileId || "").trim();
  const [userSnapshot, accountSnapshot, profileSnapshot] = await Promise.all([
    uid ? db.collection("users").doc(uid).get() : Promise.resolve(null),
    accountId ? db.collection("accounts").doc(accountId).get() : Promise.resolve(null),
    accountId && profileId
      ? db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get()
      : Promise.resolve(null),
  ]);
  return {
    user: docData(userSnapshot),
    account: docData(accountSnapshot),
    profile: docData(profileSnapshot),
  };
}

async function signedQuickCareEvidence(orderId, evidence, keepPermanently) {
  let bucket;
  try {
    bucket = getDefaultStorageBucket();
  } catch (error) {
    functions.logger.warn("Could not resolve Quick Care evidence bucket", {
      orderId,
      message: error && error.message,
    });
    return (Array.isArray(evidence) ? evidence : []).map((item) => ({
      ...(item && typeof item === "object" ? item : {}),
      keepPermanently,
      previewUrl: null,
    }));
  }
  return Promise.all((Array.isArray(evidence) ? evidence : []).map(async (item) => {
    const record = item && typeof item === "object" ? {...item} : {};
    if (record.expired === true) {
      return {...record, keepPermanently, previewUrl: null};
    }
    const path = String(record.storagePath || "").trim();
    if (!path.startsWith(`quickcare_evidence/${orderId}/`)) {
      return {...record, keepPermanently, previewUrl: null};
    }
    try {
      const [previewUrl] = await bucket.file(path).getSignedUrl({
        action: "read",
        expires: Date.now() + 15 * 60 * 1000,
      });
      return {...record, keepPermanently, previewUrl};
    } catch (error) {
      functions.logger.warn("Could not prepare Quick Care evidence preview", {
        orderId,
        path,
        message: error && error.message,
      });
      return {...record, keepPermanently, previewUrl: null};
    }
  }));
}

exports.listHelpdeskOrders = functions.runWith({invoker: "public"})
    .https.onCall(async (data, context) => {
  const actor = await requireHelpdesk(context);
  // Dispatch protected Admin/Helpdesk actions through this already-public
  // callable. Some Firebase projects enforce an organization policy that
  // prevents granting allUsers access to newly created callable functions.
  // Each action still performs its own Admin/Helpdesk role check.
  const action = String(data && data.action || "").trim();
  if (action === "searchAdminCustomer360") {
    return searchAdminCustomer360(data, context);
  }
  if (action === "updateHelpdeskTicket") {
    return updateHelpdeskTicketAction(data, context);
  }
  if (action === "getAdminPartnerManagement") {
    await requireAdmin(context);
    return loadAdminPartnerManagement();
  }
  const limit = Math.max(1, Math.min(500, Number(data && data.limit) || 250));
  const [ordersSnapshot, careSnapshot] = await Promise.all([
    db.collection("orders").orderBy("orderDate", "desc").limit(limit * 2).get(),
    db.collection("garment_care_orders").orderBy("createdAt", "desc").limit(limit).get(),
  ]);
  const orders = ordersSnapshot.docs.map((snapshot) =>
    orderSummary(snapshot, classifyOrder(snapshot.data() || {})));
  const careOrders = careSnapshot.docs.map((snapshot) =>
    orderSummary(snapshot, "garment_care"));
  const response = {orders: [...orders, ...careOrders]
    .sort((a, b) => millis(b.createdAt) - millis(a.createdAt))
    .slice(0, limit)};
  if (actor.role === "admin" && data && data.includeAdminOverview === true) {
    response.adminOverview = await loadAdminHelpdeskOverview();
  }
  return response;
    });

exports.getHelpdeskOrderDetails = functions.https.onCall(async (data, context) => {
  await requireHelpdesk(context);
  const orderId = String(data && data.orderId || "").trim();
  const orderType = String(data && data.orderType || "").trim();
  if (!orderId || !["tailoring", "measurements", "quick_care", "garment_care", "other"].includes(orderType)) {
    fail("invalid-argument", "Choose a valid order and service type.");
  }

  if (orderType === "garment_care") {
    const orderRef = db.collection("garment_care_orders").doc(orderId);
    const orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) fail("not-found", "Garment Care order not found.");
    const [items, groups, events, jobs, shipments, invoices, custody] = await Promise.all([
      orderRef.collection("items").get(),
      orderRef.collection("delivery_groups").get(),
      orderRef.collection("events").orderBy("occurredAt", "desc").limit(100).get(),
      db.collection("garment_care_service_jobs").where("orderId", "==", orderId).get(),
      db.collection("garment_care_shipments").where("orderId", "==", orderId).get(),
      db.collection("garment_care_invoices").where("orderId", "==", orderId).get(),
      db.collection("garment_care_custody_events").where("orderId", "==", orderId).get(),
    ]);
    const customer = await loadCustomerDetails(orderSnapshot.data() || {});
    return {
      orderType,
      order: docData(orderSnapshot),
      customer,
      items: items.docs.map(docData),
      deliveryGroups: groups.docs.map(docData),
      serviceJobs: jobs.docs.map(docData),
      shipments: shipments.docs.map(docData),
      invoices: invoices.docs.map(docData),
      custodyEvents: custody.docs.map(docData),
      events: events.docs.map(docData),
      canCancel: false,
      cancelReason: "Garment Care cancellation must be reviewed against its service jobs, custody and payment records.",
    };
  }

  const orderRef = db.collection("orders").doc(orderId);
  const orderSnapshot = await orderRef.get();
  if (!orderSnapshot.exists) fail("not-found", "Order not found.");
  const order = orderSnapshot.data() || {};
  const actualType = classifyOrder(order);
  if (actualType !== orderType) fail("failed-precondition", "This order belongs to a different service.");
  const [events, assignmentState] = await Promise.all([
    orderRef.collection("events").orderBy("occurredAt", "desc").limit(100).get(),
    db.collection("order_assignment_state").doc(orderId).get(),
  ]);
  const customer = await loadCustomerDetails(order);
  const orderData = docData(orderSnapshot);
  if (orderType === "quick_care") {
    const serviceIds = Array.isArray(order.quickFixServiceIds)
      ? order.quickFixServiceIds.map((value) => String(value).toLowerCase())
      : [];
    const serviceDescription = [order.quickCareTitle, order.title, order.serviceName, order.dressType]
        .filter(Boolean).join(" ").toLowerCase();
    const keepPermanently = serviceIds.includes("wardrobe") ||
      serviceDescription.includes("wardrobe");
    orderData.quickCareEvidence = await signedQuickCareEvidence(
      orderId,
      order.quickCareEvidence,
      keepPermanently,
    );
  }
  const cancellation = orderType === "quick_care"
    ? quickCareCancellation(order)
    : {allowed: false, reason: "Tailoring order cancellation must be reviewed against its assignment and payment state."};
  return {
    orderType,
    order: orderData,
    customer,
    events: events.docs.map(docData),
    assignmentState: docData(assignmentState),
    canCancel: cancellation.allowed,
    cancelReason: cancellation.reason,
  };
});

exports.cancelHelpdeskQuickCareOrder = functions.https.onCall(async (data, context) => {
  const actor = await requireHelpdesk(context);
  const orderId = String(data && data.orderId || "").trim();
  if (!orderId) fail("invalid-argument", "Choose a Quick Care order.");
  const orderRef = db.collection("orders").doc(orderId);
  const assignmentRef = db.collection("order_assignment_state").doc(orderId);
  const refundTicketRef = db.collection("support_tickets").doc();
  let refundDue = 0;
  await db.runTransaction(async (transaction) => {
    const [snapshot, assignmentSnapshot] = await Promise.all([
      transaction.get(orderRef),
      transaction.get(assignmentRef),
    ]);
    if (!snapshot.exists) fail("not-found", "Quick Care booking not found.");
    const order = snapshot.data() || {};
    if (order.orderModuleType !== "quickFix") {
      fail("failed-precondition", "This action is only for Quick Care bookings.");
    }
    const cancellation = quickCareCancellation(order);
    if (!cancellation.allowed) fail("failed-precondition", cancellation.reason);
    const cancellationTicketId = String(order.quickCareCancellationRequestTicketId || "").trim();
    const cancellationTicketRef = cancellationTicketId
      ? db.collection("support_tickets").doc(cancellationTicketId)
      : null;
    const cancellationTicketSnapshot = cancellationTicketRef
      ? await transaction.get(cancellationTicketRef)
      : null;
    refundDue = Math.max(0, Number(order.amountPaid || 0));
    if (order.paymentStatus === "fullyPaid") {
      refundDue = Math.max(refundDue, Number(order.price || order.totalAmount || 0));
    }
    transaction.update(orderRef, {
      status: "cancelled",
      quickCareWorkflowStatus: "cancelled",
      quickCareAssignmentStatus: "cancelled",
      quickCareCancellationFeeAmount: 0,
      quickCareCancellationFeePercent: 0,
      cancellationFeeAmount: 0,
      cancellationFeePercent: 0,
      cancellationRefundDue: refundDue,
      ...(refundDue > 0 ? {quickCareRefundStatus: "pending_helpdesk_review"} : {}),
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: "helpdesk",
      helpdeskCancellationByUid: actor.uid,
      quickCareCancellationRequestStatus: "approved",
      quickCareCancellationRequestResolvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (assignmentSnapshot.exists) {
      transaction.update(assignmentRef, {
        status: "cancelled",
        currentOfferId: null,
        activeCandidate: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    if (cancellationTicketSnapshot && cancellationTicketSnapshot.exists) {
      const ticket = cancellationTicketSnapshot.data() || {};
      const wasClosed = ["Resolved", "Closed"].includes(String(ticket.status || ""));
      transaction.update(cancellationTicketRef, {
        status: "Resolved",
        response: "Quick Care booking cancelled with no cancellation fee.",
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastUpdatedByUid: actor.uid,
        lastUpdatedByRole: actor.role,
        ...(!wasClosed ? {
          lastClosedByUid: actor.uid,
          lastClosedByRole: actor.role,
          lastClosedAt: FieldValue.serverTimestamp(),
        } : {}),
      });
      if (!wasClosed) {
        transaction.set(db.collection("support_ticket_activity").doc(), {
          ticketId: cancellationTicketId,
          customerUid: String(ticket.customerUid || order.customerId || ""),
          action: "closed",
          oldStatus: String(ticket.status || "Open"),
          newStatus: "Resolved",
          assignedTeam: String(ticket.assignedTeam || "quick_care"),
          actorUid: actor.uid,
          actorRole: actor.role,
          createdAt: admin.firestore.Timestamp.now(),
        });
      }
    }
    transaction.set(orderRef.collection("events").doc(), {
      type: "helpdesk_cancelled_quick_care_order",
      actorType: "helpdesk",
      actorUid: actor.uid,
      noCancellationFee: true,
      refundDue,
      occurredAt: FieldValue.serverTimestamp(),
    });
    if (refundDue > 0) {
      transaction.set(refundTicketRef, {
        customerUid: order.customerId,
        customerName: String(order.customerName || order.customerDisplayName || "Customer"),
        category: "Quick Care Issue",
        subject: "Quick Care cancellation refund review",
        message: `Helpdesk cancelled the booking more than two hours before the appointment with no cancellation fee. Please review the ₹${refundDue.toFixed(0)} refund.`,
        linkedOrderId: orderId,
        linkedOrderType: "quick_care",
        assignedTeam: "payments",
        status: "Open",
        source: "customer_helpdesk",
        languageCode: "en",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  return {status: "cancelled", noCancellationFee: true, refundDue};
});
