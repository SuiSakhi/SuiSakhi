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
  return {
    orderId: snapshot.id,
    orderType,
    orderNumber: data.orderNumber || data.orderTrackingId || snapshot.id,
    customerName: data.customerName || data.customerDisplayName || data.customerNameSnapshot || "Customer",
    customerUid: data.customerUid || data.customerId || "",
    status: isQuickCare
      ? data.quickCareWorkflowStatus || data.status || "Unknown"
      : data.status || data.orderStatus || "Unknown",
    assignmentStatus: isQuickCare ? data.quickCareAssignmentStatus || "searching" : null,
    workflowStatus: isQuickCare ? data.quickCareWorkflowStatus || "requestSubmitted" : null,
    paymentStatus: data.paymentStatus || "",
    servicePincode: orderServicePincode(data),
    total: Number(data.totalAmount || data.price || data.grandTotal || 0),
    createdAt: clean(timestamp),
    summary: data.orderModuleType === "quickFix"
      ? (data.quickCareTitle || data.title || data.serviceName || data.dressType || "Quick Care booking")
      : (data.orderTitle || data.garmentCareTitle || data.title || "Order"),
  };
}

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

exports.listHelpdeskOrders = functions.https.onCall(async (data, context) => {
  await requireHelpdesk(context);
  const limit = Math.max(1, Math.min(500, Number(data && data.limit) || 250));
  const [ordersSnapshot, careSnapshot] = await Promise.all([
    db.collection("orders").orderBy("orderDate", "desc").limit(limit * 2).get(),
    db.collection("garment_care_orders").orderBy("createdAt", "desc").limit(limit).get(),
  ]);
  const orders = ordersSnapshot.docs.map((snapshot) =>
    orderSummary(snapshot, classifyOrder(snapshot.data() || {})));
  const careOrders = careSnapshot.docs.map((snapshot) =>
    orderSummary(snapshot, "garment_care"));
  return {orders: [...orders, ...careOrders]
    .sort((a, b) => millis(b.createdAt) - millis(a.createdAt))
    .slice(0, limit)};
});

exports.getHelpdeskOrderDetails = functions.https.onCall(async (data, context) => {
  await requireHelpdesk(context);
  const orderId = String(data && data.orderId || "").trim();
  const orderType = String(data && data.orderType || "").trim();
  if (!orderId || !["tailoring", "quick_care", "garment_care", "other"].includes(orderType)) {
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
      transaction.update(cancellationTicketRef, {
        status: "Resolved",
        response: "Quick Care booking cancelled with no cancellation fee.",
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
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
