# SuiSakhi Architecture Delta v7.4 FINAL Consolidated

## Measurement Ownership, Category-Aware Garment Formula Engine, Size Intelligence, Design Metadata and Fabric Estimation Foundation

**Version:** v7.4 FINAL Consolidated  
**Base Version:** v7.3  
**Status:** Draft for Repository Preservation  
**Date:** 18-Aug-2026  
**Owner:** Sudhir Titirmare  
**Prepared For:** SuiSakhi Product and Architecture Repository  
**Document Type:** Consolidated Architecture Delta

---

## 1. Purpose

This consolidated v7.4 architecture delta captures all measurement, garment formula, size intelligence, design metadata, fabric estimation, Firebase schema, business rule and architecture decision updates discovered after v7.3.

This document replaces the need to maintain separate v7.4 addendum files for measurement, fabric engine, size intelligence and design metadata. It is intended to become the single v7.4 repository reference until these rules are merged into a future v8.0 master architecture.

Version 7.4 extends prior SuiSakhi architecture layers:

- v7.0 Measurement and Design Your Dress baseline
- v7.2 Measurement ownership, person-specific measurement loading and BR-125 historical snapshot principles
- v7.3 Draft lifecycle, resume draft governance, profile validation and measurement verification lifecycle

The major new foundation introduced in v7.4 is:

```text
Body Measurement
        ↓
Size Intelligence
        ↓
Design Metadata
        ↓
Garment Formula Engine
        ↓
Garment Measurement
        ↓
Fabric Estimation
        ↓
Customer Adjustment
        ↓
Tailor Verification
        ↓
Final Confirmed Measurement
        ↓
Production
```

---

## 2. Executive Summary

| Area | v7.4 FINAL Consolidated Summary |
|---|---|
| Measurement Ownership | Body measurements are profile/person-owned and remain the primary source of truth. |
| Design Your Dress | Measurements load by selected person and are displayed as read-only reference values. |
| New Profile Handling | If a selected profile has no saved measurement, Design Your Dress displays blank fields instead of leaked/global values. |
| Garment Measurement | Garment measurements are order/category-specific and derived from body measurement, dress type, occasion, fit and design metadata. |
| Size Intelligence | XS/S/M/L/XL style size category is derived metadata, not manually selected by customer and not a replacement for measurements. |
| Design Metadata | Each design template may store silhouette, length type, sleeve type, flare, complexity, lining and fabric preference. |
| AI Design Analysis | AI may analyze design images to produce metadata, but AI does not directly generate production measurements. |
| Formula Engine | Garment formulas are versioned, explainable, reproducible and overrideable by customer adjustment and tailor verification. |
| Fabric Estimation | Fabric estimation is based on garment measurements and design/fabric metadata, not body measurement alone. |
| Firebase Roadmap | Future metadata collections are proposed for size rules, design metadata, body-shape rules and AI design analysis. |
| Production Authority | Final Confirmed Measurement remains the only production-ready measurement authority. |

---

## 3. Core Principle

The v7.4 architecture is governed by the following principle:

```text
Measurements = Truth

Size = Metadata

Formula = Suggestion

Customer Adjustment = Preference

Tailor Verification = Validation

Final Confirmed Measurement = Production Authority
```

This principle protects customer trust, measurement integrity, historical order accuracy and future scalability.

---

## 4. Relationship With Earlier Architecture Versions

### 4.1 v7.0 Baseline

v7.0 established measurement as a core platform capability. It also established that AI camera output is an estimate and not a final stitching measurement.

v7.0 defined Design Your Dress as the order creation screen and stated that garment Length is category-specific and must not be auto-filled as zero from body scan.

### 4.2 v7.2 Measurement Ownership

v7.2 established selected-person measurement rules:

```text
Measurement Dashboard must load Firestore measurements for the selected person.
Measurement Dashboard must not show another person's measurement values.
Design Your Dress measurements are scoped to selected person and current order.
Transactions own their history through BR-125.
```

### 4.3 v7.3 Measurement Governance

v7.3 established:

```text
Measurement verification lifecycle
No stitching before validation for low-confidence sources
Draft lifecycle and resume draft hydration
Profile validation before Self orders
Discard Draft as Archive
```

### 4.4 v7.4 Consolidated Scope

v7.4 adds:

```text
Read-only Design screen measurements
Person-specific measurement loading in Design Your Dress
Body vs garment measurement separation
Garment formula engine foundation
Category and design context in formula preview
Size intelligence foundation
Body shape metadata foundation
Design metadata architecture
AI metadata extraction strategy
Fabric estimation foundation
Firebase metadata collections
```

---

## 5. Implementation Changes Completed in v7.4

| Capability | Status | Notes |
|---|---|---|
| Design screen profile-specific measurement loading | Implemented | Design Your Dress loads latest usable measurement by accountId + personId. |
| New profile blank measurement behavior | Implemented | New person/profile with no measurement shows blank fields. |
| Read-only measurement values in Design Your Dress | Implemented | Main order screen displays measurements as reference values. |
| Inline plus/minus editing removed from main design screen | Implemented | Direct adjustment will move to Adjust for This Dress workflow. |
| Take New Measurement from Design screen | Implemented | Selected person context routes to Measurement Context. |
| Garment measurement engine foundation | Implemented | Initial v1 formula engine created in `lib/services/garment_measurement_engine.dart`. |
| Formula suggestion preview in Design screen | Implemented | Suggest for this Dress preview shows formula output. |
| Category and selected design context in formula preview | Implemented | Occasion/category and design title influence notes and formula context. |
| Legacy product document exports ignored | Implemented | Heavy PDF/DOCX/HTML exports ignored to keep Git lightweight. |
| Category formula engine full production logic | Planned | Future expansion by dress type and metadata. |
| Fabric estimation engine | Planned | Future material estimation based on garment metadata. |
| Size intelligence engine | Planned | Future derived size recommendation based on body/profile data. |

---

## 6. Measurement Architecture

### 6.1 Body Measurement

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

Body measurements remain reusable across future orders and must not be overwritten by dress-specific order adjustments.

### 6.2 Garment Measurement

Garment measurement is owned by:

```text
Profile
+ Dress Type
+ Occasion Category
+ Fit Preference
+ Design Metadata
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
Flare
Lining
```

Garment measurements are order-specific and may vary even when the same body measurements are used.

### 6.3 Fabric Estimation

Fabric estimation is derived from garment and design context:

```text
Garment Measurements
Fabric Type
Fabric Width
Lining Requirement
Design Complexity
Flare Level
Margin Percentage
Formula Version
```

Fabric estimation output:

```text
Required Fabric Quantity
Confidence Score
Estimation Notes
Tailor Review Flag
```

Fabric estimation must not rely on body measurement alone.

---

## 7. Design Your Dress Architecture Update

### 7.1 Previous Risk

Before v7.4, Design Your Dress could inherit measurements from app-level/global state.

Risk:

```text
Measurements from Self or previous profile could appear for another profile.
```

### 7.2 New v7.4 Behavior

```text
Selected Profile
        ↓
Load Latest Measurement by accountId + personId
        ↓
Show Reference Measurements
        ↓
Read-Only Measurement Display
        ↓
Optional Suggest for this Dress
```

### 7.3 Design Screen Responsibility

Design Your Dress is responsible for:

```text
Order Creation
Design Selection
Fabric Selection
Fit Selection
Read-only Measurement Reference
Formula Suggestion Preview
Draft Save / Place Order
```

Design Your Dress is not responsible for directly editing base body measurements.

---

## 8. Read-Only Measurement Principle

The main Design Your Dress measurement section displays profile measurements as reference values.

Direct editing is not allowed in this section.

Future editing/adjustment paths:

```text
Take New Measurement
Adjust for This Dress
Tailor Verification
Final Confirmation
```

This protects body measurement history.

---

## 9. Garment Formula Engine Foundation

The v7.4 formula engine foundation is introduced as:

```text
lib/services/garment_measurement_engine.dart
```

Initial formula input:

```text
Body Measurement
Dress Type
Fit Preference
Occasion Category
Selected Design Title / Future Metadata
```

Initial formula output:

```text
GarmentMeasurementEstimate
  dressType
  fitPreference
  formulaVersion
  valuesCm
  notes
```

Current v1 categories:

```text
Shirt
Kurti / Kurta
Gown
Generic fallback
```

Future categories:

```text
Blouse
Saree Blouse
Salwar Suit
Anarkali Suit
Lehenga Choli
Palazzo / Pant
Skirt
Top / Tunic
Other
```

---

## 10. Category-Aware Measurement Principle

Measurement fields and formulas vary by dress type.

Examples:

### Shirt

```text
Chest
Waist
Shoulder
Sleeve Length
Shirt Length
```

### Kurti

```text
Chest
Waist
Hip
Shoulder
Sleeve Length
Kurti Length
```

### Blouse / Saree Blouse

```text
Chest
Shoulder
Blouse Length
Sleeve Length
Neck Depth
Back Design
```

### Palazzo / Pant

```text
Waist
Hip
Thigh
Inseam
Pant Length
```

### Gown

```text
Chest
Waist
Hip
Shoulder
Sleeve Length
Gown Length
Flare
Lining
```

Therefore, a single universal measurement set is not sufficient for accurate tailoring.

---

## 11. Length Rule

Length is not a pure body measurement.

Examples:

```text
Kurti Length
Shirt Length
Top Length
Blouse Length
Pant Length
Skirt Length
Gown Length
```

Length must be one of the following:

```text
Formula Derived
Manual Entry
Historical Selection
Customer Confirmed
Tailor Confirmed
```

Length should not be guessed blindly or stored as a global profile value.

---

## 12. Fit Preference Strategy

Fit preference remains separate from size.

Supported values currently:

```text
Slim
Regular
Loose
```

Future values may become:

```text
Slim Fit
Regular Fit
Relaxed Fit
Loose Fit
Oversized Fit
```

Fit preference modifies garment measurements through ease.

Fit preference must not modify base body measurements.

---

## 13. Size Intelligence Architecture

Customers shall not be required to manually select:

```text
XS
S
M
L
XL
XXL
3XL
4XL
```

Instead SuiSakhi derives recommended size from:

```text
Height
Weight
Age
Body Measurements
Body Shape
Dress Type
```

Output:

```text
Recommended Size
Confidence Score
Body Shape Classification
Profile Update Guidance
```

Example:

```text
Height = 162 cm
Weight = 67 kg
Chest = 96 cm
Waist = 84 cm
Hip = 104 cm

Recommended Size = XL
Confidence = High
```

If height or weight is missing:

```text
Recommendation confidence is reduced.
Customer should be advised to update profile for better accuracy.
```

Size is metadata only and never replaces actual measurements.

---

## 14. Body Shape Metadata

Supported future body shape values:

```text
Hourglass
Pear
Apple
Rectangle
Inverted Triangle
Other
```

Body shape metadata may influence:

```text
Garment Recommendation
Design Recommendation
Fit Recommendation
Formula Selection
Fabric Estimation
Pattern Guidance
```

Body shape should be derived from body measurements and profile data, not manually forced onto customers.

---

## 15. Official Phase-1 Dress Types

The official v7.4 Phase-1 dress type list is:

```text
Kurti
Kurta Set
Salwar Suit
Anarkali Suit
Lehenga Choli
Gown
Blouse
Saree Blouse
Top / Tunic
Shirt
Palazzo / Pant
Skirt
Other
```

This list provides practical women-focused tailoring coverage while avoiding excessive dropdown complexity.

---

## 16. Official Phase-1 Occasion Categories

The official v7.4 Phase-1 occasion list is:

```text
Daily Wear
Office Wear
Casual Outing
Festive Wear
Party Wear
Wedding Guest
Bridal / Heavy Occasion
Traditional / Religious
Maternity / Comfort Wear
Other
```

Events such as the following are intentionally not separate dropdown values:

```text
Birthday
College Function
Dance Program
Society Event
Corporate Event
School Event
```

These should be captured in Notes.

---

## 17. Design Metadata Architecture

Every design template may contain metadata.

Metadata fields:

```text
Design Id
Design Name
Dress Type
Silhouette
Length Type
Sleeve Type
Neck Type
Flare Level
Lining Required
Complexity
Fabric Preference
```

### Example: Straight Kurti

```text
Silhouette = Straight
Length Type = Regular
Sleeve Type = Three Quarter
Flare Level = None
Lining Required = No
Complexity = Low
```

### Example: Anarkali

```text
Silhouette = Anarkali
Length Type = Long
Sleeve Type = Full
Flare Level = High
Lining Required = Yes
Complexity = Medium
```

---

## 18. AI Design Analysis Strategy

AI should not directly generate production measurements.

Future AI flow:

```text
Design Image
        ↓
AI Analysis
        ↓
Metadata Extraction
        ↓
Formula Engine
        ↓
Garment Measurement
        ↓
Fabric Estimation
```

AI may extract:

```text
Silhouette
Sleeve Type
Length Type
Flare Level
Embroidery Complexity
Lining Requirement
Fabric Style
```

AI acts as recommendation engine.

Formula Engine remains measurement authority.

Tailor and customer confirmation remain final authority.

---

## 19. Fabric Estimation Foundation

Future service:

```text
lib/services/fabric_estimation_service.dart
```

Inputs:

```text
Dress Type
Garment Length
Sleeve Length
Chest / Waist / Hip Values
Size Recommendation
Body Shape
Fabric Type
Fabric Width
Lining Requirement
Flare Level
Design Complexity
Margin Percentage
Formula Version
```

Outputs:

```text
Estimated Fabric Quantity
Calculation Version
Confidence Score
Customer-Friendly Notes
Tailor Review Flag
```

Fabric estimation is advisory until tailor confirmation.

---

## 20. Order Snapshot Architecture

Orders and drafts must preserve measurement and formula snapshots.

Recommended future fields:

```text
bodyMeasurementId
bodyMeasurementSnapshot
derivedSizeRecommendation
designMetadataSnapshot
garmentMeasurementSnapshot
formulaVersion
measurementSource
fabricEstimationSnapshot
finalConfirmedMeasurementSnapshot
```

This supports:

```text
Historical Order Accuracy
BR-125: Transactions Own Their History
Customer Support
Auditability
Reorder Accuracy
Dispute Handling
```

---

## 21. Firebase Schema Extensions

### 21.1 Existing Collection: measurements

Continue using:

```text
measurements/{measurementId}
```

Recommended body-level fields:

```text
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

### 21.2 Future Collection: size_metadata_rules

Purpose:

```text
Dress-specific size intelligence and sizing metadata.
```

Example:

```text
size_metadata_rules/{ruleId}

dressType
sizeCategory
minChest
maxChest
minWaist
maxWaist
minHip
maxHip
minShoulder
maxShoulder
easeCm
active
version
```

### 21.3 Future Collection: design_metadata_templates

Purpose:

```text
Metadata-driven design intelligence.
```

Example:

```text
design_metadata_templates/{templateId}

designName
dressType
silhouette
lengthType
sleeveType
neckType
flareLevel
liningRequired
complexity
fabricPreference
version
createdAt
updatedAt
```

### 21.4 Future Collection: body_shape_rules

Purpose:

```text
Body shape classification and guidance.
```

Example:

```text
body_shape_rules/{ruleId}

bodyShape
guidance
version
active
```

### 21.5 Future Collection: design_ai_analysis

Purpose:

```text
AI generated design metadata and confidence score.
```

Example:

```text
design_ai_analysis/{analysisId}

designTemplateId
aiProvider
silhouette
lengthType
sleeveType
flareLevel
complexity
liningRequired
confidenceScore
createdAt
```

### 21.6 Future Collection: fabric_estimation_rules

Purpose:

```text
Fabric calculation rules by dress type, material, design complexity and formula version.
```

Example:

```text
fabric_estimation_rules/{ruleId}

dressType
fabricType
fabricWidth
baseMarginPercent
liningMultiplier
flareMultiplier
complexityMultiplier
active
version
```

---

## 22. Business Rules BR-136 to BR-180

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

Garment measurements belong to dress type, category, fit, design metadata and order context.

### BR-143

Garment measurements are derived using formulaVersion.

### BR-144

Garment length is category-specific.

### BR-145

Fabric estimation must use garment measurements rather than body measurements alone.

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

### BR-161

Dress Type and Occasion Category must remain separate concepts.

### BR-162

Selected design templates may carry metadata that influences garment formula and fabric estimation.

### BR-163

AI image analysis may populate design metadata in the future but must not directly generate production measurements.

### BR-164

Formula engine must remain explainable, versioned and overrideable by tailor/customer confirmation.

### BR-165

Size Category shall be automatically derived from body measurements, height, weight, dress type and sizing metadata.

### BR-166

Size Category is derived metadata and must not replace body measurements.

### BR-167

Different dress types may generate different recommended sizes for the same customer.

### BR-168

Versioned sizing tables shall be maintained per dress type.

### BR-169

Missing height or weight reduces size recommendation confidence.

### BR-170

Customers shall not manually select XS/S/M/L/XL size categories.

### BR-171

Customer adjustments override size and formula recommendations.

### BR-172

Tailor-verified measurements override formula-generated measurements.

### BR-173

Final Confirmed Measurement is production authority.

### BR-174

AI design analysis produces metadata only.

### BR-175

Design metadata may influence garment formulas.

### BR-176

Design metadata may influence fabric estimation.

### BR-177

Body shape metadata may influence future garment formulas.

### BR-178

Formula outputs must remain explainable and reproducible.

### BR-179

Historical orders must preserve sizing, design metadata and formula versions.

### BR-180

Measurements remain the primary source of truth.

---

## 23. Architecture Decisions AD-020 to AD-032

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

### AD-028

Size recommendation is metadata and not a measurement.

### AD-029

Formula engines operate using design metadata.

### AD-030

AI generates metadata recommendations but not production measurements.

### AD-031

Body measurements remain the primary source of truth.

### AD-032

Final Confirmed Measurement remains production authority.

---

## 24. Visual Flows

### Flow-015: Body to Garment Flow

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

### Flow-016: Measurement Lifecycle

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

### Flow-017: Read-Only Design Measurement Screen

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
Suggest for this Dress
        ↓
Show Formula Preview
        ↓
Future Adjust for This Dress
```

### Flow-018: Fabric Estimation Future Flow

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

### Flow-019: Size Intelligence Flow

```text
Height
+
Weight
+
Age
+
Body Measurements
        ↓
Body Shape Engine
        ↓
Size Recommendation Engine
        ↓
Dress Type
+
Occasion
+
Design Metadata
        ↓
Garment Formula Engine
        ↓
Garment Measurements
        ↓
Fabric Estimation
        ↓
Customer Adjustment
        ↓
Tailor Verification
        ↓
Final Confirmed Measurement
        ↓
Production
```

---

## 25. Implementation Status

### Completed

```text
Profile-specific measurement loading
Blank profile measurement handling
Read-only Design measurements
Take New Measurement routing
Garment measurement engine foundation
Garment suggestion preview
Category/design context in formula notes and context
Measurement integrity protection
v7.4 architecture documentation
```

### Planned

```text
Phase-1 dress type dropdown cleanup
Phase-1 occasion dropdown cleanup
Size metadata rules
Design metadata templates
Body shape rules
AI design metadata extraction
Fabric estimation engine
Adjust For This Dress screen
Garment measurement snapshot in drafts/orders
Formula versioning in persisted records
Tailor verified measurement
Final confirmed measurement
```

---

## 26. Open Items for Next Development

| Priority | Open Item | Notes |
|---|---|---|
| High | Standardize Dress Type dropdown | Use official Phase-1 list from this document. |
| High | Standardize Occasion dropdown | Use official Phase-1 occasion list from this document. |
| High | Add design metadata model | Start with static metadata or optional template fields. |
| High | Add Adjust For This Dress screen | Order-level measurement adjustment only. |
| Medium | Add size recommendation engine | Derive size metadata from body measurements and rules. |
| Medium | Add fabric estimation service | Estimate meter requirement from garment measurements and fabric metadata. |
| Medium | Store formula snapshots in orders/drafts | Preserve history and formula version. |
| Medium | Tailor verified measurement version | Separate from body and formula-generated measurement. |
| Medium | Final confirmed measurement version | Production authority. |

---

## 27. v7.4 FINAL Consolidated Conclusion

Version 7.4 consolidates SuiSakhi's measurement intelligence architecture.

The key conclusion is:

```text
Profile owns Body Measurement.
Size is Derived Metadata.
Order owns Garment Measurement.
Design Metadata guides Formula and Fabric Estimation.
Formula is Suggestion.
Tailor Verification is Validation.
Final Confirmed Measurement is Production Authority.
```

This architecture creates the foundation for:

```text
Measurement Intelligence
Fabric Intelligence
AI-Assisted Design Metadata
Body Shape Guidance
Size Recommendation
Customer Adjustment
Tailor Validation
Production Accuracy
Historical Data Integrity
Customer Trust
```

This document should be carried forward into the future v8.0 Master Architecture.
