# SuiSakhi Architecture Delta v7.4

## Measurement Ownership, Category-Aware Garment Engine and Fabric Estimation Foundation

**Version:** v7.4  
**Base Version:** v7.3  
**Status:** Draft for Repository Preservation  
**Date:** 18-Aug-2026  
**Prepared For:** SuiSakhi Product and Architecture Repository  
**Owner:** Sudhir Titirmare

---

## 1. Purpose

This document captures the architecture decisions, business rules, implementation updates, measurement ownership refinements, garment measurement strategy, fabric estimation foundation, and formula-engine direction introduced after v7.3.

Version 7.4 establishes the long-term measurement and fabric-estimation architecture for SuiSakhi.

This delta extends:

- v7.0 Measurement Architecture
- v7.2 Measurement Ownership Rules
- v7.3 Measurement Governance Rules

and introduces a clear separation between:

```text
Body Measurement
Garment Measurement
Fabric Estimation
Tailor Verification
Final Confirmed Measurement
```

---

## 2. Executive Summary

| Area | Summary |
|---|---|
| Design Your Dress | Measurements now load by selected profile/person. |
| Read-Only Measurements | Design screen now shows measurements as reference values. |
| Measurement Ownership | Body measurements remain profile-owned. |
| Garment Measurements | Future category-specific garment measurement engine introduced. |
| Formula Engine | Foundation defined for deriving order/garment measurements. |
| Fabric Estimation | Foundation defined for estimating material using garment measurements. |
| Measurement Integrity | Profile measurements cannot be accidentally overwritten by order adjustments. |
| Future Direction | Category-aware tailoring and fabric-intelligence engine. |

---

## 3. Key Discovery

Testing revealed that body measurements and garment measurements are fundamentally different concepts.

Example:

```text
Body Measurement:
Chest = 90 cm

Shirt Order:
Chest = 96 cm

Kurti Order:
Chest = 94 cm

Gown Order:
Chest = 98 cm
```

The customer's body measurement remains unchanged, while garment measurements vary based on:

```text
Dress Type
Occasion Category
Fit Preference
Tailor Rules
Formula Version
```

Therefore, body measurements and garment measurements must be separated.

---

## 4. Relationship With Earlier Architecture Versions

### 4.1 v7.0 Baseline

v7.0 established that measurement is a core platform capability, that AI Camera produces estimates requiring review, and that Design Your Dress is the official order creation screen.

v7.0 also established the important rule that Length is garment-specific and must not be auto-filled as zero from body scan.

### 4.2 v7.2 Measurement Ownership

v7.2 established that measurements belong to a selected person and must be loaded from Firestore for that selected person.

v7.2 also established that Design Your Dress measurements are scoped to the selected person and current order.

### 4.3 v7.3 Measurement Governance

v7.3 established measurement verification lifecycle rules and the principle that low-confidence measurement sources such as AI Camera, Self Measurement, Video Measurement, and Old Dress Reference require validation before stitching.

---

## 5. Implementation Changes Completed in v7.4

| Capability | Status | Notes |
|---|---|---|
| Design screen profile-specific measurement loading | Implemented | Design Your Dress loads latest usable measurement for selected person using accountId + personId. |
| New profile blank measurement behavior | Implemented | If selected profile has no saved measurement, measurement fields remain blank. |
| Read-only measurement values in Design Your Dress | Implemented | Main order screen displays measurement values but does not modify base profile body measurements. |
| Inline plus/minus measurement editing removed | Implemented | Direct adjustment will move to a future Adjust for this Dress workflow. |
| Take New Measurement action | Implemented | From Design Your Dress, selected person context can route to Measurement Context. |
| Category-aware formula engine | Planned | Future service will derive garment measurements from body measurements. |
| Fabric estimation engine | Planned | Future engine will estimate material consumption from garment measurements and fabric rules. |

---

## 6. New Measurement Architecture

### 6.1 Layer 1: Body Measurement

Body measurement is owned by:

```text
Account
  ↓
Profile / Person
```

Examples:

```text
Height
Chest
Waist
Hip
Shoulder
Arm Length
Neck
Thigh
Inseam
```

Sources:

```text
AI Camera
Manual Entry
Tailor Measurement
Video Call
Home Visit
Old Dress Reference
Measurement History
```

Body measurements remain reusable across future orders.

### 6.2 Layer 2: Garment Measurement

Garment measurement is owned by:

```text
Profile
+ Dress Type
+ Occasion Category
+ Fit Preference
+ Formula Version
+ Order / Draft Context
```

Examples:

```text
Kurti Length
Shirt Length
Blouse Length
Sleeve Length
Neck Depth
Margin
Back Design
```

These measurements are order-specific.

### 6.3 Layer 3: Fabric Estimation

Fabric estimation uses:

```text
Garment Measurements
Fabric Type
Fabric Width
Lining Requirement
Design Complexity
Margin Percentage
Formula Version
```

Fabric estimation produces:

```text
Required Fabric Quantity
Confidence Score
Estimation Notes
Tailor Review Flag
```

---

## 7. Design Your Dress Architecture Update

### 7.1 Previous Behavior

```text
Design screen could inherit measurements from global state.
```

Risk:

```text
Wrong profile measurements could be shown.
```

### 7.2 New Behavior

```text
Selected Profile
        ↓
Load Latest Measurement
        ↓
Show Reference Measurements
        ↓
Read-Only Display
```

Result:

```text
Profile measurements remain protected.
```

---

## 8. Read-Only Measurement Principle

Design Your Dress is no longer considered a measurement editing screen.

Its purpose is:

```text
Reference Measurement View
Order Creation
Design Selection
Fabric Selection
Fit Selection
```

Direct editing of profile body measurements is removed from the main Design Your Dress screen.

Future actions:

```text
Take New Measurement
Adjust For This Dress
Tailor Verification
Final Confirmation
```

---

## 9. Category-Aware Measurement Principle

Measurements must become category-aware.

Examples:

### Shirt

```text
Chest
Shoulder
Sleeve Length
Shirt Length
```

### Kurti

```text
Chest
Waist
Hip
Sleeve Length
Kurti Length
```

### Blouse

```text
Chest
Shoulder
Blouse Length
Neck Depth
Back Design
```

### Pant / Bottom

```text
Waist
Hip
Thigh
Inseam
Pant Length
```

Therefore:

```text
Garment Length is category-specific.
```

---

## 10. Length Rule

Length is not a body measurement.

Examples:

```text
Kurti Length
Top Length
Blouse Length
Pant Length
Skirt Length
Gown Length
```

Therefore:

```text
Length cannot be universally derived.
```

Length must be one of the following:

```text
Formula Derived
Manual Entry
Historical Selection
Tailor Confirmed
Customer Confirmed
```

---

## 11. Future Formula Engine

Future service:

```text
lib/services/garment_measurement_engine.dart
```

Concept:

```text
Body Measurement
+ Category Rules
+ Fit Preference
= Garment Measurement
```

Example conceptual API:

```dart
GarmentMeasurementEstimate estimateGarmentMeasurements({
  required BodyMeasurements body,
  required String dressType,
  required String occasionCategory,
  required String fitPreference,
});
```

### 11.1 Shirt Formula Concept

```text
Chest = Body Chest + Ease
Shoulder = Body Shoulder
Sleeve = Arm Length Ratio
Length = Height Ratio
```

### 11.2 Kurti Formula Concept

```text
Chest = Body Chest + Ease
Waist = Body Waist + Ease
Hip = Body Hip + Ease
Sleeve Length = Arm Length Ratio
Kurti Length = Height Ratio
```

### 11.3 Gown Formula Concept

```text
Chest = Body Chest + Ease
Waist = Body Waist + Ease
Hip = Body Hip + Ease
Gown Length = Height Ratio
Flare = Category/Design Rule
```

Formula values must be configurable and expert-reviewable. They must not be treated as permanent hardcoded truth.

---

## 12. Fit Preference Engine

Supported fit options:

```text
Slim
Regular
Loose
```

Concept:

```text
Slim    → Smaller Ease
Regular → Standard Ease
Loose   → Higher Ease
```

Fit adjustments modify garment measurements.

Fit adjustments must never modify body measurements.

---

## 13. Fabric Estimation Foundation

Future service:

```text
lib/services/fabric_estimation_service.dart
```

Inputs:

```text
Dress Type
Garment Length
Sleeve Length
Chest / Waist / Hip Derived Values
Fabric Type
Fabric Width
Lining Requirement
Design Complexity
Margin Percentage
```

Outputs:

```text
Estimated Fabric Quantity
Calculation Version
Confidence Score
Customer-Friendly Notes
Tailor Review Flag
```

Fabric estimation must use garment/order measurement, not body measurement alone.

---

## 14. Order Snapshot Architecture

Orders must preserve measurement snapshots.

Example:

```text
orders/{orderId}
```

Required measurement-related fields:

```text
bodyMeasurementId
bodyMeasurementSnapshot
garmentMeasurementSnapshot
formulaVersion
measurementSource
fabricEstimationSnapshot
finalConfirmedMeasurementSnapshot
```

Reason:

```text
Future measurements must not alter historical orders.
```

This supports the core architecture principle:

```text
Transactions Own Their History.
```

---

## 15. Firebase Roadmap

### 15.1 Existing Profile/Body Measurement Collection

Continue using:

```text
measurements/{measurementId}
```

Suggested body measurement fields:

```text
measurements/{measurementId}
  accountId
  customerProfileId
  personId
  personName
  relationship
  measurementType: body
  source: ai_camera | manual | tailor | home_visit | video_call | old_dress | history
  status: draft | ai_estimated | customer_review_required | partner_review_required | verified | accepted | order_created
  measurementValues:
    height
    chest
    waist
    hips
    shoulder
    armLength
    neck
    thigh
    inseam
  createdAt
  updatedAt
```

### 15.2 Order Draft / Order Measurement Snapshot

Future structure:

```text
order_drafts/{draftId}
  bodyMeasurementId
  formulaVersion
  measurementSource: profile_body | ai_body_plus_formula | manual_adjusted | tailor_verified
  bodyMeasurementSnapshot:
    height
    chest
    waist
    hips
    shoulder
    armLength
  garmentMeasurements:
    chest
    waist
    hip
    shoulder
    sleeveLength
    garmentLength
    neckDepth
    backDesign
    margin
  customerAdjustments:
    chest
    sleeveLength
    garmentLength
    fitPreference
```

### 15.3 Future Collections

```text
measurement_formula_rules
fabric_estimation_rules
garment_measurement_templates
```

Example:

```text
measurement_formula_rules/{ruleId}
  dressType
  category
  fitPreference
  formulaVersion
  active
  chestEaseCm
  waistEaseCm
  hipEaseCm
  lengthRatio
  sleeveRatio
```

---

## 16. New Business Rules

### BR-136

Design Your Dress must load measurements using selected accountId + personId.

Status:

```text
Implemented
```

### BR-137

If selected profile has no measurement history, Design Your Dress must display blank values.

Status:

```text
Implemented
```

### BR-138

Design screen measurements are read-only reference values.

Status:

```text
Implemented
```

### BR-139

Customer measurement adjustments belong to the order and must not overwrite body measurements.

### BR-140

AI Measurement is a body estimate and not a final stitching measurement.

### BR-141

Body measurements belong to a profile/person.

### BR-142

Garment measurements belong to dress type, category, fit, and order context.

### BR-143

Garment measurements are derived using formulaVersion.

### BR-144

Garment length is category-specific.

### BR-145

Fabric estimation must use garment measurements rather than body measurements.

### BR-146

Body measurements remain reusable across future orders.

### BR-147

Customer adjustments belong to the order level.

### BR-148

Every order must preserve a garment measurement snapshot.

### BR-149

Historical orders must remain linked to their original measurement snapshot.

### BR-150

Formula-generated measurements must store formulaVersion.

### BR-151

Formula changes must not alter historical orders.

### BR-152

Adjust For This Dress values are order-specific values.

### BR-153

Tailor verified measurements create a new measurement version.

### BR-154

Final Confirmed Measurement is the production-ready measurement.

### BR-155

AI Camera measurements are profile-level body measurements.

### BR-156

Formula-generated measurements must remain explainable and reproducible.

### BR-157

Fabric estimation calculations must store estimationVersion.

### BR-158

Tailor confirmation takes precedence over formula-generated values.

### BR-159

Customer-confirmed measurements may become reusable measurement history.

### BR-160

Measurement architecture follows:

```text
Body Measurement
 ↓
Garment Measurement
 ↓
Fabric Estimation
 ↓
Tailor Verification
 ↓
Final Confirmed Measurement
 ↓
Production
```

---

## 17. Architecture Decisions

### AD-020

Separate body measurement from garment measurement.

### AD-021

Design Your Dress becomes measurement-reference-first.

### AD-022

Order measurements are independent from profile measurements.

### AD-023

Fabric estimation uses garment measurements.

### AD-024

Formula-generated measurements require versioning.

### AD-025

Tailor-confirmed measurements are authoritative for production.

### AD-026

Customer adjustments never update baseline body measurements.

### AD-027

Measurement history remains permanently preserved.

---

## 18. Flow-015: Body To Garment Flow

```text
Profile Measurement
        ↓
Body Measurement
        ↓
Select Dress Type
        ↓
Select Category
        ↓
Select Fit Preference
        ↓
Formula Engine
        ↓
Garment Measurement
        ↓
Customer Adjustment
        ↓
Fabric Estimation
        ↓
Tailor Verification
        ↓
Final Confirmed Measurement
        ↓
Production
```

---

## 19. Flow-016: Measurement Lifecycle

```text
Take New Measurement
        ↓
Measurement Draft
        ↓
AI Estimated
        ↓
Customer Review
        ↓
Partner Review
        ↓
Verified
        ↓
Accepted
        ↓
Measurement History
        ↓
Reusable For Future Orders
```

---

## 20. Flow-017: Read-Only Design Measurement Screen

```text
Design Your Dress
        ↓
Selected Profile
        ↓
Load Latest Person Measurement
        ↓
Measurement Exists?
        ├─ Yes → Show Read-Only Reference Values
        └─ No  → Show Blank Fields + Take New Measurement
        ↓
Adjust For This Dress
        ↓
Future Order-Level Adjustment Screen
```

---

## 21. Flow-018: Fabric Estimation Future Flow

```text
Garment Measurements
        ↓
Selected Fabric Type
        ↓
Fabric Width / Lining / Complexity
        ↓
Fabric Estimation Engine
        ↓
Estimated Meter Requirement
        ↓
Customer-Friendly Notes
        ↓
Tailor Review
        ↓
Final Fabric Confirmation
```

---

## 22. Implementation Status

### Completed

```text
Profile-specific measurement loading
Blank profile measurement handling
Read-only Design measurements
Take New Measurement routing
Measurement integrity protection
```

### Planned

```text
Category Formula Engine
Adjust For This Dress Screen
Garment Measurement Snapshot
Fabric Estimation Engine
Formula Versioning
Tailor Verified Measurement
Final Confirmed Measurement
```

---

## 23. Open Items for Next Development

| Priority | Open Item | Notes |
|---|---|---|
| High | Category Formula Engine | Start with one dress type, preferably Kurti or Shirt. |
| High | Adjust For This Dress Screen | Order-level adjustment screen with plus/minus controls. |
| High | Garment Measurement Snapshot | Store derived values in order_drafts and orders. |
| Medium | Fabric Estimation Service | Estimate meters based on garment values and fabric type. |
| Medium | Formula Versioning | Store formulaVersion in derived records. |
| Medium | Tailor Verification | Separate tailor measurement and final confirmed measurement versions. |

---

## 24. v7.4 Conclusion

Version 7.4 formalizes the separation of:

```text
Body Measurement
Garment Measurement
Fabric Estimation
```

and establishes the long-term foundation for:

```text
Measurement Intelligence
Fabric Intelligence
Tailor Verification
Production Accuracy
Customer Trust
Historical Data Integrity
```

The guiding principle is:

```text
Profile owns Body Measurement.
Order owns Garment Measurement.
Production uses Final Confirmed Measurement.
```

This delta must be carried forward into the future v8.0 master architecture.
