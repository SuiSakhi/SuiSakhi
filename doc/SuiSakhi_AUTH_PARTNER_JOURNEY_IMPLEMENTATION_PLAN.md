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
→ One eligible Tailor accepts; the Tailor is the proposed owner and capacity is held
→ Customer reviews the accepted Tailor and agreed order fee
→ Customer chooses whether to finalize; SuiSakhi requests a 50% advance
→ Successful advance payment finalizes the order
→ Tailor measures directly or creates a Measurement Partner work task
→ Measurement Partner accepts, captures and submits a proposed version
→ Tailor confirms the final measurement or requests a new version
→ Stitching and QC
→ Delivery Partner assignment, delivery and tracking
```

Tailor acceptance confirms the assignment only; it does not finalize the Customer's order. The Customer decides whether to proceed, and a successful payment of the generated 50% advance is the finalization event. The Tailor response SLA can vary by service/order type. Bulk and special orders remain in a separate Admin/Helpdesk-managed workflow with direct customer/Partner coordination and negotiation; their final agreed quote is the basis for the 50% advance.

Keep the existing common Customer account/profile and common Partner account/profile foundations. A Measurement Partner task is a separate work item linked to an order, person and applicable design; it does not transfer ownership of the tailoring order. The Partner submits a new measurement proposal without overwriting Customer, Tailor or previously confirmed measurement history. The Tailor remains the final measurement authority before stitching.

### Order finalization, advance and cancellation policy — agreed baseline

- Keep **assignment accepted** and **order finalized** as separate states. The order request stays in progress while SuiSakhi searches for an eligible Tailor. After a Tailor accepts, the Customer can proceed or choose not to finalize.
- Every order uses an advance of **50% of its agreed total order fee**. Generate the advance request after Tailor acceptance and the Customer's decision to proceed. Successful advance payment marks the order finalized; Tailor measurement/fulfillment starts after finalization and any required measurement approval. A request with no agreed price yet (such as bulk/special work still under negotiation) cannot be finalized or charged until its quote is agreed; the same 50% rule then applies.
- For bulk/special work, Admin/Helpdesk completes the customer/Partner negotiation and records the agreed total quote before the system calculates the 50% advance. An unpriced request is not a finalized priced order.
- If the Customer cancels after finalization, the standard cancellation fee is **10% of the total order fee**, retained as the Admin/platform fee and deducted from the refundable amount. An authorized Admin/Helpdesk operator may waive the fee. Record the assessed fee or waiver amount, actor, timestamp and reason. Under this agreed rule, the 10% fee applies to finalized orders; it does not apply before finalization.
- The Tailor acceptance SLA and the Customer's finalization/payment window are separate timers. The Tailor SLA may vary; the Customer decision/payment expiry and the exact capacity-release behavior for a declined or unpaid accepted offer still need to be defined before implementation.

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

### Repository review — complete (read-only)

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
- The core order model stores customer UID, person context, order measurement values, and design fields in Firestore, but the current creation/model path lacks explicit account/customer-profile and Tailor-profile ownership linkage. The `DressOrder` model also does not expose all persisted selected-design fields.
- The current model has no separate Tailor-assignment acceptance, Customer-finalization state, or explicit order-finalized timestamp. Core tailoring currently defaults to a configurable 40% advance (clamped from 30–50%); quick-fix uses 50%; bulk and marketplace request stubs store 40% while their initial price is zero; and the model fallback is 40%. The current payment-completion path records `advancePaid` and `paidAt` but does not make Customer finalization a distinct lifecycle state. The agreed 50% advance for every priced order and 10% post-finalization cancellation-fee/waiver policy are not implemented.
- The current Firestore `/orders` rule allows any signed-in user to read and update/delete any order. Assignment and measurement-task access must be scoped by role/profile before exposing partner work.

Reference points used for the review:

- `doc/product_Docs/SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL.md`
- `doc/product_Docs/SuiSakhi_Partner_Lifecycle_Coding_Task_Checklist_v1.0.md`, section 10.1
- Existing Partner application, approval/status, and workspace foundations

The repository review found the production assignment and measurement work lifecycles are not implemented in the current test dashboard. Implement the assignment records and access rules first, then connect the role-specific dashboards to those workflows.

### Agreed implementation sequence — pending implementation

1. **Production order assignment and lifecycle:** Establish explicit Customer, Tailor and account/profile linkage, secure order access, and canonical order status/event transitions. Keep Tailor assignment acceptance separate from Customer finalization and garment fulfillment. Implement eligibility and offer/accept/decline/timeout so one eligible Tailor accepts and capacity is held while the Customer decides. Generate the 50% advance from the agreed total fee; only successful payment finalizes the order. Define separate Tailor and Customer response windows and capacity release for declined/unpaid offers before implementation. Keep the current test dashboard intact until production assignment data is available.
2. **Admin/Helpdesk operations oversight:** Build one role-secured operations workspace over the canonical order and Partner records. Give Helpdesk a routine monitoring and exception queue, and Admin the 360-degree view and authorized intervention capabilities, including cancellation-fee waiver. Audit staff actions and financial adjustments with actor, time, amount and reason. Do not add a separate Helpdesk login for the pilot.
3. **Measurement work-task contract:** Define a separate, secured task linked to the order, Customer/profile/person, applicable design snapshot, owning Tailor and assigned Measurement Partner. Keep its workflow separate from the tailoring order status and payment lifecycle.
4. **Measurement workflow:** Support Tailor self-measurement, a selected eligible/preferred Measurement Partner, or a system-recommended Partner offer. Require Partner acceptance for external assignments; handle decline/timeout and reassignment. Capture measurement provenance as a new proposal version; let the Tailor confirm or request a correction as a new version.
5. **Production Partner dashboards:** Build Tailor assignment/measurement controls and review, plus the Measurement Partner Requests, Schedule, Active and Completed views, on the shared account/profile foundation and implemented lifecycle. Preserve the distinction between Partner capture authority and Tailor final authority.
6. **Delivery and Customer order tracking:** Integrate the existing basic Delivery Partner dashboard after Tailor QC/ready-for-pickup. Add Customer **My Orders → All / Active / Completed** tracking from the same order, measurement and delivery event history, including Tailor acceptance, Customer decision, 50% payment/finalization and applicable delivery milestones. Show post-finalization cancellation fee/refund details and any Admin/Helpdesk waiver.
7. **Assignment optimization:** Improve live availability/capacity recommendations, service-area and SLA matching, preferred/connected Partner ordering, and reliability ranking using sustained patterns. Capability, approval, location and available capacity remain eligibility gates; a preferred relationship does not bypass governance.

The minimum live availability/capacity needed by order assignment belongs in step 1; step 7 is the later recommendation and ranking improvement. Before coding each slice, agree the concrete Firestore fields, access rules and status transitions against the authoritative architecture. During the first related source edit, correct the stale header comment in `lib/screens/partner/measurement_partner_application_screen.dart`.

This is the agreed implementation sequence, not an architecture redesign. PIN registration/recovery remains a separate deferred package.

Do not rebuild the existing application or change unrelated Customer, Tailor, Designer, authentication, or architecture behavior.

## Validation Notes

- Login and logout UX was manually validated by the project owner on 2026-10-02.
- The Welcome Partner and My Account Partner links both point to `/partner/opportunities` in the current repository.
- The Measurement Partner onboarding, customer measurement entry points, shared measurement draft service, workspace registry, order flow and Firestore order rules were reviewed read-only against the checked-in Partner Engagement Architecture and Partner Lifecycle checklist.
- The user clarified that the current Tailor dashboard is for testing and the production flow auto-matches Tailors, requires one acceptance, then assigns Measurement Partner work as a Tailor-owned subtask when needed.
- The user clarified that Admin/Helpdesk monitors order status, Admin needs a broader 360-degree view for operational decisions, and Customer tracking should cover the full applicable order and delivery lifecycle using the shared status history.
- The user clarified that an order remains in progress until a Tailor accepts; Tailor acceptance is not Customer finalization. The Customer decides whether to proceed, and successful payment of a system-generated 50% advance finalizes every priced order. A post-finalization cancellation fee is 10% of the total order fee, waivable by Admin/Helpdesk.
- No source code or tests were changed while updating this plan. The tracker update is ready for staging; no commit or push was made.
