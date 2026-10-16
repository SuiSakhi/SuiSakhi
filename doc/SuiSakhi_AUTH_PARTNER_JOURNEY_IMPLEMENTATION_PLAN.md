# SuiSakhi Authentication, Assignment and Partner Journey Plan

**Updated:** 2026-10-02
**Development branch:** `suisakhi-android-package-migration`
**Purpose:** Track the agreed customer-to-partner entry journey, deferred PIN decision, production order assignment, operations oversight, payment finalization, tracking and delivery workflow plan.

This is an implementation tracker. The approved architecture and partner checklist remain authoritative; this file does not replace or amend them.

## Current Baseline

- Shared Firebase phone/SMS OTP sign-in is in use for Customer and Partner entry.
- The Welcome screen has separate **Continue to SuiSakhi** and **Become a Partner** actions.
- Successful sign-in ensures the default Customer Profile as part of the common account foundation.
- Customer and Partner intent determine the next destination while using the same authenticated account.
- Logout returns to Welcome and clears the retained OTP state.
- OTP connection failures have user-facing retry guidance.
- New order documents snapshot the shared Customer account/profile identifiers where available; core tailoring orders also snapshot the selected delivery pincode for service-area matching. Existing order documents remain readable without these optional fields.
- Tailor availability is an explicit opt-in on the common Partner profile, defaults to unavailable, and can be changed only through a server-validated callable by the owning account. The new order matcher consumes it in the current working-tree slice; deploy Cloud Functions before validating that connection.
- Validated Git checkpoints: `f8b3753` and `f77ef6d`.

## Agreed Partner Entry Journey

### New or signed-out user

1. On Welcome, select **Become a Partner**.
2. Sign in with the shared phone/SMS OTP flow.
3. Create or load the common account and ensure its default Customer Profile.
4. Continue directly to **Partner Opportunities** (`/partner/opportunities`).
5. Select a partner category, including Measurement Partner, and continue to that category's application.

### Existing signed-in Customer

1. Open **My Account**.
2. Select **Become a Partner** under Partner Opportunities.
3. Continue to the same **Partner Opportunities** route (`/partner/opportunities`).

Both entry points already resolve to the same destination. Do not add an intermediate My Account step to the Welcome Partner path, a separate Partner login, or a second account/profile foundation.

## Decisions and Pending Items

### Partner discoverability — implemented

- Keep **Become a Partner** on Welcome for new or signed-out users.
- Keep **My Account → Become a Partner** for existing Customers.
- Preserve the default Customer Profile for accounts entering through the Partner path.
- Preserve Partner intent through authentication so the user lands on Partner Opportunities.
- No additional routing change is currently required.

### PIN registration — deferred

Do not add PIN registration or PIN login as part of the Measurement Partner work. Before a separate PIN package is approved, decide:

- Whether a PIN unlocks the current device/session or authenticates an account across devices.
- How PIN enrollment, change, forgotten-PIN recovery, and lost/new-device recovery work.
- How failed attempts are throttled and common PINs are handled.
- How the existing OTP flow remains available for recovery and Partner intent is preserved.

### Production assignment flow — agreed baseline

The current Tailor dashboard is a basic testing surface. It is not the production order-assignment model and should not define production ownership or assignment rules.

```text
Customer submits an order request
→ SuiSakhi finds eligible Tailors
→ Request remains in progress while eligible Tailors receive offers (Tailor response SLA applies)
→ One eligible Tailor accepts after reviewing the design and material; the Tailor is the proposed owner and capacity is held
→ Tailor supplies an expected-ready date; Customer sees the date and the complete centrally calculated quote
→ Customer chooses whether to finalize; SuiSakhi requests a 50% advance of the complete order total
→ Successful advance payment finalizes the order
→ Tailor measures directly or creates a Measurement Partner work task
→ Measurement Partner accepts, captures and submits a proposed version
→ Tailor confirms the final measurement or requests a new version
→ Stitching and QC
→ Delivery Partner assignment, delivery and tracking
```

Tailor acceptance confirms the assignment only; it does not finalize the Customer's order. Before accepting, the Tailor can review the selected design and material type, and supplies an expected-ready date with acceptance. The Customer sees the date and complete order quote before deciding whether to proceed. A successful payment of the generated 50% advance is the finalization event. The Tailor response SLA can vary by service/order type. Bulk and special orders remain in a separate Admin/Helpdesk-managed workflow with direct customer/Partner coordination and negotiation; their final agreed quote is the basis for the 50% advance.

Keep the existing common Customer account/profile and common Partner account/profile foundations. A Measurement Partner task is a separate work item linked to an order, person and applicable design; it does not transfer ownership of the tailoring order. The Partner submits a new measurement proposal without overwriting Customer, Tailor or previously confirmed measurement history. The Tailor remains the final measurement authority before stitching.

### Order finalization, advance and cancellation policy — agreed baseline

- Keep **assignment accepted** and **order finalized** as separate states. The order request stays in progress while SuiSakhi searches for an eligible Tailor. After a Tailor accepts, the Customer can proceed or choose not to finalize.
- Every order uses an advance of **50% of its agreed total order fee**. Generate the advance request after Tailor acceptance and the Customer's decision to proceed. Successful advance payment marks the order finalized; Tailor measurement/fulfillment starts after finalization and any required measurement approval. A request with no agreed price yet (such as bulk/special work still under negotiation) cannot be finalized or charged until its quote is agreed; the same 50% rule then applies.
- For bulk/special work, Admin/Helpdesk completes the customer/Partner negotiation and records the agreed total quote before the system calculates the 50% advance. An unpriced request is not a finalized priced order.
- The standard-order Customer total includes the applicable tailoring/stitching charge, measurement charge, delivery charge, platform fee, and taxes. The 50% advance is calculated from this complete Customer total, not from the tailoring component alone. The complete quote and its line items must be available to the Customer before the advance is requested.
- Give the Customer an upfront **estimated stitching price** from the centrally managed Customer tariff. Clearly label it as an estimate while measurement, delivery or other applicable charges are still unresolved. Before asking for payment, show and freeze the complete all-in order quote with every applicable component; calculate the 50% advance from that final total only.
- Tailor, Measurement Partner, and Delivery Partner compensation use separate Admin-managed rate cards. The Tailor receives the full agreed Tailor payout for completed tailoring work; each other Partner receives the full configured payout for their own completed, approved task. These Partner payouts are internal settlement amounts and are not shown as the Customer's price or used as a direct Customer-to-Partner payment.
- SuiSakhi's customer-facing price/rate configuration and each Partner-role payout rate are stored separately. Snapshot all applied rates, fee components, material/service selections, applicable tax values, and the quote total on the order before collecting payment. Later rate-card changes apply to future quotes and do not silently change an existing order quote or payout.
- The Customer uses one SuiSakhi checkout for the 50% advance and remaining balance. Payments and refunds are recorded against the order centrally; Partners do not collect from or settle directly with Customers. After an order/task is completed and approved, add the applicable Partner payout to the next weekly settlement batch, with separate payable lines for Tailor, Measurement Partner, and Delivery Partner work. Admin/Helpdesk can inspect reconciliation, failed/returned payments, adjustments, and settlement status; manual financial adjustments require actor, timestamp, amount and reason in the audit history.
- Customer price presentation may show one simple all-in total (for example, ₹350), with the required component/tax breakdown on the invoice. Before production invoicing, confirm with the tax/accounting adviser whether SuiSakhi or the Partner is the supplier for the applicable service and which GST/e-commerce-operator treatment applies. A single SuiSakhi checkout does not by itself determine the legal invoice issuer.
- The Tailor offer includes the selected design and material type and a required expected-ready date. The Customer sees the expected-ready date, selected design/material, complete quote and 50% advance before deciding to pay. Keep the already agreed 24-hour Customer decision window; present the complete quote when that window begins. If measurement or delivery selection changes the price, resolve that selection and refresh the complete quote before collecting the advance.
- Use a payment provider that supports the required marketplace/partner settlement workflow and weekly payouts. Do not implement a SuiSakhi stored-value wallet or hold/transfer partner funds outside the provider's compliant settlement flow. Confirm the provider settlement schedule, merchant onboarding requirements and refund/chargeback handling before enabling live payments.
- **Agreed payment and dispatch gate:** collect the first 50% through SuiSakhi checkout after the accepted Tailor, expected-ready date, design/material and quote are visible. When Tailor QC marks the garment ready, prompt the Customer to pay the remaining 50% online. Do not offer the order to Delivery or mark it out for delivery until the order is fully paid. Delivery confirmation closes the fulfillment order and starts the warranty window. Mark Partner payouts eligible after delivery/completion, all assigned work approval and full Customer payment; calculate separate weekly payout lines from the saved role-specific rates. Any SuiSakhi-funded advance payout is an explicit exception, not a normal settlement.
- Keep an auditable order ledger for advance, balance, refund, tax, platform fee, and each Partner payable. Reconcile payment-provider events against order/ledger IDs, make payment and payout operations idempotent, and expose weekly batch totals, itemized Partner statements, failures, retries and Admin-authorized adjustments in the Admin/Helpdesk workspace.
- The cancellation fee is an Admin-managed setting in `config/order_lifecycle.cancellationFeePercent`, defaulting to **10%** until Admin saves a different value. Apply it to the total order amount only after finalization; a request declined or cancelled before the 50% advance is finalized has no fee. Customer cancellation is available through the stages before stitching starts and is blocked once status reaches `inStitching` or a later stage. Record the applied percentage, fee, paid amount, refund due, any outstanding fee, and waiver actor/time. Admin/Helpdesk may waive the fee; any actual gateway refund remains a separately reconciled payment operation.
- On delivery, close the fulfillment workflow, record `deliveredAt`/`closedAt`, and start a **15-day warranty window** (Admin-configurable in `config/order_lifecycle.warrantyDays`). During that window the Customer can submit one warranty issue for Admin/Helpdesk follow-up. Collect Customer feedback after delivery and keep it on the order history; warranty claims remain separate from the closed fulfillment status.
- The Tailor acceptance SLA and the Customer's finalization/payment window are separate timers. The Tailor SLA may vary by order/service type and remains configurable. After a Tailor accepts, the Customer has **24 hours** to pay the 50% advance. If the Customer declines or the window expires without payment, close the unfinalized request, charge no cancellation fee, release the Tailor capacity reservation and return the request to Admin/Helpdesk for any permitted follow-up or reassignment. Admin/Helpdesk may extend the Customer decision window and the extension must be audited.

### Admin/Helpdesk order oversight — agreed baseline

- Admin/Helpdesk monitors the lifecycle of every Customer order and its assigned Partner work, including orders awaiting Tailor acceptance, waiting for the Customer's finalization/payment, finalized orders, and exceptions. The existing Admin and Tailor views should use the same canonical order status and assignment records; dashboard-specific copies of status are not a second source of truth.
- For the pilot, keep operations in one staff workspace to reduce operational overhead. Helpdesk handles the routine order queue, customer/Partner follow-up and exceptions. Admin can use those same workflows and has a broader 360-degree view across Customer orders, Partner status and eligibility information, assignment history, and delayed or blocked work.
- Use staff roles and permissions to distinguish routine Helpdesk access from Admin-wide visibility and intervention. Admin should be able to act in the Helpdesk workflow under the Admin staff identity; do not require a second Helpdesk account or impersonate another staff member.
- Manual actions such as reassignment, cancellation, cancellation-fee waiver or exception resolution must follow valid lifecycle transitions and record the staff actor, time, amount and reason in an audit history. Staff-only operational details remain separate from the Customer-facing tracking labels.

### Customer order-tracking flow — agreed baseline

Tracking is per independent order and is available from **My Orders → All / Active / Completed**. Reusing a design across different people or orders does not combine their tracking histories. The Customer sees a plain-language progress timeline derived from the canonical order, measurement-task and delivery events:

```text
Order received
→ Finding a Tailor
→ Tailor accepted — awaiting your decision
→ 50% advance paid — order finalized
→ Measurement, when required
→ Stitching
→ Quality check
→ Ready for delivery
→ Delivery Partner assigned / order collected
→ Out for delivery
→ Delivered
```

Before finalization, the Customer timeline makes the accepted Tailor and the decision/payment action clear; an order does not become finalized just because a Tailor accepted. Measurement details appear only when that order needs measurement. The timeline can show a home/video appointment, measurement in progress, Tailor review, or a correction in progress when applicable. It should not imply that stitching can start before the Customer finalizes the order and the Tailor finalizes any required measurement. A self-measured order can skip the Partner appointment stages. Assignment retries, Partner offer mechanics and internal eligibility scores remain operational details; the Customer sees a clear progress state and any action needed from them. On cancellation after finalization, show the cancellation-fee/refund calculation and whether Admin/Helpdesk waived the fee.

Store meaningful lifecycle changes as timestamped order events so the Customer timeline and Admin/Helpdesk view read from the same history. Admin/Helpdesk can see the operational detail behind each state, including assignment attempts, accept/decline/timeout, reassignment and elapsed time. Delivery tracking begins after Tailor QC/ready-for-pickup and can initially show event-based milestones; live map location is not assumed unless a delivery-location capability is separately implemented.

### Repository review — complete (read-only baseline before assignment implementation)

Measurement Partner code already exists; this is not a from-scratch build. A high-level read-only review found:

- Partner Opportunities includes Measurement Partner and routes to `/partner/apply/measurement`.
- The application screen hydrates and creates/resumes a category-specific draft using common Partner account/profile data.
- Measurement Partner operational details are stored under `onboardingData.extensions.measurementPartner` by a service that checks application ownership, category, and editable status.
- The screen has save-draft and submit-for-review paths; common Partner lifecycle code handles application submission, and Admin review integration exists.
- The generic Partner Workspace registry recognizes the Measurement Partner category, but Measurement Partner Operations is still marked **Coming Soon**. Designer is currently the only category with an available operational workspace module.
- The Customer measurement method chooser has Home Visit, Video Call, manual entry, old-garment reference, and history entries marked **coming soon**. Its currently connected path creates a Customer-side draft for AI camera measurement; these method entries do not create Partner service requests.
- The existing measurement documents are stored in the shared `measurements` collection. The current draft service records basic account/profile/person identifiers, source, status, and timestamps. AI estimates also store values, validation issues, confidence, and review-required status.
- The current measurement records do not show an integrated Measurement Partner assignment/capture/review lifecycle or explicit version lineage, Partner actor provenance, assigned-Tailor confirmation, or final-confirmed measurement state. The existing AI draft service can supersede earlier active draft/estimate/review-required documents for the same account and person; the inspected logic does not target other statuses.
- The application screen's file header still says operational details are UI-only and the milestone does not submit, while the current implementation persists details and submits applications. Update this stale implementation note when the next related source change is made.
- The Tailor measurement Partner shortlist/wishlist, assignment service, and live measurement-task availability state are not present in the inspected app code. Measurement Partner onboarding stores declared capabilities, service area, operating schedule, and daily capacity; live availability and capacity reservation are separate requirements.
- The core order model stores customer UID, person context, order measurement values, and design fields in Firestore. New order writes and the `DressOrder` model now include the common Customer account/profile identifiers when they can be resolved; core tailoring also stores the selected delivery pincode. Legacy order documents may omit these fields. Explicit Tailor-profile ownership, assignment state, and lifecycle events are still pending.
- The current model has no separate Tailor-assignment acceptance, Customer-finalization state, or explicit order-finalized timestamp. Core tailoring currently defaults to a configurable 40% advance (clamped from 30–50%); quick-fix uses 50%; bulk and marketplace request stubs store 40% while their initial price is zero; and the model fallback is 40%. The current payment-completion path records `advancePaid` and `paidAt` but does not make Customer finalization a distinct lifecycle state. The agreed 50% advance for every priced order and 10% post-finalization cancellation-fee/waiver policy are not implemented.
- The existing core tailoring order path still enables checkout at order creation and uses the older configurable 30–50% advance. The production flow must move advance generation until after Tailor acceptance, enforce 50%, and start the approved 24-hour Customer payment window at that point.
- The current Firestore `/orders` rule allows any signed-in user to read and update/delete any order. Assignment and measurement-task access must be scoped by role/profile before exposing partner work.

Reference points used for the review:

- `doc/product_Docs/SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL.md`
- `doc/product_Docs/SuiSakhi_Partner_Lifecycle_Coding_Task_Checklist_v1.0.md`, section 10.1
- Existing Partner application, approval/status, and workspace foundations

The repository review found the production assignment and measurement work lifecycles are not implemented in the current test dashboard. Implement the assignment records and access rules first, then connect the role-specific dashboards to those workflows.

### Agreed implementation sequence

1. **Production order assignment and lifecycle — implemented in the working tree; pending validation and deployment:** Account/profile snapshots, delivery pincode, availability, approved/online/PIN eligibility, registration-based PIN priority, sequential offers, dispatch hours, accept/decline/timeout, the 24-hour Customer decision, and 50% sandbox-payment finalization have code changes. Standard orders do not require capability or capacity matching. Keep the Tailor test-order list available for legacy records while production offers use their own tab.
2. **Admin/Helpdesk operations and routing oversight — initial order-routing slice implemented; broader operations remain:** The Owner/Admin workspace shows the PIN-grouped production routing queue, current offer and recent routing events, lets Admin reorder the Tailor priority per PIN, supports audited manual offer overrides, and now provides cancellation/warranty policy settings, order details, and cancellation-fee waiver action. A complete Helpdesk exception workspace and full Admin 360-degree view remain separate work. Audit staff actions and financial adjustments with actor, time, amount and reason. Do not add a separate Helpdesk login for the pilot.
3. **Measurement work-task contract:** Define a separate, secured task linked to the order, Customer/profile/person, applicable design snapshot, owning Tailor and assigned Measurement Partner. Keep its workflow separate from the tailoring order status and payment lifecycle.
4. **Measurement workflow:** Support Tailor self-measurement, a selected eligible/preferred Measurement Partner, or a system-recommended Partner offer. Require Partner acceptance for external assignments; handle decline/timeout and reassignment. Capture measurement provenance as a new proposal version; let the Tailor confirm or request a correction as a new version.
5. **Production Partner dashboards:** Build Tailor assignment/measurement controls and review, plus the Measurement Partner Requests, Schedule, Active and Completed views, on the shared account/profile foundation and implemented lifecycle. Preserve the distinction between Partner capture authority and Tailor final authority.
6. **Delivery and Customer order tracking — lifecycle slice implemented; measurement and production release remain:** The production Delivery flow now requires full payment before acceptance/dispatch, records delivery/closure and starts the configured warranty window. Customer **My Orders** shows design/material, expected-ready date, cancellation eligibility/fee, remaining-balance action, delivery completion, feedback, and warranty issue reporting. Continue with measurement milestones, fuller exception queue and live-notification integration after this slice is validated.
7. **Later assignment improvements:** After the simple standard-order flow is stable, consider operational workload reporting and special/bulk allocation using declared skills and experience. Do not turn capacity, capability, ratings, or performance into automatic standard-order gates without a new architecture decision. A connected-Partner relationship may influence Admin's manual choice but does not bypass profile approval and account governance.
8. **Central pricing, live payments and weekly Partner settlement:** After the service and delivery components are defined, implement separate Admin-managed Customer pricing and role-specific Partner payout rate cards. Show an upfront estimated stitching price, then include design/material and selected measurement/delivery options in the final quote; show the complete Customer total and required tax breakdown before requesting the 50% advance. Keep the Tailor's expected-ready date in the pre-payment decision. Route Customer payments/refunds through a payment provider's compliant marketplace flow and settle approved completed work to each Partner on the weekly schedule. Snapshot all quote and payout inputs on the order, and confirm the legal invoice supplier/GST treatment and payment-provider settlement terms before production release.

For standard orders, step 1 uses live availability and PIN coverage; capacity is not an eligibility gate. Skills/capabilities are reserved for Admin's bulk/special-order decisions. Before coding each slice, agree the concrete Firestore fields, access rules and status transitions against the authoritative architecture. During the first related source edit, correct the stale header comment in `lib/screens/partner/measurement_partner_application_screen.dart`.

This is the agreed implementation sequence, not an architecture redesign. PIN registration/recovery remains a separate deferred package.

Do not rebuild the existing application or change unrelated Customer, Tailor, Designer, authentication, or architecture behavior.

## Validation Notes

- Login and logout UX was manually validated by the project owner on 2026-10-02.
- The Welcome Partner and My Account Partner links both point to `/partner/opportunities` in the current repository.
- The Measurement Partner onboarding, customer measurement entry points, shared measurement draft service, workspace registry, order flow and Firestore order rules were reviewed read-only against the checked-in Partner Engagement Architecture and Partner Lifecycle checklist.
- The user clarified that the current Tailor dashboard is for testing and the production flow auto-matches Tailors, requires one acceptance, then assigns Measurement Partner work as a Tailor-owned subtask when needed.
- The user clarified that Admin/Helpdesk monitors order status, Admin needs a broader 360-degree view for operational decisions, and Customer tracking should cover the full applicable order and delivery lifecycle using the shared status history.
- The user clarified that an order remains in progress until a Tailor accepts; Tailor acceptance is not Customer finalization. The Customer decides whether to proceed, and successful payment of a system-generated 50% advance finalizes every priced order. A post-finalization cancellation fee is 10% of the total order fee, waivable by Admin/Helpdesk.
- The user selected a 24-hour Customer decision/payment window after Tailor acceptance. Decline or expiry before payment closes the unfinalized request with no cancellation fee and releases the reservation; Admin/Helpdesk may extend the window with an audit record.
- The user set the cancellation fee as Admin-configurable metadata (10% default), available until stitching starts, and chose no cancellation after `inStitching`. The user also set the second 50% payment after ready/QC and before dispatch, followed by delivery closure, feedback and a 15-day warranty window.
- The first order-data implementation slice adds Customer account/profile snapshots to new order writes and delivery-pincode snapshots to core tailoring orders. It does not yet change checkout, payment, assignment, or dashboard behavior.
- The Tailor dashboard now includes an availability switch backed by the `setTailorAvailability` callable. It does not yet create offers or change the test order list; Cloud Functions must be deployed before the switch can persist.
- The current changes are uncommitted. No push was made.

### Implementation log — 2026-10-02 — production Tailor assignment slice

**Status: implemented in the working tree; not validated, deployed, staged, or committed.** The previously staged checkpoint remains staged; this slice is an additional unstaged change.

- New core tailoring orders now start in `assignmentStatus: searching`, use a fixed 50% advance policy, and do not expose checkout until a Tailor accepts. The Designer flow returns the Customer to **My Orders** after sending the request.
- A Cloud Function finds approved, active, verified, available Tailors whose declared capability matches the garment, whose declared service-area pincodes include the order pincode, and whose declared daily capacity has an open reservation. It sends one offer at a time, ordered by the current daily-capacity load ratio. Unsupported garment mappings or missing pincode/eligible Partners enter `needs_admin_follow_up`.
- Current automatic capability mappings are Blouse/Saree Blouse, Kurti/Kurta Set/Salwar Suit/Anarkali Suit/Top-Tunic, Lehenga Choli, and Gown. Other garment types deliberately go to operations until their capability mapping is agreed.
- Offers are stored under the receiving Tailor's common profile and carry only a small order/design summary. The Tailor dashboard has an **Offers** tab with Accept/Decline. Decline, timeout, or a capacity/eligibility change advances to the next candidate. Offer deadlines are configurable at `config/order_assignment`: `defaultTailorOfferMinutes` and optional `tailorOfferMinutesByDressType`; code fallback is **120 minutes** until Admin config is supplied. This is separate from the approved 24-hour Customer window.
- Tailor acceptance records explicit account/profile ownership, reserves daily capacity, and starts the 24-hour Customer decision window. The Customer may pay the 50% advance to finalize or close the unfinalized request without a cancellation fee. Sandbox payment finalization and Customer decline are server-side callables. A scheduled Function processes expired offers and Customer windows every five minutes and returns unfinalized cases to the Admin/Helpdesk queue.
- Firestore client writes to production assignment/payment fields are blocked; callable Functions own those transitions. Tailor offer documents are scoped to their account/profile and client writes are denied. The legacy order read rule is still broad, and the current test Tailor order query still reads legacy rows broadly; tighten order reads and migrate the existing delivery/admin queries before production rollout.
- Capacity counts are held against each Tailor's declared `normalDailyCapacity` for the current India calendar day. Existing legacy/test workload is not automatically backfilled into those counters, so a baseline reconciliation is required before live auto-assignment. Connected-Partner preference, performance ranking, manual/self assignment, Admin extension UI, and a full Helpdesk queue remain later work.
- This slice does not include a live payment gateway; the production assignment payment callable accepts only the existing sandbox method while sandbox mode is enabled.
- Before using this flow, deploy the updated Firestore rules and Cloud Functions to the development/test project. The app alone is not enough: without those deployed triggers/callables, new core requests remain in `searching` and cannot be paid through checkout.
- No test/analyzer command was run for this slice. The owner should validate the deployed development flow before moving to the Measurement Partner task lifecycle.

### Implementation log — 2026-10-03 — Tailor order visibility and history

**Status: dashboard and tracking-note changes are in the working tree; not analyzer-checked, device-tested, or deployed.**

- The Tailor dashboard's **My Orders** query is now scoped to the signed-in Tailor account/profile and shows only finalized `v1` assignments. It no longer includes unassigned legacy Customer orders. Orders are grouped by their order month and year, with a refresh when the Tailor opens **My Orders**.
- New offers remain in **Offers**. Turning availability on allows future eligible requests to be offered; it does not re-run assignment for Customer requests that were already submitted.
- The app calls `setTailorAvailability`, and that callable is exported in the local Functions source. A generic `NOT_FOUND` is now shown as an actionable deployment message. The app config points to Firebase project `suisakhitest`; verify/deploy the callable there. No Firebase deployment was performed.
- The 2026-10-03 validation note reflected the then-current code's capability and positive-capacity gates. The 2026-10-04 read-only review supersedes those requirements for standard orders: next validation uses an approved/active/verified Tailor, online status, matching service PIN, PIN priority, and the configured dispatch window; it does not require a garment capability match or positive capacity.
- Historical orders without the assigned Tailor account/profile identifiers are intentionally hidden rather than attributed to every Tailor; they need a reliable ownership migration before they can appear in a Partner's archive.

### Code review and standard-order routing update — 2026-10-04

**Status: read-only code review complete; this section records the agreed target before the next source-code change. No implementation or deployment is included in this documentation update.** This section supersedes earlier standard-order capability/capacity gates and automatic-routing behavior described in the 2026-10-02 implementation log. That log remains as a historical record of the code at that time.

#### Read-only review findings

- `firebase/functions/order_assignment.js` currently requires a Tailor capability matching `dressType` and a positive `normalDailyCapacity`, and filters offers against the daily capacity counter. These are current code behaviors, but they are **not** standard-order eligibility requirements under the updated policy.
- The current order-created trigger builds candidates, sorts them by capacity load ratio and immediately calls `dispatchNextOffer`. Tailor decline and timeout also automatically dispatch the next candidate. There is no Admin-controlled PIN priority roster or manual offer-selection interface in this flow.
- Service-area matching supports explicit exact-pincode lists and `ANY` within the saved city/state. An empty list is treated as citywide only for `citywide` or unset coverage mode; a stale `pincodes` mode with an empty list is rejected. The agreed default is that blank coverage means `ANY` within the saved city/state.
- The current assignment flow has no SuiSakhi-wide dispatch-hours gate, no morning queue drain, and no PIN-grouped Admin routing queue. The offer fallback in code is currently 120 minutes; the agreed pilot offer-response default below is 30 minutes and should remain configurable.
- The existing Tailor acceptance → Customer 24-hour decision → 50% advance → finalization lifecycle is separate from assignment timing. Preserve it while changing candidate filtering and dispatch.

#### Standard-order eligibility — agreed

For a normal core-tailoring order, automatic eligibility is limited to:

1. The Tailor profile is approved, active, KYC-verified, and operationally active.
2. The Tailor is currently marked online/available.
3. The Customer delivery PIN is covered by that Tailor's service area.

Do not gate standard orders on garment capability/skill, experience, rating, capacity, workload, or a capability-to-dress-type mapping. Skills and capability declarations remain available for Admin decisions on bulk/special orders. Performance feedback may be collected for later review but is not an automatic standard-order exclusion or punishment rule.

Coverage rules:

- A non-empty explicit list such as `411061, 411057, 411027` matches only those exact PINs and replaces citywide `ANY` coverage for that profile.
- `ANY`, or a blank coverage field, means all PINs within the Tailor's saved city and state.
- Store canonical `countryCode`, `stateCode`, and `cityCode` with their display names, plus normalized PIN strings. For legacy records with missing codes, retain a safe state/city-name fallback during migration rather than dropping otherwise matchable requests.

#### Default PIN priority and sequential offers — agreed

- Build the eligible Tailor list for the Customer's delivery PIN, including exact-PIN Tailors and matching citywide `ANY` Tailors.
- Seed the default priority from Tailor registration order, oldest first. Use `registeredAt`, then profile `createdAt`, as the registration timestamp; use activation/approval timestamps only if registration timestamps are missing. Only eligible profiles enter an active routing roster. Profiles that become eligible later are appended after the existing eligible roster by default.
- Persist priority per service PIN/area. Admin can reorder/update it at any time; that changes offer order, not eligibility. A Tailor with `ANY` coverage can be included in PIN lists within the saved city.
- Send an in-app offer to one Tailor at a time. Skip Tailors who are not currently online or whose coverage no longer matches. On decline or timeout, offer to the next eligible Tailor in priority order. Do not broadcast.
- Set the initial offer response window to 30 minutes, configurable separately from the Customer's 24-hour decision window. Do not start an offer unless the full response window fits before SuiSakhi dispatch closes; for a 9:00 PM close, this means no new 30-minute offer after 8:30 PM.
- Admin may manually select/assign a Tailor after direct customer/Partner communication, regardless of the automatic PIN priority. This is an audited override: record the Admin actor, timestamp, selected Tailor, and reason. The override may bypass online or PIN-match filtering after Admin confirms the arrangement, but must not bypass the Tailor's active, approved, and verified account status. If an override replaces an outstanding offer, close that offer and record the action before sending the replacement.

#### SuiSakhi dispatch hours — agreed initial policy

- Customers may submit orders at any time. Initial routine assignment hours are **9:00 AM to 9:00 PM Asia/Kolkata (IST), daily**; keep the hours and timezone configurable for later Admin operations.
- Orders placed while dispatch is closed remain pending and unpaid in a scheduled queue. They are not lost, marked as having no eligible Tailor, or sent to a Partner overnight. The Customer sees that the request is received and Tailor matching will begin at 9:00 AM.
- At 9:00 AM, process queued requests oldest first and offer to the highest-priority eligible Tailor who is online. If no matching Tailor is online, retain the order in the Admin queue and retry when a matching Tailor comes online and during the open-window queue sweep.
- The platform-hours gate is separate from Tailor availability: within SuiSakhi dispatch hours, automatic offers still require an active, approved, verified, online Tailor and matching PIN coverage. Routine automatic offers do not start outside those hours.

#### Admin order visibility and lifecycle

- Add an Admin/Helpdesk order-routing queue grouped and searchable by Customer delivery PIN. Each order must show its pending/offer state, age, Customer/order reference, matching Tailor priority list, current offer and expiry, prior decline/timeout history, and the reason it remains queued.
- Keep requests visible when no Tailor is online, no PIN match exists, all sequential offers expire/decline, or dispatch is closed. Admin can manually choose an eligible Tailor or use the audited override above; orders must not disappear from Customer, Admin, or operations tracking.
- Before Tailor acceptance, the order remains pending and unpaid. Payment is offered only after a Tailor accepts and the Customer chooses to proceed; the existing 50% advance and 24-hour Customer decision window remain unchanged.
- Store state changes as order events so the Customer timeline and PIN-wise Admin view can explain pending, queued, offered, declined, timed out, accepted, Customer decision, and finalized states.
- The selected dress type/occasion persistence issue observed during testing is deferred to the later Order screen enhancement. It must not be used as a reason to block or misroute standard Tailor assignment under this simplified policy.

#### Implementation status before the next validation

1. **Implemented in source:** The server uses active/approved/verified + online + PIN coverage for standard eligibility; explicit PINs replace ANY, blank/ANY uses the saved city/state; capability and capacity are not standard-order gates.
2. **Implemented in source:** Auto routing uses the saved per-PIN priority order (registration timestamp by default), skips offline Tailors, and keeps one outstanding offer per order. Decline/timeout advances to the next candidate.
3. **Implemented in source:** The configured-Admin callable and Owner workspace provide the PIN-grouped queue, priority editing, one-at-a-time Admin offers, and audited overrides with a required reason. Customer and Tailor contact numbers are returned only through the Admin callable.
4. **Implemented in source:** Routine dispatch is configured for 9:00 AM–9:00 PM Asia/Kolkata; after-hours work remains unpaid and queued, the full 30-minute response window must fit before close, and queued work is retried by the five-minute sweep and an availability-change trigger when a Tailor comes online.
5. **Preserved in source:** Tailor acceptance → Customer's 24-hour decision → 50% advance → finalization. Production order updates and routing-priority documents are server-only; legacy order behavior remains separate.

The source changes are not analyzer-checked, device-tested, deployed, staged, or committed. Deploy the Functions, Firestore rules, and composite indexes together to `suisakhitest` before validating. The after-hours queue resumes on the first five-minute sweep after 9:00 AM rather than relying on an exact-minute trigger; online status changes start a separate asynchronous resume trigger.

### Implementation log — 2026-10-05 — Admin routing contact and order detail

**Status: source changes are in the working tree; pending deployed validation and device review. Existing staging is preserved.**

- Added optional additional contact numbers to the shared Partner application details for Tailor, Measurement, Delivery, Garment Care, Designer, Boutique, Brand, Fabric Supplier, Printing, Rental, and QuickCare applications. Numbers are normalized and de-duplicated against the authenticated primary mobile, copied into the approved Partner profile, and shown to Admin in application review. The applicant Basic Details rules allow this field only alongside the existing editable draft fields; older profiles continue to work with no additional number.
- Admin routing cards can call the current assigned/offer Tailor and open the approved profile summary, including primary and additional numbers, contact/business details, service PIN coverage, business address, status, experience, team/capacity, workshop equipment and Tailor capabilities. Eligible and manual-override candidate rows open the same profile detail view; contact numbers are returned only by Admin-authorized routing callables.
- Admin can add, replace, or clear alternate contact numbers on an already approved Tailor profile from that routing profile summary. The primary login number stays unchanged; the update records Admin UID and timestamp and relies on the existing configured-Admin profile update rule. New alternate numbers can be captured for every Partner type during onboarding; this Admin edit is currently exposed for Tailors in the routing workflow.
- Added a full order detail view for Admin review before routing. It includes the design image and title, garment/occasion/fit, selected material and description, accent color, measurements, customer/delivery details, notes, quote, payment and lifecycle state.
- Existing primary login number and routing eligibility rules are unchanged. Additional numbers are optional and do not affect Customer or Tailor order visibility.
- Targeted Dart analysis reported no code diagnostics; the Dart process then returned a telemetry-file permission error outside the repository. Firebase Functions syntax and Git whitespace checks passed. No automated tests, deployment, device run, staging, or commit has been performed for this update.

The 2026-10-04 review/documentation update itself made no additional source code changes.

### Agreed workflow addendum — 2026-10-06 — measurement and inbound pickup

**Approved by the user after review of the latest order screenshots.**

- Every core tailoring order requires inbound pickup from the Customer. Pickup is a Delivery Partner task: the partner records collection from the Customer and delivery/receipt at the Tailor. “Picked up” must never mean the Tailor advanced the order themselves.
- Generate one unique 12-digit order reference for each order. Print/display that same reference on the manual tag and encode it in the order QR. Use the reference throughout Customer, Partner, and Admin tracking; each scan/action still records its event type and actor. Keep the Firestore document ID as the internal database key.
- After the Customer pays the 50% advance, immediately tell them: **“Measurement will be arranged.”** Start independent measurement and inbound-pickup task records. Both tasks can be performed in one visit or in parallel.
- A Tailor may also perform measurement and delivery; a Measurement Partner may also perform delivery; or separate Measurement and Delivery Partners may perform the tasks independently. If the same person handles both, show/bundle one visit while retaining separate completion events for measurement and pickup. If different people handle them, allow both tasks to progress in parallel.
- Do not start stitching until measurement is complete and the picked-up item has been received by the Tailor. This makes stitching wait for the slower prerequisite without serializing measurement and pickup.
- Customer tracking is order-centric and must not reveal Tailor/Partner names or contact details. Admin/Helpdesk can see the complete Customer order, internal Partner identities, contacts, assignments, task history, and tracking reference.
- Keep inbound pickup distinct from post-production dispatch. After the Customer pays the remaining balance, the outbound Delivery Partner takes the ready order to the Customer; use separate task states and events for inbound collection and outbound delivery even though the same order reference/QR identifies the order.
- Assignment method for Measurement and Delivery tasks (automatic offers versus Admin assignment) remains to be decided before those tasks are exposed to Partners. Until then, do not treat an unassigned task as completed or allow the Tailor to start stitching.

#### Current implementation gaps identified against this addendum

- The production Tailor callable still advances `pending → pickedUp → atTailor`; this incorrectly gives inbound pickup to the Tailor and has no independent measurement gate.
- The Delivery Partner dashboard/callable currently handles only post-payment outbound delivery; it has no inbound pickup queue, order-code check, or receipt-at-Tailor action.
- Customer order cards and the Home recent-order card still expose the Tailor name in source; those display paths are being removed. Hiding the name from the UI alone does not redact raw Firestore fields, so a separate customer-safe order projection is required before claiming strict field-level privacy.
- Order creation does not yet allocate the unique 12-digit reference or generate a QR representation.

#### 2026-10-06 implementation progress

- Source now allocates a collision-checked 12-digit order reference in the order-created Function, keeps its QR payload to that reference alone, and exposes the code/QR in the Customer, Tailor, Delivery, and Admin order views.
- Source no longer writes the Tailor's name into a new core order on acceptance; the Admin routing callable resolves the identity from the account/profile assignment. Customer order cards and the Home summary omit the Tailor's name, and advance confirmation now says measurement will be arranged.
- The advance-payment Function initializes separate measurement and inbound-pickup task states. The pickup slice now supports Admin/Helpdesk assignment to an active, approved Delivery Partner, a Delivery dashboard inbound-pickup queue, 12-digit tag validation when the Partner collects the item, and a Tailor receipt confirmation using that same code. The Tailor can confirm measurement completion; the order becomes `atTailor` only after both independent prerequisites are complete, and the server rejects the transition to stitching until then.
- The Admin queue shows the assigned pickup Partner and contact details. Customer progress describes pickup and measurement milestones without showing Partner identities. Outbound delivery remains a separate task and continues to require full payment.
- Assignment of an external Measurement Partner, measurement capture/versioning, and automatic Partner offers remain part of the later Measurement module. For this pilot slice, the assigned Tailor records that measurement is complete after the measurement work has been performed.
- An attempted Firestore-rule edit to explicitly reject every client-supplied pickup audit/assignment field was blocked by automatic approval review; the rule set was left unchanged. Core task status fields remain rejected on client order creation, and server callables validate assignments before accepting pickup actions. Review the additional create-field restriction before production deployment.

#### Suggested manual validation after deployment

1. Create a fresh standard order, get a Tailor acceptance, and pay the 50% advance. Confirm Customer says measurement will be arranged and Admin shows separate measurement/pickup states with the 12-digit ID and QR.
2. As Admin, assign an active Delivery Partner. Confirm that Partner sees the task under **Inbound pickup**, not outbound deliveries.
3. Submit a wrong 12-digit code and confirm it is rejected. Submit the tag's correct code and confirm the status becomes collected; verify the event appears in Admin history.
4. As the assigned Tailor, confirm measurement completion and receive the item with the same 12-digit code. Confirm the order reaches **At tailor** only after both tasks are complete.
5. Try to start stitching with either prerequisite incomplete and confirm the server rejects it. After both are complete, advance to stitching and continue the previously validated ready → full payment → outbound delivery flow.
6. Confirm Customer tracking contains no Tailor or Delivery Partner name/contact, and verify Admin can see pickup Partner identity/contact and each handoff event.

### Implementation log — 2026-10-04 — simplified PIN routing and Admin queue

**Status: source changes are in the working tree; not analyzer-checked, device-tested, deployed, staged, or committed. This implementation supersedes the earlier capability/capacity-based standard-order behavior described above.**

- Standard Tailor eligibility now checks active, approved, verified status, online availability, and matching delivery-PIN coverage. Blank coverage is treated as citywide `ANY`; a non-empty explicit PIN list takes precedence. City/state matching reads both nested delivery-location values and the root fields used by current order documents.
- Automatic dispatch uses the persisted per-PIN priority list, defaults to older registered Tailors first, sends one offer at a time, and advances after decline or timeout. New Tailor profiles carry the source application's `createdAt` as `registeredAt` for stable default ordering. Standard orders do not require garment capability, capacity, experience, ratings, or workload.
- Routine offers are limited to 9:00 AM–9:00 PM Asia/Kolkata and use a configurable 30-minute response window. The full window must fit before closing. After-hours requests stay queued and unpaid; queued requests are swept oldest-first every five minutes while dispatch is open and retried by a profile-update trigger when a Tailor comes online, keeping the availability callable responsive.
- Added configured-Admin callables for the order queue, candidate refresh, PIN priority updates, and individual offers. Manual overrides require a reason, preserve Tailor approval/status checks, and create an order event. The Admin-only queue includes customer/Tailor phone numbers and recent offer history for direct coordination.
- Added the Owner **Order Routing by PIN** view, filters, per-PIN priority controls, offer/expiry display, and manual override flow. Customer order cards now explain queued, after-hours, offered, and operations-review states without exposing advance payment before Tailor acceptance.
- Added server-only Firestore rules for priority records and production order updates, plus composite indexes used by the Admin queue and oldest-first retry query.
- Dress-type persistence correction remains deferred, as agreed. No source tests, Flutter analyzer, Firebase deployment, `git add`, or commit were run.

### Implementation log — 2026-10-05 — Customer, Tailor and Admin order lifecycle

**Status: source changes are in the working tree; pending static analysis, deployed validation, and device review. The existing staged checkpoint is preserved; this implementation has not been staged or committed.**

- Tailor offers and the Customer's pre-payment decision screen show the selected design and material. Tailor acceptance requires an expected completion date; the Customer's order card and Admin routing queue show that date with the order price and payment state.
- Customer cancellation is available before stitching and rejected by the server from `inStitching` onward. Admin manages the cancellation percentage in `config/order_lifecycle.cancellationFeePercent` (10% fallback); it applies to finalized orders, and Admin can waive a recorded fee. Unfinalized requests close without a fee.
- Tailor production statuses advance in sequence through QC and ready-for-pickup. The Customer can submit the remaining balance after ready. Delivery Partner acceptance and delivery completion are server-gated on full payment; delivery closes fulfillment and records the configurable warranty end date (15-day fallback).
- Customer My Orders supports post-delivery feedback and one warranty issue during the warranty window. Admin can see order design/material, ETA, cancellation/refund details, feedback and warranty claim status, waive cancellation fees, and resolve open warranty issues.
- Balance payment remains sandbox-only. The current `orders.price` is the existing stitching quote, and the 50% advance/balance are calculated from that amount. It is not yet the agreed all-in Customer total for stitching + measurement + delivery + taxes + platform fee; that quote requires the later central pricing and Measurement/Delivery fee work. No real gateway collection/refund, push notification, or weekly payout is implemented. Customers see the ready/payment prompt in My Orders when they view or refresh their orders.
- Targeted Dart analysis reported **no issues** for the eight changed Dart files. The analyzer process then exited non-zero because its telemetry writer could not access `/Users/apple/.dart-tool`; the Flutter wrapper likewise could not update its engine cache. Node syntax checks and `git diff --check` passed. No automated tests, live Firebase deployment, or device run was performed. Deploy the Functions and app changes to `suisakhitest`, then validate a fresh order through acceptance, advance, stitching, ready, balance, delivery, feedback, and warranty. Verify cancellation and Admin waiver separately.

### Validation note — 2026-10-05 — evening pilot screenshots

- The screenshots were captured after the 9:00 PM dispatch close. Routine and manual offers are both intentionally held until 9:00 AM, so the disabled Admin buttons mean no offer was created; the Tailor correctly has nothing in **Offers**. Manual override bypasses automatic PIN/online priority for an Admin-confirmed arrangement, but it still sends an offer for the selected approved Tailor to accept and remains subject to dispatch hours.
- Customer cancellation is visible before stitching in the supplied screenshot. The server also rejects cancellation from `inStitching` onward; verify that rejection on a fresh order when resuming testing.
- The Admin rate editor now saves to Firestore before updating the shared rate list, waits for the list rebuild before closing its sheet, prevents duplicate submissions, and reports a retry message on save failure. This addresses the Flutter inherited-dependency assertion seen after saving. The fix has not yet been device-validated.
- Targeted Dart analysis reports **no issues** for `app_state.dart`, `rates_management_screen.dart`, and `owner_order_routing_screen.dart`; its process still exits after failing to write telemetry under `/Users/apple/.dart-tool`. Node syntax and Git whitespace checks pass. No deployment or automated tests were run for this screenshot follow-up.

### Agreed workflow addendum — 2026-10-09 — measurement, Meet and delivery handovers

**Approved by the user; this addendum supersedes earlier conflicting pilot notes in this plan and is recorded in `doc/SuiSakhi_PARTNER_MASTER_ARCHITECTURE_v2.0_FINAL.md`.**

- Keep one shared common Partner profile/workspace experience with common identity and governance fields plus category-specific operational details. Do not create a duplicate profile page for each Partner category. Keep the Partner task queue as the landing screen and expose the common profile from the profile icon.
- After the Customer's 50% advance finalizes an order, the Tailor chooses the measurement method and provides guidance. The Tailor may measure directly, explicitly select an eligible Measurement Partner for a home or video visit, use previous measurements, or use an old garment as a reference. Do not silently default to the first eligible Partner. The Partner schedules the home/video appointment; the Customer sees the appointment and meeting link in the order.
- After an assigned Partner completes the visit, they submit all garment-specific measurement criteria in inches by default (centimeters are optional), with the selected unit stored alongside the values, and a required note for the Tailor. The Customer sees that measurement collection is complete and Tailor review is pending. The Tailor sees the submitted values/note and remains the final measurement authority. Preserve previous submissions and confirmations in measurement history; allow the Tailor to re-initiate measurement and block production until the new measurement is confirmed.
- For video appointments, generate a unique Google Meet link under an authorized SuiSakhi Workspace identity (`connect@suisakhi.com`) and show it to the Customer in the app. Google OAuth/API authorization is required; until configured, the Partner may enter a secure HTTPS link manually. WhatsApp can remain a manual coordination channel. Calendar invitations or automated WhatsApp delivery are optional follow-up integrations and require the relevant account/API setup.
- Every finalized order requires inbound pickup, even if collected during the measurement visit. The assigned Tailor is the first preferred handler; the assigned Measurement Partner may handle it when pickup/delivery capability and service eligibility allow. If neither takes the work, auto-assign an active, approved Delivery Partner serving the order's PIN. Apply the same fallback chain to the outbound handover after QC and payment of the remaining balance.
- Keep measurement, inbound pickup, and outbound delivery as distinct task records/events even when one Partner performs multiple tasks. Measurement and pickup may proceed in parallel. Generate one 12-digit order reference after the 50% advance confirms the order and reuse it across the pickup tag, QR/RFID representation, all handovers, Customer tracking, Partner work and Admin history. Do not require a separate OTP at initial pickup.
- Show the Customer an event-based tracking stepper with visible handover milestones, including measurement, pickup/receipt at the Tailor, production, QC/ready, balance payment, outbound handover and delivery. Keep Partner names and contact numbers out of the Customer view; Admin/Helpdesk can see assignments, contact details and the complete custody history. Live map tracking is not implied.

**Next implementation order:** complete local Measurement Partner measurement entry/submission, Tailor review/final confirmation, and explicit Partner selection; then validate that pickup status/assignment updates independently. Video appointment testing follows the home visit case. Google Meet authorization and the delivery/handover rollout remain separate follow-up work.
