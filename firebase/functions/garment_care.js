const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const SERVER_TIMESTAMP = admin.firestore.FieldValue.serverTimestamp;

const SERVICES = {
  wash_fold: "Wash and Fold",
  wash_iron: "Wash and Iron",
  premium_wet_cleaning: "Premium / Wet Cleaning",
  dry_cleaning: "Dry Cleaning",
  antibacterial_wash: "Antiseptic / Antibacterial Wash",
  steam_ironing: "Steam Ironing",
  roll_pressing: "Roll Pressing",
  form_pressing: "Form / Dummy Pressing",
  advanced_stain_removal: "Advanced Stain Removal / Spotting",
  fabric_starching: "Fabric Starching",
  saree_polishing: "Saree Polishing",
  fabric_conditioning: "Fabric Conditioning and Softening",
  couture_care: "Couture and Designer Wear Care",
  bridal_care: "Bridal and Wedding Wear Care",
  embellishment_protection: "Embroidery / Zari / Zardozi Protection",
  leather_suede_fur_care: "Leather, Suede, and Fur Care",
  curtains_draperies: "Curtains and Draperies",
  blankets_duvets: "Blankets and Duvets",
  sofa_covers: "Sofa Covers",
  rugs_carpets: "Rugs and Carpets",
  sneakers_care: "Sneakers and Athletic Shoes",
  leather_shoes_care: "Leather Shoes and Boots",
  handbags_care: "Handbags and Designer Purses",
  backpacks_care: "Backpacks",
};
const SERVICE_GROUPS = {
  wash_fold: "washing_cleaning",
  wash_iron: "washing_cleaning",
  premium_wet_cleaning: "washing_cleaning",
  dry_cleaning: "washing_cleaning",
  antibacterial_wash: "washing_cleaning",
  steam_ironing: "pressing_finishing",
  roll_pressing: "pressing_finishing",
  form_pressing: "pressing_finishing",
  advanced_stain_removal: "special_treatments",
  fabric_starching: "special_treatments",
  saree_polishing: "special_treatments",
  fabric_conditioning: "special_treatments",
  couture_care: "designer_luxury",
  bridal_care: "designer_luxury",
  embellishment_protection: "designer_luxury",
  leather_suede_fur_care: "designer_luxury",
  curtains_draperies: "home_textile",
  blankets_duvets: "home_textile",
  sofa_covers: "home_textile",
  rugs_carpets: "home_textile",
  sneakers_care: "shoes_accessories",
  leather_shoes_care: "shoes_accessories",
  handbags_care: "shoes_accessories",
  backpacks_care: "shoes_accessories",
};
const HYGIENE_TREATMENT_SERVICE_IDS = new Set([
  "wash_fold",
  "wash_iron",
  "premium_wet_cleaning",
]);
// The first character identifies the service group; the three digits identify
// one accepted physical garment within its parent order. Multiple service
// jobs for the same garment share its sub-order number.
const SUB_ORDER_PREFIX_BY_GROUP = {
  washing_cleaning: "L",
  pressing_finishing: "I",
  special_treatments: "S",
  designer_luxury: "D",
  home_textile: "H",
  shoes_accessories: "A",
};
const INSPECTION_PHASE_GROUPS = new Set([
  "washing_cleaning", "pressing_finishing", "special_treatments", "designer_luxury",
]);
function defaultInspectionTemplates() {
  const templates = {};
  for (const [serviceId, serviceName] of Object.entries(SERVICES)) {
    const group = SERVICE_GROUPS[serviceId];
    templates[serviceId] = {
      allGood: "Your {service} inspection is complete. The garment is suitable for the selected service. We’ll proceed as requested. {note}",
      issueFound: "During the {service} inspection, we found: {observations}. Condition: {condition}. Recommended next step: {action}. {priceImpact} {note} We’ll only make changes you approve.",
    };
    if (group === "home_textile" || group === "shoes_accessories") {
      templates[serviceId].allGood = `Your ${serviceName} inspection is complete. The garment is suitable for the selected service. We’ll proceed as requested. {note}`;
    }
  }
  return templates;
}
function defaultGarmentCareCompletionTemplates() {
  return [
    {
      id: "starter_wash_iron", name: "Wash and iron · care label followed",
      serviceIds: ["wash_iron"], materialKeywords: [],
      methodUsed: "Wash and iron as permitted by the care label",
      processDetails: "Checked the care label and inspection notes. Used a suitable wash cycle and detergent for this garment.",
      finishingDetails: "Dried and pressed using settings permitted by the care label.",
      qualityNotes: "Checked cleanliness, seams, buttons and overall finish.", isBuiltIn: true,
    },
    {
      id: "starter_wash_fold", name: "Wash and fold · care label followed",
      serviceIds: ["wash_fold"], materialKeywords: [],
      methodUsed: "Wash and fold as permitted by the care label",
      processDetails: "Checked the care label and inspection notes. Used a suitable wash cycle and detergent for this garment.",
      finishingDetails: "Dried and folded or reshaped as suitable for the garment and care label.",
      qualityNotes: "Checked cleanliness, seams, buttons and that all accepted items are accounted for.", isBuiltIn: true,
    },
    {
      id: "starter_pressing", name: "Ironing and pressing · label checked",
      serviceIds: ["steam_ironing", "roll_pressing", "form_pressing"], materialKeywords: [],
      methodUsed: "Ironing or pressing as permitted by the care label",
      processDetails: "Checked the care label and fabric before pressing. Used a suitable heat and steam setting for this garment.",
      finishingDetails: "Finished seams and edges using a suitable pressing method.",
      qualityNotes: "Checked shape, surface and finish for shine marks or pressing damage.", isBuiltIn: true,
    },
    {
      id: "starter_dry_cleaning", name: "Dry cleaning · approved process",
      serviceIds: ["dry_cleaning", "premium_wet_cleaning"], materialKeywords: [],
      methodUsed: "Professional cleaning process approved for this garment",
      processDetails: "Checked the care label, inspection notes and approved service before cleaning.",
      finishingDetails: "Finished and presented the garment using a suitable professional method.",
      qualityNotes: "Checked appearance, seams, trims and overall finish.", isBuiltIn: true,
    },
    {
      id: "starter_delicate", name: "Delicate garment · gentle process",
      serviceIds: [], materialKeywords: ["silk", "wool", "cashmere", "delicate", "embellish"],
      methodUsed: "Gentle care process approved for this garment",
      processDetails: "Checked the care label, fabric and inspection findings. Used a gentle process suitable for the approved service.",
      finishingDetails: "Reshaped and dried or finished as suitable for the fabric and care label.",
      qualityNotes: "Checked fabric integrity, trims, seams and finish.", isBuiltIn: true,
    },
    {
      id: "starter_cotton_linen", name: "Cotton or linen · care label followed",
      serviceIds: ["wash_fold", "wash_iron"], materialKeywords: ["cotton", "linen"],
      methodUsed: "Care-label-compliant cleaning for this cotton or linen item",
      processDetails: "Checked the care label and inspection notes. Selected the wash process and settings permitted for this garment.",
      finishingDetails: "Dried and pressed using a method and settings permitted by the care label.",
      qualityNotes: "Checked cleanliness, seams, shape and overall finish.", isBuiltIn: true,
    },
    {
      id: "starter_synthetic_blend", name: "Synthetic or blended fabric · label checked",
      serviceIds: ["wash_fold", "wash_iron", "steam_ironing"], materialKeywords: ["polyester", "nylon", "synthetic", "blend"],
      methodUsed: "Care-label-compliant care for this synthetic or blended item",
      processDetails: "Checked the care label and fabric. Selected a suitable process and settings permitted for this garment.",
      finishingDetails: "Finished using suitable settings permitted by the care label.",
      qualityNotes: "Checked shape, seams and surface for damage or unwanted shine.", isBuiltIn: true,
    },
  ];
}
function normalizeCompletionTemplate(raw, { id = "" } = {}) {
  const templateId = text(id || raw && raw.id, 128);
  const name = text(raw && raw.name, 80);
  const methodUsed = text(raw && raw.methodUsed, 240);
  const serviceIds = Array.isArray(raw && raw.serviceIds)
    ? [...new Set(raw.serviceIds.map((value) => text(value, 80)).filter((value) => value && SERVICES[value]))]
    : [];
  const materialKeywords = Array.isArray(raw && raw.materialKeywords)
    ? [...new Set(raw.materialKeywords.map((value) => text(value, 60).toLowerCase()).filter(Boolean))].slice(0, 20)
    : [];
  if (!templateId || !name || !methodUsed) {
    fail("invalid-argument", "Every completion template needs an ID, name and care method.");
  }
  return {
    id: templateId,
    name,
    serviceIds,
    materialKeywords,
    methodUsed,
    processDetails: text(raw && raw.processDetails, 800),
    finishingDetails: text(raw && raw.finishingDetails, 500),
    qualityNotes: text(raw && raw.qualityNotes, 500),
  };
}
function formatInspectionTemplate(template, values) {
  return text(template, 1600).replace(/\{([a-zA-Z]+)\}/g, (_match, key) =>
    Object.prototype.hasOwnProperty.call(values, key) ? text(values[key], 500) : "")
    .replace(/\s+/g, " ").trim();
}
const INSPECTION_LABELS = {
  conditions: {
    good: "Good",
    minor_wear: "Minor wear",
    existing_stain: "Existing stain",
    existing_damage: "Existing damage",
    colour_bleeding: "Possible colour transfer risk",
    fabric_weakness: "Fabric weakness",
  },
  observations: {
    no_visible_issues: "No visible issues",
    minor_stains: "Minor stains",
    existing_stain: "Existing stain",
    colour_bleeding: "Possible colour bleeding",
    loose_seam: "Loose seam",
    missing_button: "Missing button or fastener",
    existing_damage: "Existing damage",
    delicate_embellishment: "Delicate embellishment",
    missing_embellishment: "Missing embellishment",
    fabric_weakness: "Fabric weakness",
    other: "Other visible issue",
  },
  actions: {
    proceed_as_requested: "Proceed as requested",
    gentle_handling: "Use gentle handling",
    recommend_additional_treatment: "Recommend additional treatment",
    recommend_different_service: "Recommend a different service",
    hold_for_customer_approval: "Pause until the Customer decides",
  },
  priceImpact: {
    no_additional_charge: "There is no additional charge.",
    revised_quote_required: "A revised quote is included for your approval.",
  },
};
const GROUPS = new Set(Object.values(SERVICE_GROUPS));
const ITEM_TYPES_BY_GROUP = {
  washing_cleaning: ["saree", "blouse", "dress", "salwar_suit", "pants_jeans_skirt", "shorts", "shirt", "lehenga", "undergarment_bra", "slip_scarf", "pajamas", "bathrobe_gown", "handkerchief_stockings", "vest", "dupatta", "other"],
  pressing_finishing: ["saree", "blouse", "dress_blazer", "salwar_suit", "pants_skirt", "suit_two_piece", "lehenga_choli", "shorts", "scarf", "sweater", "coat_jacket", "overcoat", "petticoat_dupatta", "shirt", "other"],
  special_treatments: ["saree", "blouse", "dress", "salwar_suit", "lehenga", "fabric", "other"],
  designer_luxury: ["saree", "blouse", "dress", "lehenga", "bridal_wear", "suit", "leather", "rexine_faux_leather", "suede", "fur", "other"],
  home_textile: ["curtain", "blanket", "sofa_cover", "rug", "other"],
  shoes_accessories: ["sneakers", "shoes", "handbag", "backpack", "other"],
};
const REQUIRED_SERVICE_IDS = Object.keys(SERVICES);
const CARE_SERVICE_CAPABILITIES = {
  wash_fold: ["garmentCare.laundry"],
  wash_iron: ["garmentCare.laundry"],
  premium_wet_cleaning: ["garmentCare.dryCleaning"],
  dry_cleaning: ["garmentCare.dryCleaning"],
  antibacterial_wash: ["garmentCare.laundry"],
  steam_ironing: ["garmentCare.steamPressing"],
  roll_pressing: ["garmentCare.rollPress"],
  form_pressing: ["garmentCare.pressing"],
  advanced_stain_removal: ["garmentCare.stainRemoval"],
  fabric_starching: ["garmentCare.fabricCare"],
  saree_polishing: ["garmentCare.sareeCare"],
  fabric_conditioning: ["garmentCare.fabricCare"],
  couture_care: ["garmentCare.specialGarmentCare"],
  bridal_care: ["garmentCare.specialGarmentCare"],
  embellishment_protection: ["garmentCare.specialGarmentCare"],
  leather_suede_fur_care: ["garmentCare.specialGarmentCare"],
  curtains_draperies: ["garmentCare.homeTextileCare"],
  blankets_duvets: ["garmentCare.homeTextileCare"],
  sofa_covers: ["garmentCare.homeTextileCare"],
  rugs_carpets: ["garmentCare.homeTextileCare"],
  sneakers_care: ["garmentCare.footwearCare"],
  leather_shoes_care: ["garmentCare.footwearCare"],
  handbags_care: ["garmentCare.accessoriesCare"],
  backpacks_care: ["garmentCare.accessoriesCare"],
};
const JOB_TRANSITIONS = {
  offered: ["accepted", "rejected"],
  accepted: ["inspectionPending"],
  inspectionPending: [],
  readyToStart: ["inProgress"],
  inProgress: ["qualityCheck"],
  qualityCheck: ["inProgress", "completed"],
};

function text(value, max = 300) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}
function makeGarmentCareSubOrderNumber(groupCode, sequence) {
  const prefix = SUB_ORDER_PREFIX_BY_GROUP[groupCode] || "G";
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 999) {
    fail("resource-exhausted", "This order has reached its sub-order limit.");
  }
  return `${prefix}${String(sequence).padStart(3, "0")}`;
}
function garmentSubOrderShipmentFields(garmentId, subOrderNumber, displayName) {
  const id = text(garmentId, 128);
  const number = text(subOrderNumber, 8);
  const name = text(displayName, 120);
  return {
    ...(number ? { subOrderNumber: number } : {}),
    subOrderNumbersByGarmentId: id && number ? { [id]: number } : {},
    garmentDisplayNamesById: id && name ? { [id]: name } : {},
  };
}
function customerDeclinedGarmentsForPartner(jobDocs, accountId, profileId, excludedGarmentIds = []) {
  const excluded = new Set(excludedGarmentIds.map((id) => text(id, 128)).filter(Boolean));
  const byGarmentId = new Map();
  for (const job of jobDocs) {
    const garmentId = text(job.get("garmentId"), 128);
    if (!garmentId || excluded.has(garmentId) ||
        job.get("assignedPartnerAccountId") !== accountId ||
        job.get("assignedPartnerProfileId") !== profileId) continue;
    const jobs = byGarmentId.get(garmentId) || [];
    jobs.push(job);
    byGarmentId.set(garmentId, jobs);
  }
  const rejectedGarments = [];
  for (const [garmentId, partnerJobs] of byGarmentId.entries()) {
    const garmentJobs = jobDocs.filter((job) => text(job.get("garmentId"), 128) === garmentId);
    const customerDeclined = partnerJobs.some((job) =>
      job.get("status") === "blocked" &&
      /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800)));
    if (!customerDeclined || !garmentJobs.length ||
        !garmentJobs.every((job) => TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")))) continue;
    rejectedGarments.push({
      garmentId,
      subOrderNumber: text(partnerJobs[0].get("subOrderNumber"), 8),
      displayName: text(partnerJobs[0].get("displayName"), 120),
      returnShipmentId: text(
        partnerJobs.find((job) => text(job.get("returnWithShipmentId"), 128))?.get("returnWithShipmentId"),
        128,
      ),
    });
  }
  return rejectedGarments;
}
function hasCustomerDeclinedService(jobDocs) {
  return jobDocs.some((job) => job.get("status") === "blocked" &&
    /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800)));
}
function customerReturnGarmentFields(shipment, rejectedGarments) {
  const primaryGarmentId = text(shipment.get("garmentId"), 128);
  const existingIds = Array.isArray(shipment.get("garmentIds"))
    ? shipment.get("garmentIds").map((id) => text(id, 128)).filter(Boolean)
    : [];
  const garmentIds = [...new Set([
    ...existingIds,
    primaryGarmentId,
    ...rejectedGarments.map((item) => item.garmentId),
  ].filter(Boolean))];
  const subOrderNumbersByGarmentId = {
    ...(shipment.get("subOrderNumbersByGarmentId") || {}),
  };
  const garmentDisplayNamesById = {
    ...(shipment.get("garmentDisplayNamesById") || {}),
  };
  const declinedIds = new Set(Array.isArray(shipment.get("returnIncludesCustomerDeclinedGarmentIds"))
    ? shipment.get("returnIncludesCustomerDeclinedGarmentIds").map((id) => text(id, 128)).filter(Boolean)
    : []);
  for (const item of rejectedGarments) {
    if (item.subOrderNumber) subOrderNumbersByGarmentId[item.garmentId] = item.subOrderNumber;
    if (item.displayName) garmentDisplayNamesById[item.garmentId] = item.displayName;
    declinedIds.add(item.garmentId);
  }
  return {
    garmentIds,
    subOrderNumbersByGarmentId,
    garmentDisplayNamesById,
    returnIncludesCustomerDeclinedGarmentIds: [...declinedIds],
  };
}
const TERMINAL_GARMENT_CARE_JOB_STATUSES = new Set(["completed", "cancelled", "blocked"]);

function fail(code, message) {
  throw new functions.https.HttpsError(code, message);
}
async function readGarmentCareOrderPaymentState(tx, orderSnap, jobsSnap) {
  const jobs = jobsSnap.docs;
  const declinedGroupIds = new Set(jobs
    .filter((job) => job.get("status") === "blocked" &&
      /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800)))
    .map((job) => text(job.get("deliveryGroupId"), 128))
    .filter(Boolean));
  const requiredGroupIds = [...new Set(jobs
    .filter((job) => !["cancelled", "blocked"].includes(job.get("status")) &&
      !declinedGroupIds.has(text(job.get("deliveryGroupId"), 128)))
    .map((job) => text(job.get("deliveryGroupId"), 128))
    .filter(Boolean))];
  const allServicesComplete = jobs.length > 0 && jobs.every((job) =>
    TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")));
  if (!requiredGroupIds.length) {
    return {
      allServicesComplete,
      allPaymentsCaptured: allServicesComplete,
      anyPaymentCaptured: false,
      paymentByGroupId: new Map(),
      invoiceByGroupId: new Map(),
    };
  }
  const invoiceSnaps = await Promise.all(requiredGroupIds.map((groupId) =>
    tx.get(db.collection("garment_care_invoices").doc(groupId))));
  const paymentRefs = invoiceSnaps.map((invoice, index) =>
    db.collection("garment_care_payments").doc(
      invoice.exists
        ? text(invoice.get("paymentId"), 128) || `payment_${requiredGroupIds[index]}`
        : `payment_${requiredGroupIds[index]}`,
    ));
  const paymentSnaps = await Promise.all(paymentRefs.map((ref) => tx.get(ref)));
  const paymentByGroupId = new Map();
  const invoiceByGroupId = new Map();
  invoiceSnaps.forEach((invoice, index) => {
    const groupId = requiredGroupIds[index];
    const payment = paymentSnaps[index];
    invoiceByGroupId.set(groupId, invoice.exists);
    const total = invoice.exists ? Number(invoice.get("grandTotal")) : NaN;
    const paid = invoice.exists && invoice.get("orderId") === orderSnap.ref.id &&
      invoice.get("deliveryGroupId") === groupId &&
      invoice.get("customerUid") === orderSnap.get("customerUid") && payment.exists &&
      payment.get("invoiceId") === invoice.id &&
      payment.get("orderId") === orderSnap.ref.id &&
      payment.get("deliveryGroupId") === groupId &&
      payment.get("customerUid") === orderSnap.get("customerUid") &&
      payment.get("status") === "captured" && payment.get("providerVerifiedCapture") === true &&
      Number.isFinite(total) && Math.abs(Number(payment.get("capturedAmount")) - total) <= 0.01;
    paymentByGroupId.set(groupId, paid);
  });
  const values = [...paymentByGroupId.values()];
  return {
    allServicesComplete,
    allPaymentsCaptured: values.length > 0 && values.every(Boolean),
    anyPaymentCaptured: values.some(Boolean),
    paymentByGroupId,
    invoiceByGroupId,
  };
}
async function readRelatedGarmentPaymentRequirements(tx, orderId, orderData, garmentId) {
  const checkoutId = text(orderData && orderData.cartCheckoutId, 128);
  const garmentIds = new Set((Array.isArray(garmentId) ? garmentId : [garmentId])
    .map((id) => text(id, 128)).filter(Boolean));
  if (!checkoutId || !garmentIds.size) return { requirements: [], siblingOrders: [] };
  const checkout = await tx.get(db.collection("garment_care_checkouts").doc(checkoutId));
  if (!checkout.exists) return { requirements: [], siblingOrders: [] };
  const siblingOrderIds = [...new Set((checkout.get("orderIds") || [])
    .map((id) => text(id, 128)).filter((id) => id && id !== orderId))];
  if (!siblingOrderIds.length) return { requirements: [], siblingOrders: [] };
  const siblingOrders = await Promise.all(siblingOrderIds.map((id) =>
    tx.get(db.collection("garment_care_orders").doc(id))));
  const siblingJobs = await Promise.all(siblingOrderIds.map((id) =>
    tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", id))));
  const siblingOrderById = new Map(siblingOrders.filter((item) => item.exists &&
    text(item.get("cartCheckoutId"), 128) === checkoutId &&
    item.get("customerUid") === orderData.customerUid)
    .map((item) => [item.id, item]));
  const groups = new Map();
  for (const jobs of siblingJobs) {
    for (const job of jobs.docs) {
      if (!garmentIds.has(text(job.get("garmentId"), 128))) continue;
      const relatedOrderId = text(job.get("orderId"), 128);
      const deliveryGroupId = text(job.get("deliveryGroupId"), 128);
      if (!relatedOrderId || !deliveryGroupId) continue;
      const key = `${relatedOrderId}:${deliveryGroupId}`;
      if (!groups.has(key)) groups.set(key, { relatedOrderId, deliveryGroupId, jobs: [] });
      groups.get(key).jobs.push(job);
    }
  }
  if (!groups.size) return {
    requirements: [],
    siblingOrders: [...siblingOrderById.values()],
    siblingJobs,
  };
  const candidates = [...groups.values()].filter((candidate) =>
    siblingOrderById.has(candidate.relatedOrderId) &&
    candidate.jobs.some((job) => job.get("status") === "completed") &&
    candidate.jobs.every((job) => TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status"))) &&
    !hasCustomerDeclinedService(candidate.jobs));
  if (!candidates.length) return {
    requirements: [],
    siblingOrders: [...siblingOrderById.values()],
    siblingJobs,
  };
  const invoiceSnaps = await Promise.all(candidates.map((item) =>
    tx.get(db.collection("garment_care_invoices").doc(item.deliveryGroupId))));
  const paymentRefs = invoiceSnaps.map((invoice, index) => db.collection("garment_care_payments").doc(
    invoice.exists
      ? text(invoice.get("paymentId"), 128) || `payment_${candidates[index].deliveryGroupId}`
      : `payment_${candidates[index].deliveryGroupId}`,
  ));
  const paymentSnaps = await Promise.all(paymentRefs.map((ref) => tx.get(ref)));
  const requirements = candidates.map((candidate, index) => {
    const invoice = invoiceSnaps[index];
    const payment = paymentSnaps[index];
    const siblingOrder = siblingOrderById.get(candidate.relatedOrderId);
    const amount = invoice.exists ? Number(invoice.get("grandTotal")) : NaN;
    const paid = invoice.exists && payment.exists && siblingOrder &&
      invoice.get("orderId") === candidate.relatedOrderId &&
      invoice.get("deliveryGroupId") === candidate.deliveryGroupId &&
      invoice.get("customerUid") === orderData.customerUid &&
      payment.get("invoiceId") === invoice.id && payment.get("orderId") === candidate.relatedOrderId &&
      payment.get("deliveryGroupId") === candidate.deliveryGroupId &&
      payment.get("status") === "captured" && payment.get("providerVerifiedCapture") === true &&
      Number.isFinite(amount) && Math.abs(Number(payment.get("capturedAmount")) - amount) <= 0.01;
    return {
      orderId: candidate.relatedOrderId,
      orderNumber: siblingOrder ? text(siblingOrder.get("orderNumber"), 32) || null : null,
      deliveryGroupId: candidate.deliveryGroupId,
      invoiceId: invoice.exists ? invoice.id : candidate.deliveryGroupId,
      paymentId: paymentRefs[index].id,
      amount: Number.isFinite(amount) ? amount : null,
      currency: invoice.exists ? text(invoice.get("currency"), 8) || "INR" : "INR",
      status: paid ? "paid" : invoice.exists ? text(payment.get("status"), 40) || "requiresCustomerAction" : "invoice_pending",
    };
  });
  return { requirements, siblingOrders: [...siblingOrderById.values()], siblingJobs };
}
async function hasPendingCheckoutServiceJobs(tx, orderId, orderData, garmentIds) {
  const checkoutId = text(orderData && orderData.cartCheckoutId, 128);
  const garmentIdSet = new Set((Array.isArray(garmentIds) ? garmentIds : [])
    .map((id) => text(id, 128)).filter(Boolean));
  if (!checkoutId || !garmentIdSet.size) return false;
  const checkout = await tx.get(db.collection("garment_care_checkouts").doc(checkoutId));
  if (!checkout.exists) return false;
  const siblingOrderIds = [...new Set((checkout.get("orderIds") || [])
    .map((id) => text(id, 128)).filter((id) => id && id !== orderId))];
  if (!siblingOrderIds.length) return false;
  const siblingOrders = await Promise.all(siblingOrderIds.map((id) =>
    tx.get(db.collection("garment_care_orders").doc(id))));
  const validOrderIds = siblingOrderIds.filter((id, index) =>
    siblingOrders[index].exists &&
    text(siblingOrders[index].get("cartCheckoutId"), 128) === checkoutId &&
    siblingOrders[index].get("customerUid") === orderData.customerUid);
  if (!validOrderIds.length) return false;
  const siblingJobs = await Promise.all(validOrderIds.map((id) =>
    tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", id))));
  return siblingJobs.some((jobs) => jobs.docs.some((job) =>
    garmentIdSet.has(text(job.get("garmentId"), 128)) &&
    !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status"))));
}
async function areGarmentCareJobsReturned(tx, jobs, confirmingShipmentId = "") {
  const jobsByGarmentId = new Map();
  for (const job of jobs) {
    const garmentId = text(job.get("garmentId"), 128);
    if (!garmentId) continue;
    const garmentJobs = jobsByGarmentId.get(garmentId) || [];
    garmentJobs.push(job);
    jobsByGarmentId.set(garmentId, garmentJobs);
  }
  const shipmentIds = new Set();
  const garmentShipmentIds = new Map();
  for (const [garmentId, garmentJobs] of jobsByGarmentId.entries()) {
    if (garmentJobs.every((job) => text(job.get("pickupRejectionCode"), 80))) continue;
    const linkedIds = garmentJobs.map((job) => text(job.get("returnWithShipmentId"), 128));
    if (linkedIds.some((id) => !id) || new Set(linkedIds).size !== 1) return false;
    garmentShipmentIds.set(garmentId, linkedIds[0]);
    if (linkedIds[0] !== confirmingShipmentId) shipmentIds.add(linkedIds[0]);
  }
  const shipmentSnaps = await Promise.all([...shipmentIds].map((id) =>
    tx.get(db.collection("garment_care_shipments").doc(id))));
  const shipmentById = new Map(shipmentSnaps.map((shipment) => [shipment.id, shipment]));
  return [...garmentShipmentIds.values()].every((shipmentId) => {
    if (shipmentId === confirmingShipmentId) return true;
    const shipment = shipmentById.get(shipmentId);
    return Boolean(shipment && shipment.exists &&
      shipment.get("shipmentType") === "customer_return" &&
      shipment.get("status") === "delivered");
  });
}
async function readShipmentRelatedPaymentState(tx, shipment) {
  const requirements = Array.isArray(shipment.relatedPaymentRequirements)
    ? shipment.relatedPaymentRequirements : [];
  if (!requirements.length) return { allPaid: true, amountDue: 0, requirements: [] };
  const invoices = await Promise.all(requirements.map((item) =>
    tx.get(db.collection("garment_care_invoices").doc(text(item && item.invoiceId, 128) ||
      text(item && item.deliveryGroupId, 128)))));
  const payments = await Promise.all(requirements.map((item, index) => {
    const invoice = invoices[index];
    const paymentId = invoice.exists
      ? text(invoice.get("paymentId"), 128) || `payment_${text(item && item.deliveryGroupId, 128)}`
      : text(item && item.paymentId, 128) || `payment_${text(item && item.deliveryGroupId, 128)}`;
    return tx.get(db.collection("garment_care_payments").doc(paymentId));
  }));
  let allPaid = true;
  let amountDue = 0;
  const resolvedRequirements = requirements.map((item, index) => {
    const invoice = invoices[index];
    const payment = payments[index];
    const amount = invoice.exists ? Number(invoice.get("grandTotal")) : NaN;
    const paid = invoice.exists && payment.exists &&
      invoice.get("orderId") === text(item && item.orderId, 128) &&
      invoice.get("deliveryGroupId") === text(item && item.deliveryGroupId, 128) &&
      invoice.get("customerUid") === text(shipment.toCustomerUid, 128) &&
      payment.get("invoiceId") === invoice.id &&
      payment.get("orderId") === text(item && item.orderId, 128) &&
      payment.get("deliveryGroupId") === text(item && item.deliveryGroupId, 128) &&
      payment.get("customerUid") === text(shipment.toCustomerUid, 128) &&
      payment.get("status") === "captured" &&
      payment.get("providerVerifiedCapture") === true &&
      Number.isFinite(amount) && Math.abs(Number(payment.get("capturedAmount")) - amount) <= 0.01;
    if (!paid) {
      allPaid = false;
      if (Number.isFinite(amount) && amount > 0) amountDue += amount;
    }
    return {
      ...item,
      invoiceId: invoice.exists ? invoice.id : text(item && item.invoiceId, 128) || null,
      amount: Number.isFinite(amount) ? amount : item && Number.isFinite(Number(item.amount))
        ? Number(item.amount) : null,
      status: paid ? "paid" : invoice.exists
        ? payment.exists ? text(payment.get("status"), 40) || "requiresCustomerAction" : "requiresCustomerAction"
        : "invoice_pending",
    };
  });
  return { allPaid, amountDue: Math.round(amountDue * 100) / 100, requirements: resolvedRequirements };
}
async function synchronizeRelatedCustomerReturnPayments(deliveryGroupId) {
  if (!deliveryGroupId) return;
  const shipments = await db.collection("garment_care_shipments")
    .where("requiredPaymentGroupIds", "array-contains", deliveryGroupId)
    .get();
  for (const shipment of shipments.docs) {
    if (shipment.get("status") === "delivered") continue;
    try {
      await db.runTransaction(async (tx) => {
        const current = await tx.get(shipment.ref);
        if (!current.exists || current.get("status") === "delivered") return;
        const requiredIds = Array.isArray(current.get("requiredPaymentGroupIds"))
          ? current.get("requiredPaymentGroupIds").map((id) => text(id, 128)) : [];
        if (!requiredIds.includes(deliveryGroupId)) return;
        const [paymentState, orderSnap, jobsSnap] = await Promise.all([
          readShipmentRelatedPaymentState(tx, current.data() || {}),
          tx.get(db.collection("garment_care_orders").doc(text(current.get("orderId"), 128))),
          tx.get(db.collection("garment_care_service_jobs")
            .where("orderId", "==", text(current.get("orderId"), 128))),
        ]);
        const paymentStatusAtDelivery = paymentState.allPaid ? "paid" : "requiresCustomerAction";
        const ownPaymentState = orderSnap.exists
          ? await readGarmentCareOrderPaymentState(tx, orderSnap, jobsSnap)
          : null;
        const paymentActionRequired = !paymentState.allPaid ||
          (ownPaymentState && hasUnpaidIssuedInvoice(ownPaymentState));
        if (current.get("paymentStatusAtDelivery") !== paymentStatusAtDelivery) {
          tx.update(current.ref, {
            paymentStatusAtDelivery,
            ...(paymentState.allPaid ? { paymentReadyAt: SERVER_TIMESTAMP() } : {}),
            updatedAt: SERVER_TIMESTAMP(),
          });
        }
        if (orderSnap.exists && orderSnap.get("paymentActionRequired") !== paymentActionRequired) {
          tx.update(orderSnap.ref, {
            paymentActionRequired,
            updatedAt: SERVER_TIMESTAMP(),
          });
        }
      });
    } catch (error) {
      console.error(`Related Garment Care return payment reconciliation failed for ${shipment.id}`, error);
    }
  }
}
function garmentDnaInvoiceSnapshot(identity, job) {
  const data = identity && typeof identity.data === "function" ? identity.data() : identity || {};
  return {
    garmentId: text(job.get("garmentId"), 128),
    displayName: text(data.displayName || job.get("displayName"), 120),
    itemTypeCode: text(data.itemTypeCode || job.get("itemTypeCode"), 80),
    brand: text(data.brand, 120) || null,
    material: text(data.material || job.get("material"), 120) || null,
    colour: text(data.colour, 80) || null,
    pattern: text(data.pattern, 120) || null,
    careLabel: text(data.careLabel, 500) || null,
    dnaVersion: Number(data.dnaVersion) || 1,
  };
}
function inspectionInvoiceSnapshot(quote) {
  const observationCodes = Array.isArray(quote.observationCodes) ? quote.observationCodes : [];
  return {
    conditionCode: quote.conditionCode || null,
    condition: INSPECTION_LABELS.conditions[quote.conditionCode] || quote.conditionFindings || null,
    observationCodes,
    observations: observationCodes.map((code) => INSPECTION_LABELS.observations[code] || code),
    inspectionNotes: quote.inspectionNotes || null,
    conditionFindings: quote.conditionFindings || null,
    customerMessage: quote.customerMessage || null,
    evidencePaths: Array.isArray(quote.inspectionEvidencePaths) ? quote.inspectionEvidencePaths : [],
  };
}
function orderPaymentStatusFromState(paymentState, includeCurrentInvoice = false) {
  const paidGroups = [...paymentState.paymentByGroupId.values()].filter(Boolean).length;
  const hasInvoice = [...paymentState.invoiceByGroupId.values()].some(Boolean) || includeCurrentInvoice;
  if (hasInvoice && paymentState.allServicesComplete && paymentState.allPaymentsCaptured) return "paid";
  if (paymentState.anyPaymentCaptured || paidGroups > 0) return "partiallyPaid";
  return hasInvoice ? "requiresCustomerAction" : "not_due";
}
function hasUnpaidIssuedInvoice(paymentState, excludingGroupId = "") {
  return [...paymentState.invoiceByGroupId.entries()].some(([groupId, exists]) =>
    exists && groupId !== excludingGroupId && paymentState.paymentByGroupId.get(groupId) !== true);
}
async function reserveGarmentCareOrderNumbers(count) {
  if (!Number.isInteger(count) || count < 1) {
    fail("invalid-argument", "At least one Garment Care order number is required.");
  }
  const counterRef = db.collection("garment_care_order_number_counters").doc("global");
  let firstSequence = 0;
  await db.runTransaction(async (tx) => {
    const counter = await tx.get(counterRef);
    const lastSequence = Number(counter.get("lastSequence")) || 0;
    if (lastSequence + count > 999999) {
      fail("resource-exhausted", "The six-digit Garment Care order sequence is full.");
    }
    firstSequence = lastSequence + 1;
    tx.set(counterRef, {
      lastSequence: lastSequence + count,
      updatedAt: SERVER_TIMESTAMP(),
    }, { merge: true });
  });
  return Array.from({ length: count }, (_, index) => firstSequence + index);
}
function makeGarmentCareOrderNumber(pincode, sequence) {
  const pin = text(pincode, 10).replace(/\D/g, "");
  if (!/^\d{6}$/.test(pin)) {
    fail("failed-precondition", "Add a valid six-digit pickup PIN code to the saved address.");
  }
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 999999) {
    fail("resource-exhausted", "The six-digit Garment Care order sequence is unavailable.");
  }
  return `${pin}${String(sequence).padStart(6, "0")}`;
}
function roundCareMoney(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}
function careRateBreakdown(policy, rate, additionalServiceFee = 0) {
  const customerAmount = Number(rate && rate.customerAmount);
  const partnerAmount = Number(rate && rate.partnerAmount);
  const taxPercent = Number(policy && policy.taxPercent) || 0;
  const deliveryPercent = Number(policy && policy.deliveryPercent) || 0;
  const fixedFee = Number(additionalServiceFee) || 0;
  if (!Number.isFinite(customerAmount) || customerAmount < 0 ||
      !Number.isFinite(partnerAmount) || partnerAmount < 0) {
    fail("failed-precondition", "A Garment Care rate is missing a valid customer or Partner amount.");
  }
  if (Number(policy && policy.pricingModelVersion) >= 2) {
    const partnerTaxAmount = roundCareMoney(partnerAmount * taxPercent / 100);
    const extraFeeTaxAmount = roundCareMoney(fixedFee * taxPercent / 100);
    const taxAmount = roundCareMoney(partnerTaxAmount + extraFeeTaxAmount);
    const deliveryAmount = roundCareMoney(partnerAmount * deliveryPercent / 100);
    const serviceAmount = roundCareMoney(customerAmount - partnerTaxAmount - deliveryAmount + fixedFee);
    const partnerPayableAmount = roundCareMoney(partnerAmount + fixedFee);
    const platformCommissionAmount = roundCareMoney(serviceAmount - partnerPayableAmount);
    if (platformCommissionAmount < -0.01) {
      fail("failed-precondition", "This rate is below the Partner, tax, and delivery cost.");
    }
    return {
      serviceAmount,
      taxAmount,
      deliveryAmount,
      partnerPayableAmount,
      platformCommissionAmount: Math.max(0, platformCommissionAmount),
      customerTotal: roundCareMoney(serviceAmount + taxAmount + deliveryAmount),
    };
  }
  const serviceAmount = roundCareMoney(customerAmount + fixedFee);
  const partnerPayableAmount = roundCareMoney(partnerAmount + fixedFee);
  const taxAmount = roundCareMoney(serviceAmount * taxPercent / 100);
  return {
    serviceAmount,
    taxAmount,
    deliveryAmount: 0,
    partnerPayableAmount,
    platformCommissionAmount: roundCareMoney(serviceAmount - partnerPayableAmount),
    customerTotal: roundCareMoney(serviceAmount + taxAmount),
  };
}
function estimateCareRates(policy, rates, fixedLogisticsAmount = 0) {
  const estimate = { serviceSubtotal: 0, taxTotal: 0, logisticsTotal: Number(fixedLogisticsAmount) || 0 };
  for (const rate of rates) {
    const parts = careRateBreakdown(policy, rate);
    estimate.serviceSubtotal += parts.serviceAmount;
    estimate.taxTotal += parts.taxAmount;
    estimate.logisticsTotal += parts.deliveryAmount;
  }
  estimate.serviceSubtotal = roundCareMoney(estimate.serviceSubtotal);
  estimate.taxTotal = roundCareMoney(estimate.taxTotal);
  estimate.logisticsTotal = roundCareMoney(estimate.logisticsTotal);
  estimate.grandTotal = roundCareMoney(estimate.serviceSubtotal + estimate.taxTotal + estimate.logisticsTotal);
  return estimate;
}
function requireAuth(context) {
  if (!context.auth) fail("unauthenticated", "Sign in required.");
  return context.auth;
}
async function requireCustomer(context, accountId, profileId) {
  const auth = requireAuth(context);
  if (!accountId || !profileId) fail("invalid-argument", "Customer profile is required.");
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnap, profileSnap] = await Promise.all([accountRef.get(), profileRef.get()]);
  const account = accountSnap.data() || {};
  const profile = profileSnap.data() || {};
  if (!accountSnap.exists || account.mobileE164 !== auth.token.phone_number ||
      !profileSnap.exists || profile.role !== "customer" || profile.status !== "active") {
    fail("permission-denied", "Use an active Customer profile owned by your account.");
  }
  return auth;
}
async function requirePartner(context, accountId, profileId) {
  const auth = requireAuth(context);
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnap, profileSnap] = await Promise.all([accountRef.get(), profileRef.get()]);
  const profile = profileSnap.data() || {};
  if (!accountSnap.exists || accountSnap.get("mobileE164") !== auth.token.phone_number ||
      !profileSnap.exists || profile.role !== "partner" || profile.partnerType !== "garmentCare" ||
      profile.status !== "active" || profile.operationalStatus !== "active" ||
      profile.activationStatus !== "active" || profile.approvalStatus !== "approved" ||
      profile.kycStatus !== "verified") {
    fail("permission-denied", "An active, approved Garment Care Partner profile is required.");
  }
  return { auth, profileRef };
}
async function requireGarmentCareDeliveryPartner(context, accountId, profileId) {
  const auth = requireAuth(context);
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnap, profileSnap] = await Promise.all([accountRef.get(), profileRef.get()]);
  const profile = profileSnap.data() || {};
  if (!accountId || !profileId || !accountSnap.exists ||
      accountSnap.get("mobileE164") !== auth.token.phone_number || !profileSnap.exists ||
      profile.role !== "partner" || !["garmentCare", "deliveryPartner"].includes(profile.partnerType) ||
      profile.status !== "active" || profile.operationalStatus !== "active" ||
      profile.activationStatus !== "active" || profile.approvalStatus !== "approved" ||
      profile.kycStatus !== "verified") {
    const partnerLabel = profile.partnerType === "deliveryPartner"
      ? "Delivery Partner" : "Garment Care Partner";
    fail("permission-denied", `An active, approved ${partnerLabel} profile is required for this delivery.`);
  }
  return { auth, profileRef, profile, partnerType: profile.partnerType };
}
async function requireAdmin(context) {
  const auth = requireAuth(context);
  const adminSnap = await db.collection("config").doc("admin").get();
  if (!(adminSnap.get("adminUids") || []).includes(auth.uid)) {
    fail("permission-denied", "Admin access is required.");
  }
  return auth;
}
function declaredCareCapabilities(profile) {
  const partnerData = profile && profile.partnerData && typeof profile.partnerData === "object"
    ? profile.partnerData : {};
  const extensions = partnerData.extensions && typeof partnerData.extensions === "object"
    ? partnerData.extensions : {};
  const care = extensions.garmentCare && typeof extensions.garmentCare === "object"
    ? extensions.garmentCare : {};
  const capabilities = care.capabilities && typeof care.capabilities === "object"
    ? care.capabilities : {};
  return Array.isArray(capabilities.declaredCapabilityCodes)
    ? capabilities.declaredCapabilityCodes.map((code) => text(code, 120)).filter(Boolean)
    : [];
}
function garmentCareOperational(profile) {
  const partnerData = profile && profile.partnerData && typeof profile.partnerData === "object"
    ? profile.partnerData : {};
  const extensions = partnerData.extensions && typeof partnerData.extensions === "object"
    ? partnerData.extensions : {};
  const care = extensions.garmentCare && typeof extensions.garmentCare === "object"
    ? extensions.garmentCare : {};
  return care.operational && typeof care.operational === "object" ? care.operational : {};
}
function garmentCarePartnerContactPhone(profile, fallback = "") {
  const data = profile && typeof profile === "object" ? profile : {};
  const partnerData = data.partnerData && typeof data.partnerData === "object"
    ? data.partnerData : {};
  return text(data.contactPhone || data.mobileE164 || data.mobileNumber || data.phone ||
    partnerData.contactPhone || fallback, 32);
}
function garmentCarePartnerName(profile, fallback = "") {
  const data = profile && typeof profile === "object" ? profile : {};
  const partnerData = data.partnerData && typeof data.partnerData === "object"
    ? data.partnerData : {};
  return text(data.businessName || data.shopName || data.displayName || data.name ||
    partnerData.businessName || fallback || "Garment Care Partner", 120);
}
function isGarmentCareAvailable(profile) {
  return garmentCareOperational(profile).availableForOrders !== false;
}
function normalizedGarmentCarePincode(value) {
  const pin = text(value, 16).replace(/\D/g, "");
  return /^\d{6}$/.test(pin) ? pin : "";
}
function garmentCareDeliveryPincodes(profile) {
  const data = profile && typeof profile === "object" ? profile : {};
  const partnerData = data.partnerData && typeof data.partnerData === "object"
    ? data.partnerData : {};
  const extensions = partnerData.extensions && typeof partnerData.extensions === "object"
    ? partnerData.extensions : {};
  const category = extensions[text(data.partnerType, 48)] &&
      typeof extensions[text(data.partnerType, 48)] === "object"
    ? extensions[text(data.partnerType, 48)] : {};
  const serviceLocation = category.serviceLocation && typeof category.serviceLocation === "object"
    ? category.serviceLocation : {};
  const serviceAddress = serviceLocation.address && typeof serviceLocation.address === "object"
    ? serviceLocation.address : {};
  const workshop = category.workshopDetails && typeof category.workshopDetails === "object"
    ? category.workshopDetails
    : partnerData.workshopDetails && typeof partnerData.workshopDetails === "object"
      ? partnerData.workshopDetails : {};
  const addresses = [
    data,
    partnerData,
    category,
    workshop,
    workshop.businessAddress,
    workshop.address,
    serviceLocation,
    serviceAddress,
    category.businessAddress,
    category.address,
    partnerData.businessAddress,
    partnerData.address,
    data.businessAddress,
    data.address,
  ].filter((value) => value && typeof value === "object" && !Array.isArray(value));
  const rawServiceAreas = [
    workshop.serviceAreaPincodes,
    category.serviceAreaPincodes,
    serviceLocation.serviceAreaPincodes,
    partnerData.serviceAreaPincodes,
    data.serviceAreaPincodes,
    workshop.serviceArea,
    category.serviceArea,
    serviceLocation.serviceArea,
    data.serviceArea,
    partnerData.serviceArea,
  ];
  const pins = new Set();
  const collectPins = (value) => {
    if (typeof value === "string" || typeof value === "number") {
      const candidates = String(value).match(/\d{6}/g) || [];
      for (const candidate of candidates) pins.add(candidate);
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) collectPins(item);
      return;
    }
    if (value && typeof value === "object") {
      for (const [key, nested] of Object.entries(value)) {
        const keyPins = key.match(/\d{6}/g) || [];
        for (const candidate of keyPins) pins.add(candidate);
        collectPins(nested);
      }
    }
  };
  for (const value of rawServiceAreas) collectPins(value);
  for (const address of addresses) {
    for (const key of ["pincode", "pinCode", "postalCode", "postal_code", "zip", "zipCode"]) {
      collectPins(address[key]);
    }
  }
  return [...pins];
}
function deliveryPartnerCoversGarmentCarePincode(profile, pincode) {
  const requestedPin = normalizedGarmentCarePincode(pincode);
  return !!requestedPin && garmentCareDeliveryPincodes(profile).includes(requestedPin);
}
function parseClock(value) {
  const match = /^(?:[01]\d|2[0-3]):[0-5]\d$/.exec(text(value, 5));
  if (!match) return null;
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}
function partnerCoversPickupWindow(profile, slot) {
  const settings = garmentCareOperational(profile);
  const open = parseClock(settings.openAt);
  const close = parseClock(settings.closeAt);
  if (open === null || close === null) return true;
  const range = slot === "9:00 AM–1:00 PM" ? [540, 780]
    : slot === "4:00 PM–8:00 PM" ? [960, 1200] : null;
  return !!range && open <= range[0] && close >= range[1];
}

function isGarmentCareWithinWorkingHours(profile, now = new Date()) {
  if (!isGarmentCareAvailable(profile)) return false;
  const settings = garmentCareOperational(profile);
  const open = parseClock(settings.openAt || "09:00");
  const close = parseClock(settings.closeAt || "20:00");
  if (open === null || close === null || close <= open) return false;
  const timeZone = text(settings.timezone, 80) || "Asia/Kolkata";
  try {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(now);
    const hour = Number(parts.find((part) => part.type === "hour")?.value);
    const minute = Number(parts.find((part) => part.type === "minute")?.value);
    const current = hour * 60 + minute;
    return current >= open && current < close;
  } catch (_) {
    return false;
  }
}

function isPickupWindowPending(shipment, now = new Date()) {
  const preferredAt = shipment && shipment.preferredPickupAt;
  if (!preferredAt || typeof preferredAt.toDate !== "function") return true;
  const timeZone = "Asia/Kolkata";
  const partsFor = (date) => Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date).map((part) => [part.type, part.value]));
  try {
    const scheduled = partsFor(preferredAt.toDate());
    const current = partsFor(now);
    const scheduledDay = `${scheduled.year}-${scheduled.month}-${scheduled.day}`;
    const currentDay = `${current.year}-${current.month}-${current.day}`;
    if (scheduledDay > currentDay) return true;
    if (scheduledDay < currentDay) return false;
    const slot = text(shipment.pickupSlot, 40);
    const endMinutes = slot === "9:00 AM–1:00 PM" ? 780
      : slot === "4:00 PM–8:00 PM" ? 1200 : null;
    if (endMinutes === null) return false;
    return Number(current.hour) * 60 + Number(current.minute) < endMinutes;
  } catch (_) {
    return false;
  }
}

function isApprovedGarmentCarePartner(profile) {
  return profile && profile.role === "partner" && profile.partnerType === "garmentCare" &&
    profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified";
}

function hasCareCapability(profile, capability) {
  return declaredCareCapabilities(profile).includes(capability);
}

function hasCareServiceCapability(profile, serviceId) {
  const required = CARE_SERVICE_CAPABILITIES[serviceId] || [];
  return required.some((capability) => hasCareCapability(profile, capability));
}

async function automaticGarmentCarePartners(now = new Date()) {
  const snapshot = await db.collectionGroup("profiles")
    .where("role", "==", "partner")
    .where("partnerType", "==", "garmentCare")
    .where("status", "==", "active")
    .where("operationalStatus", "==", "active")
    .where("activationStatus", "==", "active")
    .where("approvalStatus", "==", "approved")
    .where("kycStatus", "==", "verified")
    .get();
  return snapshot.docs.map((doc) => ({
    accountId: doc.ref.parent.parent.id,
    profileId: doc.id,
    profile: doc.data(),
    name: text(doc.get("businessName") || doc.get("displayName") || "Garment Care Partner", 120),
    contactPhone: garmentCarePartnerContactPhone(doc.data()),
    priority: Number(garmentCareOperational(doc.data()).adminPriority) || 0,
  }))
    .filter((partner) => isApprovedGarmentCarePartner(partner.profile) &&
      isGarmentCareWithinWorkingHours(partner.profile, now))
    .sort((a, b) => b.priority - a.priority || a.name.localeCompare(b.name));
}

async function autoAssignGarmentCarePickup(shipmentRef, partner, now) {
  const profileRef = db.collection("accounts").doc(partner.accountId)
    .collection("profiles").doc(partner.profileId);
  return db.runTransaction(async (tx) => {
    const [shipment, profile] = await Promise.all([
      tx.get(shipmentRef),
      tx.get(profileRef),
    ]);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_pickup" ||
        shipment.get("status") !== "queued" || !profile.exists) return false;
    const profileData = profile.data() || {};
    if (!isApprovedGarmentCarePartner(profileData) ||
        !isGarmentCareWithinWorkingHours(profileData, now) ||
        !hasCareCapability(profileData, "garmentCare.pickupDelivery") ||
        !partnerCoversPickupWindow(profileData, shipment.get("pickupSlot")) ||
        !isPickupWindowPending(shipment.data(), now)) return false;
    tx.update(shipmentRef, {
      status: "assigned",
      toPartnerAccountId: partner.accountId,
      toPartnerProfileId: partner.profileId,
      assignedPartnerName: garmentCarePartnerName(profileData, partner.name),
      assignedPartnerContactPhone: garmentCarePartnerContactPhone(profileData),
      assignedAt: SERVER_TIMESTAMP(),
      autoAssigned: true,
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(shipmentRef.collection("events").doc(), {
      type: "pickup_assigned",
      source: "automatic_priority_dispatch",
      partnerAccountId: partner.accountId,
      partnerProfileId: partner.profileId,
      actorType: "system",
      at: SERVER_TIMESTAMP(),
    });
    return true;
  });
}

async function autoOfferGarmentCareJob(jobRef, partner, now) {
  const profileRef = db.collection("accounts").doc(partner.accountId)
    .collection("profiles").doc(partner.profileId);
  return db.runTransaction(async (tx) => {
    const [jobSnap, profileSnap] = await Promise.all([
      tx.get(jobRef),
      tx.get(profileRef),
    ]);
    if (!jobSnap.exists || !profileSnap.exists) return false;
    const job = jobSnap.data() || {};
    const profile = profileSnap.data() || {};
    if ((job.status !== "queued" && job.status !== "rejected") ||
        job.dispatchEligible !== true || !isApprovedGarmentCarePartner(profile) ||
        !isGarmentCareWithinWorkingHours(profile, now) ||
        !hasCareServiceCapability(profile, job.serviceId)) return false;

    const reassignFromAccountId = text(job.reassignmentFromPartnerAccountId, 128);
    const reassignFromProfileId = text(job.reassignmentFromPartnerProfileId, 128);
    if (reassignFromAccountId === partner.accountId &&
        reassignFromProfileId === partner.profileId) return false;

    let incomingShipmentId = null;
    let transferRef = null;
    let sourceRef = null;
    if (reassignFromAccountId && reassignFromProfileId) {
      transferRef = db.collection("garment_care_shipments").doc();
      incomingShipmentId = transferRef.id;
      tx.create(transferRef, {
        shipmentId: transferRef.id,
        orderId: job.orderId,
        orderNumber: job.orderNumber || null,
        itemId: job.itemId,
        garmentId: job.garmentId,
        garmentIds: [job.garmentId],
        ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
        shipmentType: "partner_transfer",
        destinationJobId: jobRef.id,
        fromPartnerAccountId: reassignFromAccountId,
        fromPartnerProfileId: reassignFromProfileId,
        toPartnerAccountId: partner.accountId,
        toPartnerProfileId: partner.profileId,
        status: "planned",
        reassignmentReason: text(job.reassignmentReason, 800),
        createdAt: SERVER_TIMESTAMP(),
        updatedAt: SERVER_TIMESTAMP(),
      });
    } else if (job.dependsOnJobId) {
      sourceRef = db.collection("garment_care_service_jobs").doc(job.dependsOnJobId);
      const priorJob = await tx.get(sourceRef);
      if (!priorJob.exists || priorJob.get("status") !== "completed" ||
          !priorJob.get("assignedPartnerAccountId") || !priorJob.get("assignedPartnerProfileId")) return false;
      if (priorJob.get("assignedPartnerAccountId") === partner.accountId &&
          priorJob.get("assignedPartnerProfileId") === partner.profileId) {
        incomingShipmentId = text(priorJob.get("incomingShipmentId"), 128);
      } else {
        transferRef = db.collection("garment_care_shipments").doc();
        incomingShipmentId = transferRef.id;
        tx.create(transferRef, {
          shipmentId: transferRef.id,
          orderId: job.orderId,
          orderNumber: job.orderNumber || null,
          itemId: job.itemId,
          garmentId: job.garmentId,
          garmentIds: [job.garmentId],
          ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
          shipmentType: "partner_transfer",
          sourceJobId: job.dependsOnJobId,
          destinationJobId: jobRef.id,
          fromPartnerAccountId: priorJob.get("assignedPartnerAccountId"),
          fromPartnerProfileId: priorJob.get("assignedPartnerProfileId"),
          toPartnerAccountId: partner.accountId,
          toPartnerProfileId: partner.profileId,
          status: "planned",
          createdAt: SERVER_TIMESTAMP(),
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.update(sourceRef, {
          outgoingShipmentIds: admin.firestore.FieldValue.arrayUnion(transferRef.id),
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
    } else if (job.pickupShipmentId) {
      sourceRef = db.collection("garment_care_shipments").doc(job.pickupShipmentId);
      const pickup = await tx.get(sourceRef);
      if (!pickup.exists || pickup.get("status") !== "delivered") return false;
      const pickupAccountId = text(pickup.get("toPartnerAccountId"), 128);
      const pickupProfileId = text(pickup.get("toPartnerProfileId"), 128);
      if (!pickupAccountId || !pickupProfileId) return false;
      if (pickupAccountId === partner.accountId && pickupProfileId === partner.profileId) {
        incomingShipmentId = job.pickupShipmentId;
      } else {
        transferRef = db.collection("garment_care_shipments").doc();
        incomingShipmentId = transferRef.id;
        tx.create(transferRef, {
          shipmentId: transferRef.id,
          orderId: job.orderId,
          orderNumber: job.orderNumber || null,
          itemId: job.itemId,
          garmentId: job.garmentId,
          garmentIds: [job.garmentId],
          ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
          shipmentType: "partner_transfer",
          sourcePickupShipmentId: job.pickupShipmentId,
          destinationJobId: jobRef.id,
          fromPartnerAccountId: pickupAccountId,
          fromPartnerProfileId: pickupProfileId,
          toPartnerAccountId: partner.accountId,
          toPartnerProfileId: partner.profileId,
          status: "planned",
          createdAt: SERVER_TIMESTAMP(),
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.update(sourceRef, {
          outgoingShipmentIds: admin.firestore.FieldValue.arrayUnion(transferRef.id),
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
    }

    tx.update(jobRef, {
      status: "offered",
      dispatchEligible: false,
      assignedPartnerAccountId: partner.accountId,
      assignedPartnerProfileId: partner.profileId,
      assignedPartnerName: garmentCarePartnerName(profile, partner.name),
      assignedPartnerContactPhone: garmentCarePartnerContactPhone(profile),
      incomingShipmentId,
      reassignmentFromPartnerAccountId: admin.firestore.FieldValue.delete(),
      reassignmentFromPartnerProfileId: admin.firestore.FieldValue.delete(),
      reassignmentReason: admin.firestore.FieldValue.delete(),
      assignedAt: SERVER_TIMESTAMP(),
      autoAssigned: true,
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(jobRef.collection("events").doc(), {
      type: "assigned",
      source: "automatic_priority_dispatch",
      actorType: "system",
      partnerAccountId: partner.accountId,
      partnerProfileId: partner.profileId,
      shipmentId: transferRef ? transferRef.id : null,
      at: SERVER_TIMESTAMP(),
    });
    return true;
  });
}

async function reconcileCompletedGarmentCareInvoices() {
  const completedJobs = await db.collection("garment_care_service_jobs")
    .where("status", "==", "completed")
    .limit(100)
    .get();
  const groups = new Map();
  for (const job of completedJobs.docs) {
    const orderId = text(job.get("orderId"), 128);
    const deliveryGroupId = text(job.get("deliveryGroupId"), 128);
    if (orderId && deliveryGroupId) groups.set(`${orderId}:${deliveryGroupId}`, { orderId, deliveryGroupId });
  }
  let reconciled = 0;
  for (const { orderId, deliveryGroupId } of groups.values()) {
    try {
      const [invoice, shipments, orderJobs] = await Promise.all([
        db.collection("garment_care_invoices").doc(deliveryGroupId).get(),
        db.collection("garment_care_shipments").where("orderId", "==", orderId).get(),
        db.collection("garment_care_service_jobs").where("orderId", "==", orderId).get(),
      ]);
      const groupJobs = orderJobs.docs.filter((job) =>
        text(job.get("deliveryGroupId"), 128) === deliveryGroupId);
      if (hasCustomerDeclinedService(groupJobs)) continue;
      const returnShipments = shipments.docs.filter((shipment) =>
        shipment.get("shipmentType") === "customer_return" &&
        shipment.get("deliveryGroupId") === deliveryGroupId &&
        shipment.get("status") !== "delivered");
      const missingDeclinedReturns = returnShipments.some((shipment) => {
        const shipmentGarmentIds = new Set([
          ...(Array.isArray(shipment.get("garmentIds")) ? shipment.get("garmentIds") : []),
          text(shipment.get("garmentId"), 128),
        ].map((id) => text(id, 128)).filter(Boolean));
        return customerDeclinedGarmentsForPartner(
          orderJobs.docs,
          text(shipment.get("fromPartnerAccountId"), 128),
          text(shipment.get("fromPartnerProfileId"), 128),
          groupJobs.map((job) => text(job.get("garmentId"), 128)),
        ).some((item) => (!item.returnShipmentId || item.returnShipmentId === shipment.id) &&
          !shipmentGarmentIds.has(item.garmentId));
      });
      const needsReconciliation = !invoice.exists || missingDeclinedReturns || returnShipments.some((shipment) =>
        shipment.get("careComplete") !== true ||
        shipment.get("invoiceId") !== invoice.id ||
        !["requiresCustomerAction", "partiallyPaid", "paid"].includes(shipment.get("paymentStatusAtDelivery")));
      if (needsReconciliation) {
        await issueGarmentCareInvoiceAfterConsent(orderId, deliveryGroupId);
        reconciled += 1;
      }
    } catch (error) {
      console.error(`Completed Garment Care invoice reconciliation failed for ${deliveryGroupId}`, error);
    }
  }
  return reconciled;
}

async function runAutomaticGarmentCareRouting() {
  const invoiceReconciliations = await reconcileCompletedGarmentCareInvoices();
  const now = new Date();
  const partners = await automaticGarmentCarePartners(now);
  if (!partners.length) return { pickupAssignments: 0, serviceOffers: 0, invoiceReconciliations };
  let pickupAssignments = 0;
  let serviceOffers = 0;
  const pickups = await db.collection("garment_care_shipments")
    .where("shipmentType", "==", "customer_pickup")
    .where("status", "==", "queued")
    .limit(100)
    .get();
  for (const shipment of pickups.docs) {
    for (const partner of partners) {
      if (!hasCareCapability(partner.profile, "garmentCare.pickupDelivery") ||
          !partnerCoversPickupWindow(partner.profile, shipment.get("pickupSlot")) ||
          !isPickupWindowPending(shipment.data(), now)) continue;
      if (await autoAssignGarmentCarePickup(shipment.ref, partner, now)) {
        pickupAssignments += 1;
        break;
      }
    }
  }
  const jobs = await db.collection("garment_care_service_jobs")
    .where("status", "in", ["queued", "rejected"])
    .where("dispatchEligible", "==", true)
    .limit(100)
    .get();
  for (const job of jobs.docs) {
    for (const partner of partners) {
      if (!hasCareServiceCapability(partner.profile, job.get("serviceId"))) continue;
      if (await autoOfferGarmentCareJob(job.ref, partner, now)) {
        serviceOffers += 1;
        break;
      }
    }
  }
  return { pickupAssignments, serviceOffers, invoiceReconciliations };
}

function requireCareServiceCapability(profile, serviceId) {
  const required = CARE_SERVICE_CAPABILITIES[serviceId] || [];
  const declared = declaredCareCapabilities(profile);
  if (!required.length || !required.some((code) => declared.includes(code))) {
    fail("failed-precondition", `This Partner has not declared the required capability for ${SERVICES[serviceId] || serviceId}.`);
  }
}

exports.getAdminGarmentCarePricing = functions.https.onCall(async (_data, context) => {
  await requireAdmin(context);
  const pointer = await db.collection("config").doc("garmentCarePricing").get();
  const versionId = text(pointer.data() && pointer.data().activeVersionId, 128);
  const version = versionId
    ? await db.collection("garment_care_pricing_versions").doc(versionId).get()
    : null;
  if (!version || !version.exists) {
    return { versionId: null, pricingModelVersion: 2, serviceRates: {}, itemTypeRates: {},
      platformCommissionPercent: 15, taxPercent: 6, deliveryPercent: 6, logisticsAmount: 0 };
  }
  const policy = version.data() || {};
  return {
    versionId,
    pricingModelVersion: Number(policy.pricingModelVersion) || 1,
    serviceRates: policy.serviceRates || {},
    itemTypeRates: policy.itemTypeRates || {},
    platformCommissionPercent: Number(policy.platformCommissionPercent) || 0,
    taxPercent: Number(policy.taxPercent) || 0,
    deliveryPercent: policy.deliveryPercent == null ? 6 : Number(policy.deliveryPercent),
    logisticsAmount: Number(policy.logisticsAmount) || 0,
  };
});

exports.publishGarmentCarePricingVersion = functions.https.onCall(async (data, context) => {
  const auth = await requireAdmin(context);
  const inputRates = data && data.serviceRates;
  const inputItemTypeRates = data && data.itemTypeRates && typeof data.itemTypeRates === 'object' ? data.itemTypeRates : {};
  const commissionPercent = Number(data && data.platformCommissionPercent);
  const taxPercent = Number(data && data.taxPercent);
  const deliveryPercent = Number(data && data.deliveryPercent);
  const logisticsAmount = Number(data && data.logisticsAmount);
  if (!inputRates || typeof inputRates !== "object" ||
      !Number.isFinite(commissionPercent) || commissionPercent < 0 || commissionPercent > 100 ||
      !Number.isFinite(taxPercent) || taxPercent < 0 || taxPercent > 100 ||
      !Number.isFinite(deliveryPercent) || deliveryPercent < 0 || deliveryPercent > 100 ||
      !Number.isFinite(logisticsAmount) || logisticsAmount < 0) {
    fail("invalid-argument", "Provide valid service rates, commission, tax, delivery and logistics amounts.");
  }
  const serviceRates = {};
  for (const serviceId of REQUIRED_SERVICE_IDS) {
    const rate = inputRates[serviceId] || {};
    const customerAmount = Number(rate.customerAmount);
    const partnerAmount = Number(rate.partnerAmount);
    const minimumCustomerAmount = roundCareMoney(partnerAmount *
      (100 + taxPercent + deliveryPercent) / 100);
    if (!Number.isFinite(customerAmount) || customerAmount < 0 ||
        !Number.isFinite(partnerAmount) || partnerAmount < 0 ||
        customerAmount + 0.01 < minimumCustomerAmount) {
      fail("invalid-argument", `Enter valid Customer and Partner amounts for ${SERVICES[serviceId]}.`);
    }
    serviceRates[serviceId] = { customerAmount, partnerAmount, pricingUnit: "per_item" };
  }
  const itemTypeRates = {};
  for (const [serviceId, overrides] of Object.entries(inputItemTypeRates)) {
    if (!REQUIRED_SERVICE_IDS.includes(serviceId) || !overrides || typeof overrides !== "object") {
      fail("invalid-argument", "Garment-type rates must belong to a configured service.");
    }
    itemTypeRates[serviceId] = {};
    for (const [itemTypeCode, rawRate] of Object.entries(overrides)) {
      const allowed = ITEM_TYPES_BY_GROUP[SERVICE_GROUPS[serviceId]] || [];
      const customerAmount = Number(rawRate && rawRate.customerAmount);
      const partnerAmount = Number(rawRate && rawRate.partnerAmount);
      const minimumCustomerAmount = roundCareMoney(partnerAmount *
        (100 + taxPercent + deliveryPercent) / 100);
      if (!allowed.includes(itemTypeCode) || !Number.isFinite(customerAmount) ||
          customerAmount < 0 || !Number.isFinite(partnerAmount) ||
          partnerAmount < 0 || customerAmount + 0.01 < minimumCustomerAmount) {
        fail("invalid-argument", "Invalid item rate for " + SERVICES[serviceId] + " / " + itemTypeCode + ".");
      }
      itemTypeRates[serviceId][itemTypeCode] = {
        customerAmount, partnerAmount, pricingUnit: "per_item",
      };
    }
  }
  const versionRef = db.collection("garment_care_pricing_versions").doc();
  const pointerRef = db.collection("config").doc("garmentCarePricing");
  await db.runTransaction(async (tx) => {
    tx.create(versionRef, {
      versionId: versionRef.id,
      currency: "INR",
      serviceRates,
      itemTypeRates,
      platformCommissionPercent: commissionPercent,
      commissionBasis: "customer_rate_less_partner_payable_tax_and_delivery_components",
      taxPercent,
      deliveryPercent,
      logisticsAmount,
      pricingModelVersion: 2,
      publishedAt: SERVER_TIMESTAMP(),
      publishedByUid: auth.uid,
      immutable: true,
    });
    tx.set(pointerRef, {
      activeVersionId: versionRef.id,
      updatedAt: SERVER_TIMESTAMP(),
      updatedByUid: auth.uid,
    }, { merge: true });
  });
  return { versionId: versionRef.id };
});

exports.getGarmentCareInspectionTemplates = functions.https.onCall(async (_data, context) => {
  requireAuth(context);
  const pointer = await db.collection("config").doc("garmentCareInspectionTemplates").get();
  const versionId = text(pointer.data() && pointer.data().activeVersionId, 128);
  const versionSnap = versionId
    ? await db.collection("garment_care_inspection_template_versions").doc(versionId).get()
    : null;
  if (!versionSnap || !versionSnap.exists) {
    return { versionId: "default_v1", version: 1, templates: defaultInspectionTemplates() };
  }
  const version = versionSnap.data() || {};
  return {
    versionId,
    version: Number(version.version) || 1,
    templates: { ...defaultInspectionTemplates(), ...(version.templates || {}) },
  };
});

exports.publishGarmentCareInspectionTemplates = functions.https.onCall(async (data, context) => {
  const auth = await requireAdmin(context);
  const input = data && data.templates;
  if (!input || typeof input !== "object") {
    fail("invalid-argument", "Provide the approved All Good and Issue Found messages.");
  }
  const defaults = defaultInspectionTemplates();
  const serviceIds = Object.keys(SERVICES).filter((serviceId) =>
    INSPECTION_PHASE_GROUPS.has(SERVICE_GROUPS[serviceId]));
  const templates = { ...defaults };
  for (const serviceId of serviceIds) {
    const raw = input[serviceId] || {};
    const allGood = text(raw.allGood, 700);
    const issueFound = text(raw.issueFound, 1000);
    if (allGood.length < 10 || issueFound.length < 10) {
      fail("invalid-argument", `Add both customer messages for ${SERVICES[serviceId]}.`);
    }
    templates[serviceId] = { allGood, issueFound };
  }
  const pointerRef = db.collection("config").doc("garmentCareInspectionTemplates");
  const versionRef = db.collection("garment_care_inspection_template_versions").doc();
  let nextVersion = 1;
  await db.runTransaction(async (tx) => {
    const pointerSnap = await tx.get(pointerRef);
    const priorId = text(pointerSnap.data() && pointerSnap.get("activeVersionId"), 128);
    const priorSnap = priorId
      ? await tx.get(db.collection("garment_care_inspection_template_versions").doc(priorId))
      : null;
    nextVersion = (Number(priorSnap && priorSnap.exists && priorSnap.get("version")) || 0) + 1;
    tx.create(versionRef, {
      versionId: versionRef.id,
      version: nextVersion,
      templates,
      publishedAt: SERVER_TIMESTAMP(),
      publishedByUid: auth.uid,
      immutable: true,
    });
    tx.set(pointerRef, {
      activeVersionId: versionRef.id,
      version: nextVersion,
      updatedAt: SERVER_TIMESTAMP(),
      updatedByUid: auth.uid,
    }, { merge: true });
  });
  return { versionId: versionRef.id, version: nextVersion };
});

exports.getGarmentCareCompletionTemplates = functions.https.onCall(async (data, context) => {
  const isAdmin = data && data.isAdmin === true;
  if (isAdmin) {
    await requireAdmin(context);
  } else {
    await requirePartner(
      context,
      text(data && data.partnerAccountId, 128),
      text(data && data.partnerProfileId, 128),
    );
  }
  const [pointer, partnerSnap] = await Promise.all([
    db.collection("config").doc("garmentCareCompletionTemplates").get(),
    isAdmin
      ? Promise.resolve(null)
      : db.collection("accounts").doc(text(data.partnerAccountId, 128))
        .collection("profiles").doc(text(data.partnerProfileId, 128))
        .collection("garment_care_completion_templates").get(),
  ]);
  const versionId = text(pointer.data() && pointer.data().activeVersionId, 128);
  const versionSnap = versionId
    ? await db.collection("garment_care_completion_template_versions").doc(versionId).get()
    : null;
  const version = versionSnap && versionSnap.exists ? versionSnap.data() || {} : {};
  const templates = Array.isArray(version.templates)
    ? version.templates.map((item) => normalizeCompletionTemplate(item))
    : defaultGarmentCareCompletionTemplates();
  return {
    versionId: versionId || "starter_v1",
    version: Number(version.version) || 1,
    templates,
    starterTemplates: defaultGarmentCareCompletionTemplates(),
    partnerTemplates: partnerSnap
      ? partnerSnap.docs.map((doc) => normalizeCompletionTemplate(doc.data(), { id: doc.id }))
      : [],
  };
});

exports.publishGarmentCareCompletionTemplates = functions.https.onCall(async (data, context) => {
  const auth = await requireAdmin(context);
  const input = data && data.templates;
  if (!Array.isArray(input) || input.length > 80) {
    fail("invalid-argument", "Provide up to 80 completion templates.");
  }
  const templates = input.map((item) => normalizeCompletionTemplate(item));
  if (new Set(templates.map((item) => item.id)).size !== templates.length) {
    fail("invalid-argument", "Each completion template must have a unique ID.");
  }
  const pointerRef = db.collection("config").doc("garmentCareCompletionTemplates");
  const versionRef = db.collection("garment_care_completion_template_versions").doc();
  let nextVersion = 1;
  await db.runTransaction(async (tx) => {
    const pointerSnap = await tx.get(pointerRef);
    const priorId = text(pointerSnap.data() && pointerSnap.get("activeVersionId"), 128);
    const priorSnap = priorId
      ? await tx.get(db.collection("garment_care_completion_template_versions").doc(priorId))
      : null;
    nextVersion = (Number(priorSnap && priorSnap.exists && priorSnap.get("version")) || 0) + 1;
    tx.create(versionRef, {
      versionId: versionRef.id,
      version: nextVersion,
      templates,
      publishedAt: SERVER_TIMESTAMP(),
      publishedByUid: auth.uid,
      immutable: true,
    });
    tx.set(pointerRef, {
      activeVersionId: versionRef.id,
      version: nextVersion,
      updatedAt: SERVER_TIMESTAMP(),
      updatedByUid: auth.uid,
    }, { merge: true });
  });
  return { versionId: versionRef.id, version: nextVersion };
});

exports.savePartnerGarmentCareCompletionTemplate = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  await requirePartner(context, accountId, profileId);
  const template = normalizeCompletionTemplate(data && data.template);
  const ref = db.collection("accounts").doc(accountId)
    .collection("profiles").doc(profileId)
    .collection("garment_care_completion_templates").doc(template.id);
  const existing = await ref.get();
  await ref.set({
    ...template,
    createdAt: existing.exists ? existing.get("createdAt") || SERVER_TIMESTAMP() : SERVER_TIMESTAMP(),
    updatedAt: SERVER_TIMESTAMP(),
    updatedByUid: context.auth.uid,
  }, { merge: true });
  return { templateId: template.id };
});

exports.deletePartnerGarmentCareCompletionTemplate = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  await requirePartner(context, accountId, profileId);
  const templateId = text(data && data.templateId, 128);
  if (!templateId) fail("invalid-argument", "Choose the Partner template to delete.");
  await db.collection("accounts").doc(accountId)
    .collection("profiles").doc(profileId)
    .collection("garment_care_completion_templates").doc(templateId).delete();
  return { templateId };
});

// Legacy single-shipment callable retained locally; the exported checkout
// implementation below supersedes it with quantity and per-group orders.
const legacyCreateGarmentCareOrder = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.customerAccountId, 128);
  const profileId = text(data && data.customerProfileId, 128);
  const auth = await requireCustomer(context, accountId, profileId);
  const pickupAddress = data && data.pickupAddress;
  const pickupAddressId = text(pickupAddress && pickupAddress.addressId, 128);
  const pickupSlot = text(data && data.pickupSlot, 40);
  const preferredPickupAtMillis = Number(data && data.preferredPickupAtMillis);
  const preferredPickupAt = Number.isFinite(preferredPickupAtMillis)
    ? admin.firestore.Timestamp.fromMillis(preferredPickupAtMillis)
    : null;
  if (!pickupAddressId || !["9:00 AM–1:00 PM", "4:00 PM–8:00 PM"].includes(pickupSlot) ||
      !preferredPickupAt || preferredPickupAt.toDate() < new Date()) {
    fail("invalid-argument", "Choose a saved pickup address, a supported time slot, and a future date.");
  }
  const addressSnap = await db.collection("accounts").doc(accountId)
    .collection("addresses").doc(pickupAddressId).get();
  if (!addressSnap.exists || addressSnap.get("status") !== "active") {
    fail("failed-precondition", "Select an active saved pickup address.");
  }
  const addressData = addressSnap.data() || {};
  const [legacyAccount, legacyProfile] = await Promise.all([
    db.collection("accounts").doc(accountId).get(),
    db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get(),
  ]);
  const legacyAccountData = legacyAccount.data() || {};
  const legacyProfileData = legacyProfile.data() || {};
  const pricingPointer = await db.collection("config").doc("garmentCarePricing").get();
  const pricingPolicyVersionId = text(pricingPointer.data() && pricingPointer.data().activeVersionId, 128);
  const pricingPolicySnap = pricingPolicyVersionId
    ? await db.collection("garment_care_pricing_versions").doc(pricingPolicyVersionId).get()
    : null;
  if (!pricingPolicySnap || !pricingPolicySnap.exists) {
    fail("failed-precondition", "Garment Care pricing has not been configured by Admin yet.");
  }
  const pricingPolicy = pricingPolicySnap.data() || {};
  const pickupAddressSnapshot = {
    addressId: pickupAddressId,
    addressType: text(addressData.addressType || "Address", 60),
    name: text(addressData.name || legacyProfileData.displayName || legacyProfileData.fullName || legacyProfileData.name, 100),
    mobileNumber: text(addressData.mobileNumber || legacyAccountData.mobileE164 || auth.token.phone_number, 30),
    addressLine1: text(addressData.addressLine1, 180),
    addressLine2: text(addressData.addressLine2, 180),
    landmark: text(addressData.landmark, 120),
    city: text(addressData.cityName || addressData.city, 80),
    state: text(addressData.stateName || addressData.state, 80),
    pincode: text(addressData.pincode || addressData.postalCode, 10).replace(/\D/g, ""),
    formattedAddress: text(addressData.formattedAddress, 500),
  };
  if (!/^\d{6}$/.test(pickupAddressSnapshot.pincode)) {
    fail("failed-precondition", "Add a valid six-digit pickup PIN code to the saved address.");
  }
  if (pickupAddressSnapshot.mobileNumber.replace(/\D/g, "").length < 4) {
    fail("failed-precondition", "Add a valid customer mobile number to the pickup address before placing this order. The last four digits are used to confirm delivery.");
  }
  const items = Array.isArray(data && data.items) ? data.items : [];
  if (!items.length) fail("invalid-argument", "Add at least one garment.");
  if (items.length > 20) fail("invalid-argument", "A Garment Care request can contain up to 20 individual garments.");

  const normalized = items.map((raw) => {
    const item = raw || {};
    const groupCode = text(item.groupCode, 64);
    const requestedServiceIds = Array.isArray(item.serviceIds)
      ? item.serviceIds.map((id) => text(id, 80))
      : [];
    const hasServiceSteps = Array.isArray(item.serviceSteps);
    const rawServiceSteps = hasServiceSteps
      ? item.serviceSteps
      : requestedServiceIds.map((serviceId) => ({ groupCode, serviceId }));
    const serviceSteps = rawServiceSteps.map((step) => ({
      groupCode: text(step && step.groupCode, 64),
      serviceId: text(step && step.serviceId, 80),
    }));
    const serviceIds = serviceSteps.map((step) => step.serviceId);
    const serviceIdsMatchSteps = !hasServiceSteps ||
      (requestedServiceIds.length === serviceIds.length &&
        requestedServiceIds.every((serviceId, index) => serviceId === serviceIds[index]));
    if (!GROUPS.has(groupCode) || !INSPECTION_PHASE_GROUPS.has(groupCode) || !serviceSteps.length ||
        !serviceIdsMatchSteps ||
        new Set(serviceIds).size !== serviceIds.length ||
        serviceSteps.some((step) => !GROUPS.has(step.groupCode) || !INSPECTION_PHASE_GROUPS.has(step.groupCode) ||
          SERVICE_GROUPS[step.serviceId] !== step.groupCode) ||
        groupCode !== serviceSteps[0].groupCode) {
      fail("invalid-argument", "Choose one valid service for each step in the requested order.");
    }
    return {
      itemId: db.collection("garment_care_orders").doc().id,
      garmentId: text(item.garmentId, 128),
      sourceOrderId: text(item.sourceOrderId, 128),
      displayName: text(item.displayName, 120),
      itemTypeCode: text(item.itemTypeCode, 80) || "other",
      material: text(item.material, 120),
      groupCode,
      serviceIds,
      serviceSteps,
      conditionNotes: text(item.conditionNotes, 1000),
      careNotes: text(item.careNotes, 1000),
      conditionPhotoPaths: Array.isArray(item.conditionPhotoPaths)
        ? item.conditionPhotoPaths.map((path) => text(path, 500)).filter(Boolean).slice(0, 6)
        : [],
    };
  });
  if (normalized.some((item) => item.garmentId && item.sourceOrderId)) {
    fail("invalid-argument", "Use either a saved Garment DNA ID or an earlier order reference.");
  }
  const existingIds = normalized.map((item) => item.garmentId || (item.sourceOrderId ? `tailoring_${item.sourceOrderId}` : "")).filter(Boolean);
  if (new Set(existingIds).size !== existingIds.length) {
    fail("invalid-argument", "A physical garment can appear only once in this order.");
  }
  if (normalized.some((item) => !item.displayName)) {
    fail("invalid-argument", "Add a short name for each garment.");
  }
  const totalServiceJobs = normalized.reduce((sum, item) => sum + item.serviceIds.length, 0);
  if (totalServiceJobs > 100) {
    fail("invalid-argument", "A Garment Care request can include up to 100 service steps.");
  }
  const orderRef = db.collection("garment_care_orders").doc();
  const orderNumber = makeGarmentCareOrderNumber(
    pickupAddressSnapshot.pincode,
    (await reserveGarmentCareOrderNumbers(1))[0],
  );
  const deliveryGroupRef = orderRef.collection("delivery_groups").doc();
  const pickupShipmentRef = db.collection("garment_care_shipments").doc();
  const pickupPackageRef = db.collection("garment_care_packages").doc();
  const resolved = [];
  for (const item of normalized) {
    if (item.garmentId) {
      const identity = await db.collection("garment_identities").doc(item.garmentId).get();
      if (!identity.exists || identity.get("customerUid") !== auth.uid) {
        fail("permission-denied", "A saved garment reference must belong to your account.");
      }
      resolved.push({ ...item, identityRef: identity.ref, createIdentity: false, legacyDnaSnapshot: null });
    } else if (item.sourceOrderId) {
      const sourceOrder = await db.collection("orders").doc(item.sourceOrderId).get();
      const dna = sourceOrder.get("garmentRecord");
      if (!sourceOrder.exists || sourceOrder.get("customerId") !== auth.uid ||
          !sourceOrder.get("garmentRecordPublishedAt") || !dna || typeof dna !== "object") {
        fail("permission-denied", "The selected previous garment report is not available to this Customer.");
      }
      const identityRef = db.collection("garment_identities").doc(`tailoring_${item.sourceOrderId}`);
      const identity = await identityRef.get();
      if (identity.exists && identity.get("customerUid") !== auth.uid) {
        fail("permission-denied", "This previous garment identity is already linked to another Customer.");
      }
      resolved.push({
        ...item,
        garmentId: identityRef.id,
        identityRef,
        createIdentity: !identity.exists,
        legacyDnaSnapshot: dna,
      });
    } else {
      const identityRef = db.collection("garment_identities").doc();
      resolved.push({
        ...item,
        garmentId: identityRef.id,
        identityRef,
        createIdentity: true,
        legacyDnaSnapshot: null,
      });
    }
  }

  const batch = db.batch();
  const now = SERVER_TIMESTAMP();
  batch.create(orderRef, {
    orderId: orderRef.id,
    orderNumber,
    customerUid: auth.uid,
    customerAccountId: accountId,
    customerProfileId: profileId,
    statusProjection: "partner_assignment",
    itemCount: resolved.length,
    serviceCount: resolved.reduce((count, item) => count + item.serviceIds.length, 0),
    deliveryGroupIds: [deliveryGroupRef.id],
    shipmentIds: [pickupShipmentRef.id],
    packageIds: [pickupPackageRef.id],
    pickupAddressSnapshot,
    pickupSlot,
    preferredPickupAt,
    pricingState: "after_inspection",
    pricingPolicyVersionId,
    createdFromPricingVersionId: pricingPolicyVersionId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  });
  batch.create(deliveryGroupRef, {
    deliveryGroupId: deliveryGroupRef.id,
    orderId: orderRef.id,
    orderNumber,
    itemIds: resolved.map((item) => item.itemId),
    statusProjection: "open",
    pricingState: "after_inspection",
    pricingPolicyVersionId,
    logisticsAmount: Number(pricingPolicy.logisticsAmount) || 0,
    createdAt: now,
  });
  batch.create(pickupShipmentRef, {
    shipmentId: pickupShipmentRef.id,
    orderId: orderRef.id,
    orderNumber,
    deliveryGroupId: deliveryGroupRef.id,
    shipmentType: "customer_pickup",
    itemIds: resolved.map((item) => item.itemId),
    garmentIds: resolved.map((item) => item.garmentId),
    packageId: pickupPackageRef.id,
    pickupAddressSnapshot,
    preferredPickupAt,
    pickupSlot,
    status: "queued",
    createdAt: now,
    updatedAt: now,
  });
  batch.create(pickupPackageRef, {
    packageId: pickupPackageRef.id,
    orderId: orderRef.id,
    deliveryGroupId: deliveryGroupRef.id,
    garmentIds: resolved.map((item) => item.garmentId),
    packageType: "pickup_container",
    temporary: true,
    createdAt: now,
  });
  const createdJobs = [];
  for (const item of resolved) {
    const garmentRef = item.identityRef || db.collection("garment_identities").doc(item.garmentId);
    if (item.createIdentity) {
      batch.create(garmentRef, {
        garmentId: item.garmentId,
        customerUid: auth.uid,
        customerAccountId: accountId,
        customerProfileId: profileId,
        displayName: item.displayName,
        itemTypeCode: item.itemTypeCode,
        material: item.material || null,
        sourceOrderId: item.sourceOrderId || null,
        sourceType: item.sourceOrderId ? "legacy_tailoring_order" : "garment_care_intake",
        currentCustodianType: "customer",
        currentCustodianAccountId: accountId,
        currentCustodianProfileId: profileId,
        legacyDnaSnapshot: item.legacyDnaSnapshot || null,
        dnaVersion: item.sourceOrderId ? 2 : 1,
        createdAt: now,
        updatedAt: now,
      });
    }
    const itemRef = orderRef.collection("items").doc(item.itemId);
    batch.create(itemRef, {
      itemId: item.itemId,
      orderId: orderRef.id,
      garmentId: item.garmentId,
      deliveryGroupId: deliveryGroupRef.id,
      displayName: item.displayName,
      itemTypeCode: item.itemTypeCode,
      material: item.material || null,
      serviceGroupCode: item.groupCode,
      serviceIds: item.serviceIds,
      serviceSteps: item.serviceSteps,
      conditionNotes: item.conditionNotes,
      careNotes: item.careNotes,
      conditionPhotoPaths: item.conditionPhotoPaths,
      sourceOrderId: item.sourceOrderId || null,
      createdAt: now,
    });
    let dependsOnJobId = null;
    for (const step of item.serviceSteps) {
      const serviceId = step.serviceId;
      const jobRef = db.collection("garment_care_service_jobs").doc();
      batch.create(jobRef, {
        jobId: jobRef.id,
        orderId: orderRef.id,
        itemId: item.itemId,
        garmentId: item.garmentId,
        deliveryGroupId: deliveryGroupRef.id,
        serviceGroupCode: step.groupCode,
        serviceId,
        serviceName: SERVICES[serviceId],
        material: item.material || null,
        conditionNotes: item.conditionNotes,
        careNotes: item.careNotes,
        conditionPhotoPaths: item.conditionPhotoPaths,
        knowledgeCardVersionId: "curated_baseline_2026_10_v1",
        status: "queued",
        dispatchEligible: dependsOnJobId === null,
        dependsOnJobId,
        pickupShipmentId: pickupShipmentRef.id,
        assignedPartnerAccountId: null,
        assignedPartnerProfileId: null,
        inspectionRequired: true,
        createdAt: now,
        updatedAt: now,
      });
      dependsOnJobId = jobRef.id;
      createdJobs.push(jobRef.id);
    }
  }
  batch.create(orderRef.collection("events").doc(), {
    type: "garment_care_order_created",
    actorUid: auth.uid,
    orderNumber,
    at: now,
    itemCount: resolved.length,
    jobIds: createdJobs,
  });
  await batch.commit();
  return { orderId: orderRef.id, orderNumber, deliveryGroupId: deliveryGroupRef.id, jobIds: createdJobs };
});

// Customer-safe rate-card projection. Partner payable and commission fields
// remain server-only; the Customer sees only the amounts needed for an estimate.
exports.getCustomerGarmentCarePricing = functions.https.onCall(async (_data, context) => {
  requireAuth(context);
  const pointer = await db.collection("config").doc("garmentCarePricing").get();
  const versionId = text(pointer.data() && pointer.data().activeVersionId, 128);
  const version = versionId
    ? await db.collection("garment_care_pricing_versions").doc(versionId).get()
    : null;
  if (!version || !version.exists) {
    fail("failed-precondition", "Garment Care pricing has not been configured yet.");
  }
  const policy = version.data() || {};
  const rates = {};
  for (const serviceId of REQUIRED_SERVICE_IDS) {
    const rate = (policy.serviceRates || {})[serviceId] || {};
    const customerAmount = Number(rate.customerAmount);
    if (!Number.isFinite(customerAmount) || customerAmount < 0) {
      fail("failed-precondition", "The active Garment Care rate card is incomplete.");
    }
    rates[serviceId] = { customerAmount, pricingUnit: "per_item" };
  }
  const itemTypeRates = {};
  for (const [serviceId, overrides] of Object.entries(policy.itemTypeRates || {})) {
    itemTypeRates[serviceId] = {};
    for (const [itemTypeCode, rate] of Object.entries(overrides || {})) {
      itemTypeRates[serviceId][itemTypeCode] = {
        customerAmount: Number(rate.customerAmount) || 0,
        pricingUnit: "per_item",
      };
    }
  }
  return {
    pricingPolicyVersionId: versionId,
    pricingModelVersion: Number(policy.pricingModelVersion) || 1,
    currency: text(policy.currency || "INR", 8),
    serviceRates: rates,
    itemTypeRates,
    itemTypesByGroup: ITEM_TYPES_BY_GROUP,
    taxPercent: Number(policy.taxPercent) || 0,
    deliveryPercent: policy.deliveryPercent == null ? 6 : Number(policy.deliveryPercent),
    logisticsAmount: Number(policy.logisticsAmount) || 0,
  };
});

// Cart checkout creates one parent request and a separately scheduled and
// priced service sub-order (delivery group) for every selected service group.
// Jobs stay linked to the same physical Garment DNA across sequential steps.
exports.createGarmentCareOrder = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.customerAccountId, 128);
  const profileId = text(data && data.customerProfileId, 128);
  const auth = await requireCustomer(context, accountId, profileId);
  const pickupAddressId = text(data && data.pickupAddressId, 128);
  if (!pickupAddressId) fail("invalid-argument", "Choose a saved pickup address.");
  const addressSnap = await db.collection("accounts").doc(accountId)
    .collection("addresses").doc(pickupAddressId).get();
  if (!addressSnap.exists || addressSnap.get("status") !== "active") {
    fail("failed-precondition", "Select an active saved pickup address.");
  }
  const addressData = addressSnap.data() || {};
  const [customerAccountSnap, customerProfileSnap] = await Promise.all([
    db.collection("accounts").doc(accountId).get(),
    db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get(),
  ]);
  const customerAccount = customerAccountSnap.data() || {};
  const customerProfile = customerProfileSnap.data() || {};
  const pickupAddressSnapshot = {
    addressId: pickupAddressId,
    addressType: text(addressData.addressType || "Address", 60),
    name: text(addressData.name || customerProfile.displayName || customerProfile.fullName || customerProfile.name, 100),
    mobileNumber: text(addressData.mobileNumber || customerAccount.mobileE164 || auth.token.phone_number, 30),
    addressLine1: text(addressData.addressLine1, 180),
    addressLine2: text(addressData.addressLine2, 180),
    landmark: text(addressData.landmark, 120),
    city: text(addressData.cityName || addressData.city, 80),
    state: text(addressData.stateName || addressData.state, 80),
    pincode: text(addressData.pincode || addressData.postalCode, 10).replace(/\D/g, ""),
    formattedAddress: text(addressData.formattedAddress, 500),
  };
  if (!/^\d{6}$/.test(pickupAddressSnapshot.pincode)) {
    fail("failed-precondition", "Add a valid six-digit pickup PIN code to the saved address.");
  }
  if (pickupAddressSnapshot.mobileNumber.replace(/\D/g, "").length < 4) {
    fail("failed-precondition", "Add a valid customer mobile number to the pickup address before placing this order. The last four digits are used to confirm delivery.");
  }
  const pricingPointer = await db.collection("config").doc("garmentCarePricing").get();
  const pricingPolicyVersionId = text(pricingPointer.data() && pricingPointer.data().activeVersionId, 128);
  const pricingPolicySnap = pricingPolicyVersionId
    ? await db.collection("garment_care_pricing_versions").doc(pricingPolicyVersionId).get()
    : null;
  if (!pricingPolicySnap || !pricingPolicySnap.exists) {
    fail("failed-precondition", "Garment Care pricing has not been configured by Admin yet.");
  }
  const pricingPolicy = pricingPolicySnap.data() || {};
  const pickupByGroup = data && data.pickupByServiceGroup && typeof data.pickupByServiceGroup === "object"
    ? data.pickupByServiceGroup : {};
  const rawItems = Array.isArray(data && data.items) ? data.items : [];
  if (!rawItems.length || rawItems.length > 50) {
    fail("invalid-argument", "Add between 1 and 50 care items to the cart.");
  }
  const roundMoney = (value) => Math.round(value * 100) / 100;
  const normalizedLines = rawItems.map((raw) => {
    const line = raw || {};
    const groupCode = text(line.groupCode, 64);
    const requestedIds = Array.isArray(line.serviceIds)
      ? line.serviceIds.map((id) => text(id, 80)) : [];
    const hasSteps = Array.isArray(line.serviceSteps);
    const serviceSteps = (hasSteps ? line.serviceSteps : requestedIds.map((serviceId) => ({ groupCode, serviceId })))
      .map((step) => ({ groupCode: text(step && step.groupCode, 64), serviceId: text(step && step.serviceId, 80) }));
    const quantity = Number(line.quantity);
    const serviceIds = serviceSteps.map((step) => step.serviceId);
    const idsMatch = !hasSteps || (requestedIds.length === serviceIds.length &&
      requestedIds.every((serviceId, index) => serviceId === serviceIds[index]));
    if (!GROUPS.has(groupCode) || !INSPECTION_PHASE_GROUPS.has(groupCode) || !serviceSteps.length || serviceSteps.length > 6 ||
        !idsMatch || !Number.isInteger(quantity) || quantity < 1 || quantity > 20 ||
        serviceIds.includes("antibacterial_wash") ||
        serviceSteps.some((step) => !GROUPS.has(step.groupCode) || !INSPECTION_PHASE_GROUPS.has(step.groupCode) || SERVICE_GROUPS[step.serviceId] !== step.groupCode) ||
        new Set(serviceIds).size !== serviceIds.length || groupCode !== serviceSteps[0].groupCode) {
      fail("invalid-argument", "Choose a valid care service per step. Hygiene wash is an optional treatment within a suitable wash service.");
    }
    const garmentId = text(line.garmentId, 128);
    const sourceOrderId = text(line.sourceOrderId, 128);
    if ((garmentId || sourceOrderId) && quantity !== 1) {
      fail("invalid-argument", "A saved physical garment can be ordered only once per cart line.");
    }
    const itemTypeCode = text(line.itemTypeCode, 80) || "other";
    const displayName = text(line.displayName, 120) ||
      (itemTypeCode === "other" ? "Other garment" : itemTypeCode.replaceAll("_", " "));
    return {
      garmentId,
      sourceOrderId,
      itemTypeCode,
      displayName,
      material: text(line.material, 120),
      quantity,
      groupCode,
      serviceIds,
      serviceSteps,
      hygieneWashRequested: line.hygieneWashRequested === true &&
        serviceIds.some((serviceId) => HYGIENE_TREATMENT_SERVICE_IDS.has(serviceId)),
      conditionNotes: text(line.conditionNotes, 1000),
      careNotes: text(line.careNotes, 1000),
      starchLevel: text(line.starchLevel, 40),
      conditionPhotoPaths: Array.isArray(line.conditionPhotoPaths)
        ? line.conditionPhotoPaths.map((path) => text(path, 500)).filter(Boolean).slice(0, 6) : [],
    };
  });
  const garmentCount = normalizedLines.reduce((sum, line) => sum + line.quantity, 0);
  const serviceJobCount = normalizedLines.reduce((sum, line) => sum + line.quantity * line.serviceSteps.length, 0);
  if (garmentCount > 100 || serviceJobCount > 100) {
    fail("invalid-argument", "A cart can contain up to 100 individually tracked service jobs.");
  }
  const savedIds = normalizedLines.map((line) => line.garmentId || (line.sourceOrderId ? `tailoring_${line.sourceOrderId}` : "")).filter(Boolean);
  if (new Set(savedIds).size !== savedIds.length) {
    fail("invalid-argument", "Use a saved physical garment only once per cart item.");
  }
  const serviceGroupCodes = [...new Set(normalizedLines.flatMap((line) => line.serviceSteps.map((step) => step.groupCode)))];
  const schedules = {};
  for (const groupCode of serviceGroupCodes) {
    const schedule = pickupByGroup[groupCode] || {};
    const slot = text(schedule.pickupSlot, 40);
    const atMillis = Number(schedule.preferredPickupAtMillis);
    const at = Number.isFinite(atMillis) ? admin.firestore.Timestamp.fromMillis(atMillis) : null;
    const expectedStart = slot === "9:00 AM–1:00 PM" ? "09:00" :
      slot === "4:00 PM–8:00 PM" ? "16:00" : null;
    const localStart = at ? new Intl.DateTimeFormat("en-GB", {
      timeZone: "Asia/Kolkata",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).format(at.toDate()) : "";
    if (!at || at.toMillis() <= Date.now() || !expectedStart || localStart !== expectedStart) {
      fail("invalid-argument", `That pickup window has started or passed for ${groupCode}. Choose an available date and time.`);
    }
    schedules[groupCode] = { preferredPickupAt: at, pickupSlot: slot };
  }

  const groups = new Map(serviceGroupCodes.map((code) => {
    const orderRef = db.collection("garment_care_orders").doc();
    return [code, {
      orderRef,
      orderNumber: "",
      deliveryGroupId: db.collection("garment_care_orders").doc().id,
      code,
      itemIds: [],
      jobIds: [],
      garmentIds: new Set(),
      serviceIds: new Set(),
      firstStepItems: [],
      garmentDisplayNamesById: new Map(),
      deliveryGroupsByGarmentId: new Map(),
      estimatedServiceSubtotal: 0,
      estimatedTaxTotal: 0,
      estimatedDeliveryTotal: 0,
    }];
  }));
  const orderSequences = await reserveGarmentCareOrderNumbers(groups.size);
  [...groups.values()].forEach((group, index) => {
    group.orderNumber = makeGarmentCareOrderNumber(pickupAddressSnapshot.pincode, orderSequences[index]);
  });
  const checkoutRef = db.collection("garment_care_checkouts").doc();
  const checkoutId = checkoutRef.id;
  const physicalGarments = [];
  for (const line of normalizedLines) {
    for (let unit = 0; unit < line.quantity; unit += 1) {
      let garmentId = line.quantity === 1 ? line.garmentId : "";
      let identityRef;
      let createIdentity = false;
      let legacyDnaSnapshot = null;
      if (garmentId) {
        identityRef = db.collection("garment_identities").doc(garmentId);
        const identity = await identityRef.get();
        if (!identity.exists || identity.get("customerUid") !== auth.uid) {
          fail("permission-denied", "A saved garment reference must belong to your account.");
        }
      } else if (line.sourceOrderId) {
        const sourceOrder = await db.collection("orders").doc(line.sourceOrderId).get();
        const dna = sourceOrder.get("garmentRecord");
        if (!sourceOrder.exists || sourceOrder.get("customerId") !== auth.uid ||
            !sourceOrder.get("garmentRecordPublishedAt") || !dna || typeof dna !== "object") {
          fail("permission-denied", "The selected previous garment report is not available to this Customer.");
        }
        garmentId = `tailoring_${line.sourceOrderId}`;
        identityRef = db.collection("garment_identities").doc(garmentId);
        const identity = await identityRef.get();
        if (identity.exists && identity.get("customerUid") !== auth.uid) {
          fail("permission-denied", "This previous garment identity is already linked to another Customer.");
        }
        createIdentity = !identity.exists;
        legacyDnaSnapshot = dna;
      } else {
        identityRef = db.collection("garment_identities").doc();
        garmentId = identityRef.id;
        createIdentity = true;
      }
      const steps = line.serviceSteps.map((step, index) => {
        const group = groups.get(step.groupCode);
        group.garmentIds.add(garmentId);
        group.garmentDisplayNamesById.set(garmentId, line.displayName);
        const subOrderNumber = "";
        let deliveryGroup = group.deliveryGroupsByGarmentId.get(garmentId);
        if (!deliveryGroup) {
          deliveryGroup = {
            deliveryGroupId: group.deliveryGroupsByGarmentId.size === 0
              ? group.deliveryGroupId
              : db.collection("garment_care_orders").doc().id,
            garmentId,
            subOrderNumber: "",
            displayName: line.displayName,
            itemIds: [],
            jobIds: [],
            serviceIds: new Set(),
            estimatedServiceSubtotal: 0,
            estimatedTaxTotal: 0,
            estimatedDeliveryTotal: 0,
          };
          group.deliveryGroupsByGarmentId.set(garmentId, deliveryGroup);
        }
        const itemId = db.collection("garment_care_orders").doc().id;
        const jobId = db.collection("garment_care_service_jobs").doc().id;
        group.itemIds.push(itemId);
        group.jobIds.push(jobId);
        group.serviceIds.add(step.serviceId);
        deliveryGroup.itemIds.push(itemId);
        deliveryGroup.jobIds.push(jobId);
        deliveryGroup.serviceIds.add(step.serviceId);
        const rate = ((pricingPolicy.itemTypeRates || {})[step.serviceId] || {})[line.itemTypeCode] ||
          (pricingPolicy.serviceRates || {})[step.serviceId] || {};
        const customerRate = Number(rate.customerAmount);
        if (!Number.isFinite(customerRate) || customerRate < 0) {
          fail("failed-precondition", `No active estimate is configured for ${SERVICES[step.serviceId]}.`);
        }
        const pricingParts = careRateBreakdown(pricingPolicy, rate);
        group.estimatedServiceSubtotal += pricingParts.serviceAmount;
        group.estimatedTaxTotal += pricingParts.taxAmount;
        group.estimatedDeliveryTotal += pricingParts.deliveryAmount;
        deliveryGroup.estimatedServiceSubtotal += pricingParts.serviceAmount;
        deliveryGroup.estimatedTaxTotal += pricingParts.taxAmount;
        deliveryGroup.estimatedDeliveryTotal += pricingParts.deliveryAmount;
        const normalizedStep = {
          ...step,
          itemId,
          jobId,
          subOrderNumber,
          deliveryGroupId: deliveryGroup.deliveryGroupId,
        };
        if (index === 0) {
          group.firstStepItems.push({ itemId, jobId, garmentId, subOrderNumber, displayName: line.displayName });
        }
        return normalizedStep;
      });
      physicalGarments.push({ line, garmentId, identityRef, createIdentity, legacyDnaSnapshot, steps });
    }
  }
  for (const group of groups.values()) {
    group.estimatedServiceSubtotal = roundMoney(group.estimatedServiceSubtotal);
    group.estimatedTaxTotal = roundMoney(group.estimatedTaxTotal);
    group.estimatedDeliveryTotal = roundMoney(group.estimatedDeliveryTotal);
    const garmentGroups = [...group.deliveryGroupsByGarmentId.values()];
    const fixedLogisticsCents = Math.max(0, Math.round((Number(pricingPolicy.logisticsAmount) || 0) * 100));
    const baseCents = garmentGroups.length ? Math.floor(fixedLogisticsCents / garmentGroups.length) : 0;
    let remainingCents = garmentGroups.length ? fixedLogisticsCents % garmentGroups.length : 0;
    for (const deliveryGroup of garmentGroups) {
      deliveryGroup.estimatedServiceSubtotal = roundMoney(deliveryGroup.estimatedServiceSubtotal);
      deliveryGroup.estimatedTaxTotal = roundMoney(deliveryGroup.estimatedTaxTotal);
      deliveryGroup.estimatedDeliveryTotal = roundMoney(deliveryGroup.estimatedDeliveryTotal);
      const allocatedFixedCents = baseCents + (remainingCents > 0 ? 1 : 0);
      if (remainingCents > 0) remainingCents -= 1;
      deliveryGroup.baseLogisticsAmount = roundMoney(allocatedFixedCents / 100);
      deliveryGroup.logisticsAmount = roundMoney(
        deliveryGroup.estimatedDeliveryTotal + deliveryGroup.baseLogisticsAmount,
      );
      deliveryGroup.estimatedGrandTotal = roundMoney(
        deliveryGroup.estimatedServiceSubtotal + deliveryGroup.estimatedTaxTotal + deliveryGroup.logisticsAmount,
      );
    }
    group.logisticsAmount = roundMoney(garmentGroups.reduce((sum, item) => sum + item.logisticsAmount, 0));
    group.estimatedGrandTotal = roundMoney(group.estimatedServiceSubtotal + group.estimatedTaxTotal + group.logisticsAmount);
  }
  const batch = db.batch();
  const now = SERVER_TIMESTAMP();
  const orderIds = [...groups.values()].map((group) => group.orderRef.id);
  const deliveryGroupIds = [...groups.values()].map((group) => group.deliveryGroupId);
  const shipmentIds = [];
  const packageIds = [];
  for (const group of groups.values()) {
    group.pickupShipmentId = group.firstStepItems.length ? db.collection("garment_care_shipments").doc().id : null;
    group.packageId = group.firstStepItems.length ? db.collection("garment_care_packages").doc().id : null;
    if (group.pickupShipmentId) shipmentIds.push(group.pickupShipmentId);
    if (group.packageId) packageIds.push(group.packageId);
  }
  batch.create(checkoutRef, {
    checkoutId,
    cartCheckoutId: checkoutId,
    customerUid: auth.uid,
    customerAccountId: accountId,
    customerProfileId: profileId,
    itemCount: garmentCount,
    requestedItemCount: garmentCount,
    serviceCount: serviceJobCount,
    requestedServiceCount: serviceJobCount,
    pickupRejectedGarmentIds: [],
    pickupRejectedItemCount: 0,
    pickupRejectedServiceCount: 0,
    orderIds,
    serviceGroupCodes,
    estimatedGrandTotal: roundMoney([...groups.values()].reduce((sum, group) => sum + group.estimatedGrandTotal, 0)),
    orders: [...groups.values()].map((group) => ({
      orderId: group.orderRef.id,
      orderNumber: group.orderNumber,
      serviceGroupCode: group.code,
    })),
    pickupAddressSnapshot,
    pricingPolicyVersionId,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  });
  for (const group of groups.values()) {
    const orderRef = group.orderRef;
    batch.create(orderRef, {
      orderId: orderRef.id,
      orderNumber: group.orderNumber,
      cartCheckoutId: checkoutId,
      customerUid: auth.uid,
      customerAccountId: accountId,
      customerProfileId: profileId,
      serviceGroupCode: group.code,
      statusProjection: "partner_assignment",
      itemCount: group.garmentIds.size,
      requestedItemCount: group.garmentIds.size,
      subOrderCount: 0,
      nextSubOrderSequence: 1,
      serviceCount: group.jobIds.length,
      requestedServiceCount: group.jobIds.length,
      deliveryGroupIds: [...group.deliveryGroupsByGarmentId.values()].map((item) => item.deliveryGroupId),
      shipmentIds: group.pickupShipmentId ? [group.pickupShipmentId] : [],
      packageIds: group.packageId ? [group.packageId] : [],
      estimatedGrandTotal: group.estimatedGrandTotal,
      estimateStatus: "preliminary_pending_inspection",
      pickupAddressSnapshot,
      pricingState: "after_inspection",
      pricingPolicyVersionId,
      createdFromPricingVersionId: pricingPolicyVersionId,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 3,
    });
    const schedule = schedules[group.code];
    for (const deliveryGroup of group.deliveryGroupsByGarmentId.values()) {
      const deliveryGroupRef = orderRef.collection("delivery_groups").doc(deliveryGroup.deliveryGroupId);
      batch.create(deliveryGroupRef, {
        deliveryGroupId: deliveryGroup.deliveryGroupId,
        orderId: orderRef.id,
        orderNumber: group.orderNumber,
        serviceGroupCode: group.code,
        serviceIds: [...deliveryGroup.serviceIds],
        itemIds: deliveryGroup.itemIds,
        jobIds: deliveryGroup.jobIds,
        garmentIds: [deliveryGroup.garmentId],
        subOrderNumber: deliveryGroup.subOrderNumber,
        displayName: deliveryGroup.displayName,
        itemCount: 1,
        statusProjection: "open",
        pricingState: "after_inspection",
        estimateStatus: "preliminary_pending_inspection",
        estimatedServiceSubtotal: deliveryGroup.estimatedServiceSubtotal,
        estimatedTaxTotal: deliveryGroup.estimatedTaxTotal,
        estimatedLogisticsTotal: deliveryGroup.logisticsAmount,
        estimatedGrandTotal: deliveryGroup.estimatedGrandTotal,
        currency: text(pricingPolicy.currency || "INR", 8),
        pricingPolicyVersionId,
        baseLogisticsAmount: deliveryGroup.baseLogisticsAmount,
        logisticsAmount: deliveryGroup.logisticsAmount,
        pickupAddressSnapshot,
        preferredPickupAt: schedule.preferredPickupAt,
        pickupSlot: schedule.pickupSlot,
        pickupShipmentId: group.pickupShipmentId,
        createdAt: now,
      });
    }
    if (group.pickupShipmentId) {
      const shipmentRef = db.collection("garment_care_shipments").doc(group.pickupShipmentId);
      const packageRef = db.collection("garment_care_packages").doc(group.packageId);
      const firstItems = group.firstStepItems;
      batch.create(shipmentRef, {
        shipmentId: group.pickupShipmentId,
        orderId: orderRef.id,
        orderNumber: group.orderNumber,
        deliveryGroupId: group.deliveryGroupId,
        deliveryGroupIds: [...group.deliveryGroupsByGarmentId.values()].map((item) => item.deliveryGroupId),
        shipmentType: "customer_pickup",
        itemIds: firstItems.map((item) => item.itemId),
        garmentIds: firstItems.map((item) => item.garmentId),
        garmentDisplayNamesById: Object.fromEntries(
          firstItems.map((item) => [item.garmentId, item.displayName]),
        ),
        packageId: group.packageId,
        pickupAddressSnapshot,
        preferredPickupAt: schedule.preferredPickupAt,
        pickupSlot: schedule.pickupSlot,
        status: "queued",
        createdAt: now,
        updatedAt: now,
      });
      batch.create(packageRef, {
        packageId: group.packageId,
        orderId: orderRef.id,
        orderNumber: group.orderNumber,
        deliveryGroupId: group.deliveryGroupId,
        deliveryGroupIds: [...group.deliveryGroupsByGarmentId.values()].map((item) => item.deliveryGroupId),
        garmentIds: firstItems.map((item) => item.garmentId),
        garmentDisplayNamesById: Object.fromEntries(
          firstItems.map((item) => [item.garmentId, item.displayName]),
        ),
        packageType: "pickup_container",
        temporary: true,
        createdAt: now,
      });
    }
  }
  const createdJobs = [];
  for (const garment of physicalGarments) {
    const line = garment.line;
    if (garment.createIdentity) {
      batch.create(garment.identityRef, {
        garmentId: garment.garmentId,
        customerUid: auth.uid,
        customerAccountId: accountId,
        customerProfileId: profileId,
        displayName: line.displayName,
        itemTypeCode: line.itemTypeCode,
        material: line.material || null,
        sourceOrderId: line.sourceOrderId || null,
        sourceType: line.sourceOrderId ? "legacy_tailoring_order" : "garment_care_intake",
        currentCustodianType: "customer",
        currentCustodianAccountId: accountId,
        currentCustodianProfileId: profileId,
        legacyDnaSnapshot: garment.legacyDnaSnapshot || null,
        dnaVersion: line.sourceOrderId ? 2 : 1,
        createdAt: now,
        updatedAt: now,
      });
    }
    let dependsOnJobId = null;
    for (const step of garment.steps) {
      const group = groups.get(step.groupCode);
      const orderRef = group.orderRef;
      const itemRef = orderRef.collection("items").doc(step.itemId);
      batch.create(itemRef, {
        itemId: step.itemId,
        orderId: orderRef.id,
        orderNumber: group.orderNumber,
        garmentId: garment.garmentId,
        subOrderNumber: step.subOrderNumber,
        deliveryGroupId: step.deliveryGroupId,
        displayName: line.displayName,
        itemTypeCode: line.itemTypeCode,
        quantity: 1,
        material: line.material || null,
        serviceGroupCode: step.groupCode,
        serviceIds: [step.serviceId],
        serviceSteps: [{ groupCode: step.groupCode, serviceId: step.serviceId }],
        hygieneWashRequested: line.hygieneWashRequested === true &&
          HYGIENE_TREATMENT_SERVICE_IDS.has(step.serviceId),
        conditionNotes: line.conditionNotes,
        careNotes: line.careNotes,
        starchLevel: line.starchLevel || null,
        conditionPhotoPaths: line.conditionPhotoPaths,
        sourceOrderId: line.sourceOrderId || null,
        createdAt: now,
      });
      const jobRef = db.collection("garment_care_service_jobs").doc(step.jobId);
      batch.create(jobRef, {
        jobId: step.jobId,
        orderId: orderRef.id,
        orderNumber: group.orderNumber,
        itemId: step.itemId,
        garmentId: garment.garmentId,
        subOrderNumber: step.subOrderNumber,
        displayName: line.displayName,
        itemTypeCode: line.itemTypeCode,
        deliveryGroupId: step.deliveryGroupId,
        serviceGroupCode: step.groupCode,
        serviceId: step.serviceId,
        serviceName: SERVICES[step.serviceId],
        hygieneWashRequested: line.hygieneWashRequested === true &&
          HYGIENE_TREATMENT_SERVICE_IDS.has(step.serviceId),
        material: line.material || null,
        conditionNotes: line.conditionNotes,
        careNotes: line.careNotes,
        starchLevel: line.starchLevel || null,
        conditionPhotoPaths: line.conditionPhotoPaths,
        knowledgeCardVersionId: "curated_baseline_2026_10_v1",
        status: "queued",
        dispatchEligible: dependsOnJobId === null,
        dependsOnJobId,
        pickupShipmentId: dependsOnJobId === null ? group.pickupShipmentId : null,
        assignedPartnerAccountId: null,
        assignedPartnerProfileId: null,
        inspectionRequired: true,
        createdAt: now,
        updatedAt: now,
      });
      dependsOnJobId = step.jobId;
      createdJobs.push(step.jobId);
    }
  }
  for (const group of groups.values()) {
    batch.create(group.orderRef.collection("events").doc(), {
      type: "garment_care_service_order_created",
      actorUid: auth.uid,
      cartCheckoutId: checkoutId,
      orderId: group.orderRef.id,
      orderNumber: group.orderNumber,
      serviceGroupCode: group.code,
      at: now,
      itemCount: group.garmentIds.size,
      deliveryGroupIds: [...group.deliveryGroupsByGarmentId.values()].map((item) => item.deliveryGroupId),
      jobIds: group.jobIds,
    });
  }
  const cartDraftRef = db.collection("accounts").doc(accountId)
    .collection("profiles").doc(profileId)
    .collection("garment_care_cart_drafts").doc("current");
  batch.delete(cartDraftRef);
  await batch.commit();
  try {
    await runAutomaticGarmentCareRouting();
  } catch (error) {
    console.error("Automatic Garment Care routing after order creation failed", error);
  }
  return {
    checkoutId,
    cartCheckoutId: checkoutId,
    orderIds,
    orders: [...groups.values()].map((group) => ({
      orderId: group.orderRef.id,
      orderNumber: group.orderNumber,
      serviceGroupCode: group.code,
      deliveryGroupIds: [...group.deliveryGroupsByGarmentId.values()].map((item) => item.deliveryGroupId),
      deliveryGroupId: group.deliveryGroupId,
    })),
    jobIds: createdJobs,
  };
});

// Sub-order numbers are created only after pickup decisions are confirmed.
// Tracking must never assign a code to garments that have not been accepted.
exports.ensureGarmentCareSubOrderNumbers = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = text(data && data.orderId, 128);
  if (!orderId) fail("invalid-argument", "A Garment Care order is required.");

  const orderRef = db.collection("garment_care_orders").doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) fail("not-found", "This Garment Care order could not be found.");
  if (orderSnap.get("customerUid") !== auth.uid) {
    fail("permission-denied", "You can update sub-order labels only for your own order.");
  }

  const [jobsSnap, shipmentsSnap] = await Promise.all([
    db.collection("garment_care_service_jobs").where("orderId", "==", orderId).get(),
    db.collection("garment_care_shipments").where("orderId", "==", orderId).get(),
  ]);
  if (jobsSnap.empty) return { orderNumber: orderSnap.get("orderNumber") || "", subOrderCount: 0 };
  const acceptedGarmentIds = new Set(shipmentsSnap.docs
    .filter((shipment) => shipment.get("shipmentType") === "customer_pickup")
    .flatMap((shipment) => Array.isArray(shipment.get("collectedGarmentIds"))
      ? shipment.get("collectedGarmentIds").map((id) => text(id, 128))
      : []));
  const acceptedSubOrderNumbers = new Set(jobsSnap.docs
    .filter((job) => acceptedGarmentIds.has(text(job.get("garmentId"), 128)))
    .map((job) => text(job.get("subOrderNumber"), 8))
    .filter((number) => /^[A-Z]\d{3}$/.test(number)));
  return {
    orderNumber: text(orderSnap.get("orderNumber"), 32),
    subOrderCount: acceptedSubOrderNumbers.size,
    updatedRecords: 0,
  };
});

exports.updateGarmentCarePartnerPreferences = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const available = data && data.availableForOrders;
  const openAt = text(data && data.openAt, 5);
  const closeAt = text(data && data.closeAt, 5);
  if (typeof available !== "boolean" || parseClock(openAt) === null || parseClock(closeAt) === null ||
      parseClock(closeAt) <= parseClock(openAt)) {
    fail("invalid-argument", "Choose availability and valid opening/closing times.");
  }
  const { profileRef } = await requirePartner(context, accountId, profileId);
  await profileRef.update({
    "partnerData.extensions.garmentCare.operational.availableForOrders": available,
    "partnerData.extensions.garmentCare.operational.openAt": openAt,
    "partnerData.extensions.garmentCare.operational.closeAt": closeAt,
    "partnerData.extensions.garmentCare.operational.timezone": "Asia/Kolkata",
    "partnerData.extensions.garmentCare.operational.updatedAt": SERVER_TIMESTAMP(),
  });
  try {
    await runAutomaticGarmentCareRouting();
  } catch (error) {
    console.error("Automatic Garment Care routing after Partner availability update failed", error);
  }
  return { availableForOrders: available, openAt, closeAt };
});

exports.updateGarmentCareDeliveryPartnerAvailability = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const available = data && data.available;
  if (!accountId || !profileId || typeof available !== "boolean") {
    fail("invalid-argument", "Choose whether to be available for Garment Care delivery.");
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const profileRef = accountRef.collection("profiles").doc(profileId);
  const [accountSnap, profileSnap] = await Promise.all([accountRef.get(), profileRef.get()]);
  const profile = profileSnap.data() || {};
  if (!accountSnap.exists || accountSnap.get("mobileE164") !== auth.token.phone_number ||
      !profileSnap.exists || profile.role !== "partner" || profile.partnerType !== "deliveryPartner") {
    fail("permission-denied", "You can update Garment Care delivery availability only for your own Delivery Partner profile.");
  }
  const activeAndApproved = profile.status === "active" && profile.operationalStatus === "active" &&
    profile.activationStatus === "active" && profile.approvalStatus === "approved" &&
    profile.kycStatus === "verified";
  if (available && !activeAndApproved) {
    fail("failed-precondition", "Only an approved, active, verified Delivery Partner can accept Garment Care deliveries.");
  }
  if (available && garmentCareDeliveryPincodes(profile).length === 0) {
    fail("failed-precondition", "Add at least one service-area PIN code to your Delivery Partner profile before going online for Garment Care deliveries.");
  }
  await profileRef.update({
    garmentCareDeliveryAvailable: available,
    garmentCareDeliveryAvailabilityUpdatedAt: SERVER_TIMESTAMP(),
    garmentCareDeliveryAvailabilityUpdatedByUid: auth.uid,
    updatedAt: SERVER_TIMESTAMP(),
  });
  return { available };
});

exports.updateGarmentCarePartnerPriority = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const priority = Number(data && data.priority);
  if (!accountId || !profileId || !Number.isInteger(priority) || priority < 0 || priority > 100) {
    fail("invalid-argument", "Set a Partner priority from 0 to 100.");
  }
  const profileRef = db.collection("accounts").doc(accountId).collection("profiles").doc(profileId);
  const profile = await profileRef.get();
  if (!profile.exists || profile.get("role") !== "partner" || profile.get("partnerType") !== "garmentCare" ||
      profile.get("approvalStatus") !== "approved" || profile.get("kycStatus") !== "verified") {
    fail("failed-precondition", "Priority can be changed only for an approved, verified Garment Care Partner.");
  }
  await profileRef.update({
    "partnerData.extensions.garmentCare.operational.adminPriority": priority,
    "partnerData.extensions.garmentCare.operational.priorityUpdatedAt": SERVER_TIMESTAMP(),
    "partnerData.extensions.garmentCare.operational.priorityUpdatedByUid": context.auth.uid,
  });
  return { priority };
});

exports.getGarmentCarePartnerCandidates = functions.https.onCall(async (_data, context) => {
  await requireAdmin(context);
  const snapshot = await db.collectionGroup("profiles")
    .where("role", "==", "partner")
    .where("partnerType", "==", "garmentCare")
    .where("status", "==", "active")
    .where("operationalStatus", "==", "active")
    .where("activationStatus", "==", "active")
    .where("approvalStatus", "==", "approved")
    .where("kycStatus", "==", "verified")
    .get();
  const partners = snapshot.docs.map((doc) => {
    const profile = doc.data();
    const operational = garmentCareOperational(profile);
    return {
      accountId: doc.ref.parent.parent.id,
      profileId: doc.id,
      name: text(doc.get("businessName") || doc.get("displayName") || "Garment Care Partner", 120),
      contactPhone: garmentCarePartnerContactPhone(profile),
      availableForOrders: operational.availableForOrders !== false,
      openAt: text(operational.openAt, 5),
      closeAt: text(operational.closeAt, 5),
      priority: Number(operational.adminPriority) || 0,
      capabilityCodes: declaredCareCapabilities(profile),
    };
  }).filter((partner) => partner.availableForOrders)
    .sort((a, b) => b.priority - a.priority || a.name.localeCompare(b.name));
  return { partners };
});

exports.getGarmentCareDeliveryCandidates = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const shipmentId = text(data && data.shipmentId, 128);
  await requirePartner(context, accountId, profileId);
  if (!shipmentId) fail("invalid-argument", "Customer delivery shipment is required.");
  const shipmentSnap = await db.collection("garment_care_shipments").doc(shipmentId).get();
  if (!shipmentSnap.exists || shipmentSnap.get("shipmentType") !== "customer_return" ||
      shipmentSnap.get("status") !== "planned" ||
      shipmentSnap.get("fromPartnerAccountId") !== accountId ||
      shipmentSnap.get("fromPartnerProfileId") !== profileId) {
    fail("failed-precondition", "Only the assigned service Partner can choose a delivery Partner for this return.");
  }
  const orderId = text(shipmentSnap.get("orderId"), 128);
  if (!orderId) fail("failed-precondition", "The Customer order details are unavailable.");
  const orderSnap = await db.collection("garment_care_orders").doc(orderId).get();
  if (!orderSnap.exists) fail("failed-precondition", "The Customer order details are unavailable.");
  const customerPincode = normalizedGarmentCarePincode(
    (orderSnap.get("pickupAddressSnapshot") || {}).pincode,
  );
  if (!customerPincode) {
    fail("failed-precondition", "The Customer delivery PIN is unavailable for this order.");
  }
  const baseQuery = db.collectionGroup("profiles")
    .where("role", "==", "partner")
    .where("status", "==", "active")
    .where("operationalStatus", "==", "active")
    .where("activationStatus", "==", "active")
    .where("approvalStatus", "==", "approved")
    .where("kycStatus", "==", "verified");
  const [careSnapshot, deliverySnapshot] = await Promise.all([
    baseQuery.where("partnerType", "==", "garmentCare").get(),
    baseQuery.where("partnerType", "==", "deliveryPartner").get(),
  ]);
  const excluded = (doc) => doc.ref.parent.parent.id === accountId && doc.id === profileId;
  const carePartners = careSnapshot.docs
    .filter((doc) => !excluded(doc) && isGarmentCareAvailable(doc.data()) &&
      deliveryPartnerCoversGarmentCarePincode(doc.data(), customerPincode) &&
      declaredCareCapabilities(doc.data()).includes("garmentCare.pickupDelivery"));
  const deliveryPartners = deliverySnapshot.docs
    .filter((doc) => !excluded(doc) && doc.get("garmentCareDeliveryAvailable") === true &&
      deliveryPartnerCoversGarmentCarePincode(doc.data(), customerPincode));
  return {
    customerPincode,
    partners: [...carePartners, ...deliveryPartners]
      .map((doc) => ({
        accountId: doc.ref.parent.parent.id,
        profileId: doc.id,
        partnerType: text(doc.get("partnerType"), 48),
        name: garmentCarePartnerName(doc.data()),
        contactPhone: garmentCarePartnerContactPhone(doc.data()),
        coveragePincode: customerPincode,
      }))
      .sort((a, b) => a.name.localeCompare(b.name)),
  };
});

exports.assignGarmentCareReturnPartner = functions.https.onCall(async (data, context) => {
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const targetAccountId = text(data && data.deliveryPartnerAccountId, 128);
  const targetProfileId = text(data && data.deliveryPartnerProfileId, 128);
  const { auth } = await requirePartner(context, accountId, profileId);
  if (!shipmentId || !targetAccountId || !targetProfileId ||
      (accountId === targetAccountId && profileId === targetProfileId)) {
    fail("invalid-argument", "Choose another available delivery Partner for the Customer return.");
  }
  const targetRef = db.collection("accounts").doc(targetAccountId).collection("profiles").doc(targetProfileId);
  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  await db.runTransaction(async (tx) => {
    const shipment = await tx.get(shipmentRef);
    if (!shipment.exists) fail("not-found", "Customer return shipment not found.");
    const orderId = text(shipment.get("orderId"), 128);
    if (!orderId) fail("failed-precondition", "The Customer order details are unavailable.");
    const orderRef = db.collection("garment_care_orders").doc(orderId);
    const [order, target] = await Promise.all([tx.get(orderRef), tx.get(targetRef)]);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_return" ||
        shipment.get("status") !== "planned" || shipment.get("fromPartnerAccountId") !== accountId ||
        shipment.get("fromPartnerProfileId") !== profileId) {
      fail("failed-precondition", "Only the assigned service Partner can route a planned customer return.");
    }
    if (!order.exists) fail("failed-precondition", "The Customer order details are unavailable.");
    const customerPincode = normalizedGarmentCarePincode(
      (order.get("pickupAddressSnapshot") || {}).pincode,
    );
    const targetProfile = target.data() || {};
    const targetPartnerType = text(target.get("partnerType"), 48);
    const activeAndApproved = target.exists && target.get("role") === "partner" &&
      target.get("status") === "active" && target.get("operationalStatus") === "active" &&
      target.get("activationStatus") === "active" && target.get("approvalStatus") === "approved" &&
      target.get("kycStatus") === "verified";
    const eligibleCarePartner = targetPartnerType === "garmentCare" &&
      isGarmentCareAvailable(targetProfile) &&
      deliveryPartnerCoversGarmentCarePincode(targetProfile, customerPincode) &&
      declaredCareCapabilities(targetProfile).includes("garmentCare.pickupDelivery");
    const eligibleDeliveryPartner = targetPartnerType === "deliveryPartner" &&
      target.get("garmentCareDeliveryAvailable") === true &&
      deliveryPartnerCoversGarmentCarePincode(targetProfile, customerPincode);
    if (!activeAndApproved || (!eligibleCarePartner && !eligibleDeliveryPartner)) {
      fail("failed-precondition", "Choose an available, approved Partner who covers this Customer's PIN.");
    }
    tx.update(shipmentRef, {
      deliveryMode: "other_partner",
      deliveryPartnerAccountId: targetAccountId,
      deliveryPartnerProfileId: targetProfileId,
      deliveryPartnerName: garmentCarePartnerName(targetProfile),
      deliveryPartnerContactPhone: garmentCarePartnerContactPhone(targetProfile),
      toPartnerAccountId: targetAccountId,
      toPartnerProfileId: targetProfileId,
      deliveryPartnerType: targetPartnerType,
      deliveryPartnerCoveragePincode: customerPincode,
      deliveryPartnerAssignedAt: SERVER_TIMESTAMP(),
      ...(targetPartnerType === "deliveryPartner" ? {
        deliveryPartnerAcceptanceStatus: "pending",
        deliveryPartnerDeclinedReason: admin.firestore.FieldValue.delete(),
      } : {
        deliveryPartnerAcceptanceStatus: admin.firestore.FieldValue.delete(),
        deliveryPartnerDeclinedReason: admin.firestore.FieldValue.delete(),
      }),
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(shipmentRef.collection("events").doc(), {
      type: "customer_return_delivery_partner_assigned",
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      deliveryPartnerAccountId: targetAccountId,
      deliveryPartnerProfileId: targetProfileId,
      deliveryPartnerType: targetPartnerType,
      deliveryPartnerCoveragePincode: customerPincode,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: "assigned" };
});

exports.respondToGarmentCareDeliveryAssignment = functions.https.onCall(async (data, context) => {
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const decision = text(data && data.decision, 20);
  const reasonCode = text(data && data.reasonCode, 80);
  const allowedReasons = ["not_available", "outside_service_area", "capacity_full", "vehicle_issue", "other"];
  const { auth, partnerType } = await requireGarmentCareDeliveryPartner(
    context, accountId, profileId,
  );
  if (partnerType !== "deliveryPartner") {
    fail("permission-denied", "Only the assigned Delivery Partner can respond to this delivery assignment.");
  }
  if (!shipmentId || !["accept", "reject"].includes(decision) ||
      (decision === "reject" && !allowedReasons.includes(reasonCode))) {
    fail("invalid-argument", "Choose accept or decline and provide a reason when declining.");
  }
  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  const eventRef = shipmentRef.collection("events").doc();
  await db.runTransaction(async (tx) => {
    const shipment = await tx.get(shipmentRef);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_return" ||
        shipment.get("status") !== "planned" || shipment.get("deliveryMode") !== "other_partner" ||
        shipment.get("deliveryPartnerType") !== "deliveryPartner" ||
        shipment.get("deliveryPartnerAccountId") !== accountId ||
        shipment.get("deliveryPartnerProfileId") !== profileId) {
      fail("permission-denied", "This Customer delivery assignment is no longer assigned to your profile.");
    }
    const currentDecision = text(shipment.get("deliveryPartnerAcceptanceStatus"), 20) || "pending";
    if (decision === "accept" && currentDecision === "accepted") {
      return;
    }
    if (currentDecision !== "pending") {
      fail("failed-precondition", "This delivery assignment has already been accepted or declined.");
    }
    if (decision === "accept") {
      tx.update(shipmentRef, {
        deliveryPartnerAcceptanceStatus: "accepted",
        deliveryPartnerAcceptedAt: SERVER_TIMESTAMP(),
        deliveryPartnerAcceptedByUid: auth.uid,
        updatedAt: SERVER_TIMESTAMP(),
      });
      tx.create(eventRef, {
        type: "customer_return_delivery_partner_accepted",
        actorUid: auth.uid,
        partnerAccountId: accountId,
        partnerProfileId: profileId,
        at: SERVER_TIMESTAMP(),
      });
      return;
    }
    tx.update(shipmentRef, {
      deliveryMode: "service_partner",
      deliveryPartnerAcceptanceStatus: "rejected",
      deliveryPartnerDeclinedReason: reasonCode,
      deliveryPartnerDeclinedAt: SERVER_TIMESTAMP(),
      deliveryPartnerDeclinedByUid: auth.uid,
      lastDeclinedDeliveryPartnerAccountId: accountId,
      lastDeclinedDeliveryPartnerProfileId: profileId,
      lastDeclinedDeliveryPartnerName: text(shipment.get("deliveryPartnerName"), 120),
      toPartnerAccountId: admin.firestore.FieldValue.delete(),
      toPartnerProfileId: admin.firestore.FieldValue.delete(),
      deliveryPartnerAccountId: admin.firestore.FieldValue.delete(),
      deliveryPartnerProfileId: admin.firestore.FieldValue.delete(),
      deliveryPartnerName: admin.firestore.FieldValue.delete(),
      deliveryPartnerContactPhone: admin.firestore.FieldValue.delete(),
      deliveryPartnerType: admin.firestore.FieldValue.delete(),
      deliveryPartnerCoveragePincode: admin.firestore.FieldValue.delete(),
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(eventRef, {
      type: "customer_return_delivery_partner_declined",
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      reasonCode,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: decision === "accept" ? "accepted" : "rejected" };
});

exports.assignGarmentCarePickup = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  if (!shipmentId || !accountId || !profileId) fail("invalid-argument", "Pickup shipment and Partner are required.");
  const profile = await db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get();
  if (!profile.exists || profile.get("role") !== "partner" ||
      profile.get("partnerType") !== "garmentCare" || profile.get("status") !== "active" ||
      profile.get("operationalStatus") !== "active" || profile.get("activationStatus") !== "active" ||
      profile.get("approvalStatus") !== "approved" || profile.get("kycStatus") !== "verified") {
    fail("failed-precondition", "Select an active, approved and verified Garment Care Partner.");
  }
    if (!isGarmentCareAvailable(profile.data())) {
      fail("failed-precondition", "This Partner is not currently available for new Garment Care orders.");
    }
    if (!declaredCareCapabilities(profile.data()).includes("garmentCare.pickupDelivery")) {
      fail("failed-precondition", "This Partner has not declared Pickup & Delivery capability.");
    }
  const ref = db.collection("garment_care_shipments").doc(shipmentId);
  await db.runTransaction(async (tx) => {
    const shipment = await tx.get(ref);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_pickup" || shipment.get("status") !== "queued") {
      fail("failed-precondition", "This pickup is no longer awaiting assignment.");
    }
    if (!partnerCoversPickupWindow(profile.data(), shipment.get("pickupSlot"))) {
      fail("failed-precondition", "This Partner's business hours do not cover the selected pickup window.");
    }
    tx.update(ref, {
      status: "assigned",
      toPartnerAccountId: accountId,
      toPartnerProfileId: profileId,
      assignedPartnerName: garmentCarePartnerName(profile.data()),
      assignedPartnerContactPhone: garmentCarePartnerContactPhone(profile.data()),
      assignedAt: SERVER_TIMESTAMP(),
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(ref.collection("events").doc(), {
      type: "pickup_assigned",
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      actorUid: context.auth.uid,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: "assigned" };
});

exports.getGarmentCarePickupPartnerDetails = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const shipmentId = text(data && data.shipmentId, 128);
  if (!shipmentId) fail("invalid-argument", "Pickup shipment is required.");
  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  const shipment = await shipmentRef.get();
  if (!shipment.exists || shipment.get("shipmentType") !== "customer_pickup") {
    fail("not-found", "Garment Care pickup was not found.");
  }
  const orderId = text(shipment.get("orderId"), 128);
  const order = orderId ? await db.collection("garment_care_orders").doc(orderId).get() : null;
  if (!order || !order.exists) fail("not-found", "Garment Care order was not found.");
  if (order.get("customerUid") !== auth.uid) await requireAdmin(context);

  const accountId = text(shipment.get("toPartnerAccountId"), 128);
  const profileId = text(shipment.get("toPartnerProfileId"), 128);
  if (!accountId || !profileId) {
    fail("failed-precondition", "A Partner has not been assigned to this pickup yet.");
  }
  const partnerAccountRef = db.collection("accounts").doc(accountId);
  const [partnerAccount, profile] = await Promise.all([
    partnerAccountRef.get(),
    partnerAccountRef.collection("profiles").doc(profileId).get(),
  ]);
  if (!profile.exists || profile.get("role") !== "partner" || profile.get("partnerType") !== "garmentCare") {
    fail("not-found", "The assigned Garment Care Partner profile could not be found.");
  }
  const profileData = profile.data() || {};
  const partnerAccountData = partnerAccount.data() || {};
  const contactPhone = text(
    garmentCarePartnerContactPhone(profileData,
      shipment.get("assignedPartnerContactPhone") || partnerAccountData.mobileE164 || partnerAccountData.phoneNumber),
    32,
  );
  const alternateSources = [
    profileData.additionalContactNumbers,
    profileData.alternateContactNumbers,
    profileData.alternateMobileE164,
    profileData.alternatePhone,
    partnerAccountData.additionalContactNumbers,
    partnerAccountData.alternateContactNumbers,
    partnerAccountData.alternateMobileE164,
    partnerAccountData.alternatePhone,
  ];
  const additionalContactPhones = alternateSources
    .flatMap((value) => Array.isArray(value) ? value : [value])
    .map((value) => text(value, 32))
    .filter((value, index, values) => value && value !== contactPhone && values.indexOf(value) === index)
    .slice(0, 3);
  return {
    name: garmentCarePartnerName(profileData, shipment.get("assignedPartnerName")),
    contactPhone,
    additionalContactPhones,
  };
});

exports.getGarmentCarePickupWorkDetails = functions.https.onCall(async (data, context) => {
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  if (!shipmentId || !accountId || !profileId) {
    fail("invalid-argument", "Pickup and Partner profile are required.");
  }
  const shipment = await db.collection("garment_care_shipments").doc(shipmentId).get();
  if (!shipment.exists || shipment.get("shipmentType") !== "customer_pickup") {
    fail("not-found", "Garment Care pickup was not found.");
  }
  if (shipment.get("toPartnerAccountId") !== accountId ||
      shipment.get("toPartnerProfileId") !== profileId) {
    fail("permission-denied", "This pickup is not assigned to your Partner profile.");
  }
  await requirePartner(context, accountId, profileId);
  const orderId = text(shipment.get("orderId"), 128);
  const garmentIds = new Set(Array.isArray(shipment.get("garmentIds"))
    ? shipment.get("garmentIds").map((id) => text(id, 128)).filter(Boolean)
    : []);
  if (!orderId || !garmentIds.size) {
    fail("failed-precondition", "This pickup is missing its service or garment details.");
  }
  const jobs = await db.collection("garment_care_service_jobs")
    .where("orderId", "==", orderId).get();
  const byGarment = new Map();
  for (const job of jobs.docs) {
    const garmentId = text(job.get("garmentId"), 128);
    if (!garmentIds.has(garmentId)) continue;
    if (!byGarment.has(garmentId)) {
      byGarment.set(garmentId, {
        garmentId,
        subOrderNumber: text(job.get("subOrderNumber"), 8),
        serviceGroupCode: text(job.get("serviceGroupCode"), 64),
        displayName: text(job.get("displayName") || job.get("itemTypeCode") || "Garment", 120),
        material: text(job.get("material"), 80),
        services: [],
      });
    }
    const garment = byGarment.get(garmentId);
    if (!garment.subOrderNumber) garment.subOrderNumber = text(job.get("subOrderNumber"), 8);
    if (!garment.serviceGroupCode) garment.serviceGroupCode = text(job.get("serviceGroupCode"), 64);
    const serviceName = text(job.get("serviceName") || SERVICES[job.get("serviceId")], 120);
    if (serviceName && !garment.services.includes(serviceName)) garment.services.push(serviceName);
  }
  return {
    orderNumber: text(shipment.get("orderNumber"), 32),
    garments: [...byGarment.values()].sort((a, b) => a.garmentId.localeCompare(b.garmentId)),
  };
});

exports.getGarmentCarePartnerServiceJobDetails = functions.https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  if (!jobId || !accountId || !profileId) {
    fail("invalid-argument", "Service job and Partner profile are required.");
  }
  await requirePartner(context, accountId, profileId);
  const job = await db.collection("garment_care_service_jobs").doc(jobId).get();
  if (!job.exists || job.get("assignedPartnerAccountId") !== accountId ||
      job.get("assignedPartnerProfileId") !== profileId) {
    fail("permission-denied", "This service job is not assigned to your Partner profile.");
  }
  const order = await db.collection("garment_care_orders").doc(text(job.get("orderId"), 128)).get();
  if (!order.exists) fail("not-found", "Garment Care order was not found.");
  const groupId = text(job.get("deliveryGroupId"), 128);
  const group = groupId
    ? await order.ref.collection("delivery_groups").doc(groupId).get()
    : null;
  const address = (group && group.exists && group.get("pickupAddressSnapshot")) ||
    order.get("pickupAddressSnapshot") || {};
  const addressLabel = text(address.formattedAddress, 500) || [
    address.addressLine1,
    address.addressLine2,
    address.landmark,
    address.city,
    address.state,
    address.pincode,
  ].map((value) => text(value, 180)).filter(Boolean).join(", ");
  const preferredPickupAt = (group && group.exists && group.get("preferredPickupAt")) ||
    order.get("preferredPickupAt");
  return {
    orderId: text(job.get("orderId"), 128),
    orderNumber: text(job.get("orderNumber") || order.get("orderNumber"), 32),
    customerName: text(address.name, 120),
    customerPhone: text(address.mobileNumber, 32),
    pickupAddress: addressLabel,
    pickupSlot: text((group && group.exists && group.get("pickupSlot")) || order.get("pickupSlot"), 80),
    pickupAt: preferredPickupAt && typeof preferredPickupAt.toDate === "function"
      ? preferredPickupAt.toDate().toISOString()
      : null,
    garmentId: text(job.get("garmentId"), 128),
    displayName: text(job.get("displayName") || job.get("itemTypeCode") || "Garment", 120),
    serviceName: text(job.get("serviceName") || SERVICES[job.get("serviceId")], 120),
    material: text(job.get("material"), 120),
    conditionNotes: text(job.get("conditionNotes"), 1000),
    careNotes: text(job.get("careNotes"), 1000),
    status: text(job.get("status"), 40),
  };
});

exports.sendGarmentCarePartnerOrderNote = functions.https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const message = text(data && data.message, 1000);
  if (!jobId || !accountId || !profileId || message.length < 5) {
    fail("invalid-argument", "Write a Customer update of at least five characters.");
  }
  const { auth } = await requirePartner(context, accountId, profileId);
  const jobRef = db.collection("garment_care_service_jobs").doc(jobId);
  const noteId = db.collection("garment_care_orders").doc().id;
  const jobEventRef = jobRef.collection("events").doc();
  let orderNumber = "";
  await db.runTransaction(async (tx) => {
    const job = await tx.get(jobRef);
    if (!job.exists || job.get("assignedPartnerAccountId") !== accountId ||
        job.get("assignedPartnerProfileId") !== profileId) {
      fail("permission-denied", "This service job is not assigned to your Partner profile.");
    }
    if (!["offered", "accepted", "inspectionPending", "awaitingConsent", "readyToStart", "inProgress", "qualityCheck", "awaitingCustomerEdit"].includes(job.get("status"))) {
      fail("failed-precondition", "Customer updates are available while this service is active.");
    }
    const orderRef = db.collection("garment_care_orders").doc(text(job.get("orderId"), 128));
    const order = await tx.get(orderRef);
    if (!order.exists) fail("not-found", "Garment Care order was not found.");
    orderNumber = text(job.get("orderNumber") || order.get("orderNumber"), 32);
    const payload = {
      type: "partner_customer_note",
      orderId: orderRef.id,
      orderNumber,
      jobId,
      garmentId: text(job.get("garmentId"), 128),
      displayName: text(job.get("displayName") || job.get("itemTypeCode") || "Garment", 120),
      serviceName: text(job.get("serviceName") || SERVICES[job.get("serviceId")], 120),
      partnerName: text(job.get("assignedPartnerName"), 120) || "Garment Care Partner",
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      message,
      actorUid: auth.uid,
      at: SERVER_TIMESTAMP(),
    };
    tx.create(orderRef.collection("events").doc(noteId), payload);
    tx.create(jobEventRef, {
      type: "partner_customer_note_sent",
      orderEventId: noteId,
      message,
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: "sent", orderNumber };
});

exports.acceptGarmentCarePickup = functions.https.onCall(async (data, context) => {
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const { auth } = await requirePartner(context, accountId, profileId);
  if (!shipmentId) fail("invalid-argument", "Pickup shipment is required.");

  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  const eventRef = shipmentRef.collection("events").doc();
  await db.runTransaction(async (tx) => {
    const shipment = await tx.get(shipmentRef);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_pickup") {
      fail("not-found", "Garment Care pickup was not found.");
    }
    const record = shipment.data() || {};
    if (record.status !== "assigned" || record.toPartnerAccountId !== accountId ||
        record.toPartnerProfileId !== profileId) {
      fail("permission-denied", "This pickup is not assigned to your Partner profile.");
    }
    if (record.pickupAcceptedByUid) {
      if (record.pickupAcceptedByUid === auth.uid &&
          record.pickupAcceptedByAccountId === accountId &&
          record.pickupAcceptedByProfileId === profileId) return;
      fail("failed-precondition", "This pickup has already been accepted by another Partner user.");
    }
    tx.update(shipmentRef, {
      pickupAcceptedAt: SERVER_TIMESTAMP(),
      pickupAcceptedByUid: auth.uid,
      pickupAcceptedByAccountId: accountId,
      pickupAcceptedByProfileId: profileId,
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(eventRef, {
      type: "pickup_accepted",
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: "accepted" };
});

exports.getGarmentCareServicePartnerDetails = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const jobId = text(data && data.jobId, 128);
  if (!jobId) fail("invalid-argument", "Garment Care service job is required.");
  const job = await db.collection("garment_care_service_jobs").doc(jobId).get();
  if (!job.exists) fail("not-found", "Garment Care service job was not found.");
  const order = await db.collection("garment_care_orders").doc(text(job.get("orderId"), 128)).get();
  if (!order.exists) fail("not-found", "Garment Care order was not found.");
  if (order.get("customerUid") !== auth.uid) await requireAdmin(context);
  const accountId = text(job.get("assignedPartnerAccountId"), 128);
  const profileId = text(job.get("assignedPartnerProfileId"), 128);
  if (!accountId || !profileId) {
    return { assigned: false, name: "", contactPhone: "", additionalContactPhones: [] };
  }
  const accountRef = db.collection("accounts").doc(accountId);
  const [account, profile] = await Promise.all([
    accountRef.get(),
    accountRef.collection("profiles").doc(profileId).get(),
  ]);
  if (!profile.exists || profile.get("role") !== "partner" || profile.get("partnerType") !== "garmentCare") {
    fail("not-found", "The assigned Garment Care service Partner could not be found.");
  }
  const profileData = profile.data() || {};
  const accountData = account.data() || {};
  const contactPhone = garmentCarePartnerContactPhone(
    profileData,
    accountData.mobileE164 || accountData.phoneNumber,
  );
  const alternateSources = [
    profileData.additionalContactNumbers,
    profileData.alternateContactNumbers,
    profileData.alternateMobileE164,
    profileData.alternatePhone,
    accountData.additionalContactNumbers,
    accountData.alternateContactNumbers,
    accountData.alternateMobileE164,
    accountData.alternatePhone,
  ];
  const additionalContactPhones = alternateSources
    .flatMap((value) => Array.isArray(value) ? value : [value])
    .map((value) => text(value, 32))
    .filter((value, index, values) => value && value !== contactPhone && values.indexOf(value) === index)
    .slice(0, 3);
  return {
    assigned: true,
    name: garmentCarePartnerName(profileData, job.get("assignedPartnerName")),
    contactPhone,
    additionalContactPhones,
  };
});

exports.getGarmentCareInspectionContext = functions.https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  await requirePartner(context, accountId, profileId);
  if (!jobId) fail("invalid-argument", "Garment Care service job is required.");
  const jobSnap = await db.collection("garment_care_service_jobs").doc(jobId).get();
  if (!jobSnap.exists || jobSnap.get("assignedPartnerAccountId") !== accountId ||
      jobSnap.get("assignedPartnerProfileId") !== profileId || jobSnap.get("status") !== "inspectionPending") {
    fail("permission-denied", "This inspection is not assigned to your Partner profile or is not ready.");
  }
  const job = jobSnap.data() || {};
  const orderSnap = await db.collection("garment_care_orders").doc(text(job.orderId, 128)).get();
  if (!orderSnap.exists) fail("not-found", "Garment Care order was not found.");
  const pricingVersionId = text(orderSnap.get("pricingPolicyVersionId"), 128);
  const [pricingSnap, templatePointer] = await Promise.all([
    pricingVersionId
      ? db.collection("garment_care_pricing_versions").doc(pricingVersionId).get()
      : Promise.resolve(null),
    db.collection("config").doc("garmentCareInspectionTemplates").get(),
  ]);
  if (!pricingSnap || !pricingSnap.exists) fail("failed-precondition", "The order's approved pricing version is unavailable.");
  const policy = pricingSnap.data() || {};
  const configuredRate = ((policy.itemTypeRates || {})[job.serviceId] || {})[job.itemTypeCode] ||
    (policy.serviceRates || {})[job.serviceId] || {};
  if (!Number.isFinite(Number(configuredRate.customerAmount))) {
    fail("failed-precondition", "The approved rate for this service is unavailable.");
  }
  const pricing = careRateBreakdown(policy, configuredRate, 0);
  const templateVersionId = text(templatePointer.data() && templatePointer.get("activeVersionId"), 128);
  const templateVersionSnap = templateVersionId
    ? await db.collection("garment_care_inspection_template_versions").doc(templateVersionId).get()
    : null;
  const templateVersion = templateVersionSnap && templateVersionSnap.exists ? templateVersionSnap.data() || {} : null;
  return {
    jobId,
    orderId: job.orderId,
    garmentId: job.garmentId,
    serviceId: job.serviceId,
    serviceName: job.serviceName || SERVICES[job.serviceId],
    serviceRate: pricing.serviceAmount,
    estimatedCustomerTotal: pricing.customerTotal,
    currency: "INR",
    inspectionTemplateVersionId: templateVersion ? templateVersionId : "default_v1",
    inspectionTemplateVersion: templateVersion ? Number(templateVersion.version) || 1 : 1,
    templates: { ...defaultInspectionTemplates(), ...(templateVersion && templateVersion.templates || {}) },
  };
});

exports.getGarmentCareOrderCustomerDetails = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = text(data && data.orderId, 128);
  if (!orderId) fail("invalid-argument", "Garment Care order is required.");
  const order = await db.collection("garment_care_orders").doc(orderId).get();
  if (!order.exists) fail("not-found", "Garment Care order was not found.");
  if (order.get("customerUid") !== auth.uid) await requireAdmin(context);

  const address = order.get("pickupAddressSnapshot") || {};
  const accountId = text(order.get("customerAccountId"), 128);
  const profileId = text(order.get("customerProfileId"), 128);
  const accountRef = accountId ? db.collection("accounts").doc(accountId) : null;
  const [account, profile] = await Promise.all([
    accountRef ? accountRef.get() : Promise.resolve(null),
    accountRef && profileId
      ? accountRef.collection("profiles").doc(profileId).get()
      : Promise.resolve(null),
  ]);
  return {
    name: text(address.name || (profile && (profile.get("displayName") || profile.get("fullName") || profile.get("name") || profile.get("contactName"))), 120),
    contactPhone: text(address.mobileNumber || (profile && (profile.get("mobileE164") || profile.get("phone") || profile.get("contactPhone"))) || (account && account.get("mobileE164")), 32),
    formattedAddress: text(address.formattedAddress, 500),
  };
});

exports.assignGarmentCareServiceJob = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const jobId = text(data && data.jobId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  if (!jobId || !accountId || !profileId) fail("invalid-argument", "Job and Partner are required.");
  const profile = await db.collection("accounts").doc(accountId).collection("profiles").doc(profileId).get();
  if (!profile.exists || profile.get("role") !== "partner" ||
      profile.get("partnerType") !== "garmentCare" || profile.get("status") !== "active" ||
      profile.get("operationalStatus") !== "active" || profile.get("activationStatus") !== "active" ||
      profile.get("approvalStatus") !== "approved" || profile.get("kycStatus") !== "verified") {
    fail("failed-precondition", "Select an active, approved and verified Garment Care Partner.");
  }
  if (!isGarmentCareAvailable(profile.data())) {
    fail("failed-precondition", "This Partner is not currently available for new Garment Care orders.");
  }
  const ref = db.collection("garment_care_service_jobs").doc(jobId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail("not-found", "Service Job not found.");
    const job = snap.data() || {};
    requireCareServiceCapability(profile.data(), job.serviceId);
    if ((job.status !== "queued" && job.status !== "rejected") || job.dispatchEligible !== true) {
      fail("failed-precondition", "This Service Job is not yet eligible for Partner assignment.");
    }
    let priorRef = null;
    let priorJob = null;
    let shipmentRef = null;
    let incomingShipmentId = null;
    const reassignFromAccountId = text(job.reassignmentFromPartnerAccountId, 128);
    const reassignFromProfileId = text(job.reassignmentFromPartnerProfileId, 128);
    if (reassignFromAccountId === accountId && reassignFromProfileId === profileId) {
      fail("failed-precondition", "Choose a different Partner for this reassignment.");
    }
    if (reassignFromAccountId && reassignFromProfileId) {
      shipmentRef = db.collection("garment_care_shipments").doc();
      tx.create(shipmentRef, {
        shipmentId: shipmentRef.id,
        orderId: job.orderId,
        orderNumber: job.orderNumber || null,
        itemId: job.itemId,
        garmentId: job.garmentId,
        garmentIds: [job.garmentId],
        ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
        shipmentType: "partner_transfer",
        destinationJobId: jobId,
        fromPartnerAccountId: reassignFromAccountId,
        fromPartnerProfileId: reassignFromProfileId,
        toPartnerAccountId: accountId,
        toPartnerProfileId: profileId,
        status: "planned",
        reassignmentReason: text(job.reassignmentReason, 800),
        createdAt: SERVER_TIMESTAMP(),
        updatedAt: SERVER_TIMESTAMP(),
      });
      incomingShipmentId = shipmentRef.id;
    } else if (job.dependsOnJobId) {
      priorRef = db.collection("garment_care_service_jobs").doc(job.dependsOnJobId);
      priorJob = await tx.get(priorRef);
      if (!priorJob.exists || priorJob.get("status") !== "completed" ||
          !priorJob.get("assignedPartnerAccountId") || !priorJob.get("assignedPartnerProfileId")) {
        fail("failed-precondition", "The preceding service must be completed and assigned before transfer.");
      }
      if (priorJob.get("assignedPartnerAccountId") === accountId &&
          priorJob.get("assignedPartnerProfileId") === profileId) {
        incomingShipmentId = text(priorJob.get("incomingShipmentId"), 128);
      } else {
        shipmentRef = db.collection("garment_care_shipments").doc();
        tx.create(shipmentRef, {
          shipmentId: shipmentRef.id,
          orderId: job.orderId,
          orderNumber: job.orderNumber || null,
          itemId: job.itemId,
          garmentId: job.garmentId,
          garmentIds: [job.garmentId],
          ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
          shipmentType: "partner_transfer",
          sourceJobId: job.dependsOnJobId,
          destinationJobId: jobId,
          fromPartnerAccountId: priorJob.get("assignedPartnerAccountId"),
          fromPartnerProfileId: priorJob.get("assignedPartnerProfileId"),
          toPartnerAccountId: accountId,
          toPartnerProfileId: profileId,
          status: "planned",
          createdAt: SERVER_TIMESTAMP(),
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.update(priorRef, {
          outgoingShipmentIds: admin.firestore.FieldValue.arrayUnion(shipmentRef.id),
          updatedAt: SERVER_TIMESTAMP(),
        });
        incomingShipmentId = shipmentRef.id;
      }
    } else if (job.pickupShipmentId) {
      const pickupRef = db.collection("garment_care_shipments").doc(job.pickupShipmentId);
      const pickup = await tx.get(pickupRef);
      if (!pickup.exists || pickup.get("status") !== "delivered") {
        fail("failed-precondition", "The customer pickup must be verified before assigning the first service Partner.");
      }
      const pickupPartnerAccountId = pickup.get("toPartnerAccountId");
      const pickupPartnerProfileId = pickup.get("toPartnerProfileId");
      if (!pickupPartnerAccountId || !pickupPartnerProfileId) {
        fail("failed-precondition", "The pickup Partner assignment is missing.");
      }
      if (pickupPartnerAccountId === accountId && pickupPartnerProfileId === profileId) {
        incomingShipmentId = job.pickupShipmentId;
      } else {
        shipmentRef = db.collection("garment_care_shipments").doc();
        tx.create(shipmentRef, {
          shipmentId: shipmentRef.id,
          orderId: job.orderId,
          orderNumber: job.orderNumber || null,
          itemId: job.itemId,
          garmentId: job.garmentId,
          garmentIds: [job.garmentId],
          ...garmentSubOrderShipmentFields(job.garmentId, job.subOrderNumber, job.displayName),
          shipmentType: "partner_transfer",
          sourcePickupShipmentId: job.pickupShipmentId,
          destinationJobId: jobId,
          fromPartnerAccountId: pickupPartnerAccountId,
          fromPartnerProfileId: pickupPartnerProfileId,
          toPartnerAccountId: accountId,
          toPartnerProfileId: profileId,
          status: "planned",
          createdAt: SERVER_TIMESTAMP(),
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.update(pickupRef, {
          outgoingShipmentIds: admin.firestore.FieldValue.arrayUnion(shipmentRef.id),
          updatedAt: SERVER_TIMESTAMP(),
        });
        incomingShipmentId = shipmentRef.id;
      }
    }
    tx.update(ref, {
      status: "offered",
      dispatchEligible: false,
      assignedPartnerAccountId: accountId,
      assignedPartnerProfileId: profileId,
      assignedPartnerName: text(profile.get("businessName") || profile.get("displayName") || "Garment Care Partner", 120),
      assignedPartnerContactPhone: garmentCarePartnerContactPhone(profile.data()),
      incomingShipmentId,
      reassignmentFromPartnerAccountId: admin.firestore.FieldValue.delete(),
      reassignmentFromPartnerProfileId: admin.firestore.FieldValue.delete(),
      reassignmentReason: admin.firestore.FieldValue.delete(),
      assignedAt: SERVER_TIMESTAMP(),
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(ref.collection("events").doc(), {
      type: "assigned",
      actorUid: context.auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      shipmentId: shipmentRef ? shipmentRef.id : null,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { status: "offered" };
});

exports.requestGarmentCareJobReassignment = functions.https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const reason = text(data && data.reason, 800);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const { auth } = await requirePartner(context, accountId, profileId);
  if (!jobId || reason.length < 5) fail("invalid-argument", "Explain why this job needs another Partner.");
  const jobRef = db.collection("garment_care_service_jobs").doc(jobId);
  await db.runTransaction(async (tx) => {
    const job = await tx.get(jobRef);
    if (!job.exists || job.get("assignedPartnerAccountId") !== accountId ||
        job.get("assignedPartnerProfileId") !== profileId) {
      fail("permission-denied", "This Service Job is not assigned to your Partner profile.");
    }
    if (!["accepted", "inspectionPending"].includes(job.get("status"))) {
      fail("failed-precondition", "Request another Partner after accepting the job and receiving the garment, before treatment starts.");
    }
    const incomingShipmentId = text(job.get("incomingShipmentId"), 128);
    const incomingShipment = incomingShipmentId
      ? await tx.get(db.collection("garment_care_shipments").doc(incomingShipmentId)) : null;
    if (!incomingShipment || !incomingShipment.exists || incomingShipment.get("status") !== "delivered") {
      fail("failed-precondition", "Confirm garment receipt before requesting reassignment.");
    }
    const order = await tx.get(db.collection("garment_care_orders").doc(job.get("orderId")));
    if (!order.exists) fail("not-found", "Garment Care order not found.");
    const revisionRef = db.collection("garment_care_item_revisions").doc();
    tx.create(revisionRef, {
      revisionId: revisionRef.id,
      orderId: job.get("orderId"),
      orderNumber: job.get("orderNumber") || null,
      jobId,
      garmentId: job.get("garmentId"),
      customerUid: order.get("customerUid"),
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      reason,
      status: "pendingCustomerDecision",
      createdAt: SERVER_TIMESTAMP(),
    });
    tx.update(jobRef, {
      status: "awaitingCustomerEdit",
      dispatchEligible: false,
      revisionRequestId: revisionRef.id,
      revisionReason: reason,
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(jobRef.collection("events").doc(), {
      type: "customer_edit_requested",
      revisionId: revisionRef.id,
      reason,
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      at: SERVER_TIMESTAMP(),
    });
    tx.update(db.collection("garment_care_orders").doc(job.get("orderId")), {
      statusProjection: "customer_action_required",
      updatedAt: SERVER_TIMESTAMP(),
    });
  });
  return { status: "pendingCustomerDecision" };
});

exports.respondToGarmentCareItemRevision = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const revisionId = text(data && data.revisionId, 128);
  const decision = text(data && data.decision, 24);
  const replacementServiceId = text(data && data.replacementServiceId, 80);
  if (!revisionId || !["keep", "change", "remove"].includes(decision)) {
    fail("invalid-argument", "Choose keep, change, or remove for the affected garment.");
  }
  const revisionRef = db.collection("garment_care_item_revisions").doc(revisionId);
  await db.runTransaction(async (tx) => {
    const revision = await tx.get(revisionRef);
    if (!revision.exists || revision.get("customerUid") !== auth.uid ||
        revision.get("status") !== "pendingCustomerDecision") {
      fail("permission-denied", "This Garment Care change request is not available to your account.");
    }
    const jobRef = db.collection("garment_care_service_jobs").doc(revision.get("jobId"));
    const job = await tx.get(jobRef);
    if (!job.exists || job.get("status") !== "awaitingCustomerEdit") {
      fail("failed-precondition", "This Service Job is no longer waiting for your decision.");
    }
    const orderRef = db.collection("garment_care_orders").doc(job.get("orderId"));
    const order = await tx.get(orderRef);
    if (!order.exists || order.get("customerUid") !== auth.uid) fail("permission-denied", "This order is not yours.");
    const allJobsQuery = db.collection("garment_care_service_jobs")
      .where("orderId", "==", job.get("orderId")).where("garmentId", "==", job.get("garmentId"));
    const allJobs = await tx.get(allJobsQuery);
    if (allJobs.docs.some((item) => ["inProgress", "qualityCheck", "completed"].includes(item.get("status")))) {
      fail("failed-precondition", "This garment has already entered treatment and cannot be changed in this request.");
    }
    const groupRef = orderRef.collection("delivery_groups").doc(job.get("deliveryGroupId"));
    const group = await tx.get(groupRef);
    if (!group.exists) fail("not-found", "Service order details were not found.");
    const itemRef = orderRef.collection("items").doc(job.get("itemId"));
    const item = await tx.get(itemRef);
    const event = { type: "customer_decided_item_revision", revisionId, decision, actorUid: auth.uid, at: SERVER_TIMESTAMP() };
    if (decision === "remove") {
      const removedItemIds = new Set(allJobs.docs.map((candidate) => text(candidate.get("itemId"), 128)).filter(Boolean));
      const removedItemRefs = [...removedItemIds].map((id) => orderRef.collection("items").doc(id));
      const removedItems = await Promise.all(removedItemRefs.map((ref) => tx.get(ref)));
      const versionId = text(order.get("pricingPolicyVersionId"), 128);
      const pricing = versionId ? await tx.get(db.collection("garment_care_pricing_versions").doc(versionId)) : null;
      if (!pricing || !pricing.exists) fail("failed-precondition", "The order pricing version is unavailable.");
      const remaining = (await tx.get(db.collection("garment_care_service_jobs")
        .where("orderId", "==", job.get("orderId")))).docs
        .filter((candidate) => candidate.get("garmentId") !== job.get("garmentId") && candidate.get("status") !== "cancelled");
      const pricingData = pricing.data() || {};
      const rates = pricingData.serviceRates || {};
      const itemRates = pricingData.itemTypeRates || {};
      const configuredRates = remaining.map((candidate) => {
        const serviceId = candidate.get("serviceId");
        const itemType = candidate.get("itemTypeCode") || "other";
        return itemRates[serviceId] && itemRates[serviceId][itemType] || rates[serviceId] || {};
      });
      const estimate = estimateCareRates(pricingData, configuredRates,
        configuredRates.length ? Number(pricingData.logisticsAmount) || 0 : 0);
      const subtotal = estimate.serviceSubtotal;
      const tax = estimate.taxTotal;
      const logistics = estimate.logisticsTotal;
      const grandTotal = estimate.grandTotal;
      const checkoutId = text(order.get("cartCheckoutId"), 128);
      let checkoutEstimate = null;
      if (checkoutId) {
        const checkoutRef = db.collection("garment_care_checkouts").doc(checkoutId);
        const checkout = await tx.get(checkoutRef);
        if (checkout.exists) {
          const otherOrderIds = (checkout.get("orderIds") || []).filter((id) => id !== job.get("orderId"));
          const otherOrderJobs = await Promise.all(otherOrderIds.map((otherOrderId) =>
            tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", otherOrderId))));
          const garmentStillInAnotherGroup = otherOrderJobs.some((jobs) =>
            jobs.docs.some((candidate) => candidate.get("garmentId") === job.get("garmentId") && candidate.get("status") !== "cancelled"));
          const oldOrderTotal = Number(order.get("estimatedGrandTotal")) || 0;
          const checkoutTotal = Number(checkout.get("estimatedGrandTotal")) || 0;
          checkoutEstimate = {
            ref: checkoutRef,
            total: roundMoney(checkoutTotal - oldOrderTotal + grandTotal),
            itemCount: Math.max(0, (Number(checkout.get("itemCount")) || 0) - (garmentStillInAnotherGroup ? 0 : 1)),
            serviceCount: Math.max(0, (Number(checkout.get("serviceCount")) || 0) - allJobs.size),
          };
        }
      }
      const shipmentRef = db.collection("garment_care_shipments").doc();
      const packageRef = db.collection("garment_care_packages").doc();
      tx.create(shipmentRef, {
        shipmentId: shipmentRef.id, orderId: job.get("orderId"), orderNumber: job.get("orderNumber"),
        deliveryGroupId: job.get("deliveryGroupId"), itemId: job.get("itemId"),
        garmentId: job.get("garmentId"), garmentIds: [job.get("garmentId")],
        ...garmentSubOrderShipmentFields(job.get("garmentId"), job.get("subOrderNumber"), job.get("displayName")),
        packageId: packageRef.id,
        shipmentType: "customer_return", deliveryMode: "service_partner",
        toCustomerUid: auth.uid, fromPartnerAccountId: job.get("assignedPartnerAccountId") || revision.get("partnerAccountId"),
        fromPartnerProfileId: job.get("assignedPartnerProfileId") || revision.get("partnerProfileId"),
        fromPartnerName: job.get("assignedPartnerName") || revision.get("partnerName") || null,
        fromPartnerContactPhone: job.get("assignedPartnerContactPhone") || revision.get("partnerContactPhone") || null,
        deliveryPartnerName: job.get("assignedPartnerName") || revision.get("partnerName") || null,
        deliveryPartnerContactPhone: job.get("assignedPartnerContactPhone") || revision.get("partnerContactPhone") || null,
        toPartnerAccountId: job.get("assignedPartnerAccountId") || revision.get("partnerAccountId"),
        toPartnerProfileId: job.get("assignedPartnerProfileId") || revision.get("partnerProfileId"),
        status: "planned", reason: "Customer removed item after Partner requested a change.",
        createdAt: SERVER_TIMESTAMP(), updatedAt: SERVER_TIMESTAMP(),
      });
      tx.create(packageRef, {
        packageId: packageRef.id, orderId: job.get("orderId"), orderNumber: job.get("orderNumber"),
        deliveryGroupId: job.get("deliveryGroupId"), garmentIds: [job.get("garmentId")],
        packageType: "customer_return_container", temporary: true, createdAt: SERVER_TIMESTAMP(),
      });
      for (const candidate of allJobs.docs) tx.update(candidate.ref, { status: "cancelled", dispatchEligible: false, updatedAt: SERVER_TIMESTAMP() });
      removedItems.forEach((removedItem, index) => {
        if (removedItem.exists) tx.update(removedItemRefs[index], { status: "removed_by_customer", removedAt: SERVER_TIMESTAMP() });
      });
      const currentJobIds = (group.get("jobIds") || []).filter((id) => !allJobs.docs.some((candidate) => candidate.id === id));
      const currentItemIds = (group.get("itemIds") || []).filter((id) => !removedItemIds.has(id));
      const remainingGarments = new Set(remaining.map((candidate) => candidate.get("garmentId")));
      const groupPatch = {
        jobIds: currentJobIds, itemIds: currentItemIds,
        serviceIds: [...new Set(remaining.map((candidate) => candidate.get("serviceId")))],
        estimatedServiceSubtotal: subtotal, estimatedTaxTotal: tax,
        estimatedLogisticsTotal: logistics, logisticsAmount: logistics,
        estimatedGrandTotal: grandTotal,
        statusProjection: remaining.length ? group.get("statusProjection") : "cancelled",
        updatedAt: SERVER_TIMESTAMP(),
      };
      tx.update(groupRef, groupPatch);
      tx.update(orderRef, {
        itemCount: remainingGarments.size, serviceCount: remaining.length,
        estimatedGrandTotal: grandTotal,
        statusProjection: remaining.length ? "customer_action_required" : "return_pending",
        shipmentIds: admin.firestore.FieldValue.arrayUnion(shipmentRef.id),
        packageIds: admin.firestore.FieldValue.arrayUnion(packageRef.id),
        updatedAt: SERVER_TIMESTAMP(),
      });
      if (checkoutEstimate) {
        tx.update(checkoutEstimate.ref, {
          estimatedGrandTotal: checkoutEstimate.total,
          itemCount: checkoutEstimate.itemCount,
          serviceCount: checkoutEstimate.serviceCount,
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
      tx.create(orderRef.collection("events").doc(), { ...event, type: "garment_removed_and_return_requested", shipmentId: shipmentRef.id });
    } else {
      let replacement = job.get("serviceId");
      let revisedEstimate = null;
      let checkoutEstimate = null;
      if (decision === "change") {
        if (SERVICE_GROUPS[replacementServiceId] !== job.get("serviceGroupCode")) {
          fail("invalid-argument", "Choose another service from the same service group.");
        }
        replacement = replacementServiceId;
        const itemType = job.get("itemTypeCode") || "other";
        const versionId = text(order.get("pricingPolicyVersionId"), 128);
        const pricing = versionId ? await tx.get(db.collection("garment_care_pricing_versions").doc(versionId)) : null;
        if (!pricing || !pricing.exists) fail("failed-precondition", "The order pricing version is unavailable.");
        const pricingData = pricing.data() || {};
        const itemRate = ((pricingData.itemTypeRates || {})[replacement] || {})[itemType];
        const baseRate = (pricingData.serviceRates || {})[replacement];
        const customerAmount = Number(itemRate && itemRate.customerAmount != null ? itemRate.customerAmount : baseRate && baseRate.customerAmount);
        if (!Number.isFinite(customerAmount)) fail("failed-precondition", "No active estimate is configured for that replacement service.");
        const groupJobs = await tx.get(db.collection("garment_care_service_jobs")
          .where("orderId", "==", job.get("orderId")).where("deliveryGroupId", "==", job.get("deliveryGroupId")));
        if (groupJobs.docs.some((candidate) => candidate.id !== job.id &&
            candidate.get("status") !== "cancelled" && candidate.get("serviceId") === replacement)) {
          fail("invalid-argument", "This service is already included in the garment's care plan.");
        }
        const rates = pricingData.serviceRates || {};
        const itemRates = pricingData.itemTypeRates || {};
        const configuredRates = groupJobs.docs
          .filter((candidate) => candidate.get("status") !== "cancelled")
          .map((candidate) => {
            const serviceId = candidate.id === job.id ? replacement : candidate.get("serviceId");
            const candidateType = candidate.get("itemTypeCode") || "other";
            const rate = itemRates[serviceId] && itemRates[serviceId][candidateType] || rates[serviceId] || {};
            if (!Number.isFinite(Number(rate.customerAmount)) || Number(rate.customerAmount) < 0) {
              fail("failed-precondition", `No active estimate is configured for ${SERVICES[serviceId] || "this service"}.`);
            }
            return rate;
          });
        const estimate = estimateCareRates(pricingData, configuredRates, Number(pricingData.logisticsAmount) || 0);
        const subtotal = estimate.serviceSubtotal;
        const tax = estimate.taxTotal;
        const logistics = estimate.logisticsTotal;
        const grandTotal = estimate.grandTotal;
        const serviceIds = [...new Set(groupJobs.docs
          .filter((candidate) => candidate.get("status") !== "cancelled")
          .map((candidate) => candidate.id === job.id ? replacement : candidate.get("serviceId")))];
        revisedEstimate = {
          estimatedServiceSubtotal: subtotal,
          estimatedTaxTotal: tax,
          estimatedGrandTotal: grandTotal,
          estimatedLogisticsTotal: logistics,
          logisticsAmount: logistics,
          serviceIds,
          estimateStatus: "preliminary_pending_inspection",
          updatedAt: SERVER_TIMESTAMP(),
        };
        const checkoutId = text(order.get("cartCheckoutId"), 128);
        if (checkoutId) {
          const checkoutRef = db.collection("garment_care_checkouts").doc(checkoutId);
          const checkout = await tx.get(checkoutRef);
          if (checkout.exists) {
            const oldOrderTotal = Number(order.get("estimatedGrandTotal")) || 0;
            const checkoutTotal = Number(checkout.get("estimatedGrandTotal")) || 0;
            checkoutEstimate = { ref: checkoutRef, total: roundMoney(checkoutTotal - oldOrderTotal + grandTotal) };
          }
        }
      }
      tx.update(jobRef, {
        ...(decision === "change" ? { serviceId: replacement, serviceName: SERVICES[replacement] } : {}),
        status: "queued", dispatchEligible: true,
        acceptedAt: admin.firestore.FieldValue.delete(),
        inspectionStartedAt: admin.firestore.FieldValue.delete(),
        assignedPartnerAccountId: admin.firestore.FieldValue.delete(),
        assignedPartnerProfileId: admin.firestore.FieldValue.delete(),
        reassignmentFromPartnerAccountId: revision.get("partnerAccountId"),
        reassignmentFromPartnerProfileId: revision.get("partnerProfileId"),
        reassignmentReason: revision.get("reason"),
        revisionRequestId: admin.firestore.FieldValue.delete(), revisionReason: admin.firestore.FieldValue.delete(),
        updatedAt: SERVER_TIMESTAMP(),
      });
      if (decision === "change" && item.exists) tx.update(itemRef, { serviceIds: [replacement], serviceSteps: [{ groupCode: job.get("serviceGroupCode"), serviceId: replacement }] });
      if (revisedEstimate) {
        tx.update(groupRef, { ...revisedEstimate, statusProjection: "open" });
        if (checkoutEstimate) tx.update(checkoutEstimate.ref, { estimatedGrandTotal: checkoutEstimate.total, updatedAt: SERVER_TIMESTAMP() });
      }
      tx.update(orderRef, {
        ...(revisedEstimate ? { estimatedGrandTotal: revisedEstimate.estimatedGrandTotal } : {}),
        statusProjection: "partner_assignment",
        updatedAt: SERVER_TIMESTAMP(),
      });
      tx.create(jobRef.collection("events").doc(), { ...event, replacementServiceId: decision === "change" ? replacement : null });
    }
    tx.update(revisionRef, { status: decision === "remove" ? "accepted" : "resolved", decision, replacementServiceId: decision === "change" ? replacementServiceId : null, decidedAt: SERVER_TIMESTAMP(), decidedByUid: auth.uid });
  });
  return { decision };
});

exports.advanceGarmentCareServiceJob = functions.runWith({ timeoutSeconds: 120 }).https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const target = text(data && data.targetStatus, 40);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const { auth } = await requirePartner(context, accountId, profileId);
  const rawTreatmentRecord = data && data.treatmentRecord && typeof data.treatmentRecord === "object"
    ? data.treatmentRecord : {};
  const treatmentRecord = {
    methodUsed: text(rawTreatmentRecord.methodUsed, 240),
    processDetails: text(rawTreatmentRecord.processDetails, 800),
    finishingDetails: text(rawTreatmentRecord.finishingDetails, 500),
    qualityNotes: text(rawTreatmentRecord.qualityNotes, 500),
    templateId: text(rawTreatmentRecord.templateId, 128),
    templateName: text(rawTreatmentRecord.templateName, 80),
    templateVersionId: text(rawTreatmentRecord.templateVersionId, 128),
  };
  const ref = db.collection("garment_care_service_jobs").doc(jobId);
  const supportedTargets = new Set(Object.values(JOB_TRANSITIONS).flat());
  if (!jobId || !supportedTargets.has(target)) {
    fail("invalid-argument", "Choose a supported Service Job action.");
  }
  if (target === "completed" && !treatmentRecord.methodUsed) {
    fail("invalid-argument", "Record the care method actually used before completing this garment service.");
  }
  const progressRank = {
    offered: 0,
    accepted: 1,
    inspectionPending: 2,
    awaitingConsent: 3,
    readyToStart: 4,
    inProgress: 5,
    qualityCheck: 6,
    completed: 7,
  };
  const transitionResult = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("assignedPartnerAccountId") !== accountId ||
        snap.get("assignedPartnerProfileId") !== profileId) {
      fail("permission-denied", "This job is not assigned to your Partner profile.");
    }
    const currentStatus = snap.get("status");
    // A callable may commit successfully while the mobile client times out
    // before receiving its response. Treat retries as success once this job
    // has reached the requested step (or a later step), instead of surfacing
    // a misleading invalid-transition error or changing the job back.
    if (currentStatus === target ||
        (Number.isInteger(progressRank[currentStatus]) &&
         Number.isInteger(progressRank[target]) &&
         progressRank[currentStatus] > progressRank[target])) {
      return { status: currentStatus, alreadyApplied: true };
    }
    if (!(JOB_TRANSITIONS[currentStatus] || []).includes(target)) {
      fail("failed-precondition", `Cannot move this job to ${target} from its current state.`);
    }
    if (target === "inspectionPending") {
      const shipmentId = text(snap.get("incomingShipmentId"), 128);
      const shipment = shipmentId
        ? await tx.get(db.collection("garment_care_shipments").doc(shipmentId))
        : null;
      if (!shipment || !shipment.exists || shipment.get("status") !== "delivered") {
        fail("failed-precondition", "Verify the pickup or Partner-to-Partner receipt before inspection.");
      }
    }

    let order = null;
    let identityRef = null;
    let privateRate = null;
    let quote = null;
    let groupJobs = null;
    let invoiceRef = null;
    let invoiceSnap = null;
    let paymentRef = null;
    let paymentSnap = null;
    let invoicePricing = null;
    let invoiceDeliveryGroup = null;
    let orderPaymentState = null;
    let orderReturnShipments = null;
    let invoiceLines = [];
    let shouldCreateInvoice = false;
    let allOrderServicesCompleteAfterThisJob = false;
    let groupCompleteAfterThisJob = false;
    let followOnServicePending = false;
    let orderJobsForReturn = [];
    let dependentJobs = [];
    let returnShipmentRef = null;
    let returnPackageRef = null;
    let relatedGarmentPaymentRequirements = [];
    let relatedGarmentSiblingJobs = [];
    if (target === "completed") {
      const orderRef = db.collection("garment_care_orders").doc(snap.get("orderId"));
      identityRef = db.collection("garment_identities").doc(snap.get("garmentId"));
      const quoteId = text(snap.get("quoteVersionId"), 128);
      const consentId = text(snap.get("consentId"), 128);
      if (!quoteId) fail("failed-precondition", "A completed inspection quote is required.");
      const [orderSnap, identitySnap, quoteSnap, consentSnap, privateRateSnap] = await Promise.all([
        tx.get(orderRef),
        tx.get(identityRef),
        tx.get(db.collection("garment_care_quote_versions").doc(quoteId)),
        consentId
          ? tx.get(db.collection("garment_care_consents").doc(consentId))
          : Promise.resolve(null),
        tx.get(db.collection("garment_care_partner_quote_rates").doc(quoteId)),
      ]);
      if (!orderSnap.exists || !identitySnap.exists || !quoteSnap.exists || !privateRateSnap.exists) {
        fail("failed-precondition", "Garment DNA, quote, or Partner payable data is unavailable.");
      }
      if (consentSnap
          ? (!consentSnap.exists || consentSnap.get("status") !== "accepted")
          : quoteSnap.get("status") !== "accepted") {
        fail("failed-precondition", "Customer consent must be accepted before completion.");
      }
      order = orderSnap.data() || {};
      quote = quoteSnap.data() || {};
      privateRate = privateRateSnap.data() || {};
      if (quote.jobId !== jobId || privateRate.jobId !== jobId ||
          privateRate.partnerAccountId !== accountId || privateRate.partnerProfileId !== profileId) {
        fail("failed-precondition", "Quote and payable allocation do not match this assigned job.");
      }

      const jobsQuery = db.collection("garment_care_service_jobs")
        .where("orderId", "==", snap.get("orderId"))
        .where("deliveryGroupId", "==", snap.get("deliveryGroupId"));
      const jobsSnap = await tx.get(jobsQuery);
      groupJobs = jobsSnap.docs;
      const customerDeclinedGroup = hasCustomerDeclinedService(groupJobs);
      const dependentJobsSnap = await tx.get(
        db.collection("garment_care_service_jobs")
          .where("dependsOnJobId", "==", jobId)
          .where("status", "==", "queued"),
      );
      dependentJobs = dependentJobsSnap.docs;
      const completedGroupJobs = groupJobs.filter((job) =>
        job.id === jobId || job.get("status") === "completed");
      groupCompleteAfterThisJob = groupJobs.length > 0 && groupJobs.every((job) =>
        job.id === jobId || TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")));
      if (groupCompleteAfterThisJob) {
        const orderJobsSnap = await tx.get(db.collection("garment_care_service_jobs")
          .where("orderId", "==", snap.get("orderId")));
        orderJobsForReturn = orderJobsSnap.docs;
        allOrderServicesCompleteAfterThisJob = orderJobsSnap.docs.length > 0 &&
          orderJobsSnap.docs.every((job) => job.id === jobId ||
            TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")));
        if (allOrderServicesCompleteAfterThisJob) {
          followOnServicePending = await hasPendingCheckoutServiceJobs(
            tx,
            orderRef.id,
            order,
            [...new Set(orderJobsSnap.docs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))],
          );
        }
        orderPaymentState = await readGarmentCareOrderPaymentState(tx, orderSnap, orderJobsSnap);
        invoiceRef = db.collection("garment_care_invoices").doc(snap.get("deliveryGroupId"));
        paymentRef = db.collection("garment_care_payments").doc(`payment_${snap.get("deliveryGroupId")}`);
        const deliveryGroupRef = orderRef.collection("delivery_groups").doc(snap.get("deliveryGroupId"));
        const versionId = text(order.pricingPolicyVersionId, 128);
        if (!versionId) fail("failed-precondition", "The order has no pinned pricing version.");
        const versionRef = db.collection("garment_care_pricing_versions").doc(versionId);
        [invoiceSnap, paymentSnap, invoicePricing, invoiceDeliveryGroup, orderReturnShipments] = await Promise.all([
          tx.get(invoiceRef),
          tx.get(paymentRef),
          tx.get(versionRef),
          tx.get(deliveryGroupRef),
          tx.get(db.collection("garment_care_shipments").where("orderId", "==", snap.get("orderId"))),
        ]);
        if (!invoicePricing.exists) fail("failed-precondition", "The order's pricing version is unavailable.");
        if (!invoiceDeliveryGroup.exists) fail("failed-precondition", "The garment sub-order details are unavailable.");
        if (!invoiceSnap.exists && !customerDeclinedGroup) {
          const quoteIds = [...new Set(completedGroupJobs.map((job) =>
            job.id === jobId ? quoteId : text(job.get("quoteVersionId"), 128)).filter(Boolean))];
          const quoteSnaps = await Promise.all(quoteIds.map((id) =>
            tx.get(db.collection("garment_care_quote_versions").doc(id))));
          if (quoteSnaps.some((item) => !item.exists)) {
            fail("failed-precondition", "A completed service is missing its accepted quote.");
          }
          const quoteById = new Map(quoteSnaps.map((item) => [item.id, item.data()]));
          const identityIds = [...new Set(completedGroupJobs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))];
          const identitySnaps = await Promise.all(identityIds.map((id) =>
            id === text(snap.get("garmentId"), 128)
              ? Promise.resolve(identitySnap)
              : tx.get(db.collection("garment_identities").doc(id))));
          const identityById = new Map(identitySnaps.filter((item) => item && item.exists)
            .map((item) => [item.id, item]));
          for (const job of completedGroupJobs) {
            const jobQuoteId = job.id === jobId ? quoteId : text(job.get("quoteVersionId"), 128);
            const jobQuote = quoteById.get(jobQuoteId) || {};
            if (!jobQuoteId || jobQuote.jobId !== job.id || !Number.isFinite(Number(jobQuote.serviceAmount))) {
              fail("failed-precondition", "A delivery-group quote is incomplete.");
            }
            invoiceLines.push({
              jobId: job.id,
              itemId: job.get("itemId"),
              garmentId: job.get("garmentId"),
              subOrderNumber: text(job.get("subOrderNumber"), 8) || null,
              quoteId: jobQuoteId,
              serviceId: job.get("serviceId"),
              serviceName: job.get("serviceName"),
              serviceAmount: Number(jobQuote.serviceAmount),
              taxAmount: Number(jobQuote.taxAmount) || 0,
              logisticsAmount: Number(jobQuote.logisticsAmount) || 0,
              currency: jobQuote.currency || "INR",
              garmentDna: garmentDnaInvoiceSnapshot(
                identityById.get(text(job.get("garmentId"), 128)), job,
              ),
              inspection: inspectionInvoiceSnapshot(jobQuote),
              treatmentRecord: job.id === jobId
                ? treatmentRecord
                : job.get("treatmentRecord") || null,
            });
          }
          shouldCreateInvoice = true;
        }
      }
    }

    if (target === "completed" && groupCompleteAfterThisJob && dependentJobs.length === 0 &&
        !hasCustomerDeclinedService(groupJobs || [])) {
      returnShipmentRef = db.collection("garment_care_shipments").doc();
      returnPackageRef = db.collection("garment_care_packages").doc();
      const garmentId = text(snap.get("garmentId"), 128);
      const rejectedGarments = customerDeclinedGarmentsForPartner(
        orderJobsForReturn,
        accountId,
        profileId,
        [garmentId],
      ).filter((item) => !item.returnShipmentId);
      const returnGarments = [
        {
          garmentId,
          subOrderNumber: text(snap.get("subOrderNumber"), 8),
          displayName: text(snap.get("displayName"), 120),
        },
        ...rejectedGarments,
      ];
      const returnGarmentIds = [...new Set(returnGarments.map((item) => item.garmentId))];
      const relatedGarmentData = await readRelatedGarmentPaymentRequirements(
        tx,
        text(snap.get("orderId"), 128),
        order || {},
        returnGarmentIds,
      );
      relatedGarmentPaymentRequirements = relatedGarmentData.requirements;
      const returnedGarmentIdSet = new Set(returnGarmentIds);
      relatedGarmentSiblingJobs = (relatedGarmentData.siblingJobs || []).flatMap((jobs) =>
        jobs.docs.filter((job) => returnedGarmentIdSet.has(text(job.get("garmentId"), 128))));
      const subOrderNumbersByGarmentId = Object.fromEntries(returnGarments
        .filter((item) => item.subOrderNumber)
        .map((item) => [item.garmentId, item.subOrderNumber]));
      const garmentDisplayNamesById = Object.fromEntries(returnGarments
        .filter((item) => item.displayName)
        .map((item) => [item.garmentId, item.displayName]));
      tx.create(returnShipmentRef, {
        shipmentId: returnShipmentRef.id,
        orderId: snap.get("orderId"),
        orderNumber: order && order.orderNumber || null,
        deliveryGroupId: snap.get("deliveryGroupId"),
        itemId: snap.get("itemId"),
        garmentId,
        garmentIds: returnGarmentIds,
        ...(subOrderNumbersByGarmentId[garmentId]
          ? { subOrderNumber: subOrderNumbersByGarmentId[garmentId] }
          : {}),
        subOrderNumbersByGarmentId,
        garmentDisplayNamesById,
        returnIncludesCustomerDeclinedGarmentIds: rejectedGarments.map((item) => item.garmentId),
        relatedPaymentRequirements: relatedGarmentPaymentRequirements,
        requiredPaymentGroupIds: relatedGarmentPaymentRequirements.map((item) => item.deliveryGroupId),
        returnJobIds: [...new Set([
          ...orderJobsForReturn.filter((job) => returnGarmentIds.includes(text(job.get("garmentId"), 128)))
            .map((job) => job.id),
          ...relatedGarmentSiblingJobs.map((job) => job.id),
        ])],
        cartCheckoutId: text(order.cartCheckoutId, 128) || null,
        packageId: returnPackageRef.id,
        shipmentType: "customer_return",
        deliveryMode: "service_partner",
        toCustomerUid: order && order.customerUid,
        fromPartnerAccountId: accountId,
        fromPartnerProfileId: profileId,
        fromPartnerName: text(snap.get("assignedPartnerName"), 120),
        fromPartnerContactPhone: text(snap.get("assignedPartnerContactPhone"), 32),
        deliveryPartnerName: text(snap.get("assignedPartnerName"), 120),
        deliveryPartnerContactPhone: text(snap.get("assignedPartnerContactPhone"), 32),
        toPartnerAccountId: accountId,
        toPartnerProfileId: profileId,
        status: "planned",
        careComplete: groupCompleteAfterThisJob,
        paymentStatusAtDelivery: groupCompleteAfterThisJob
          ? "requiresCustomerAction"
          : "invoice_pending",
        ...(groupCompleteAfterThisJob && invoiceRef
          ? { invoiceId: invoiceRef.id }
          : {}),
        createdAt: SERVER_TIMESTAMP(),
        updatedAt: SERVER_TIMESTAMP(),
      });
      tx.create(returnPackageRef, {
        packageId: returnPackageRef.id,
        orderId: snap.get("orderId"),
        orderNumber: order && order.orderNumber || null,
        deliveryGroupId: snap.get("deliveryGroupId"),
        garmentIds: returnGarmentIds,
        packageType: "customer_return_container",
        temporary: true,
        createdAt: SERVER_TIMESTAMP(),
      });
      for (const rejectedGarment of rejectedGarments) {
        for (const candidate of orderJobsForReturn.filter((item) =>
          text(item.get("garmentId"), 128) === rejectedGarment.garmentId)) {
          tx.update(candidate.ref, {
            returnWithShipmentId: returnShipmentRef.id,
            returnWithDeliveryGroupId: snap.get("deliveryGroupId"),
            updatedAt: SERVER_TIMESTAMP(),
          });
        }
      }
      for (const relatedJob of relatedGarmentSiblingJobs) {
        tx.update(relatedJob.ref, {
          returnWithShipmentId: returnShipmentRef.id,
          returnWithDeliveryGroupId: snap.get("deliveryGroupId"),
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
    }

    tx.update(ref, {
      status: target,
      ...(target === "completed" ? { treatmentRecord, treatmentRecordedAt: SERVER_TIMESTAMP() } : {}),
      ...(target === "accepted" ? { acceptedAt: SERVER_TIMESTAMP(), inspectionStartedAt: admin.firestore.FieldValue.delete() } : {}),
      ...(target === "inspectionPending" ? {
        acceptedAt: snap.get("acceptedAt") || snap.get("updatedAt") || SERVER_TIMESTAMP(),
        inspectionStartedAt: SERVER_TIMESTAMP(),
      } : {}),
      dispatchEligible: target === "rejected",
      ...(target === "rejected" ? {
        reassignmentFromPartnerAccountId: accountId,
        reassignmentFromPartnerProfileId: profileId,
        reassignmentReason: text(data && data.note, 800) || "Partner declined the assignment.",
        assignedPartnerAccountId: admin.firestore.FieldValue.delete(),
        assignedPartnerProfileId: admin.firestore.FieldValue.delete(),
      } : {}),
      ...(returnShipmentRef
        ? { outgoingShipmentIds: admin.firestore.FieldValue.arrayUnion(returnShipmentRef.id) }
        : {}),
      updatedAt: SERVER_TIMESTAMP(),
    });
    if (returnShipmentRef) {
      tx.update(db.collection("garment_care_orders").doc(snap.get("orderId")), {
        shipmentIds: admin.firestore.FieldValue.arrayUnion(returnShipmentRef.id),
        updatedAt: SERVER_TIMESTAMP(),
      });
    }
    tx.create(ref.collection("events").doc(), {
      type: "status_changed",
      fromStatus: snap.get("status"),
      toStatus: target,
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      at: SERVER_TIMESTAMP(),
      note: text(data && data.note, 800),
      ...(target === "completed" ? { treatmentRecord } : {}),
    });
    if (target === "completed") {
      for (const dependent of dependentJobs) {
        tx.update(dependent.ref, {
          dispatchEligible: true,
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
      const historyRef = db.collection("garment_care_history_events").doc();
      tx.create(historyRef, {
        eventId: historyRef.id,
        eventType: "service_completed",
        customerUid: order.customerUid,
        garmentId: snap.get("garmentId"),
        orderId: snap.get("orderId"),
        itemId: snap.get("itemId"),
        itemTypeCode: snap.get("itemTypeCode") || null,
        jobId,
        serviceId: snap.get("serviceId"),
        serviceName: snap.get("serviceName"),
        knowledgeCardVersionId: snap.get("knowledgeCardVersionId") || "curated_baseline_2026_10_v1",
        partnerAccountId: accountId,
        partnerProfileId: profileId,
        partnerName: text(snap.get("assignedPartnerName"), 120) || null,
        quoteId: text(snap.get("quoteVersionId"), 128),
        customerConsentId: text(snap.get("consentId"), 128) || null,
        customerMessage: quote.customerMessage || quote.inspectionNotes || null,
        approvedTreatment: {
          serviceId: snap.get("serviceId"),
          serviceName: snap.get("serviceName"),
          actionCode: quote.recommendedActionCode || "proceed_as_requested",
          inspectionMode: quote.inspectionMode || "legacy",
          conditionCode: quote.conditionCode || null,
          observationCodes: Array.isArray(quote.observationCodes) ? quote.observationCodes : [],
          priceImpactCode: quote.priceImpactCode || "no_additional_charge",
          customerMessage: quote.customerMessage || quote.inspectionNotes || null,
          inspectionTemplateId: quote.inspectionTemplateId || null,
          inspectionTemplateVersion: Number(quote.inspectionTemplateVersion) || null,
          inspectionTemplateVersionId: quote.inspectionTemplateVersionId || null,
          serviceAmount: Number(quote.serviceAmount) || 0,
          currency: quote.currency || "INR",
        },
        treatmentRecord,
        qualityResult: "passed",
        evidencePaths: Array.isArray(quote.inspectionEvidencePaths) ? quote.inspectionEvidencePaths : [],
        customerAuthorizedException: quote.additionalServiceReason || quote.optionalNote || null,
        completedAt: SERVER_TIMESTAMP(),
        createdAt: SERVER_TIMESTAMP(),
      });
      tx.update(identityRef, {
        updatedAt: SERVER_TIMESTAMP(),
        lastCareAt: SERVER_TIMESTAMP(),
        lastCareServiceId: snap.get("serviceId"),
        careHistoryCount: admin.firestore.FieldValue.increment(1),
        dnaVersion: admin.firestore.FieldValue.increment(1),
      });
      const payableRef = db.collection("garment_care_partner_payables").doc(`accrual_${jobId}`);
      tx.create(payableRef, {
        entryId: payableRef.id,
        entryType: "service_job_accrual",
        orderId: snap.get("orderId"),
        orderNumber: order.orderNumber || null,
        deliveryGroupId: snap.get("deliveryGroupId"),
        itemId: snap.get("itemId"),
        garmentId: snap.get("garmentId"),
        jobId,
        quoteId: snap.get("quoteVersionId"),
        partnerAccountId: accountId,
        partnerProfileId: profileId,
        pricingPolicyVersionId: privateRate.pricingPolicyVersionId,
        grossPartnerPayable: Number(privateRate.partnerPayableAmount),
        platformCommissionAmount: Number(privateRate.platformCommissionAmount),
        currency: "INR",
        ledgerStatus: "accrued",
        settlementStatus: "held",
        holdReason: "awaiting_delivery_group_payment_delivery_and_reconciliation",
        createdAt: SERVER_TIMESTAMP(),
      });
      if (shouldCreateInvoice && invoiceRef && invoiceSnap && !invoiceSnap.exists) {
        const lines = invoiceLines;
        const subtotal = lines.reduce((sum, line) => sum + line.serviceAmount, 0);
        const tax = lines.reduce((sum, line) => sum + line.taxAmount, 0);
        const pricing = invoicePricing.data() || {};
        const fixedLogistics = Number(invoiceDeliveryGroup.get("baseLogisticsAmount"));
        const logistics = roundCareMoney(lines.reduce((sum, line) =>
          sum + (Number(line.logisticsAmount) || 0), 0) +
          (Number.isFinite(fixedLogistics) ? fixedLogistics : Number(pricing.logisticsAmount) || 0));
        const roundMoney = (value) => Math.round(value * 100) / 100;
        const invoiceTotal = roundMoney(subtotal + tax + logistics);
        if (!paymentRef || !paymentSnap || paymentSnap.exists) {
          fail("failed-precondition", "A payment record already exists for this invoice; Admin reconciliation is required.");
        }
      tx.create(paymentRef, {
          paymentId: paymentRef.id,
          invoiceId: invoiceRef.id,
          orderId: snap.get("orderId"),
          orderNumber: order.orderNumber || null,
          deliveryGroupId: snap.get("deliveryGroupId"),
          customerUid: order.customerUid,
          amount: invoiceTotal,
          currency: "INR",
          status: "requiresCustomerAction",
          providerReadiness: "blocked_pending_merchant_and_provider_approval",
          collectionMode: "customer_prepaid_before_delivery",
          providerVerifiedCapture: false,
          capturedAmount: 0,
          refundedAmount: 0,
          createdAt: SERVER_TIMESTAMP(),
        });
        tx.create(invoiceRef, {
          invoiceId: invoiceRef.id,
          orderId: snap.get("orderId"),
          orderNumber: order.orderNumber || null,
          deliveryGroupId: snap.get("deliveryGroupId"),
          customerUid: order.customerUid,
          paymentId: paymentRef.id,
          pricingPolicyVersionId: order.pricingPolicyVersionId,
          currency: "INR",
          lines,
          serviceSubtotal: roundMoney(subtotal),
          taxTotal: roundMoney(tax),
          logisticsTotal: roundMoney(logistics),
          grandTotal: invoiceTotal,
          invoiceStatus: "issued",
          followOnServicePending,
          collectionMode: "customer_prepaid_before_delivery",
          createdAt: SERVER_TIMESTAMP(),
        });
        const deliveryGroupRef = db.collection("garment_care_orders").doc(snap.get("orderId"))
          .collection("delivery_groups").doc(snap.get("deliveryGroupId"));
        tx.update(deliveryGroupRef, {
          invoiceId: invoiceRef.id,
          invoiceTotal,
          invoiceStatus: "awaiting_payment",
          paymentStatus: "requiresCustomerAction",
          followOnServicePending,
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.update(db.collection("garment_care_orders").doc(snap.get("orderId")), {
          invoiceIds: admin.firestore.FieldValue.arrayUnion(invoiceRef.id),
          statusProjection: allOrderServicesCompleteAfterThisJob
            ? followOnServicePending ? "awaiting_next_service" : "awaiting_payment"
            : order.statusProjection === "awaiting_payment"
              ? "open"
              : order.statusProjection || "open",
          paymentStatus: orderPaymentStatusFromState(orderPaymentState, true),
          paymentActionRequired: true,
          updatedAt: SERVER_TIMESTAMP(),
        });
        for (const shipment of (orderReturnShipments && orderReturnShipments.docs) || []) {
          if (shipment.get("shipmentType") === "customer_return" &&
              shipment.get("deliveryGroupId") === snap.get("deliveryGroupId") &&
              shipment.get("status") !== "delivered") {
            tx.update(shipment.ref, {
              careComplete: true,
              paymentStatusAtDelivery: "requiresCustomerAction",
              invoiceId: invoiceRef.id,
              updatedAt: SERVER_TIMESTAMP(),
            });
          }
        }
      }
      if (groupCompleteAfterThisJob && invoiceSnap && invoiceSnap.exists && orderPaymentState) {
        const groupPaid = orderPaymentState.paymentByGroupId.get(snap.get("deliveryGroupId")) === true;
        tx.update(orderRef, {
          paymentStatus: orderPaymentStatusFromState(orderPaymentState),
          paymentActionRequired: hasUnpaidIssuedInvoice(orderPaymentState),
          updatedAt: SERVER_TIMESTAMP(),
        });
        for (const shipment of (orderReturnShipments && orderReturnShipments.docs) || []) {
          if (shipment.get("shipmentType") === "customer_return" &&
              shipment.get("deliveryGroupId") === snap.get("deliveryGroupId") &&
              shipment.get("status") !== "delivered") {
            tx.update(shipment.ref, {
              careComplete: true,
              paymentStatusAtDelivery: groupPaid ? "paid" : "requiresCustomerAction",
              invoiceId: invoiceSnap.id,
              updatedAt: SERVER_TIMESTAMP(),
            });
          }
        }
      }
    }
    return { status: target, alreadyApplied: false };
  });
  if (["completed", "rejected"].includes(target) &&
      !transitionResult.alreadyApplied) {
    try {
      await runAutomaticGarmentCareRouting();
    } catch (error) {
      console.error(`Automatic Garment Care routing after ${target} failed`, error);
    }
  }
  return {
    status: transitionResult.status || target,
    alreadyApplied: transitionResult.alreadyApplied === true,
  };
});
exports.submitGarmentCareInspectionQuote = functions.runWith({ timeoutSeconds: 120 }).https.onCall(async (data, context) => {
  const jobId = text(data && data.jobId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const inspectionNotes = text(data && data.inspectionNotes, 1600);
  const conditionFindings = text(data && data.conditionFindings, 1600);
  const inspectionMode = text(data && data.inspectionMode, 24);
  const conditionCode = text(data && data.conditionCode, 80);
  const observationCodes = Array.isArray(data && data.observationCodes)
    ? data.observationCodes.map((value) => text(value, 80)).filter(Boolean).slice(0, 12)
    : [];
  const recommendedActionCode = text(data && data.recommendedActionCode, 80);
  const priceImpactCode = text(data && data.priceImpactCode, 80);
  let customerMessage = text(data && data.customerMessage, 1600);
  const optionalNote = text(data && data.optionalNote, 1000);
  const inspectionTemplateId = text(data && data.inspectionTemplateId, 128);
  const inspectionTemplateVersionId = text(data && data.inspectionTemplateVersionId, 128);
  const inspectionTemplateVersion = Number.isInteger(Number(data && data.inspectionTemplateVersion))
    ? Number(data.inspectionTemplateVersion)
    : null;
  const inspectionEvidencePaths = Array.isArray(data && data.inspectionEvidencePaths)
    ? data.inspectionEvidencePaths.map((value) => text(value, 700)).filter(Boolean).slice(0, 10)
    : [];
  const additionalServiceFee = data && data.additionalServiceFee !== undefined ? Number(data.additionalServiceFee) : 0;
  const additionalServiceReason = text(data && data.additionalServiceReason, 500);
  const { auth } = await requirePartner(context, accountId, profileId);
  const structuredInspection = ["allGood", "issueFound"].includes(inspectionMode);
  if (!jobId || (!inspectionNotes && !structuredInspection) || !Number.isFinite(additionalServiceFee) || additionalServiceFee < 0 || additionalServiceFee > 500000 || (additionalServiceFee > 0 && !additionalServiceReason)) fail("invalid-argument", "Complete the inspection and add a reason for any extra charge.");
  if (structuredInspection && (!conditionCode || !recommendedActionCode || !priceImpactCode || !inspectionTemplateId || !inspectionTemplateVersionId || inspectionTemplateVersion == null)) {
    fail("invalid-argument", "The inspection result and approved customer message are required.");
  }
  if (structuredInspection && inspectionMode === "issueFound" && observationCodes.length === 0) {
    fail("invalid-argument", "Choose at least one inspection observation.");
  }
  if (structuredInspection && (!INSPECTION_LABELS.conditions[conditionCode] ||
      !INSPECTION_LABELS.actions[recommendedActionCode] || !INSPECTION_LABELS.priceImpact[priceImpactCode] ||
      observationCodes.some((code) => !INSPECTION_LABELS.observations[code]))) {
    fail("invalid-argument", "Choose inspection results from the approved lists.");
  }
  let inspectionTemplates = defaultInspectionTemplates();
  if (structuredInspection && inspectionTemplateVersionId !== "default_v1") {
    const templateSnap = await db.collection("garment_care_inspection_template_versions")
      .doc(inspectionTemplateVersionId).get();
    if (!templateSnap.exists || Number(templateSnap.get("version")) !== inspectionTemplateVersion) {
      fail("failed-precondition", "The approved inspection message version is unavailable. Refresh and try again.");
    }
    inspectionTemplates = { ...inspectionTemplates, ...(templateSnap.get("templates") || {}) };
  }
  const sensitiveObservations = new Set(["existing_damage", "existing_stain", "colour_bleeding", "fabric_weakness", "missing_embellishment"]);
  const ref = db.collection("garment_care_service_jobs").doc(jobId);
  const orderCollection = db.collection("garment_care_orders");
  const quoteRef = db.collection("garment_care_quote_versions").doc();
  const privateRateRef = db.collection("garment_care_partner_quote_rates").doc(quoteRef.id);
  const consentRef = db.collection("garment_care_consents").doc();
  let consentRequired = true;
  let orderId = "";
  let deliveryGroupId = "";
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("assignedPartnerAccountId") !== accountId ||
        snap.get("assignedPartnerProfileId") !== profileId || snap.get("status") !== "inspectionPending") {
      fail("permission-denied", "This inspection is not assigned to your Partner profile or is not ready for pricing.");
    }
    const job = snap.data() || {};
    orderId = text(job.orderId, 128);
    deliveryGroupId = text(job.deliveryGroupId, 128);
    const orderSnap = await tx.get(orderCollection.doc(job.orderId));
    if (!orderSnap.exists) fail("not-found", "Parent Care Order not found.");
    const versionId = text(orderSnap.get("pricingPolicyVersionId"), 128);
    const version = versionId
      ? await tx.get(db.collection("garment_care_pricing_versions").doc(versionId))
      : null;
    if (!version || !version.exists) fail("failed-precondition", "The order's approved pricing version is unavailable.");
    const policy = version.data() || {};
    const configuredRate = ((policy.itemTypeRates || {})[job.serviceId] || {})[job.itemTypeCode] ||
      (policy.serviceRates || {})[job.serviceId] || {};
    const baseServiceAmount = Number(configuredRate.customerAmount);
    const basePartnerAmount = Number(configuredRate.partnerAmount);
    const taxPercent = Number(policy.taxPercent);
    const commissionPercent = Number(policy.platformCommissionPercent);
    if (!Number.isFinite(baseServiceAmount) || baseServiceAmount < 0 ||
        !Number.isFinite(basePartnerAmount) || basePartnerAmount < 0 || basePartnerAmount > baseServiceAmount ||
        !Number.isFinite(taxPercent) || taxPercent < 0 ||
        !Number.isFinite(commissionPercent) || commissionPercent < 0 || commissionPercent > 100) {
      fail("failed-precondition", "The order pricing version has no valid price, Partner payable, commission and tax for this service.");
    }
    const pricingParts = careRateBreakdown(policy, configuredRate, additionalServiceFee);
    const serviceAmount = pricingParts.serviceAmount;
    const partnerAmount = pricingParts.partnerPayableAmount;
    const commissionAmount = pricingParts.platformCommissionAmount;
    const deliveryAmount = pricingParts.deliveryAmount;
    if (Number(policy.pricingModelVersion) < 2 &&
        Math.abs(commissionAmount - Math.round(baseServiceAmount * commissionPercent) / 100) > 0.01) {
      fail("failed-precondition", "The pinned service rate does not reconcile with its commission policy.");
    }
    const taxAmount = pricingParts.taxAmount;
    const customerTotal = pricingParts.customerTotal;
    if (structuredInspection) {
      const serviceTemplates = inspectionTemplates[job.serviceId] || defaultInspectionTemplates()[job.serviceId];
      const template = serviceTemplates && serviceTemplates[inspectionMode];
      if (!template) fail("failed-precondition", "An approved message template is not configured for this service.");
      const observationText = observationCodes.map((code) => INSPECTION_LABELS.observations[code]).join(", ");
      customerMessage = formatInspectionTemplate(template, {
        service: text(job.serviceName || SERVICES[job.serviceId], 160),
        condition: INSPECTION_LABELS.conditions[conditionCode],
        observations: observationText || "No visible issues",
        action: INSPECTION_LABELS.actions[recommendedActionCode],
        priceImpact: INSPECTION_LABELS.priceImpact[priceImpactCode],
        note: optionalNote ? "Additional note: " + optionalNote : "",
      });
    }
    const actionNeedsApproval = recommendedActionCode !== "proceed_as_requested";
    const riskNeedsApproval = ["existing_damage", "existing_stain", "colour_bleeding", "fabric_weakness"].includes(conditionCode) || observationCodes.some((code) => sensitiveObservations.has(code));
    consentRequired = !structuredInspection || additionalServiceFee > 0 || priceImpactCode !== "no_additional_charge" || actionNeedsApproval || riskNeedsApproval;
    const evidencePrefix = "garment_care_evidence/" + job.orderId + "/inspection/" + jobId + "/" + job.garmentId + "/" + auth.uid + "/";
    if (inspectionEvidencePaths.some((path) => !path.startsWith(evidencePrefix) || path.includes(".."))) {
      fail("permission-denied", "Inspection photos must be uploaded by the assigned Partner for this garment.");
    }
    const quote = {
      quoteId: quoteRef.id,
      orderId: job.orderId,
      orderNumber: orderSnap.get("orderNumber") || null,
      deliveryGroupId: job.deliveryGroupId,
      itemId: job.itemId,
      garmentId: job.garmentId,
      jobId,
      customerUid: orderSnap.get("customerUid"),
      serviceId: job.serviceId,
      serviceName: job.serviceName,
      pricingPolicyVersionId: versionId,
      serviceAmount,
      baseServiceAmount,
      additionalServiceFee,
      additionalServiceReason: additionalServiceReason || null,
      taxPercent,
      taxAmount,
      logisticsAmount: deliveryAmount,
    deliveryPercent: policy.deliveryPercent == null ? 6 : Number(policy.deliveryPercent),
      deliveryAmount,
      customerTotal,
      currency: "INR",
      status: consentRequired ? "awaiting_customer_consent" : "accepted",
      inspectionNotes,
      conditionFindings,
      ...(structuredInspection ? {
        inspectionMode,
        conditionCode,
        observationCodes,
        recommendedActionCode,
        priceImpactCode,
        customerMessage,
        optionalNote: optionalNote || null,
        inspectionTemplateId,
        inspectionTemplateVersion,
        inspectionTemplateVersionId,
        inspectionEvidencePaths,
      } : {}),
      createdAt: SERVER_TIMESTAMP(),
      createdByPartnerAccountId: accountId,
      createdByPartnerProfileId: profileId,
    };
    tx.create(quoteRef, quote);
    tx.create(privateRateRef, {
      quoteId: quoteRef.id,
      jobId,
      orderId: job.orderId,
      orderNumber: orderSnap.get("orderNumber") || null,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      baseServiceAmount,
      additionalServiceFee,
      partnerPayableAmount: partnerAmount,
      platformCommissionAmount: commissionAmount,
      deliveryAmount,
      platformCommissionPercent: commissionPercent,
      pricingPolicyVersionId: versionId,
      createdAt: SERVER_TIMESTAMP(),
    });
    if (consentRequired) {
      tx.create(consentRef, {
        consentId: consentRef.id,
        quoteId: quoteRef.id,
        jobId,
        orderId: job.orderId,
        orderNumber: orderSnap.get("orderNumber") || null,
        customerUid: orderSnap.get("customerUid"),
        garmentId: job.garmentId,
        status: "pending",
        requestedAt: SERVER_TIMESTAMP(),
      });
    }
    tx.update(ref, {
      status: consentRequired ? "awaitingConsent" : "readyToStart",
      quoteVersionId: quoteRef.id,
      consentId: consentRequired ? consentRef.id : null,
      inspectionNotes,
      conditionFindings,
      ...(structuredInspection ? {
        inspectionMode,
        conditionCode,
        observationCodes,
        recommendedActionCode,
        priceImpactCode,
        customerMessage,
        optionalNote: optionalNote || null,
        inspectionTemplateId,
        inspectionTemplateVersion,
        inspectionTemplateVersionId,
        inspectionEvidencePaths,
      } : {}),
      updatedAt: SERVER_TIMESTAMP(),
    });
    if (consentRequired) {
      tx.update(orderCollection.doc(job.orderId), {
        statusProjection: "customer_action_required",
        updatedAt: SERVER_TIMESTAMP(),
      });
    }
    tx.create(ref.collection("events").doc(), {
      type: consentRequired ? "inspection_quote_submitted" : "inspection_completed_no_changes",
      actorUid: auth.uid,
      quoteId: quoteRef.id,
      ...(consentRequired ? { consentId: consentRef.id } : {}),
      inspectionMode: inspectionMode || "legacy",
      inspectionTemplateId: inspectionTemplateId || null,
      inspectionTemplateVersion,
      inspectionTemplateVersionId: inspectionTemplateVersionId || null,
      at: SERVER_TIMESTAMP(),
    });
  });
  return { quoteId: quoteRef.id, consentId: consentRequired ? consentRef.id : null, consentRequired };
});
exports.recordGarmentCareHandover = functions.https.onCall(async (data, context) => {
  const action = text(data && data.action, 20);
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const evidencePhotosByGarmentId = data && data.evidencePhotosByGarmentId && typeof data.evidencePhotosByGarmentId === "object" ? data.evidencePhotosByGarmentId : {};
  const confirmedGarmentIds = Array.isArray(data && data.confirmedGarmentIds)
    ? data.confirmedGarmentIds.map((id) => text(id, 128)).filter(Boolean)
    : [text(data && data.confirmedGarmentId, 128)].filter(Boolean);
  const rejectedGarmentIds = Array.isArray(data && data.rejectedGarmentIds)
    ? data.rejectedGarmentIds.map((id) => text(id, 128)).filter(Boolean)
    : [];
  const pickupRejectionReasons = data && data.pickupRejectionReasons && typeof data.pickupRejectionReasons === "object"
    ? data.pickupRejectionReasons
    : {};
  const { auth, profileRef, partnerType } = await requireGarmentCareDeliveryPartner(
    context, accountId, profileId,
  );
  const actingProfile = await profileRef.get();
  if (!shipmentId || !["release", "receive"].includes(action)) {
    fail("invalid-argument", "Shipment and handover action are required.");
  }
  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  const handoverResult = await db.runTransaction(async (tx) => {
    const shipment = await tx.get(shipmentRef);
    if (!shipment.exists) fail("not-found", "Transfer shipment not found.");
    const record = shipment.data() || {};
    if (partnerType === "deliveryPartner" &&
        (record.shipmentType !== "customer_return" ||
          record.deliveryPartnerType !== "deliveryPartner" ||
          record.deliveryPartnerAccountId !== accountId ||
          record.deliveryPartnerProfileId !== profileId)) {
      fail("permission-denied", "This delivery Partner can act only on Customer returns assigned to this profile.");
    }
    const expectedIds = Array.isArray(record.garmentIds) && record.garmentIds.length
      ? record.garmentIds.map((id) => text(id, 128)).sort()
      : [text(record.garmentId, 128)].filter(Boolean);
    const pickupReceiptEvidenceRequired = action === "receive" && record.shipmentType === "customer_pickup";
    const confirmedSet = new Set(confirmedGarmentIds);
    const rejectedSet = new Set(rejectedGarmentIds);
    if (action === "release" && record.status === "inTransit" &&
        record.releasedByAccountId === accountId && record.releasedByProfileId === profileId) {
      return { status: "inTransit", alreadyApplied: true };
    }
    if (action === "receive" && record.receivedByAccountId === accountId &&
        record.receivedByProfileId === profileId) {
      const priorConfirmed = Array.isArray(record.collectedGarmentIds)
        ? record.collectedGarmentIds.map((id) => text(id, 128)).sort() : [];
      const priorRejected = Array.isArray(record.rejectedGarmentIds)
        ? record.rejectedGarmentIds.map((id) => text(id, 128)).sort() : [];
      if ((pickupReceiptEvidenceRequired && ["delivered", "failed"].includes(record.status) &&
          JSON.stringify(priorConfirmed) === JSON.stringify([...confirmedSet].sort()) &&
          JSON.stringify(priorRejected) === JSON.stringify([...rejectedSet].sort())) ||
          (record.shipmentType === "customer_return" && record.deliveryMode === "other_partner" &&
            record.status === "planned")) {
        return { status: record.status, alreadyApplied: true };
      }
    }
    const pickupDecisionIds = [...confirmedSet, ...rejectedSet].sort();
    const invalidPickupDecision = pickupReceiptEvidenceRequired && (
      confirmedSet.size + rejectedSet.size !== expectedIds.length ||
      [...confirmedSet].some((id) => rejectedSet.has(id)) ||
      JSON.stringify(pickupDecisionIds) !== JSON.stringify(expectedIds) ||
      rejectedGarmentIds.some((id) => !["complex_care", "unsafe_condition", "service_mismatch", "service_unavailable", "garment_not_present", "other"].includes(text(pickupRejectionReasons[id], 80)))
    );
    if (!expectedIds.length || (pickupReceiptEvidenceRequired
      ? invalidPickupDecision
      : JSON.stringify([...confirmedGarmentIds].sort()) !== JSON.stringify(expectedIds))) {
      fail("failed-precondition", "Confirm every individual Garment ID in this shipment before custody can change.");
    }
    if (pickupReceiptEvidenceRequired) {
      if (record.status !== "assigned" || record.toPartnerAccountId !== accountId ||
          record.toPartnerProfileId !== profileId ||
          (record.pickupAcceptedByUid && (record.pickupAcceptedByUid !== auth.uid ||
            record.pickupAcceptedByAccountId !== accountId ||
            record.pickupAcceptedByProfileId !== profileId))) {
        fail("failed-precondition", "This pickup is no longer assigned to your Partner profile.");
      }
      const evidenceIds = Object.keys(evidencePhotosByGarmentId).sort();
      if (JSON.stringify(evidenceIds) !== JSON.stringify([...confirmedSet].sort())) {
        fail("failed-precondition", "Capture and attach one condition photo for every garment you collect.");
      }
      for (const garmentId of confirmedSet) {
        const path = text(evidencePhotosByGarmentId[garmentId], 700);
        const requiredPrefix = "garment_care_evidence/" + record.orderId + "/" +
          shipmentId + "/" + garmentId + "/" + auth.uid + "/";
        if (!path.startsWith(requiredPrefix) || path.includes("..")) {
          fail("permission-denied", "A pickup photo must be uploaded by this assigned Partner for the matching garment.");
        }
      }
    }
    const orderRef = db.collection("garment_care_orders").doc(record.orderId);
    const orderSnap = await tx.get(orderRef);
    const identitySnaps = await Promise.all(expectedIds.map((id) =>
      tx.get(db.collection("garment_identities").doc(id))));
    const pickupJobsSnap = pickupReceiptEvidenceRequired
      ? await tx.get(db.collection("garment_care_service_jobs")
        .where("orderId", "==", record.orderId))
      : null;
    const pickupDeliveryGroupRefs = pickupReceiptEvidenceRequired
      ? [...new Set(pickupJobsSnap.docs.map((job) => text(job.get("deliveryGroupId"), 128)).filter(Boolean))]
        .map((deliveryGroupId) => orderRef.collection("delivery_groups").doc(deliveryGroupId))
      : [];
    const pickupDeliveryGroupSnaps = await Promise.all(pickupDeliveryGroupRefs.map((ref) => tx.get(ref)));
    const pickupPackageRef = pickupReceiptEvidenceRequired && record.packageId
      ? db.collection("garment_care_packages").doc(record.packageId)
      : null;
    if (pickupPackageRef) await tx.get(pickupPackageRef);
    const pickupJobsByOrderId = new Map();
    const pickupRelatedJobDocs = [];
    const pickupRelatedOrderSnaps = new Map();
    let pickupCheckoutRef = null;
    let pickupCheckoutSnap = null;
    if (pickupReceiptEvidenceRequired) {
      const relatedJobDocs = new Map();
      for (let offset = 0; offset < expectedIds.length; offset += 30) {
        const garmentIds = expectedIds.slice(offset, offset + 30);
        const relatedJobs = await tx.get(db.collection("garment_care_service_jobs")
          .where("garmentId", "in", garmentIds));
        for (const job of relatedJobs.docs) relatedJobDocs.set(job.id, job);
      }
      pickupJobsByOrderId.set(record.orderId, pickupJobsSnap.docs);
      const allRelatedOrderIds = [...new Set([...relatedJobDocs.values()]
        .map((job) => text(job.get("orderId"), 128))
        .filter((id) => id && id !== record.orderId))];
      const allRelatedOrderSnaps = await Promise.all(allRelatedOrderIds.map((id) =>
        tx.get(db.collection("garment_care_orders").doc(id))));
      const checkoutId = text(orderSnap.get("cartCheckoutId"), 128);
      if (checkoutId) {
        pickupCheckoutRef = db.collection("garment_care_checkouts").doc(checkoutId);
        pickupCheckoutSnap = await tx.get(pickupCheckoutRef);
      }
      const relatedOrderIds = allRelatedOrderIds.filter((id, index) =>
        Boolean(checkoutId) && allRelatedOrderSnaps[index].exists &&
        text(allRelatedOrderSnaps[index].get("cartCheckoutId"), 128) === checkoutId);
      const relatedOrderSnaps = relatedOrderIds.map((id) =>
        allRelatedOrderSnaps[allRelatedOrderIds.indexOf(id)]);
      const relatedOrderJobSnaps = await Promise.all(relatedOrderIds.map((id) =>
        tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", id))));
      relatedOrderIds.forEach((id, index) => {
        pickupJobsByOrderId.set(id, relatedOrderJobSnaps[index].docs);
        pickupRelatedOrderSnaps.set(id, relatedOrderSnaps[index]);
      });
      pickupRelatedJobDocs.push(...[...relatedJobDocs.values()].filter((job) =>
        text(job.get("orderId"), 128) === record.orderId ||
        pickupRelatedOrderSnaps.has(text(job.get("orderId"), 128))));
    }
    if (!orderSnap.exists || identitySnaps.some((identity) =>
      !identity.exists || identity.get("customerUid") !== orderSnap.get("customerUid"))) {
      fail("failed-precondition", "The shipment does not match the Parent Order's individual Garment IDs.");
    }
    const subOrderNumbersByGarmentId = {};
    const relatedSubOrderNumbersByOrderId = new Map();
    const relatedNextSubOrderSequenceByOrderId = new Map();
    let pickupSubOrderCount = 0;
    let nextSubOrderSequence = Number(orderSnap.get("nextSubOrderSequence")) || 1;
    if (pickupReceiptEvidenceRequired && confirmedSet.size) {
      const acceptedGarmentIds = [...confirmedSet].sort();
      for (const garmentId of acceptedGarmentIds) {
        const garmentJobs = pickupJobsSnap.docs.filter((job) =>
          text(job.get("garmentId"), 128) === garmentId);
        if (!garmentJobs.length) {
          fail("failed-precondition", "An accepted garment is missing its booked service details.");
        }
        const firstJob = garmentJobs[0];
        const serviceGroupCode = text(orderSnap.get("serviceGroupCode"), 64) ||
          text(firstJob.get("serviceGroupCode"), 64);
        const subOrderNumber = makeGarmentCareSubOrderNumber(
          serviceGroupCode,
          nextSubOrderSequence++,
        );
        subOrderNumbersByGarmentId[garmentId] = subOrderNumber;
      }
      pickupSubOrderCount = acceptedGarmentIds.length;
      for (const relatedOrderId of pickupJobsByOrderId.keys()) {
        if (relatedOrderId === record.orderId) continue;
        const orderJobs = pickupJobsByOrderId.get(relatedOrderId) || [];
        const relatedOrder = pickupRelatedOrderSnaps.get(relatedOrderId);
        if (!relatedOrder?.exists) continue;
        const numbersByGarmentId = {};
        let sequence = Number(relatedOrder.get("nextSubOrderSequence")) || 1;
        for (const garmentId of acceptedGarmentIds) {
          const garmentJobs = orderJobs.filter((job) =>
            text(job.get("garmentId"), 128) === garmentId);
          if (!garmentJobs.length) continue;
          const existingNumber = garmentJobs
            .map((job) => text(job.get("subOrderNumber"), 8))
            .find((value) => /^[A-Z]\d{3}$/.test(value));
          const firstJob = garmentJobs[0];
          const serviceGroupCode = text(relatedOrder.get("serviceGroupCode"), 64) ||
            text(firstJob.get("serviceGroupCode"), 64);
          numbersByGarmentId[garmentId] = existingNumber ||
            makeGarmentCareSubOrderNumber(serviceGroupCode, sequence++);
        }
        if (Object.keys(numbersByGarmentId).length) {
          relatedSubOrderNumbersByOrderId.set(relatedOrderId, numbersByGarmentId);
          relatedNextSubOrderSequenceByOrderId.set(relatedOrderId, sequence);
        }
      }
    }
    const pickupOrderSummaries = new Map();
    let pickupCheckoutSummary = null;
    if (pickupReceiptEvidenceRequired) {
      for (const [relatedOrderId, relatedJobs] of pickupJobsByOrderId.entries()) {
        const relatedOrder = relatedOrderId === record.orderId
          ? orderSnap
          : pickupRelatedOrderSnaps.get(relatedOrderId);
        if (!relatedOrder || !relatedOrder.exists) continue;
        const garmentIds = new Set(relatedJobs
          .map((job) => text(job.get("garmentId"), 128)).filter(Boolean));
        const rejectedIds = new Set(relatedJobs
          .filter((job) => text(job.get("pickupRejectionCode"), 80))
          .map((job) => text(job.get("garmentId"), 128)).filter(Boolean));
        for (const garmentId of rejectedSet) {
          if (garmentIds.has(garmentId)) rejectedIds.add(garmentId);
        }
        const newNumbers = relatedOrderId === record.orderId
          ? subOrderNumbersByGarmentId
          : relatedSubOrderNumbersByOrderId.get(relatedOrderId) || {};
        const assignedIds = new Set(relatedJobs
          .filter((job) => /^[A-Z]\d{3}$/.test(text(job.get("subOrderNumber"), 8)))
          .map((job) => text(job.get("garmentId"), 128)).filter(Boolean));
        for (const garmentId of Object.keys(newNumbers)) assignedIds.add(garmentId);
        for (const garmentId of rejectedIds) assignedIds.delete(garmentId);
        const previousRejected = Array.isArray(relatedOrder.get("pickupRejectedGarmentIds"))
          ? relatedOrder.get("pickupRejectedGarmentIds").map((id) => text(id, 128)).filter(Boolean)
          : [];
        for (const garmentId of previousRejected) rejectedIds.add(garmentId);
        const requestedCount = Number(relatedOrder.get("requestedItemCount")) ||
          Number(relatedOrder.get("itemCount")) || garmentIds.size;
        const requestedServiceCount = Number(relatedOrder.get("requestedServiceCount")) ||
          Number(relatedOrder.get("serviceCount")) || relatedJobs.length;
        const rejectedServiceCount = relatedJobs.filter((job) =>
          rejectedIds.has(text(job.get("garmentId"), 128))).length;
        const allGarmentsRejected = garmentIds.size > 0 &&
          [...garmentIds].every((garmentId) => rejectedIds.has(garmentId));
        pickupOrderSummaries.set(relatedOrderId, {
          itemCount: Math.max(0, requestedCount - rejectedIds.size),
          serviceCount: Math.max(0, requestedServiceCount - rejectedServiceCount),
          collectedItemCount: assignedIds.size,
          pickupRejectedGarmentIds: [...rejectedIds],
          pickupRejectedItemCount: rejectedIds.size,
          pickupRejectedServiceCount: rejectedServiceCount,
          subOrderCount: assignedIds.size,
          nextSubOrderSequence: relatedOrderId === record.orderId
            ? nextSubOrderSequence
            : relatedNextSubOrderSequenceByOrderId.get(relatedOrderId) ||
              Number(relatedOrder.get("nextSubOrderSequence")) || 1,
          statusProjection: rejectedIds.size > 0
            ? assignedIds.size > 0 ? "pickup_partial" : allGarmentsRejected ? "cancelled" : "pickup_rejected"
            : text(relatedOrder.get("statusProjection"), 80) || "open",
          ...(allGarmentsRejected ? {
            deliveryStatus: "not_required",
            paymentStatus: "not_due",
            paymentActionRequired: false,
            completedAt: SERVER_TIMESTAMP(),
          } : {}),
        });
      }
      if (pickupCheckoutSnap && pickupCheckoutSnap.exists) {
        const previousRejectedIds = new Set(
          (Array.isArray(pickupCheckoutSnap.get("pickupRejectedGarmentIds"))
            ? pickupCheckoutSnap.get("pickupRejectedGarmentIds") : [])
            .map((id) => text(id, 128)).filter(Boolean),
        );
        const rejectedIds = new Set([...previousRejectedIds, ...rejectedSet]);
        const newlyRejectedIds = [...rejectedIds].filter((id) => !previousRejectedIds.has(id));
        const newlyRejectedJobIds = new Set([
          ...pickupJobsSnap.docs,
          ...pickupRelatedJobDocs,
        ].filter((job) => newlyRejectedIds.includes(text(job.get("garmentId"), 128)))
          .map((job) => job.id));
        const requestedItemCount = Number(pickupCheckoutSnap.get("requestedItemCount")) ||
          Number(pickupCheckoutSnap.get("itemCount")) || rejectedIds.size + confirmedSet.size;
        const requestedServiceCount = Number(pickupCheckoutSnap.get("requestedServiceCount")) ||
          Number(pickupCheckoutSnap.get("serviceCount")) || newlyRejectedJobIds.size;
        const rejectedServiceCount = (Number(pickupCheckoutSnap.get("pickupRejectedServiceCount")) || 0) +
          newlyRejectedJobIds.size;
        pickupCheckoutSummary = {
          itemCount: Math.max(0, requestedItemCount - rejectedIds.size),
          requestedItemCount,
          pickupRejectedGarmentIds: [...rejectedIds],
          pickupRejectedItemCount: rejectedIds.size,
          serviceCount: Math.max(0, requestedServiceCount - rejectedServiceCount),
          requestedServiceCount,
          pickupRejectedServiceCount: rejectedServiceCount,
        };
      }
    }
    let eventType;
    let custodianType;
    let nextShipmentStatus;
    let customerReturnPartnerReceipt = false;
    if (action === "release") {
      if (!(["partner_transfer", "customer_return"].includes(record.shipmentType)) || record.status !== "planned" ||
          record.fromPartnerAccountId !== accountId || record.fromPartnerProfileId !== profileId) {
        fail("permission-denied", "Only the sending Partner can release this planned shipment.");
      }
      if (record.shipmentType === "customer_return") {
        const deliveryGroupId = text(record.deliveryGroupId, 128);
        const returnOnly = record.returnOnly === true;
        const [serviceJobs, invoice] = await Promise.all([
          tx.get(db.collection("garment_care_service_jobs")
            .where("orderId", "==", record.orderId)
            .where("deliveryGroupId", "==", deliveryGroupId)),
          deliveryGroupId
            ? tx.get(db.collection("garment_care_invoices").doc(deliveryGroupId))
            : Promise.resolve(null),
        ]);
        const returnJobIds = Array.isArray(record.returnJobIds)
          ? [...new Set(record.returnJobIds.map((id) => text(id, 128)).filter(Boolean))] : [];
        const returnOnlyJobs = returnOnly
          ? await Promise.all(returnJobIds.map((id) =>
            tx.get(db.collection("garment_care_service_jobs").doc(id))))
          : [];
        const relatedReturnJobIds = Array.isArray(record.returnJobIds)
          ? [...new Set(record.returnJobIds.map((id) => text(id, 128)).filter(Boolean))] : [];
        const relatedReturnJobs = relatedReturnJobIds.length
          ? returnOnlyJobs.length
            ? returnOnlyJobs
            : await Promise.all(relatedReturnJobIds.map((id) =>
              tx.get(db.collection("garment_care_service_jobs").doc(id))))
          : [];
        const relatedPaymentState = await readShipmentRelatedPaymentState(tx, record);
        if (!returnOnly && (!serviceJobs || serviceJobs.empty ||
            serviceJobs.docs.some((job) =>
              !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status"))))) {
          fail("failed-precondition", "Finish every service in this garment sub-order before starting delivery.");
        }
        if (returnOnly && (!returnOnlyJobs.length ||
            returnOnlyJobs.some((job) => !job.exists ||
              text(job.get("garmentId"), 128) !== text(record.garmentId, 128) ||
              !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")) ||
              text(job.get("returnWithShipmentId"), 128) !== shipmentId) ||
            !returnOnlyJobs.some((job) => job.exists && job.get("status") === "blocked" &&
              /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800))))) {
          fail("failed-precondition", "The customer-declined garment must finish all care steps before its no-charge return.");
        }
        if (!returnOnly && relatedReturnJobs.some((job) => !job.exists ||
            !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")) ||
            text(job.get("returnWithShipmentId"), 128) !== shipmentId)) {
          fail("failed-precondition", "Every service for the garments in this return must be complete and linked to the same handover.");
        }
        if (!returnOnly && (!invoice || !invoice.exists)) {
          fail("failed-precondition", "This garment sub-order's final invoice is prepared after its services are complete.");
        }
        const isPartnerToPartnerTransfer = record.deliveryMode === "other_partner" &&
          Boolean(text(record.toPartnerAccountId, 128));
        if (isPartnerToPartnerTransfer && record.deliveryPartnerType === "deliveryPartner" &&
            record.deliveryPartnerAcceptanceStatus !== "accepted") {
          fail("failed-precondition", "The assigned Delivery Partner must accept this return before the Garment Care Partner releases it.");
        }
        if (!returnOnly && !isPartnerToPartnerTransfer) {
          const orderJobs = await tx.get(db.collection("garment_care_service_jobs")
            .where("orderId", "==", record.orderId));
          const paymentState = await readGarmentCareOrderPaymentState(tx, orderSnap, orderJobs);
          if (paymentState.paymentByGroupId.get(deliveryGroupId) !== true) {
            fail("failed-precondition", "The Customer must pay this garment sub-order's final invoice before delivery.");
          }
        }
        if (!relatedPaymentState.allPaid) {
          fail("failed-precondition", "Pay every earlier completed service invoice for this garment before returning it to the Customer.");
        }
      }
      eventType = "released";
      custodianType = "logistics";
      nextShipmentStatus = "inTransit";
    } else {
      const pickupReceipt = record.shipmentType === "customer_pickup" && record.status === "assigned";
      const transferReceipt = record.shipmentType === "partner_transfer" && record.status === "inTransit";
      customerReturnPartnerReceipt = record.shipmentType === "customer_return" &&
        record.deliveryMode === "other_partner" && record.status === "inTransit";
      if ((!pickupReceipt && !transferReceipt && !customerReturnPartnerReceipt) || record.toPartnerAccountId !== accountId ||
          record.toPartnerProfileId !== profileId) {
        fail("permission-denied", "Only the assigned receiving Partner can confirm this receipt.");
      }
      eventType = customerReturnPartnerReceipt
        ? "received_for_customer_delivery"
        : pickupReceiptEvidenceRequired
          ? (confirmedSet.size === expectedIds.length ? "received" : confirmedSet.size > 0 ? "pickup_partially_received" : "pickup_rejected")
          : "received";
      custodianType = "partner";
      nextShipmentStatus = customerReturnPartnerReceipt
        ? "planned"
        : pickupReceiptEvidenceRequired && confirmedSet.size === 0
          ? "failed"
          : "delivered";
    }
    const actorAccountField = action === "release" ? "releasingPartnerAccountId" : "receivingPartnerAccountId";
    const actorProfileField = action === "release" ? "releasingPartnerProfileId" : "receivingPartnerProfileId";
    tx.update(shipmentRef, {
      status: nextShipmentStatus,
      ...(customerReturnPartnerReceipt ? {
        fromPartnerAccountId: accountId,
        fromPartnerProfileId: profileId,
        fromPartnerName: text(actingProfile.get("businessName") || actingProfile.get("displayName") || "Garment Care Partner", 120),
        fromPartnerContactPhone: text(actingProfile.get("contactPhone"), 32),
        toPartnerAccountId: admin.firestore.FieldValue.delete(),
        toPartnerProfileId: admin.firestore.FieldValue.delete(),
      } : {}),
      ...(pickupReceiptEvidenceRequired ? {
        evidencePhotosByGarmentId,
        collectedGarmentIds: [...confirmedSet],
        rejectedGarmentIds: [...rejectedSet],
        pickupRejectionReasons: Object.fromEntries([...rejectedSet].map((id) => [id, text(pickupRejectionReasons[id], 80)])),
        subOrderNumbersByGarmentId,
        subOrderCount: pickupSubOrderCount,
        ...(confirmedSet.size > 0 ? {
          pickupAcceptedAt: record.pickupAcceptedAt || SERVER_TIMESTAMP(),
          pickupAcceptedByUid: record.pickupAcceptedByUid || auth.uid,
          pickupAcceptedByAccountId: record.pickupAcceptedByAccountId || accountId,
          pickupAcceptedByProfileId: record.pickupAcceptedByProfileId || profileId,
        } : {}),
        ...(rejectedSet.size > 0 ? {
          pickupRejectedAt: SERVER_TIMESTAMP(),
          pickupRejectedByUid: auth.uid,
          pickupRejectedByAccountId: accountId,
          pickupRejectedByProfileId: profileId,
        } : {}),
      } : {}),
      [action === "release" ? "releasedAt" : "receivedAt"]: SERVER_TIMESTAMP(),
      [action === "release" ? "releasedByAccountId" : "receivedByAccountId"]: accountId,
      [action === "release" ? "releasedByProfileId" : "receivedByProfileId"]: profileId,
      updatedAt: SERVER_TIMESTAMP(),
    });
    for (const identity of identitySnaps) {
      if (pickupReceiptEvidenceRequired && !confirmedSet.has(identity.id)) continue;
      tx.update(identity.ref, {
        currentCustodianType: custodianType,
        currentCustodianAccountId: action === "release" ? null : accountId,
        currentCustodianProfileId: action === "release" ? null : profileId,
        currentCustodyShipmentId: shipmentId,
        updatedAt: SERVER_TIMESTAMP(),
      });
    }
    if (record.packageId) {
      const packageRef = db.collection("garment_care_packages").doc(record.packageId);
      tx.set(packageRef, {
        packageId: record.packageId,
        orderId: record.orderId,
        orderNumber: record.orderNumber || null,
        garmentIds: pickupReceiptEvidenceRequired ? [...confirmedSet] : expectedIds,
        currentCustodianType: custodianType,
        currentCustodianAccountId: action === "release" ? null : accountId,
        currentCustodianProfileId: action === "release" ? null : profileId,
        currentCustodyShipmentId: shipmentId,
        ...(pickupReceiptEvidenceRequired ? {
          subOrderNumbersByGarmentId,
          subOrderCount: pickupSubOrderCount,
        } : {}),
        updatedAt: SERVER_TIMESTAMP(),
      }, { merge: true });
    }
    if (pickupReceiptEvidenceRequired) {
      for (const deliveryGroup of pickupDeliveryGroupSnaps) {
        if (!deliveryGroup.exists) continue;
        const garmentIds = Array.isArray(deliveryGroup.get("garmentIds"))
          ? deliveryGroup.get("garmentIds").map((id) => text(id, 128))
          : [];
        const subOrderNumber = garmentIds.map((id) => subOrderNumbersByGarmentId[id]).find(Boolean);
        tx.update(deliveryGroup.ref, {
          subOrderNumber: subOrderNumber || admin.firestore.FieldValue.delete(),
          subOrderGroupKey: subOrderNumber || admin.firestore.FieldValue.delete(),
          pickupConfirmedAt: subOrderNumber ? SERVER_TIMESTAMP() : admin.firestore.FieldValue.delete(),
        });
      }
      tx.update(orderRef, {
        ...pickupOrderSummaries.get(record.orderId),
        updatedAt: SERVER_TIMESTAMP(),
      });
      for (const relatedOrderId of pickupRelatedOrderSnaps.keys()) {
        const summary = pickupOrderSummaries.get(relatedOrderId);
        if (!summary) continue;
        tx.update(db.collection("garment_care_orders").doc(relatedOrderId), {
          ...summary,
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
      if (pickupCheckoutRef && pickupCheckoutSummary) {
        tx.update(pickupCheckoutRef, {
          ...pickupCheckoutSummary,
          updatedAt: SERVER_TIMESTAMP(),
        });
      }
    }
    const eventRef = db.collection("garment_care_custody_events").doc();
    tx.create(eventRef, {
      eventId: eventRef.id,
      orderId: record.orderId,
      orderNumber: record.orderNumber || null,
      itemId: record.itemId || null,
      garmentId: confirmedSet.size === 1 ? [...confirmedSet][0] : null,
      garmentIds: pickupReceiptEvidenceRequired ? [...confirmedSet] : expectedIds,
      ...(pickupReceiptEvidenceRequired ? {
        rejectedGarmentIds: [...rejectedSet],
        pickupRejectionReasons: Object.fromEntries([...rejectedSet].map((id) => [id, text(pickupRejectionReasons[id], 80)])),
        subOrderNumbersByGarmentId,
      } : {}),
      packageId: record.packageId || null,
      shipmentId,
      sourceJobId: record.sourceJobId || null,
      destinationJobId: record.destinationJobId || null,
      eventType,
      ...(pickupReceiptEvidenceRequired ? { evidencePhotosByGarmentId } : {}),
      [actorAccountField]: accountId,
      [actorProfileField]: profileId,
      actorUid: auth.uid,
      at: SERVER_TIMESTAMP(),
    });
    tx.create(shipmentRef.collection("events").doc(), {
      eventType,
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      confirmedGarmentIds: pickupReceiptEvidenceRequired ? [...confirmedSet] : expectedIds,
      custodyEventId: eventRef.id,
      at: SERVER_TIMESTAMP(),
    });
    if (pickupReceiptEvidenceRequired) {
      const partnerProfile = actingProfile.data() || {};
      const partnerName = garmentCarePartnerName(partnerProfile, "Garment Care Partner");
      const partnerPhone = garmentCarePartnerContactPhone(partnerProfile);
      for (const job of pickupJobsSnap.docs) {
        const garmentId = text(job.get("garmentId"), 128);
        const jobStatus = job.get("status");
        const subOrderNumber = subOrderNumbersByGarmentId[garmentId];
        const subOrderFields = {
          subOrderNumber: subOrderNumber || admin.firestore.FieldValue.delete(),
          subOrderGroupKey: subOrderNumber || admin.firestore.FieldValue.delete(),
          pickupConfirmedAt: subOrderNumber ? SERVER_TIMESTAMP() : admin.firestore.FieldValue.delete(),
        };
        if (job.get("itemId")) {
          tx.update(db.collection("garment_care_orders").doc(record.orderId)
            .collection("items").doc(job.get("itemId")), subOrderFields);
        }
        if (rejectedSet.has(garmentId) && !["completed", "cancelled"].includes(jobStatus)) {
          const rejectionCode = text(pickupRejectionReasons[garmentId], 80);
          tx.update(job.ref, {
            ...subOrderFields,
            status: "cancelled",
            dispatchEligible: false,
            pickupRejectionCode: rejectionCode,
            pickupRejectedAt: SERVER_TIMESTAMP(),
            updatedAt: SERVER_TIMESTAMP(),
          });
          tx.create(job.ref.collection("events").doc(), {
            type: "garment_not_collected_at_pickup",
            rejectionCode,
            actorUid: auth.uid,
            at: SERVER_TIMESTAMP(),
          });
          continue;
        }
        if (!confirmedSet.has(garmentId) ||
            !hasCareServiceCapability(partnerProfile, job.get("serviceId"))) {
          tx.update(job.ref, subOrderFields);
          continue;
        }
        const assignedHere = job.get("assignedPartnerAccountId") === accountId &&
          job.get("assignedPartnerProfileId") === profileId &&
          job.get("incomingShipmentId") === shipmentId;
        const canAcceptQueued = jobStatus === "queued" && job.get("dispatchEligible") === true;
        const canAcceptOffered = jobStatus === "offered" && assignedHere;
        if (!canAcceptQueued && !canAcceptOffered) {
          tx.update(job.ref, subOrderFields);
          continue;
        }
        tx.update(job.ref, {
          ...subOrderFields,
          status: "accepted",
          dispatchEligible: false,
          conditionPhotoPaths: admin.firestore.FieldValue.arrayUnion(
            text(evidencePhotosByGarmentId[garmentId], 700),
          ),
          assignedPartnerAccountId: accountId,
          assignedPartnerProfileId: profileId,
          assignedPartnerName: partnerName,
          assignedPartnerContactPhone: partnerPhone,
          incomingShipmentId: shipmentId,
          assignedAt: job.get("assignedAt") || SERVER_TIMESTAMP(),
          acceptedAt: SERVER_TIMESTAMP(),
          acceptanceSource: "pickup_confirmation",
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.create(job.ref.collection("events").doc(), {
          type: "accepted_at_pickup",
          source: "combined_pickup_confirmation",
          actorUid: auth.uid,
          partnerAccountId: accountId,
          partnerProfileId: profileId,
          shipmentId,
          at: SERVER_TIMESTAMP(),
        });
      }
      const updatedDeliveryGroups = new Set();
      for (const job of pickupRelatedJobDocs) {
        const relatedOrderId = text(job.get("orderId"), 128);
        if (!relatedOrderId || relatedOrderId === record.orderId) continue;
        const garmentId = text(job.get("garmentId"), 128);
        const jobStatus = text(job.get("status"), 40);
        const number = relatedSubOrderNumbersByOrderId.get(relatedOrderId)?.[garmentId] || "";
        const subOrderFields = {
          subOrderNumber: number || admin.firestore.FieldValue.delete(),
          subOrderGroupKey: number || admin.firestore.FieldValue.delete(),
          pickupConfirmedAt: number ? SERVER_TIMESTAMP() : admin.firestore.FieldValue.delete(),
        };
        if (job.get("itemId")) {
          tx.update(db.collection("garment_care_orders").doc(relatedOrderId)
            .collection("items").doc(job.get("itemId")), subOrderFields);
        }
        if (rejectedSet.has(garmentId)) {
          if (!["completed", "cancelled", "blocked"].includes(jobStatus)) {
            const rejectionCode = text(pickupRejectionReasons[garmentId], 80);
            tx.update(job.ref, {
              subOrderNumber: admin.firestore.FieldValue.delete(),
              subOrderGroupKey: admin.firestore.FieldValue.delete(),
              status: "cancelled",
              dispatchEligible: false,
              pickupRejectionCode: rejectionCode,
              pickupRejectedAt: SERVER_TIMESTAMP(),
              updatedAt: SERVER_TIMESTAMP(),
            });
            tx.create(job.ref.collection("events").doc(), {
              type: "garment_not_collected_at_pickup",
              rejectionCode,
              actorUid: auth.uid,
              shipmentId,
              sourceOrderId: record.orderId,
              at: SERVER_TIMESTAMP(),
            });
          }
          continue;
        }
        if (!confirmedSet.has(garmentId) || !number) continue;
        tx.update(job.ref, {
          ...subOrderFields,
          updatedAt: SERVER_TIMESTAMP(),
        });
        const deliveryGroupId = text(job.get("deliveryGroupId"), 128);
        const key = `${relatedOrderId}:${deliveryGroupId}`;
        if (deliveryGroupId && !updatedDeliveryGroups.has(key)) {
          updatedDeliveryGroups.add(key);
          tx.update(db.collection("garment_care_orders").doc(relatedOrderId)
            .collection("delivery_groups").doc(deliveryGroupId), {
              subOrderNumber: number,
              subOrderGroupKey: number,
              pickupConfirmedAt: SERVER_TIMESTAMP(),
            });
        }
      }
    }
    return { status: nextShipmentStatus };
  });
  if (action === "receive" && confirmedGarmentIds.length > 0 &&
      handoverResult.alreadyApplied !== true) {
    try {
      await runAutomaticGarmentCareRouting();
    } catch (error) {
      console.error("Automatic Garment Care routing after garment receipt failed", error);
    }
  }
  return handoverResult;
});

exports.autoRouteGarmentCareOrders = functions.pubsub
  .schedule("every 5 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const result = await runAutomaticGarmentCareRouting();
    console.log("Automatic Garment Care routing sweep completed", result);
    return result;
  });

async function issueGarmentCareInvoiceAfterConsent(orderId, deliveryGroupId) {
  const orderRef = db.collection("garment_care_orders").doc(orderId);
  const groupRef = orderRef.collection("delivery_groups").doc(deliveryGroupId);
  const invoiceRef = db.collection("garment_care_invoices").doc(deliveryGroupId);
  const paymentRef = db.collection("garment_care_payments").doc("payment_" + deliveryGroupId);
  const pricingVersionId = text((await orderRef.get()).get("pricingPolicyVersionId"), 128);
  const pricingVersionRef = pricingVersionId
    ? db.collection("garment_care_pricing_versions").doc(pricingVersionId)
    : null;
  return db.runTransaction(async (tx) => {
    const jobsQuery = db.collection("garment_care_service_jobs")
      .where("orderId", "==", orderId)
      .where("deliveryGroupId", "==", deliveryGroupId);
    const jobsSnap = await tx.get(jobsQuery);
    // A customer decline rejects the garment sub-order as a whole. Do not
    // invoice any earlier completed steps for that same garment.
    if (hasCustomerDeclinedService(jobsSnap.docs)) return false;
    const billableJobs = jobsSnap.docs.filter((job) => job.get("status") === "completed");
    if (!billableJobs.length) return false;
    // Quotes can be approved before treatment begins. Never issue the final
    // payment request until every billable service in this delivery group is
    // complete; completion owns invoice creation.
    if (jobsSnap.docs.some((job) =>
      !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")))) return false;
    const quoteRefs = billableJobs.map((job) => {
      const quoteId = text(job.get("quoteVersionId"), 128);
      return quoteId ? db.collection("garment_care_quote_versions").doc(quoteId) : null;
    });
    const consentRefs = billableJobs.map((job) => {
      const consentId = text(job.get("consentId"), 128);
      return consentId ? db.collection("garment_care_consents").doc(consentId) : null;
    });
    const [orderSnap, groupSnap, invoiceSnap, paymentSnap, pricingVersionSnap, quoteSnaps, consentSnaps] =
      await Promise.all([
        tx.get(orderRef), tx.get(groupRef), tx.get(invoiceRef), tx.get(paymentRef),
        pricingVersionRef ? tx.get(pricingVersionRef) : Promise.resolve(null),
        Promise.all(quoteRefs.map((ref) => ref ? tx.get(ref) : Promise.resolve(null))),
        Promise.all(consentRefs.map((ref) => ref ? tx.get(ref) : Promise.resolve(null))),
      ]);
    if (!orderSnap.exists || !groupSnap.exists) {
      fail("not-found", "The Garment Care order or service-group record was not found.");
    }
    if (invoiceSnap.exists) {
      if (!["issued", "paid"].includes(invoiceSnap.get("invoiceStatus")) ||
          jobsSnap.docs.some((job) =>
            !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")))) return false;
      const [orderJobsSnap, returnShipmentsSnap] = await Promise.all([
        tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", orderId)),
        tx.get(db.collection("garment_care_shipments").where("orderId", "==", orderId)),
      ]);
      const paymentState = await readGarmentCareOrderPaymentState(tx, orderSnap, orderJobsSnap);
      const followOnServicePending = paymentState.allServicesComplete &&
        await hasPendingCheckoutServiceJobs(
          tx,
          orderId,
          orderSnap.data() || {},
          [...new Set(orderJobsSnap.docs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))],
        );
      const groupPaid = paymentState.paymentByGroupId.get(deliveryGroupId) === true;
      const billedGarmentIds = billableJobs.map((job) => text(job.get("garmentId"), 128));
      const attachedDeclinedGarmentIds = new Set();
      for (const shipment of returnShipmentsSnap.docs) {
        if (shipment.get("shipmentType") !== "customer_return" ||
            shipment.get("deliveryGroupId") !== deliveryGroupId ||
            shipment.get("status") === "delivered") continue;
        const rejectedGarments = customerDeclinedGarmentsForPartner(
          orderJobsSnap.docs,
          text(shipment.get("fromPartnerAccountId"), 128),
          text(shipment.get("fromPartnerProfileId"), 128),
          billedGarmentIds,
        );
        const rejectedForShipment = rejectedGarments.filter((item) =>
          (!item.returnShipmentId || item.returnShipmentId === shipment.id) &&
          !attachedDeclinedGarmentIds.has(item.garmentId) &&
          orderJobsSnap.docs.some((job) => text(job.get("garmentId"), 128) === item.garmentId &&
            job.get("assignedPartnerAccountId") === shipment.get("fromPartnerAccountId") &&
            job.get("assignedPartnerProfileId") === shipment.get("fromPartnerProfileId")));
        for (const item of rejectedForShipment) attachedDeclinedGarmentIds.add(item.garmentId);
        const returnGarmentFields = customerReturnGarmentFields(shipment, rejectedForShipment);
        tx.update(shipment.ref, {
          ...returnGarmentFields,
          careComplete: true,
          paymentStatusAtDelivery: groupPaid ? "paid" : "requiresCustomerAction",
          invoiceId: invoiceRef.id,
          updatedAt: SERVER_TIMESTAMP(),
        });
        for (const rejectedGarment of rejectedForShipment) {
          for (const job of orderJobsSnap.docs.filter((candidate) =>
            text(candidate.get("garmentId"), 128) === rejectedGarment.garmentId)) {
            tx.update(job.ref, {
              returnWithShipmentId: shipment.id,
              returnWithDeliveryGroupId: deliveryGroupId,
              updatedAt: SERVER_TIMESTAMP(),
            });
          }
        }
      }
      const paymentStatus = orderPaymentStatusFromState(paymentState);
      tx.update(orderRef, {
        paymentStatus,
        paymentActionRequired: hasUnpaidIssuedInvoice(paymentState),
        statusProjection: paymentState.allServicesComplete
          ? followOnServicePending
            ? "awaiting_next_service"
            : paymentState.allPaymentsCaptured ? "awaiting_delivery" : "awaiting_payment"
          : orderSnap.get("statusProjection") === "awaiting_payment"
            ? "open"
            : orderSnap.get("statusProjection") || "open",
        updatedAt: SERVER_TIMESTAMP(),
      });
      return true;
    }
    if (paymentSnap.exists) {
      fail("failed-precondition", "A payment record exists without its invoice; Admin reconciliation is required.");
    }
    if (quoteSnaps.some((quote, index) => {
      if (!quote || !quote.exists) return true;
      const quoteData = quote.data() || {};
      const consent = consentSnaps[index];
      return consent && consent.exists
        ? consent.get("status") !== "accepted"
        : quoteData.status !== "accepted";
    })) {
      return false;
    }
    const orderJobsSnap = await tx.get(db.collection("garment_care_service_jobs")
      .where("orderId", "==", orderId));
    const paymentState = await readGarmentCareOrderPaymentState(tx, orderSnap, orderJobsSnap);
    const followOnServicePending = paymentState.allServicesComplete &&
      await hasPendingCheckoutServiceJobs(
        tx,
        orderId,
        orderSnap.data() || {},
        [...new Set(orderJobsSnap.docs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))],
      );
    const returnShipmentsSnap = await tx.get(db.collection("garment_care_shipments")
      .where("orderId", "==", orderId));
    const billedGarmentIds = billableJobs.map((job) => text(job.get("garmentId"), 128));
    const identityIds = [...new Set(billableJobs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))];
    const identitySnaps = await Promise.all(identityIds.map((id) =>
      tx.get(db.collection("garment_identities").doc(id))));
    const identityById = new Map(identitySnaps.filter((item) => item.exists)
      .map((item) => [item.id, item]));
    const lines = billableJobs.map((job, index) => {
      const quote = quoteSnaps[index].data() || {};
      if (quote.jobId !== job.id || quote.orderId !== orderId ||
          !Number.isFinite(Number(quote.serviceAmount))) {
        fail("failed-precondition", "An accepted inspection quote does not match its Service Job.");
      }
      return {
        jobId: job.id,
        itemId: job.get("itemId"),
        garmentId: job.get("garmentId"),
        subOrderNumber: text(job.get("subOrderNumber"), 8) || null,
        quoteId: quoteSnaps[index].id,
        serviceId: job.get("serviceId"),
        serviceName: job.get("serviceName"),
        serviceAmount: Number(quote.serviceAmount),
        baseServiceAmount: Number(quote.baseServiceAmount) || Number(quote.serviceAmount),
        additionalServiceFee: Number(quote.additionalServiceFee) || 0,
        additionalServiceReason: quote.additionalServiceReason || null,
        taxAmount: Number(quote.taxAmount) || 0,
        logisticsAmount: Number(quote.logisticsAmount) || 0,
        currency: quote.currency || "INR",
        garmentDna: garmentDnaInvoiceSnapshot(
          identityById.get(text(job.get("garmentId"), 128)), job,
        ),
        inspection: inspectionInvoiceSnapshot(quote),
        treatmentRecord: job.get("treatmentRecord") || null,
      };
    });
    const roundMoney = (value) => Math.round(value * 100) / 100;
    const subtotal = roundMoney(lines.reduce((sum, line) => sum + line.serviceAmount, 0));
    const tax = roundMoney(lines.reduce((sum, line) => sum + line.taxAmount, 0));
    const groupFixedLogistics = Number(groupSnap.get("baseLogisticsAmount"));
    const fallbackFixedLogistics = pricingVersionSnap && pricingVersionSnap.exists
      ? Number(pricingVersionSnap.get("logisticsAmount")) || 0
      : 0;
    const logistics = roundMoney(lines.reduce((sum, line) => sum + (Number(line.logisticsAmount) || 0), 0) +
      (Number.isFinite(groupFixedLogistics) ? groupFixedLogistics : fallbackFixedLogistics));
    const invoiceTotal = roundMoney(subtotal + tax + logistics);
    const now = SERVER_TIMESTAMP();
    tx.create(paymentRef, {
      paymentId: paymentRef.id,
      invoiceId: invoiceRef.id,
      orderId,
      orderNumber: orderSnap.get("orderNumber") || null,
      deliveryGroupId,
      customerUid: orderSnap.get("customerUid"),
      amount: invoiceTotal,
      currency: "INR",
      status: "requiresCustomerAction",
      providerReadiness: "blocked_pending_merchant_and_provider_approval",
      providerVerifiedCapture: false,
      capturedAmount: 0,
      refundedAmount: 0,
      createdAt: now,
    });
    tx.create(invoiceRef, {
      invoiceId: invoiceRef.id,
      orderId,
      orderNumber: orderSnap.get("orderNumber") || null,
      deliveryGroupId,
      customerUid: orderSnap.get("customerUid"),
      paymentId: paymentRef.id,
      pricingPolicyVersionId: orderSnap.get("pricingPolicyVersionId") || null,
      currency: "INR",
      lines,
      serviceSubtotal: subtotal,
      taxTotal: tax,
      logisticsTotal: logistics,
      grandTotal: invoiceTotal,
      invoiceStatus: "issued",
      followOnServicePending,
      createdAt: now,
    });
    tx.update(groupRef, {
      invoiceId: invoiceRef.id,
      invoiceTotal,
      invoiceStatus: "awaiting_payment",
      paymentStatus: "requiresCustomerAction",
      followOnServicePending,
      updatedAt: now,
    });
    tx.update(orderRef, {
      invoiceIds: admin.firestore.FieldValue.arrayUnion(invoiceRef.id),
      paymentStatus: orderPaymentStatusFromState(paymentState, true),
      paymentActionRequired: true,
      statusProjection: paymentState.allServicesComplete
        ? followOnServicePending ? "awaiting_next_service" : "awaiting_payment"
        : orderSnap.get("statusProjection") === "awaiting_payment"
          ? "open"
          : orderSnap.get("statusProjection") || "open",
      updatedAt: now,
    });
    const linkedDeclinedGarmentIds = new Set();
    for (const shipment of returnShipmentsSnap.docs) {
      if (shipment.get("shipmentType") === "customer_return" &&
          shipment.get("deliveryGroupId") === deliveryGroupId &&
          shipment.get("status") !== "delivered") {
        const rejectedGarments = customerDeclinedGarmentsForPartner(
          orderJobsSnap.docs,
          text(shipment.get("fromPartnerAccountId"), 128),
          text(shipment.get("fromPartnerProfileId"), 128),
          billedGarmentIds,
        );
        const rejectedForShipment = rejectedGarments.filter((item) =>
          (!item.returnShipmentId || item.returnShipmentId === shipment.id) &&
          !linkedDeclinedGarmentIds.has(item.garmentId) &&
          orderJobsSnap.docs.some((job) => text(job.get("garmentId"), 128) === item.garmentId &&
            job.get("assignedPartnerAccountId") === shipment.get("fromPartnerAccountId") &&
            job.get("assignedPartnerProfileId") === shipment.get("fromPartnerProfileId")));
        for (const item of rejectedForShipment) linkedDeclinedGarmentIds.add(item.garmentId);
        const returnGarmentFields = customerReturnGarmentFields(shipment, rejectedForShipment);
        tx.update(shipment.ref, {
          ...returnGarmentFields,
          careComplete: true,
          paymentStatusAtDelivery: "requiresCustomerAction",
          invoiceId: invoiceRef.id,
          updatedAt: now,
        });
        for (const rejectedGarment of rejectedForShipment) {
          for (const job of orderJobsSnap.docs.filter((candidate) =>
            text(candidate.get("garmentId"), 128) === rejectedGarment.garmentId)) {
            tx.update(job.ref, {
              returnWithShipmentId: shipment.id,
              returnWithDeliveryGroupId: deliveryGroupId,
              updatedAt: now,
            });
          }
        }
      }
    }
    tx.create(orderRef.collection("events").doc(), {
      type: "inspection_quotes_accepted_invoice_issued",
      deliveryGroupId,
      invoiceId: invoiceRef.id,
      paymentId: paymentRef.id,
      amount: invoiceTotal,
      at: now,
    });
    return true;
  });
}


exports.lookupGarmentCareOrderTag = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderNumber = text(data && data.orderNumber, 80);
  if (!orderNumber) fail("invalid-argument", "Order number is required.");
  const matches = await db.collection("garment_care_orders").where("orderNumber", "==", orderNumber).limit(1).get();
  if (matches.empty) fail("not-found", "Garment Care order was not found.");
  const order = matches.docs[0];
  let authorized = order.get("customerUid") === auth.uid;
  if (!authorized && auth.token.phone_number) {
    const account = await db.collection("accounts").where("mobileE164", "==", auth.token.phone_number).limit(1).get();
    if (!account.empty) {
      const accountId = account.docs[0].id;
      const [jobs, shipments] = await Promise.all([
        db.collection("garment_care_service_jobs").where("orderId", "==", order.id).where("assignedPartnerAccountId", "==", accountId).limit(1).get(),
        db.collection("garment_care_shipments").where("orderId", "==", order.id).where("fromPartnerAccountId", "==", accountId).limit(1).get(),
      ]);
      authorized = !jobs.empty || !shipments.empty;
      if (!authorized) {
        const incoming = await db.collection("garment_care_shipments").where("orderId", "==", order.id).where("toPartnerAccountId", "==", accountId).limit(1).get();
        authorized = !incoming.empty;
      }
    }
  }
  if (!authorized) fail("permission-denied", "This order tag is not available to this account.");
  return {
    kind: "garmentCare",
    orderId: order.id,
    orderNumber: order.get("orderNumber"),
    serviceGroupCode: order.get("serviceGroupCode"),
    statusProjection: order.get("statusProjection"),
    itemCount: order.get("itemCount") || 0,
    serviceCount: order.get("serviceCount") || 0,
  };
});

exports.submitGarmentCareFeedback = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = text(data && data.orderId, 128);
  const rating = Number(data && data.rating);
  const feedback = text(data && data.feedback, 1000);
  if (!orderId || !Number.isInteger(rating) || rating < 1 || rating > 5) fail("invalid-argument", "Choose a rating from 1 to 5.");
  const orderRef = db.collection("garment_care_orders").doc(orderId);
  await db.runTransaction(async (tx) => {
    const order = await tx.get(orderRef);
    if (!order.exists || order.get("customerUid") !== auth.uid) fail("permission-denied", "This is not your Garment Care order.");
    if (order.get("statusProjection") !== "completed" || order.get("feedbackSubmittedAt")) {
      fail("failed-precondition", "Feedback is available once after delivery.");
    }
    tx.update(orderRef, { feedbackRating: rating, feedbackText: feedback, feedbackSubmittedAt: SERVER_TIMESTAMP(), updatedAt: SERVER_TIMESTAMP() });
    tx.create(orderRef.collection("events").doc(), { type: "customer_submitted_garment_care_feedback", actorUid: auth.uid, rating, at: SERVER_TIMESTAMP() });
  });
  return { status: "submitted" };
});

exports.reportGarmentCareWarrantyIssue = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = text(data && data.orderId, 128);
  const description = text(data && data.description, 1500);
  if (!orderId || description.length < 5) fail("invalid-argument", "Describe the issue in at least 5 characters.");
  const orderRef = db.collection("garment_care_orders").doc(orderId);
  await db.runTransaction(async (tx) => {
    const order = await tx.get(orderRef);
    if (!order.exists || order.get("customerUid") !== auth.uid) fail("permission-denied", "This is not your Garment Care order.");
    const completedAt = order.get("completedAt");
    if (order.get("statusProjection") !== "completed" || !completedAt ||
        completedAt.toDate().getTime() + 5 * 24 * 60 * 60 * 1000 < Date.now()) {
      fail("failed-precondition", "The five-day Garment Care warranty window is closed.");
    }
    if (["open", "underReview"].includes(order.get("warrantyClaimStatus"))) fail("failed-precondition", "A warranty issue is already open for this order.");
    const claimRef = db.collection("garment_care_warranty_claims").doc();
    tx.create(claimRef, { claimId: claimRef.id, orderId, orderNumber: order.get("orderNumber") || null, customerUid: auth.uid, description, status: "open", reportedAt: SERVER_TIMESTAMP() });
    tx.update(orderRef, { warrantyClaimId: claimRef.id, warrantyClaimStatus: "open", warrantyIssueDescription: description, warrantyIssueReportedAt: SERVER_TIMESTAMP(), updatedAt: SERVER_TIMESTAMP() });
    tx.create(orderRef.collection("events").doc(), { type: "customer_reported_garment_care_warranty_issue", actorUid: auth.uid, claimId: claimRef.id, at: SERVER_TIMESTAMP() });
  });
  return { status: "open" };
});

exports.getGarmentCareDeliveryPaymentDetails = functions.https.onCall(async (data, context) => {
  const shipmentId = text(data && data.shipmentId, 128);
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  await requireGarmentCareDeliveryPartner(context, accountId, profileId);
  if (!shipmentId) fail("invalid-argument", "Choose the customer delivery shipment.");
  const shipment = await db.collection("garment_care_shipments").doc(shipmentId).get();
  if (!shipment.exists || shipment.get("shipmentType") !== "customer_return" ||
      shipment.get("status") !== "inTransit") {
    fail("failed-precondition", "Payment details are available for an active customer delivery.");
  }
  const assignedAccountId = text(shipment.get("deliveryPartnerAccountId") || shipment.get("fromPartnerAccountId"), 128);
  const assignedProfileId = text(shipment.get("deliveryPartnerProfileId") || shipment.get("fromPartnerProfileId"), 128);
  if (assignedAccountId !== accountId || assignedProfileId !== profileId) {
    fail("permission-denied", "This delivery is not assigned to your Partner profile.");
  }
  const deliveryGroupId = text(shipment.get("deliveryGroupId"), 128);
  const relatedRequirements = Array.isArray(shipment.get("relatedPaymentRequirements"))
    ? shipment.get("relatedPaymentRequirements") : [];
  const relatedInvoices = await Promise.all(relatedRequirements.map(async (requirement) => {
    const relatedGroupId = text(requirement && requirement.deliveryGroupId, 128);
    const invoiceId = text(requirement && requirement.invoiceId, 128) || relatedGroupId;
    if (!relatedGroupId || !invoiceId) return { status: "invoice_pending", amountDue: 0 };
    const invoice = await db.collection("garment_care_invoices").doc(invoiceId).get();
    const paymentId = invoice.exists
      ? text(invoice.get("paymentId"), 128) || `payment_${relatedGroupId}`
      : text(requirement && requirement.paymentId, 128) || `payment_${relatedGroupId}`;
    const payment = await db.collection("garment_care_payments").doc(paymentId).get();
    const amount = invoice.exists ? Number(invoice.get("grandTotal")) || 0 : 0;
    const paid = invoice.exists && payment.exists &&
      invoice.get("orderId") === text(requirement.orderId, 128) &&
      invoice.get("deliveryGroupId") === relatedGroupId &&
      invoice.get("customerUid") === shipment.get("toCustomerUid") &&
      payment.get("invoiceId") === invoice.id &&
      payment.get("status") === "captured" && payment.get("providerVerifiedCapture") === true &&
      Math.abs(Number(payment.get("capturedAmount")) - amount) <= 0.01;
    return {
      orderNumber: text(requirement.orderNumber, 32) || null,
      invoiceId: invoice.exists ? invoice.id : invoiceId,
      deliveryGroupId: relatedGroupId,
      status: paid ? "paid" : invoice.exists
        ? payment.exists ? text(payment.get("status"), 40) || "requiresCustomerAction" : "requiresCustomerAction"
        : "invoice_pending",
      amountDue: paid ? 0 : amount,
      currency: invoice.exists ? text(invoice.get("currency"), 8) || "INR" : "INR",
    };
  }));
  let invoice = null;
  let payment = null;
  let ownAmountDue = 0;
  if (shipment.get("returnOnly") !== true) {
    if (!deliveryGroupId) fail("failed-precondition", "The delivery has no invoice group.");
    [invoice, payment] = await Promise.all([
      db.collection("garment_care_invoices").doc(deliveryGroupId).get(),
      db.collection("garment_care_payments").doc(`payment_${deliveryGroupId}`).get(),
    ]);
    if (!invoice.exists || !payment.exists ||
        invoice.get("orderId") !== shipment.get("orderId") ||
        payment.get("invoiceId") !== invoice.id) {
      fail("failed-precondition", "The final order payment request is not ready yet.");
    }
    const ownAmount = Number(invoice.get("grandTotal")) || 0;
    ownAmountDue = payment.get("status") === "captured" && payment.get("providerVerifiedCapture") === true
      ? 0 : ownAmount;
  }
  const relatedAmountDue = relatedInvoices.reduce((sum, item) => sum + item.amountDue, 0);
  const relatedPaymentsPaid = relatedInvoices.every((item) => item.status === "paid");
  const ownPaid = shipment.get("returnOnly") === true || ownAmountDue === 0;
  return {
    amountDue: Math.round((ownAmountDue + relatedAmountDue) * 100) / 100,
    invoiceStatus: shipment.get("returnOnly") === true
      ? relatedInvoices.length ? relatedPaymentsPaid ? "related_paid" : "related_payment_required" : "not_required"
      : text(invoice.get("invoiceStatus"), 40),
    paymentStatus: ownPaid && relatedPaymentsPaid
      ? shipment.get("returnOnly") === true && !relatedInvoices.length ? "not_due" : "paid"
      : "requiresCustomerAction",
    paymentMethod: payment && payment.exists
      ? text(payment.get("collectionMethod") || invoice.get("paymentMethod"), 80)
      : "none",
    relatedInvoices,
  };
});

exports.completeSandboxGarmentCarePayment = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const invoiceId = text(data && data.invoiceId, 128);
  const method = text(data && data.paymentMethod, 24);
  if (!invoiceId || !["card", "upi", "netbanking"].includes(method)) {
    fail("invalid-argument", "Choose an invoice and a valid test payment method.");
  }
  const invoiceRef = db.collection("garment_care_invoices").doc(invoiceId);
  const result = await db.runTransaction(async (tx) => {
    const invoice = await tx.get(invoiceRef);
    if (!invoice.exists) fail("not-found", "The final invoice was not found.");
    const orderId = text(invoice.get("orderId"), 128);
    const deliveryGroupId = text(invoice.get("deliveryGroupId"), 128);
    if (!orderId || !deliveryGroupId || invoiceId !== deliveryGroupId) {
      fail("failed-precondition", "The invoice is not linked to a delivery group.");
    }
    const orderRef = db.collection("garment_care_orders").doc(orderId);
    const groupRef = orderRef.collection("delivery_groups").doc(deliveryGroupId);
    const paymentRef = db.collection("garment_care_payments").doc(
      text(invoice.get("paymentId"), 128) || `payment_${deliveryGroupId}`,
    );
    const [order, group, payment, config, jobs] = await Promise.all([
      tx.get(orderRef), tx.get(groupRef), tx.get(paymentRef),
      tx.get(db.doc("config/payouts")),
      tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", orderId)),
    ]);
    const groupJobs = await tx.get(db.collection("garment_care_service_jobs")
      .where("orderId", "==", orderId).where("deliveryGroupId", "==", deliveryGroupId));
    if (!order.exists || order.get("customerUid") !== auth.uid ||
        invoice.get("customerUid") !== auth.uid) {
      fail("permission-denied", "This final invoice does not belong to your Customer order.");
    }
    if (config.exists && config.get("sandboxMode") === false) {
      fail("failed-precondition", "Live Garment Care payments are not configured. No test payment was recorded.");
    }
    if (!group.exists || !payment.exists || payment.get("invoiceId") !== invoiceId ||
        payment.get("orderId") !== orderId || payment.get("deliveryGroupId") !== deliveryGroupId) {
      fail("failed-precondition", "The invoice payment request is not ready. Contact SuiSakhi support.");
    }
    const total = Number(invoice.get("grandTotal"));
    if (!Number.isFinite(total) || total <= 0 || Math.abs(Number(payment.get("amount")) - total) > 0.01) {
      fail("failed-precondition", "The payment amount does not match the final invoice.");
    }
    const currentStatus = text(payment.get("status"), 40);
    if (currentStatus === "captured" && payment.get("providerVerifiedCapture") === true) {
      return { status: "paid", alreadyPaid: true, amount: total };
    }
    if (currentStatus !== "requiresCustomerAction" || invoice.get("invoiceStatus") !== "issued") {
      fail("failed-precondition", "This invoice is not awaiting Customer payment.");
    }
    if (groupJobs.empty || groupJobs.docs.some((job) =>
      !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")))) {
      fail("failed-precondition", "This garment's care must be complete before its invoice can be paid.");
    }
    const completedJobIds = new Set(groupJobs.docs
      .filter((job) => job.get("status") === "completed")
      .map((job) => job.id));
    const invoiceLines = Array.isArray(invoice.get("lines")) ? invoice.get("lines") : [];
    const invoiceLineJobIds = new Set(invoiceLines.map((line) => text(line && line.jobId, 128)));
    if (invoiceLineJobIds.size !== invoiceLines.length ||
        invoiceLineJobIds.size !== completedJobIds.size ||
        [...invoiceLineJobIds].some((jobId) => !completedJobIds.has(jobId))) {
      fail("failed-precondition", "This invoice must include completed services only; contact support to correct its lines.");
    }
    const paymentState = await readGarmentCareOrderPaymentState(tx, order, jobs);
    const followOnServicePending = paymentState.allServicesComplete &&
      await hasPendingCheckoutServiceJobs(
        tx,
        orderId,
        order.data() || {},
        [...new Set(jobs.docs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))],
      );
    const customerReturnShipments = await tx.get(db.collection("garment_care_shipments")
      .where("orderId", "==", orderId));
    const localReturnPaymentStates = new Map();
    for (const shipment of customerReturnShipments.docs) {
      if (shipment.get("shipmentType") !== "customer_return" ||
          shipment.get("deliveryGroupId") !== deliveryGroupId) continue;
      localReturnPaymentStates.set(shipment.id,
        await readShipmentRelatedPaymentState(tx, shipment.data() || {}));
    }
    const allPaid = paymentState.allServicesComplete &&
      [...paymentState.paymentByGroupId.entries()].every(([groupId, paid]) =>
        paid || groupId === deliveryGroupId);
    const paymentActionRequired = hasUnpaidIssuedInvoice(paymentState, deliveryGroupId);
    const nextOrderPaymentStatus = allPaid ? "paid" : "partiallyPaid";
    const now = SERVER_TIMESTAMP();
    tx.update(paymentRef, {
      status: "captured",
      paymentProvider: "sandbox",
      paymentMethod: method,
      providerReadiness: "sandbox_test_only_no_money_moved",
      providerVerifiedCapture: true,
      capturedAmount: total,
      capturedAt: now,
      allocationStatus: "sandbox_not_allocated",
      updatedAt: now,
    });
    tx.update(invoiceRef, {
      invoiceStatus: "paid",
      paymentMethod: `sandbox_${method}`,
      paidAt: now,
      updatedAt: now,
    });
    tx.update(groupRef, {
      invoiceStatus: "paid",
      paymentStatus: "captured",
      updatedAt: now,
    });
    tx.update(orderRef, {
      paymentStatus: nextOrderPaymentStatus,
      paymentActionRequired,
      ...(allPaid
        ? {
          paidAt: now,
          statusProjection: followOnServicePending ? "awaiting_next_service" : "awaiting_delivery",
        }
        : followOnServicePending
        ? { statusProjection: "awaiting_next_service" }
        : { statusProjection: paymentState.allServicesComplete ? "awaiting_payment" : (order.get("statusProjection") === "awaiting_payment" ? "open" : order.get("statusProjection") || "open") }),
      updatedAt: now,
    });
    for (const shipment of customerReturnShipments.docs) {
      if (shipment.get("shipmentType") === "customer_return" &&
          shipment.get("deliveryGroupId") === deliveryGroupId) {
        const relatedState = localReturnPaymentStates.get(shipment.id);
        tx.update(shipment.ref, {
          paymentStatusAtDelivery: relatedState && !relatedState.allPaid
            ? "requiresCustomerAction" : "paid",
          invoiceId,
          ...(relatedState && !relatedState.allPaid ? {} : { paymentReadyAt: now }),
          updatedAt: now,
        });
      }
    }
    tx.create(orderRef.collection("events").doc(), {
      type: "garment_care_sandbox_payment_completed",
      invoiceId,
      paymentId: paymentRef.id,
      deliveryGroupId,
      amount: total,
      paymentMethod: method,
      actorUid: auth.uid,
      noMoneyMoved: true,
      at: now,
    });
    tx.create(db.collection("garment_care_payment_events").doc(), {
      eventType: "sandbox_payment_completed_no_money_moved",
      invoiceId,
      paymentId: paymentRef.id,
      orderId,
      orderNumber: order.get("orderNumber") || null,
      deliveryGroupId,
      amount: total,
      paymentMethod: method,
      actorUid: auth.uid,
      at: now,
    });
    return { status: "paid", alreadyPaid: false, amount: total, orderPaymentStatus: nextOrderPaymentStatus };
  });
  try {
    await synchronizeRelatedCustomerReturnPayments(deliveryGroupId);
  } catch (error) {
    console.error(`Related Garment Care payment synchronization failed for ${deliveryGroupId}`, error);
  }
  return result;
});

exports.recordGarmentCarePaymentAtDelivery = functions.https.onCall(async (_data, context) => {
  requireAuth(context);
  fail("failed-precondition", "Customer payment must be completed in the app before the Partner dispatches the garments.");
});

exports.confirmGarmentCareCustomerDelivery = functions.https.onCall(async (data, context) => {
  const accountId = text(data && data.partnerAccountId, 128);
  const profileId = text(data && data.partnerProfileId, 128);
  const { auth } = await requireGarmentCareDeliveryPartner(context, accountId, profileId);
  const shipmentId = text(data && data.shipmentId, 128);
  const pin = text(data && data.pin, 4);
  if (!shipmentId) fail("invalid-argument", "Choose the delivery to confirm.");
  if (!/^\d{4}$/.test(pin)) fail("invalid-argument", "Enter the last four digits of your registered phone number.");
  const shipmentRef = db.collection("garment_care_shipments").doc(shipmentId);
  await db.runTransaction(async (tx) => {
    const shipment = await tx.get(shipmentRef);
    if (!shipment.exists || shipment.get("shipmentType") !== "customer_return" ||
        !text(shipment.get("toCustomerUid"), 128)) {
      fail("failed-precondition", "This Customer delivery is not ready for handover confirmation.");
    }
    const record = shipment.data() || {};
    if (record.status === "delivered" && record.deliveryPinVerified === true &&
        record.deliveryConfirmedByAccountId === accountId &&
        record.deliveryConfirmedByProfileId === profileId) {
      return;
    }
    if (record.status !== "inTransit") {
      fail("failed-precondition", "This Customer delivery is not ready for handover confirmation.");
    }
    const returnOnly = record.returnOnly === true;
    if (record.deliveryMode === "other_partner" && text(record.toPartnerAccountId, 128)) {
      fail("failed-precondition", "This shipment is still moving between Partners and has not been dispatched to you.");
    }
    const assignedAccountId = text(record.deliveryPartnerAccountId || record.fromPartnerAccountId, 128);
    const assignedProfileId = text(record.deliveryPartnerProfileId || record.fromPartnerProfileId, 128);
    if (assignedAccountId !== accountId || assignedProfileId !== profileId) {
      fail("permission-denied", "This Customer delivery is not assigned to your Partner profile.");
    }
    const orderRef = db.collection("garment_care_orders").doc(record.orderId);
    const returnGarmentIds = [...new Set([
      ...(Array.isArray(record.garmentIds)
        ? record.garmentIds.map((id) => text(id, 128)).filter(Boolean)
        : []),
      text(record.garmentId, 128),
    ].filter(Boolean))];
    if (!returnGarmentIds.includes(text(record.garmentId, 128))) {
      fail("failed-precondition", "The return shipment is missing its primary garment.");
    }
    const identityRefs = returnGarmentIds.map((id) =>
      db.collection("garment_identities").doc(id));
    const packageRef = record.packageId
      ? db.collection("garment_care_packages").doc(record.packageId) : null;
    const paymentRef = record.deliveryGroupId
      ? db.collection("garment_care_payments").doc(`payment_${text(record.deliveryGroupId, 128)}`)
      : null;
    const [orderSnap, identitySnaps, jobsSnap, groupJobsSnap, packageSnap, paymentSnap] =
      await Promise.all([
        tx.get(orderRef),
        Promise.all(identityRefs.map((ref) => tx.get(ref))),
        tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", record.orderId)),
        tx.get(db.collection("garment_care_service_jobs")
          .where("orderId", "==", record.orderId)
          .where("deliveryGroupId", "==", record.deliveryGroupId)),
        packageRef ? tx.get(packageRef) : Promise.resolve(null),
        paymentRef ? tx.get(paymentRef) : Promise.resolve(null),
      ]);
    const returnJobIds = Array.isArray(record.returnJobIds)
      ? [...new Set(record.returnJobIds.map((id) => text(id, 128)).filter(Boolean))] : [];
    const returnJobSnaps = await Promise.all(returnJobIds.map((id) =>
      tx.get(db.collection("garment_care_service_jobs").doc(id))));
    if (!orderSnap.exists || orderSnap.get("customerUid") !== record.toCustomerUid ||
        identitySnaps.some((identity) =>
          !identity.exists || identity.get("customerUid") !== orderSnap.get("customerUid"))) {
      fail("permission-denied", "This delivery does not belong to your Customer order.");
    }
    const address = orderSnap.get("pickupAddressSnapshot") || {};
    const registeredPhone = text(address.mobileNumber || orderSnap.get("customerPhone"), 32).replace(/\D/g, "");
    if (registeredPhone.length < 4) {
      fail("failed-precondition", "A registered phone number is not available for this order. Contact SuiSakhi support.");
    }
    if (registeredPhone.slice(-4) !== pin) {
      fail("permission-denied", "The four-digit delivery PIN does not match the phone number on this order.");
    }
    const paymentState = await readGarmentCareOrderPaymentState(tx, orderSnap, jobsSnap);
    const relatedPaymentState = await readShipmentRelatedPaymentState(tx, record);
    if (!returnOnly && (groupJobsSnap.empty || groupJobsSnap.docs.some((job) =>
      !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status"))))) {
      fail("failed-precondition", "This garment's care must be complete before confirming handover.");
    }
    if (returnOnly) {
      const primaryJobs = returnJobSnaps.filter((job) =>
        job.exists && text(job.get("garmentId"), 128) === text(record.garmentId, 128));
      if (!returnJobIds.length || !primaryJobs.length || primaryJobs.length !== returnJobSnaps.length || primaryJobs.some((job) =>
        !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")) ||
        text(job.get("returnWithShipmentId"), 128) !== shipmentId) ||
          !primaryJobs.some((job) => job.get("status") === "blocked" &&
            /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800)))) {
        fail("failed-precondition", "This no-charge return must be linked to a completed customer-declined garment.");
      }
    } else if (paymentState.paymentByGroupId.get(text(record.deliveryGroupId, 128)) !== true ||
        !paymentSnap || !paymentSnap.exists || paymentSnap.get("status") !== "captured" ||
        paymentSnap.get("providerVerifiedCapture") !== true) {
      fail("failed-precondition", "This garment's final invoice must be paid before confirming handover.");
    }
    if (!relatedPaymentState.allPaid) {
      fail("failed-precondition", "Earlier completed service invoices for this garment must be paid before confirming handover.");
    }
    if (!returnOnly && returnJobIds.length > 0 && returnJobSnaps.some((job) =>
      !job.exists || !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")) ||
      text(job.get("returnWithShipmentId"), 128) !== shipmentId)) {
      fail("failed-precondition", "Every service for the garments in this return must be complete and linked to the same handover.");
    }
    const bundledGarmentIds = returnGarmentIds.filter((id) => id !== text(record.garmentId, 128));
    for (const bundledGarmentId of bundledGarmentIds) {
      const bundledJobs = jobsSnap.docs.filter((job) =>
        text(job.get("garmentId"), 128) === bundledGarmentId);
      if (!bundledJobs.length || bundledJobs.some((job) =>
        !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")) ||
        text(job.get("returnWithShipmentId"), 128) !== shipmentId) ||
          !bundledJobs.some((job) => job.get("status") === "blocked" &&
            /^declined by customer\b/i.test(text(job.get("customerDecisionNote"), 800)))) {
        fail("failed-precondition", "Only customer-declined garments assigned to this Partner can be returned with the paid garment.");
      }
      const bundledGroupIds = [...new Set(bundledJobs
        .map((job) => text(job.get("deliveryGroupId"), 128))
        .filter((id) => id && id !== text(record.deliveryGroupId, 128)))];
      const bundledInvoices = await Promise.all(bundledGroupIds.map((id) =>
        tx.get(db.collection("garment_care_invoices").doc(id))));
      const verifiedRelatedInvoiceIds = new Set(relatedPaymentState.requirements
        .filter((requirement) => requirement.status === "paid")
        .map((requirement) => text(requirement.invoiceId, 128))
        .filter(Boolean));
      if (bundledInvoices.some((invoice) =>
        invoice.exists && !verifiedRelatedInvoiceIds.has(invoice.id))) {
        fail("failed-precondition", "A declined garment has a separate invoice; contact support before handover.");
      }
    }
    const relatedOrderIds = [...new Set(relatedPaymentState.requirements
      .map((item) => text(item.orderId, 128)).filter((id) => id && id !== record.orderId))];
    const [relatedOrderSnaps, relatedOrderJobsSnaps] = await Promise.all([
      Promise.all(relatedOrderIds.map((id) => tx.get(db.collection("garment_care_orders").doc(id)))),
      Promise.all(relatedOrderIds.map((id) =>
        tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", id)))),
    ]);
    const relatedOrderPaymentStates = await Promise.all(relatedOrderIds.map((id, index) =>
      readGarmentCareOrderPaymentState(tx, relatedOrderSnaps[index], relatedOrderJobsSnaps[index])));
    const allReturnsDelivered = await areGarmentCareJobsReturned(tx, jobsSnap.docs, shipmentId);
    const relatedOrderReturnsDelivered = await Promise.all(relatedOrderJobsSnaps.map((jobs) =>
      areGarmentCareJobsReturned(tx, jobs.docs, shipmentId)));
    const now = SERVER_TIMESTAMP();
    tx.update(shipmentRef, {
      status: "delivered",
      deliveredAt: now,
      customerConfirmedAt: now,
      deliveryConfirmedByPartnerUid: auth.uid,
      deliveryConfirmedByAccountId: accountId,
      deliveryConfirmedByProfileId: profileId,
      deliveryPinVerified: true,
      paymentStatusAtDelivery: returnOnly && relatedPaymentState.requirements.length === 0
        ? "not_due" : "paid",
      updatedAt: now,
    });
    for (const identityRef of identityRefs) {
      tx.update(identityRef, {
        currentCustodianType: "customer",
        currentCustodianAccountId: orderSnap.get("customerAccountId") || null,
        currentCustodianProfileId: orderSnap.get("customerProfileId") || null,
        currentCustodyShipmentId: shipmentId,
        lastDeliveredAt: now,
        lastDeliveryOrderId: record.orderId,
        dnaVersion: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      });
    }
    if (packageRef && packageSnap && packageSnap.exists) {
      tx.update(packageRef, {
        currentCustodianType: "customer",
        currentCustodianAccountId: orderSnap.get("customerAccountId") || null,
        currentCustodianProfileId: orderSnap.get("customerProfileId") || null,
        currentCustodyShipmentId: shipmentId,
        updatedAt: now,
      });
    }
    const custodyRef = db.collection("garment_care_custody_events").doc();
    tx.create(custodyRef, {
      eventId: custodyRef.id,
      orderId: record.orderId,
      orderNumber: record.orderNumber || null,
      cartCheckoutId: text(record.cartCheckoutId || orderSnap.get("cartCheckoutId"), 128) || null,
      itemId: record.itemId || null,
      garmentId: record.garmentId,
      garmentIds: returnGarmentIds,
      packageId: record.packageId || null,
      shipmentId,
      eventType: "customer_delivery_confirmed",
      actorUid: auth.uid,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      at: now,
    });
    for (const garmentId of returnGarmentIds) {
      const isBilledGarment = !returnOnly && garmentId === text(record.garmentId, 128);
      const garmentJob = jobsSnap.docs.find((job) =>
        text(job.get("garmentId"), 128) === garmentId);
      const deliveryHistoryRef = db.collection("garment_care_history_events").doc();
      tx.create(deliveryHistoryRef, {
        eventId: deliveryHistoryRef.id,
        eventType: isBilledGarment
          ? "delivery_completed"
          : "customer_declined_garment_returned_with_paid_garment",
        customerUid: orderSnap.get("customerUid"),
        garmentId,
        orderId: record.orderId,
        orderNumber: record.orderNumber || orderSnap.get("orderNumber") || null,
        cartCheckoutId: text(record.cartCheckoutId || orderSnap.get("cartCheckoutId"), 128) || null,
        itemId: garmentJob && garmentJob.get("itemId") || record.itemId || null,
        deliveryGroupId: isBilledGarment
          ? record.deliveryGroupId || null
          : text(garmentJob && garmentJob.get("deliveryGroupId"), 128) || null,
        shipmentId,
        invoiceId: isBilledGarment ? paymentSnap.get("invoiceId") || null : null,
        paymentId: isBilledGarment ? paymentSnap.id : null,
        paymentStatus: isBilledGarment ? "captured" : "not_billed",
        relatedPaidInvoiceId: isBilledGarment || !paymentSnap || !paymentSnap.exists
          ? null : paymentSnap.get("invoiceId") || null,
        relatedPaidInvoiceIds: relatedPaymentState.requirements
          .filter((requirement) => requirement.status === "paid")
          .map((requirement) => requirement.invoiceId),
        relatedPaidOrderIds: relatedPaymentState.requirements
          .filter((requirement) => requirement.status === "paid")
          .map((requirement) => requirement.orderId),
        paymentMethod: isBilledGarment
          ? paymentSnap.get("paymentMethod") || "verified_provider_capture"
          : null,
        paidAmount: isBilledGarment ? Number(paymentSnap.get("capturedAmount")) || 0 : 0,
        deliveryConfirmedByAccountId: accountId,
        deliveryConfirmedByProfileId: profileId,
        deliveryConfirmedByPartnerUid: auth.uid,
        currency: paymentSnap && paymentSnap.exists
          ? paymentSnap.get("currency") || "INR" : "INR",
        completedAt: now,
        createdAt: now,
      });
    }
    if (paymentState.allServicesComplete && paymentState.allPaymentsCaptured && allReturnsDelivered) {
      tx.update(orderRef, {
        statusProjection: "completed",
        deliveryStatus: "delivered",
        paymentStatus: orderPaymentStatusFromState(paymentState),
        paymentActionRequired: false,
        completedAt: now,
        updatedAt: now,
      });
      tx.create(orderRef.collection("events").doc(), {
        type: orderPaymentStatusFromState(paymentState) === "not_due"
          ? "garment_care_order_delivered_no_payment_due"
          : "garment_care_order_delivered_and_paid",
        actorUid: auth.uid,
        partnerAccountId: accountId,
        partnerProfileId: profileId,
        at: now,
      });
    } else {
      tx.update(orderRef, {
        statusProjection: "partially_delivered",
        deliveryStatus: "partially_delivered",
        paymentStatus: orderPaymentStatusFromState(paymentState),
        paymentActionRequired: hasUnpaidIssuedInvoice(paymentState),
        updatedAt: now,
      });
    }
    for (let index = 0; index < relatedOrderIds.length; index += 1) {
      const relatedOrder = relatedOrderSnaps[index];
      if (!relatedOrder.exists) continue;
      const relatedJobs = relatedOrderJobsSnaps[index].docs;
      const returnedGarmentIds = new Set(
        (Array.isArray(relatedOrder.get("crossOrderReturnedGarmentIds"))
          ? relatedOrder.get("crossOrderReturnedGarmentIds") : [])
          .map((id) => text(id, 128)).filter(Boolean),
      );
      for (const garmentId of returnGarmentIds) returnedGarmentIds.add(garmentId);
      const allRelatedGarmentsReturned = relatedOrderReturnsDelivered[index];
      const siblingPaymentState = relatedOrderPaymentStates[index];
      const siblingServicesComplete = relatedJobs.length > 0 && relatedJobs.every((job) =>
        TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")));
      const siblingComplete = siblingServicesComplete && siblingPaymentState.allPaymentsCaptured &&
        allRelatedGarmentsReturned;
      tx.update(relatedOrder.ref, {
        crossOrderReturnedGarmentIds: [...returnedGarmentIds],
        crossOrderReturnShipmentIds: admin.firestore.FieldValue.arrayUnion(shipmentId),
        ...(siblingComplete ? {
          statusProjection: "completed",
          deliveryStatus: "delivered",
          paymentStatus: orderPaymentStatusFromState(siblingPaymentState),
          paymentActionRequired: false,
          completedAt: now,
        } : {}),
        updatedAt: now,
      });
      const relatedEventRef = relatedOrder.ref.collection("events").doc();
      tx.create(relatedEventRef, {
        type: "garment_care_cross_service_garment_returned",
        shipmentId,
        sourceOrderId: record.orderId,
        sourceOrderNumber: record.orderNumber || null,
        garmentIds: returnGarmentIds,
        actorUid: auth.uid,
        partnerAccountId: accountId,
        partnerProfileId: profileId,
        completed: siblingComplete,
        at: now,
      });
    }
  });
  return { status: "delivered" };
});

exports.respondToGarmentCareConsent = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const consentId = text(data && data.consentId, 128);
  const decision = text(data && data.decision, 20);
  if (!consentId || !["accepted", "rejected"].includes(decision)) {
    fail("invalid-argument", "Choose accept or reject for this consent request.");
  }
  const ref = db.collection("garment_care_consents").doc(consentId);
  let orderId = "";
  let deliveryGroupId = "";
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("customerUid") !== auth.uid) {
      fail("permission-denied", "This consent request is not yours.");
    }
    const jobRef = db.collection("garment_care_service_jobs").doc(snap.get("jobId"));
    const jobSnap = await tx.get(jobRef);
    if (!jobSnap.exists) fail("not-found", "The Service Job was not found.");
    orderId = text(jobSnap.get("orderId"), 128);
    deliveryGroupId = text(jobSnap.get("deliveryGroupId"), 128);
    const orderRef = db.collection("garment_care_orders").doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists || orderSnap.get("customerUid") !== auth.uid) {
      fail("permission-denied", "This order is not yours.");
    }
    const orderJobs = await tx.get(
      db.collection("garment_care_service_jobs").where("orderId", "==", orderId),
    );
    const garmentId = text(jobSnap.get("garmentId"), 128);
    const [garmentJobs, orderShipments] = decision === "rejected"
      ? await Promise.all([
        tx.get(db.collection("garment_care_service_jobs").where("garmentId", "==", garmentId)),
        tx.get(db.collection("garment_care_shipments").where("orderId", "==", orderId)),
      ])
      : [null, null];
    const relatedGarmentData = decision === "rejected"
      ? await readRelatedGarmentPaymentRequirements(tx, orderId, orderSnap.data() || {}, garmentId)
      : { requirements: [], siblingJobs: [] };
    const relatedPaymentRequirements = relatedGarmentData.requirements || [];
    const relatedPaymentGroupIds = relatedPaymentRequirements.map((item) => item.deliveryGroupId);
    const relatedPaymentsArePaid = relatedPaymentRequirements.every((item) => item.status === "paid");
    const careCycleOrderIds = new Set([
      orderId,
      ...(relatedGarmentData.siblingOrders || []).filter((item) => item.exists).map((item) => item.id),
    ]);
    const currentGarmentJobs = (garmentJobs && garmentJobs.docs || []).filter((candidate) =>
      careCycleOrderIds.has(text(candidate.get("orderId"), 128)));
    const anotherCustomerActionPending = orderJobs.docs.some((candidate) =>
      candidate.id !== jobSnap.id &&
      ["awaitingConsent", "awaitingCustomerEdit"].includes(candidate.get("status")));
    if (snap.get("status") === decision) return;
    if (snap.get("status") !== "pending") fail("failed-precondition", "This consent request is no longer pending.");
    const queuedDescendants = new Map();
    if (decision === "rejected") {
      const seen = new Set([jobSnap.id]);
      const frontier = [jobSnap.id];
      while (frontier.length > 0) {
        const predecessorId = frontier.shift();
        const dependents = await tx.get(db.collection("garment_care_service_jobs")
          .where("dependsOnJobId", "==", predecessorId));
        for (const dependent of dependents.docs) {
          if (dependent.get("status") !== "queued" || seen.has(dependent.id)) continue;
          seen.add(dependent.id);
          queuedDescendants.set(dependent.id, dependent);
          frontier.push(dependent.id);
        }
      }
    }
    const affectedSiblingOrderUpdates = new Map();
    if (decision === "rejected" && queuedDescendants.size > 0) {
      const siblingOrdersById = new Map((relatedGarmentData.siblingOrders || [])
        .filter((item) => item.exists).map((item) => [item.id, item]));
      const siblingJobsByOrderId = new Map();
      for (const jobs of relatedGarmentData.siblingJobs || []) {
        const siblingOrderId = jobs.docs.length ? text(jobs.docs[0].get("orderId"), 128) : "";
        if (siblingOrderId) siblingJobsByOrderId.set(siblingOrderId, jobs.docs);
      }
      for (const descendant of queuedDescendants.values()) {
        const descendantOrderId = text(descendant.get("orderId"), 128);
        if (!descendantOrderId || descendantOrderId === orderId ||
            !siblingOrdersById.has(descendantOrderId)) continue;
        const siblingOrder = siblingOrdersById.get(descendantOrderId);
        const siblingJobs = siblingJobsByOrderId.get(descendantOrderId) || [];
        const cancelledJobIds = new Set([...queuedDescendants.values()]
          .filter((candidate) => text(candidate.get("orderId"), 128) === descendantOrderId)
          .map((candidate) => candidate.id));
        const remainingJobs = siblingJobs.filter((candidate) =>
          !cancelledJobIds.has(candidate.id) && candidate.get("status") !== "cancelled");
        const remainingGarmentIds = new Set(remainingJobs
          .filter((candidate) => !text(candidate.get("pickupRejectionCode"), 80))
          .map((candidate) => text(candidate.get("garmentId"), 128)).filter(Boolean));
        affectedSiblingOrderUpdates.set(descendantOrderId, {
          order: siblingOrder,
          itemCount: remainingGarmentIds.size,
          serviceCount: remainingJobs.length,
          cancelledServiceCount: cancelledJobIds.size,
          allServicesCancelled: remainingJobs.length === 0,
        });
      }
    }
    let returnShipmentToUpdate = null;
    let returnPackageToUpdate = null;
    let returnOnlyShipmentRef = null;
    let returnOnlyPackageRef = null;
    let returnPaymentActionRequired = false;
    const assignedAccountId = text(jobSnap.get("assignedPartnerAccountId"), 128);
    const assignedProfileId = text(jobSnap.get("assignedPartnerProfileId"), 128);
    const garmentJobsWillBeTerminal = decision === "rejected" && currentGarmentJobs.length > 0 &&
      currentGarmentJobs.every((candidate) =>
        candidate.id === jobSnap.id || queuedDescendants.has(candidate.id) ||
        TERMINAL_GARMENT_CARE_JOB_STATUSES.has(candidate.get("status")));
    if (decision === "rejected" && garmentJobsWillBeTerminal && assignedAccountId && assignedProfileId) {
      const existingReturn = orderShipments.docs.find((shipment) =>
        shipment.get("shipmentType") === "customer_return" &&
        shipment.get("status") === "planned" && shipment.get("returnOnly") !== true &&
        shipment.get("deliveryMode") === "service_partner" &&
        text(shipment.get("fromPartnerAccountId"), 128) === assignedAccountId &&
        text(shipment.get("fromPartnerProfileId"), 128) === assignedProfileId &&
        !(Array.isArray(shipment.get("garmentIds")) &&
          shipment.get("garmentIds").map((id) => text(id, 128)).includes(garmentId)));
      const otherAssignedWorkPending = orderJobs.docs.some((candidate) =>
        text(candidate.get("garmentId"), 128) !== garmentId &&
        candidate.get("assignedPartnerAccountId") === assignedAccountId &&
        candidate.get("assignedPartnerProfileId") === assignedProfileId &&
        !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(candidate.get("status")));
      if (existingReturn) {
        returnShipmentToUpdate = existingReturn;
        const packageId = text(existingReturn.get("packageId"), 128);
        if (packageId) {
          const packageSnap = await tx.get(db.collection("garment_care_packages").doc(packageId));
          if (packageSnap.exists) returnPackageToUpdate = packageSnap;
        }
      } else if (!otherAssignedWorkPending) {
        returnOnlyShipmentRef = db.collection("garment_care_shipments").doc();
        returnOnlyPackageRef = db.collection("garment_care_packages").doc();
      }
    }
    tx.update(ref, { status: decision, decidedAt: SERVER_TIMESTAMP(), decidedByUid: auth.uid });
    tx.update(jobRef, {
      status: decision === "accepted" ? "readyToStart" : "blocked",
      ...(decision === "rejected" ? {
        customerDecisionNote: "Declined by customer: the proposed service or price change was not approved. Do not perform this service; do not bill this garment. Return it with completed garments when possible, or arrange a no-charge return.",
        customerRejectedAt: SERVER_TIMESTAMP(),
      } : {}),
      updatedAt: SERVER_TIMESTAMP(),
    });
    tx.create(jobRef.collection("events").doc(), {
      type: "customer_consent_decided",
      consentId,
      decision,
      actorUid: auth.uid,
      at: SERVER_TIMESTAMP(),
    });
    if (decision === "rejected") {
      for (const dependent of queuedDescendants.values()) {
        tx.update(dependent.ref, {
          status: "cancelled",
          dispatchEligible: false,
          cancellationReason: "customer_declined_suborder",
          customerDeclinedJobId: jobSnap.id,
          customerDecisionNote: "Not started because the customer declined a service for this garment. Do not bill this garment; return it with completed garments when possible.",
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.create(dependent.ref.collection("events").doc(), {
          type: "cancelled_after_customer_service_decline",
          declinedJobId: jobSnap.id,
          actorType: "system",
          at: SERVER_TIMESTAMP(),
        });
      }
      for (const [siblingOrderId, update] of affectedSiblingOrderUpdates.entries()) {
        tx.update(update.order.ref, {
          itemCount: update.itemCount,
          serviceCount: update.serviceCount,
          customerDeclinedGarmentIds: admin.firestore.FieldValue.arrayUnion(garmentId),
          cancelledServiceCount: admin.firestore.FieldValue.increment(update.cancelledServiceCount),
          ...(update.allServicesCancelled ? {
            statusProjection: "cancelled",
            deliveryStatus: "not_required",
            paymentStatus: "not_due",
            paymentActionRequired: false,
            completedAt: SERVER_TIMESTAMP(),
          } : {}),
          updatedAt: SERVER_TIMESTAMP(),
        });
        tx.create(update.order.ref.collection("events").doc(), {
          type: "garment_care_follow_on_services_cancelled_after_customer_decline",
          declinedOrderId: orderId,
          declinedOrderNumber: orderSnap.get("orderNumber") || null,
          declinedGarmentId: garmentId,
          cancelledServiceCount: update.cancelledServiceCount,
          orderCancelled: update.allServicesCancelled,
          actorType: "system",
          at: SERVER_TIMESTAMP(),
        });
      }
      const returnShipmentId = returnShipmentToUpdate?.id || returnOnlyShipmentRef?.id;
      if (returnShipmentId) {
        const declinedGarment = {
          garmentId,
          subOrderNumber: text(jobSnap.get("subOrderNumber"), 8),
          displayName: text(jobSnap.get("displayName"), 120),
        };
        const returnGroupId = returnShipmentToUpdate
          ? text(returnShipmentToUpdate.get("deliveryGroupId"), 128)
          : deliveryGroupId;
        if (returnShipmentToUpdate) {
          const returnGarmentFields = customerReturnGarmentFields(
            returnShipmentToUpdate,
            [declinedGarment],
          );
          const existingRequirements = Array.isArray(returnShipmentToUpdate.get("relatedPaymentRequirements"))
            ? returnShipmentToUpdate.get("relatedPaymentRequirements") : [];
          const mergedRequirementsByGroupId = new Map();
          for (const requirement of [...existingRequirements, ...relatedPaymentRequirements]) {
            const groupId = text(requirement && requirement.deliveryGroupId, 128);
            if (groupId) mergedRequirementsByGroupId.set(groupId, requirement);
          }
          const mergedRequirements = [...mergedRequirementsByGroupId.values()];
          const mergedRequirementsArePaid = mergedRequirements.every((item) => item.status === "paid");
          returnPaymentActionRequired = mergedRequirements.length > 0 && !mergedRequirementsArePaid;
          const existingPaymentStatus = text(returnShipmentToUpdate.get("paymentStatusAtDelivery"), 40);
          tx.update(returnShipmentToUpdate.ref, {
            ...returnGarmentFields,
            returnJobIds: [...new Set([
              ...(Array.isArray(returnShipmentToUpdate.get("returnJobIds"))
                ? returnShipmentToUpdate.get("returnJobIds").map((id) => text(id, 128)) : []),
              ...currentGarmentJobs.map((candidate) => candidate.id),
            ].filter(Boolean))],
            relatedPaymentRequirements: mergedRequirements,
            requiredPaymentGroupIds: mergedRequirements.map((item) => item.deliveryGroupId),
            paymentStatusAtDelivery: existingPaymentStatus === "paid" && mergedRequirementsArePaid
              ? "paid"
              : mergedRequirements.length && !mergedRequirementsArePaid
                ? "requiresCustomerAction"
                : existingPaymentStatus,
            updatedAt: SERVER_TIMESTAMP(),
          });
          if (returnPackageToUpdate) {
            tx.update(returnPackageToUpdate.ref, {
              garmentIds: returnGarmentFields.garmentIds,
              subOrderNumbersByGarmentId: returnGarmentFields.subOrderNumbersByGarmentId,
              garmentDisplayNamesById: returnGarmentFields.garmentDisplayNamesById,
              updatedAt: SERVER_TIMESTAMP(),
            });
          }
        } else if (returnOnlyShipmentRef && returnOnlyPackageRef) {
          const subOrderNumber = text(jobSnap.get("subOrderNumber"), 8);
          const displayName = text(jobSnap.get("displayName"), 120);
          tx.create(returnOnlyShipmentRef, {
            shipmentId: returnOnlyShipmentRef.id,
            orderId,
            orderNumber: orderSnap.get("orderNumber") || null,
            deliveryGroupId,
            itemId: jobSnap.get("itemId") || null,
            garmentId,
            garmentIds: [garmentId],
            ...(subOrderNumber ? { subOrderNumber } : {}),
            subOrderNumbersByGarmentId: subOrderNumber
              ? { [garmentId]: subOrderNumber } : {},
            garmentDisplayNamesById: displayName ? { [garmentId]: displayName } : {},
            returnIncludesCustomerDeclinedGarmentIds: [garmentId],
            relatedPaymentRequirements,
            requiredPaymentGroupIds: relatedPaymentGroupIds,
            returnJobIds: currentGarmentJobs.map((candidate) => candidate.id),
            cartCheckoutId: text(orderSnap.get("cartCheckoutId"), 128) || null,
            packageId: returnOnlyPackageRef.id,
            shipmentType: "customer_return",
            deliveryMode: "service_partner",
            returnOnly: true,
            returnReason: "customer_declined_inspection",
            careComplete: true,
            paymentStatusAtDelivery: relatedPaymentRequirements.length
              ? relatedPaymentsArePaid ? "paid" : "requiresCustomerAction"
              : "not_due",
            toCustomerUid: auth.uid,
            fromPartnerAccountId: assignedAccountId,
            fromPartnerProfileId: assignedProfileId,
            fromPartnerName: text(jobSnap.get("assignedPartnerName"), 120) || null,
            fromPartnerContactPhone: text(jobSnap.get("assignedPartnerContactPhone"), 32) || null,
            deliveryPartnerName: text(jobSnap.get("assignedPartnerName"), 120) || null,
            deliveryPartnerContactPhone: text(jobSnap.get("assignedPartnerContactPhone"), 32) || null,
            toPartnerAccountId: assignedAccountId,
            toPartnerProfileId: assignedProfileId,
            status: "planned",
            createdAt: SERVER_TIMESTAMP(),
            updatedAt: SERVER_TIMESTAMP(),
          });
          returnPaymentActionRequired = relatedPaymentRequirements.length > 0 && !relatedPaymentsArePaid;
          tx.create(returnOnlyPackageRef, {
            packageId: returnOnlyPackageRef.id,
            orderId,
            orderNumber: orderSnap.get("orderNumber") || null,
            deliveryGroupId,
            garmentIds: [garmentId],
            subOrderNumbersByGarmentId: subOrderNumber
              ? { [garmentId]: subOrderNumber } : {},
            garmentDisplayNamesById: displayName ? { [garmentId]: displayName } : {},
            packageType: "customer_return_container",
            temporary: true,
            createdAt: SERVER_TIMESTAMP(),
          });
          tx.update(orderRef, {
            shipmentIds: admin.firestore.FieldValue.arrayUnion(returnOnlyShipmentRef.id),
            packageIds: admin.firestore.FieldValue.arrayUnion(returnOnlyPackageRef.id),
            updatedAt: SERVER_TIMESTAMP(),
          });
        }
        for (const candidate of currentGarmentJobs) {
          tx.update(candidate.ref, {
            returnWithShipmentId: returnShipmentId,
            returnWithDeliveryGroupId: returnGroupId,
            updatedAt: SERVER_TIMESTAMP(),
          });
        }
      }
    }
    if (decision === "rejected" && (returnShipmentToUpdate || returnOnlyShipmentRef)) {
      tx.update(orderRef, {
        statusProjection: "return_pending",
        deliveryStatus: "return_pending",
        paymentActionRequired: orderSnap.get("paymentActionRequired") === true || returnPaymentActionRequired,
        updatedAt: SERVER_TIMESTAMP(),
      });
    } else if (anotherCustomerActionPending || orderSnap.get("statusProjection") === "customer_action_required") {
      tx.update(orderRef, {
        statusProjection: anotherCustomerActionPending ? "customer_action_required" : "open",
        updatedAt: SERVER_TIMESTAMP(),
      });
    }
  });
  if (decision === "rejected") {
    try {
      await runAutomaticGarmentCareRouting();
    } catch (error) {
      console.error(`Automatic Garment Care routing after customer decline failed for ${deliveryGroupId}`, error);
    }
  }
  return { decision };
});


exports.completeSandboxGarmentCarePaymentBatch = functions.https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const invoiceIds = [...new Set((Array.isArray(data && data.invoiceIds) ? data.invoiceIds : [])
    .map((value) => text(value, 128)).filter(Boolean))];
  const method = text(data && data.paymentMethod, 24);
  if (invoiceIds.length < 2 || invoiceIds.length > 100 ||
      !["card", "upi", "netbanking"].includes(method)) {
    fail("invalid-argument", "Choose at least two invoices from one service order and a valid test payment method.");
  }
  const invoiceRefs = invoiceIds.map((id) => db.collection("garment_care_invoices").doc(id));
  const result = await db.runTransaction(async (tx) => {
    const invoiceSnaps = await Promise.all(invoiceRefs.map((ref) => tx.get(ref)));
    if (invoiceSnaps.some((invoice) => !invoice.exists)) fail("not-found", "One or more final invoices were not found.");
    const orderId = text(invoiceSnaps[0].get("orderId"), 128);
    const orderRef = db.collection("garment_care_orders").doc(orderId);
    const rows = invoiceSnaps.map((invoice) => {
      const deliveryGroupId = text(invoice.get("deliveryGroupId"), 128);
      if (!deliveryGroupId || invoice.id !== deliveryGroupId ||
          text(invoice.get("orderId"), 128) !== orderId || invoice.get("customerUid") !== auth.uid) {
        fail("failed-precondition", "Combined payment can include invoices from one Customer service order only.");
      }
      return {
        invoice,
        deliveryGroupId,
        amount: Number(invoice.get("grandTotal")),
        groupRef: orderRef.collection("delivery_groups").doc(deliveryGroupId),
        paymentRef: db.collection("garment_care_payments").doc(
          text(invoice.get("paymentId"), 128) || `payment_${deliveryGroupId}`,
        ),
      };
    });
    const [order, config, jobs, shipments, ...related] = await Promise.all([
      tx.get(orderRef),
      tx.get(db.doc("config/payouts")),
      tx.get(db.collection("garment_care_service_jobs").where("orderId", "==", orderId)),
      tx.get(db.collection("garment_care_shipments").where("orderId", "==", orderId)),
      ...rows.flatMap((row) => [
        tx.get(row.groupRef),
        tx.get(row.paymentRef),
        tx.get(db.collection("garment_care_service_jobs")
          .where("orderId", "==", orderId).where("deliveryGroupId", "==", row.deliveryGroupId)),
      ]),
    ]);
    if (!order.exists || order.get("customerUid") !== auth.uid) {
      fail("permission-denied", "This service order does not belong to your Customer account.");
    }
    if (config.exists && config.get("sandboxMode") === false) {
      fail("failed-precondition", "Live Garment Care payments are not configured. No test payment was recorded.");
    }
    const states = rows.map((row, index) => ({
      ...row,
      group: related[index * 3],
      payment: related[index * 3 + 1],
      groupJobs: related[index * 3 + 2],
    }));
    const alreadyPaid = states.every((row) => row.invoice.get("invoiceStatus") === "paid" &&
      row.payment.exists && row.payment.get("status") === "captured" &&
      row.payment.get("providerVerifiedCapture") === true &&
      Math.abs(Number(row.payment.get("capturedAmount")) - row.amount) <= 0.01);
    if (alreadyPaid) {
      return {
        status: "paid",
        alreadyPaid: true,
        amount: Math.round(states.reduce((sum, row) => sum + row.amount, 0) * 100) / 100,
        paymentBatchId: text(states[0].invoice.get("paymentBatchId"), 128) || null,
      };
    }
    for (const row of states) {
      if (!row.group.exists || !row.payment.exists ||
          row.payment.get("invoiceId") !== row.invoice.id ||
          row.payment.get("orderId") !== orderId ||
          row.payment.get("deliveryGroupId") !== row.deliveryGroupId ||
          row.payment.get("customerUid") !== auth.uid ||
          row.payment.get("status") !== "requiresCustomerAction" ||
          row.invoice.get("invoiceStatus") !== "issued" ||
          !Number.isFinite(row.amount) || row.amount <= 0 ||
          Math.abs(Number(row.payment.get("amount")) - row.amount) > 0.01) {
        fail("failed-precondition", "Every invoice in a combined payment must be issued, unpaid, and ready.");
      }
      const groupJobs = row.groupJobs.docs;
      if (!groupJobs.length || groupJobs.some((job) =>
        !TERMINAL_GARMENT_CARE_JOB_STATUSES.has(job.get("status")))) {
        fail("failed-precondition", "Every included garment must finish its service steps before payment.");
      }
      const completedJobIds = new Set(groupJobs.filter((job) => job.get("status") === "completed").map((job) => job.id));
      const lines = Array.isArray(row.invoice.get("lines")) ? row.invoice.get("lines") : [];
      const lineJobIds = new Set(lines.map((line) => text(line && line.jobId, 128)));
      if (lineJobIds.size !== lines.length || lineJobIds.size !== completedJobIds.size ||
          [...lineJobIds].some((jobId) => !completedJobIds.has(jobId))) {
        fail("failed-precondition", "Each included invoice must contain only its completed service lines.");
      }
    }

    const paymentState = await readGarmentCareOrderPaymentState(tx, order, jobs);
    const batchGroupIds = new Set(rows.map((row) => row.deliveryGroupId));
    const shipmentStates = new Map();
    for (const shipment of shipments.docs) {
      if (shipment.get("shipmentType") === "customer_return" &&
          batchGroupIds.has(text(shipment.get("deliveryGroupId"), 128)) &&
          shipment.get("status") !== "delivered") {
        shipmentStates.set(shipment.id, await readShipmentRelatedPaymentState(tx, shipment.data() || {}));
      }
    }
    const followOnServicePending = paymentState.allServicesComplete &&
      await hasPendingCheckoutServiceJobs(
        tx, orderId, order.data() || {},
        [...new Set(jobs.docs.map((job) => text(job.get("garmentId"), 128)).filter(Boolean))],
      );
    const total = Math.round(rows.reduce((sum, row) => sum + row.amount, 0) * 100) / 100;
    const paymentBatchRef = db.collection("garment_care_payment_batches").doc();
    const batchPaymentRef = db.collection("garment_care_payments").doc(`payment_batch_${paymentBatchRef.id}`);
    const invoiceLines = rows.map((row) => {
      const first = (Array.isArray(row.invoice.get("lines")) ? row.invoice.get("lines") : [])[0] || {};
      const dna = first.garmentDna && typeof first.garmentDna === "object" ? first.garmentDna : {};
      return {
        invoiceId: row.invoice.id,
        deliveryGroupId: row.deliveryGroupId,
        subOrderNumber: text(first.subOrderNumber, 12) || null,
        garmentId: text(first.garmentId, 128) || null,
        displayName: text(dna.displayName, 120) || text(first.serviceName, 120) || "Garment",
        serviceSubtotal: Number(row.invoice.get("serviceSubtotal")) || 0,
        taxTotal: Number(row.invoice.get("taxTotal")) || 0,
        logisticsTotal: Number(row.invoice.get("logisticsTotal")) || 0,
        grandTotal: row.amount,
      };
    });
    const sumField = (field) => Math.round(rows.reduce((sum, row) =>
      sum + (Number(row.invoice.get(field)) || 0), 0) * 100) / 100;
    const now = SERVER_TIMESTAMP();
    const paymentBatchId = paymentBatchRef.id;
    const totalFields = {
      serviceSubtotal: sumField("serviceSubtotal"),
      taxTotal: sumField("taxTotal"),
      logisticsTotal: sumField("logisticsTotal"),
    };

    tx.create(batchPaymentRef, {
      paymentId: batchPaymentRef.id,
      paymentBatchId,
      invoiceIds,
      deliveryGroupIds: [...batchGroupIds],
      orderId,
      orderNumber: order.get("orderNumber") || null,
      customerUid: auth.uid,
      amount: total,
      currency: "INR",
      status: "captured",
      paymentProvider: "sandbox",
      paymentMethod: method,
      providerReadiness: "sandbox_test_only_no_money_moved",
      providerVerifiedCapture: true,
      capturedAmount: total,
      refundedAmount: 0,
      allocationStatus: "sandbox_not_allocated",
      collectionMode: "customer_prepaid_before_delivery",
      createdAt: now,
      capturedAt: now,
    });
    tx.create(paymentBatchRef, {
      paymentBatchId,
      orderId,
      orderNumber: order.get("orderNumber") || null,
      serviceGroupCode: text(order.get("serviceGroupCode"), 80) || null,
      customerUid: auth.uid,
      invoiceIds,
      deliveryGroupIds: [...batchGroupIds],
      lines: invoiceLines,
      ...totalFields,
      grandTotal: total,
      currency: "INR",
      invoiceStatus: "paid",
      paymentStatus: "captured",
      paymentId: batchPaymentRef.id,
      paymentMethod: `sandbox_${method}`,
      noMoneyMoved: true,
      createdAt: now,
      paidAt: now,
    });
    for (const row of states) {
      tx.update(row.paymentRef, {
        status: "captured",
        paymentProvider: "sandbox",
        paymentMethod: method,
        providerReadiness: "sandbox_test_only_no_money_moved",
        providerVerifiedCapture: true,
        capturedAmount: row.amount,
        paymentBatchId,
        batchPaymentId: batchPaymentRef.id,
        capturedAt: now,
        allocationStatus: "sandbox_not_allocated",
        updatedAt: now,
      });
      tx.update(row.invoice.ref, {
        invoiceStatus: "paid",
        paymentMethod: `sandbox_${method}`,
        paymentBatchId,
        paidAt: now,
        updatedAt: now,
      });
      tx.update(row.group.ref, {
        invoiceStatus: "paid",
        paymentStatus: "captured",
        paymentBatchId,
        updatedAt: now,
      });
    }
    const allPaid = paymentState.allServicesComplete &&
      [...paymentState.paymentByGroupId.entries()].every(([groupId, paid]) =>
        paid || batchGroupIds.has(groupId));
    const paymentActionRequired = [...paymentState.invoiceByGroupId.entries()].some(
      ([groupId, hasInvoice]) => hasInvoice && !batchGroupIds.has(groupId) &&
        paymentState.paymentByGroupId.get(groupId) !== true,
    );
    const nextOrderPaymentStatus = allPaid ? "paid" : "partiallyPaid";
    tx.update(orderRef, {
      paymentStatus: nextOrderPaymentStatus,
      paymentActionRequired,
      ...(allPaid ? { paidAt: now } : {}),
      statusProjection: allPaid
        ? followOnServicePending ? "awaiting_next_service" : "awaiting_delivery"
        : followOnServicePending ? "awaiting_next_service"
        : paymentState.allServicesComplete ? "awaiting_payment"
        : order.get("statusProjection") === "awaiting_payment" ? "open"
        : order.get("statusProjection") || "open",
      updatedAt: now,
    });
    for (const shipment of shipments.docs) {
      const groupId = text(shipment.get("deliveryGroupId"), 128);
      if (shipment.get("shipmentType") !== "customer_return" || !batchGroupIds.has(groupId) ||
          shipment.get("status") === "delivered") continue;
      const relatedState = shipmentStates.get(shipment.id);
      const shipmentPaid = relatedState && relatedState.requirements.every((item) =>
        item.status === "paid" || batchGroupIds.has(text(item.deliveryGroupId, 128)));
      tx.update(shipment.ref, {
        paymentStatusAtDelivery: shipmentPaid ? "paid" : "requiresCustomerAction",
        invoiceId: groupId,
        paymentBatchId,
        ...(shipmentPaid ? { paymentReadyAt: now } : {}),
        updatedAt: now,
      });
    }
    tx.create(orderRef.collection("events").doc(), {
      type: "garment_care_sandbox_payment_batch_completed",
      paymentBatchId,
      paymentId: batchPaymentRef.id,
      invoiceIds,
      deliveryGroupIds: [...batchGroupIds],
      amount: total,
      paymentMethod: method,
      actorUid: auth.uid,
      noMoneyMoved: true,
      at: now,
    });
    tx.create(db.collection("garment_care_payment_events").doc(), {
      eventType: "sandbox_payment_batch_completed_no_money_moved",
      paymentBatchId,
      paymentId: batchPaymentRef.id,
      invoiceIds,
      orderId,
      orderNumber: order.get("orderNumber") || null,
      amount: total,
      paymentMethod: method,
      actorUid: auth.uid,
      at: now,
    });
    return { status: "paid", alreadyPaid: false, amount: total, paymentBatchId, orderPaymentStatus: nextOrderPaymentStatus };
  });
  if (!result.alreadyPaid) {
    for (const invoiceId of invoiceIds) {
      try {
        await synchronizeRelatedCustomerReturnPayments(invoiceId);
      } catch (error) {
        console.error(`Related Garment Care payment synchronization failed for ${invoiceId}`, error);
      }
    }
  }
  return result;
});

// Provider adapters must set providerVerifiedCapture only after signature and
// API verification. This callable performs the idempotent internal allocation.

exports.deleteExpiredGarmentCareEvidence = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix: "garment_care_evidence/" });
    const now = Date.now();
    let deleted = 0;
    for (const file of files) {
      const [metadata] = await file.getMetadata();
      const orderId = text(metadata && metadata.metadata && metadata.metadata.orderId, 128);
      if (!orderId) continue;
      const order = await db.collection("garment_care_orders").doc(orderId).get();
      const completedAt = order.exists ? order.get("completedAt") : null;
      if (completedAt && completedAt.toDate().getTime() + 7 * 24 * 60 * 60 * 1000 <= now) {
        await file.delete({ ignoreNotFound: true });
        deleted += 1;
      }
    }
    return { deleted };
  });

exports.allocateGarmentCareCapturedPayment = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);
  const paymentId = text(data && data.paymentId, 128);
  if (!paymentId) fail("invalid-argument", "Payment ID is required.");
  const paymentRef = db.collection("garment_care_payments").doc(paymentId);
  let allocationIds = [];
  await db.runTransaction(async (tx) => {
    const paymentSnap = await tx.get(paymentRef);
    if (!paymentSnap.exists) fail("not-found", "Garment Care payment was not found.");
    if (paymentSnap.get("allocationStatus") === "allocated") {
      allocationIds = paymentSnap.get("allocationIds") || [];
      return;
    }
    if (paymentSnap.get("paymentProvider") === "sandbox") {
      fail("failed-precondition", "Sandbox Garment Care payments move no money and cannot create Partner payouts.");
    }
    if (paymentSnap.get("status") !== "captured" || paymentSnap.get("providerVerifiedCapture") !== true) {
      fail("failed-precondition", "Payment must be captured and verified by the configured provider before allocation.");
    }
    const invoiceId = text(paymentSnap.get("invoiceId"), 128);
    const invoiceRef = db.collection("garment_care_invoices").doc(invoiceId);
    const invoiceSnap = await tx.get(invoiceRef);
    if (!invoiceSnap.exists || invoiceSnap.get("orderId") !== paymentSnap.get("orderId") ||
        invoiceSnap.get("deliveryGroupId") !== paymentSnap.get("deliveryGroupId")) {
      fail("failed-precondition", "Payment does not match its delivery-group invoice.");
    }
    const invoice = invoiceSnap.data() || {};
    const orderRef = db.collection("garment_care_orders").doc(invoice.orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) fail("not-found", "The Garment Care order was not found.");
    const returnShipmentsSnap = await tx.get(db.collection("garment_care_shipments")
      .where("orderId", "==", invoice.orderId));
    const capturedAmount = Number(paymentSnap.get("capturedAmount"));
    const invoiceTotal = Number(invoice.grandTotal);
    if (!Number.isFinite(capturedAmount) || !Number.isFinite(invoiceTotal) ||
        Math.abs(capturedAmount - invoiceTotal) > 0.01) {
      fail("failed-precondition", "Captured amount does not equal the final invoice total.");
    }
    const jobsQuery = db.collection("garment_care_service_jobs")
      .where("orderId", "==", paymentSnap.get("orderId"))
      .where("deliveryGroupId", "==", paymentSnap.get("deliveryGroupId"));
    const jobsSnap = await tx.get(jobsQuery);
    const billableJobs = jobsSnap.docs.filter((job) => job.get("status") === "completed");
    if (!billableJobs.length || billableJobs.some((job) => job.get("status") !== "completed")) {
      fail("failed-precondition", "Every Service Job in the delivery group must be complete before payment allocation.");
    }
    const invoiceLines = Array.isArray(invoice.lines) ? invoice.lines : [];
    const lineByJob = new Map(invoiceLines.map((line) => [text(line.jobId, 128), line]));
    if (lineByJob.size !== billableJobs.length || billableJobs.some((job) => !lineByJob.has(job.id))) {
      fail("failed-precondition", "Invoice service lines do not match the completed Service Jobs.");
    }
    const rateSnaps = await Promise.all(billableJobs.map((job) =>
      tx.get(db.collection("garment_care_partner_quote_rates").doc(text(job.get("quoteVersionId"), 128)))));
    const payableRefs = billableJobs.map((job) =>
      db.collection("garment_care_partner_payables").doc(`accrual_${job.id}`));
    const payableSnaps = await Promise.all(payableRefs.map((ref) => tx.get(ref)));
    if (rateSnaps.some((rate) => !rate.exists) || payableSnaps.some((entry) => !entry.exists)) {
      fail("failed-precondition", "A completed service is missing its private payable or accrued ledger entry.");
    }
    const allocationRefs = [];
    let partnerAndCommissionTotal = 0;
    billableJobs.forEach((job, index) => {
      const line = lineByJob.get(job.id) || {};
      const privateRate = rateSnaps[index].data() || {};
      const payable = payableSnaps[index];
      const partnerAmount = Number(privateRate.partnerPayableAmount);
      const commissionAmount = Number(privateRate.platformCommissionAmount);
      const serviceAmount = Number(line.serviceAmount);
      if (privateRate.jobId !== job.id || payable.get("jobId") !== job.id ||
          payable.get("ledgerStatus") !== "accrued" ||
          !Number.isFinite(partnerAmount) || !Number.isFinite(commissionAmount) ||
          Math.abs(partnerAmount + commissionAmount - serviceAmount) > 0.01) {
        fail("failed-precondition", `Payment allocation does not reconcile for Service Job ${job.id}.`);
      }
      partnerAndCommissionTotal += partnerAmount + commissionAmount;
      const partnerAllocationRef = db.collection("garment_care_payment_allocations")
        .doc(`allocation_${paymentId}_partner_${job.id}`);
      const commissionAllocationRef = db.collection("garment_care_payment_allocations")
        .doc(`allocation_${paymentId}_commission_${job.id}`);
      allocationRefs.push({ ref: partnerAllocationRef, type: "partner_service_payable", amount: partnerAmount, job, privateRate });
      allocationRefs.push({ ref: commissionAllocationRef, type: "platform_commission", amount: commissionAmount, job, privateRate });
    });
    const subtotal = Number(invoice.serviceSubtotal);
    const logistics = Number(invoice.logisticsTotal);
    const tax = Number(invoice.taxTotal);
    const currencyTotal = Math.round((partnerAndCommissionTotal + logistics + tax) * 100) / 100;
    if (![subtotal, logistics, tax].every(Number.isFinite) ||
        Math.abs(partnerAndCommissionTotal - subtotal) > 0.01 ||
        Math.abs(currencyTotal - capturedAmount) > 0.01) {
      fail("failed-precondition", "Partner, platform, logistics and tax allocations do not equal the captured amount.");
    }
    const orderInvoiceIds = [...new Set([
      ...(Array.isArray(orderSnap.get("invoiceIds")) ? orderSnap.get("invoiceIds") : []),
      invoiceId,
    ].map((id) => text(id, 128)).filter(Boolean))];
    const orderInvoiceSnaps = await Promise.all(orderInvoiceIds.map((id) =>
      id === invoiceId ? Promise.resolve(invoiceSnap) :
        tx.get(db.collection("garment_care_invoices").doc(id))));
    const issuedInvoices = orderInvoiceSnaps
      .filter((item) => item && item.exists)
      .map((item) => ({
        invoice: item,
        paymentRef: db.collection("garment_care_payments")
          .doc(text(item.get("paymentId"), 128) || `payment_${item.id}`),
      }));
    const orderPaymentSnaps = await Promise.all(issuedInvoices.map(({ paymentRef: ref }) =>
      ref.id === paymentId ? Promise.resolve(paymentSnap) : tx.get(ref)));
    const paymentStatusByInvoiceId = new Map();
    issuedInvoices.forEach(({ invoice: item }, index) => {
      const paymentForInvoice = orderPaymentSnaps[index];
      const paid = paymentForInvoice && paymentForInvoice.exists &&
        (paymentForInvoice.get("status") === "collectedAtDelivery" ||
          (paymentForInvoice.get("status") === "captured" &&
            paymentForInvoice.get("providerVerifiedCapture") === true));
      paymentStatusByInvoiceId.set(item.id, paid === true);
    });
    const allOrderJobsSnap = await tx.get(db.collection("garment_care_service_jobs")
      .where("orderId", "==", invoice.orderId));
    const expectedDeliveryGroups = [...new Set(allOrderJobsSnap.docs
      .filter((job) => !["blocked", "cancelled"].includes(job.get("status")))
      .map((job) => text(job.get("deliveryGroupId"), 128))
      .filter(Boolean))];
    const allInvoicesIssued = expectedDeliveryGroups.length > 0
      ? expectedDeliveryGroups.every((id) => paymentStatusByInvoiceId.has(id))
      : paymentStatusByInvoiceId.size > 0;
    const allOrderPaymentsReceived = allInvoicesIssued &&
      [...paymentStatusByInvoiceId.values()].every(Boolean);
    const anyOrderPaymentReceived = [...paymentStatusByInvoiceId.values()].some(Boolean);
    const orderPaymentStatus = allOrderPaymentsReceived
      ? "paid"
      : anyOrderPaymentReceived
        ? "partiallyPaid"
        : "requiresCustomerAction";
    const paymentActionRequired = [...paymentStatusByInvoiceId.values()].some((paid) => !paid);
    if (logistics > 0) {
      allocationRefs.push({
        ref: db.collection("garment_care_payment_allocations").doc(`allocation_${paymentId}_logistics`),
        type: "logistics_clearing",
        amount: logistics,
      });
    }
    if (tax > 0) {
      allocationRefs.push({
        ref: db.collection("garment_care_payment_allocations").doc(`allocation_${paymentId}_tax`),
        type: "tax_liability",
        amount: tax,
      });
    }
    allocationIds = allocationRefs.map((item) => item.ref.id);
    const now = SERVER_TIMESTAMP();
    for (const allocation of allocationRefs) {
      tx.create(allocation.ref, {
        allocationId: allocation.ref.id,
        paymentId,
        invoiceId,
        orderId: invoice.orderId,
        orderNumber: invoice.orderNumber || null,
        deliveryGroupId: invoice.deliveryGroupId,
        allocationType: allocation.type,
        amount: Math.round(allocation.amount * 100) / 100,
        currency: invoice.currency || "INR",
        jobId: allocation.job && allocation.job.id || null,
        partnerAccountId: allocation.privateRate && allocation.privateRate.partnerAccountId || null,
        partnerProfileId: allocation.privateRate && allocation.privateRate.partnerProfileId || null,
        createdAt: now,
      });
    }
    billableJobs.forEach((job, index) => {
      tx.update(payableRefs[index], {
        paymentId,
        partnerAllocationId: `allocation_${paymentId}_partner_${job.id}`,
        paymentCaptureAllocated: true,
        settlementStatus: "held",
        holdReason: "awaiting_verified_delivery_provider_reconciliation_and_claim_window",
        updatedAt: now,
      });
    });
    tx.update(paymentRef, {
      allocationStatus: "allocated",
      allocationIds,
      gatewayFeeAmount: Number(paymentSnap.get("gatewayFeeAmount")) || 0,
      allocationCompletedAt: now,
      updatedAt: now,
    });
    tx.update(invoiceRef, { invoiceStatus: "paid", paidAt: now, updatedAt: now });
    const deliveryGroupRef = db.collection("garment_care_orders").doc(invoice.orderId)
      .collection("delivery_groups").doc(invoice.deliveryGroupId);
    tx.update(deliveryGroupRef, {
      invoiceStatus: "paid",
      paymentStatus: "captured",
      updatedAt: now,
    });
    tx.update(orderRef, {
      paymentStatus: orderPaymentStatus,
      paymentActionRequired,
      ...(allOrderPaymentsReceived ? { paidAt: now } : {}),
      updatedAt: now,
    });
    for (const shipment of returnShipmentsSnap.docs) {
      if (shipment.get("shipmentType") === "customer_return" &&
          shipment.get("deliveryGroupId") === invoice.deliveryGroupId &&
          shipment.get("status") !== "delivered") {
        tx.update(shipment.ref, {
          paymentStatusAtDelivery: "paid",
          invoiceId,
          paymentReadyAt: now,
          updatedAt: now,
        });
      }
    }
    tx.create(db.collection("garment_care_payment_events").doc(), {
      eventType: "captured_payment_allocated",
      paymentId,
      orderId: invoice.orderId,
      orderNumber: invoice.orderNumber || null,
      deliveryGroupId: invoice.deliveryGroupId,
      allocationIds,
      actorUid: context.auth.uid,
      at: now,
    });
  });
  return { paymentId, allocationIds, allocationStatus: "allocated" };
});
