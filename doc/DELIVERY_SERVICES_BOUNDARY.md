# Delivery services boundary

## Protect the tested Tailoring flow

- The existing Tailoring delivery dashboard stays at `/delivery` and remains the owner of Tailoring orders, availability and delivery status.
- Garment Care delivery must not add fields, filters, status transitions or service controls to the Tailoring dashboard or Tailoring order state machine.
- Delivery service selection starts at `/delivery/services`. Each service gets its own availability flag, assignment queue, acceptance/rejection record and custody steps.
- A new service must use its own assignment and custody data, even when its UI follows familiar Tailoring patterns.

## Garment Care delivery flow

1. A Garment Care Partner assigns a Customer return to an eligible Delivery Partner in the Customer's PIN-code area.
2. The Delivery Partner accepts or declines the assignment. A decline requires a reason and returns the planned return to the Garment Care Partner, which can choose another Partner or handle the Customer return itself.
3. The Garment Care Partner cannot release the return to a Delivery Partner until that Partner accepts.
4. After transfer, the Delivery Partner confirms receipt, starts Customer delivery, and confirms the handover with the Customer PIN. The delivery queue remains keyed by the assigned Delivery Partner after custody changes.
5. Availability is controlled only by `garmentCareDeliveryAvailable`; changing it must not change Tailoring availability.
6. Delivery Partner eligibility matches the Customer PIN against both the Partner's approved business PIN and every PIN in the Partner's service area. Service-area entries may contain multiple PIN codes; normalize and consider all of them for listing, availability validation and assignment.

## Change checklist

- Keep `/delivery` routes, Tailoring order states, callable functions and Firestore rules behavior unchanged.
- Add a new route or service-specific fields/functions for Garment Care delivery instead of branching Tailoring state transitions.
- Verify the existing Tailoring accept, pickup, delivery and PIN-confirmation paths still use their current code.
- Verify Garment Care acceptance, reasoned decline, reassignment, handover, payment gating and Customer PIN delivery independently.
