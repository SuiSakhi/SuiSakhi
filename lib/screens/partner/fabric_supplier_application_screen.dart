import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/metadata/fabric_supplier_partner_capability_metadata.dart';
import '../../models/address_details.dart';
import '../../models/operating_schedule.dart';
import '../../models/partner_application.dart';
import '../../models/partner_capability_selection.dart';
import '../../models/fabric_supplier_partner_details.dart';
import '../../services/partner_service.dart';
import '../../widgets/address/address_form_section.dart';
import '../../widgets/capability/capability_multi_selector.dart';
import '../../widgets/partner/partner_application_lifecycle_section.dart';
import '../../widgets/partner/partner_basic_details_section.dart';
import '../../widgets/partner/partner_reapply_dialog.dart';
import '../../widgets/schedule/operating_schedule_field.dart';

class FabricSupplierApplicationScreen extends StatefulWidget {
  const FabricSupplierApplicationScreen({super.key});
  @override
  State<FabricSupplierApplicationScreen> createState() => _FabricSupplierApplicationScreenState();
}

class _FabricSupplierApplicationScreenState extends State<FabricSupplierApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _business = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _serviceArea = TextEditingController();
  final _teamSize = TextEditingController();
  final _normalCapacity = TextEditingController();
  final _peakCapacity = TextEditingController();
  final _notes = TextEditingController();
  final _inventorySummary = TextEditingController();
  final _minimumOrderQuantity = TextEditingController();
  AddressDetails _address = const AddressDetails();
  OperatingSchedule _schedule = const OperatingSchedule();
  PartnerCapabilitySelection _capabilities = const PartnerCapabilitySelection();
  bool _inventoryAvailable = false;
  bool _catalogueAvailable = false;
  PartnerApplication? _application;
  String? _accountId;
  String? _customerProfileId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editable => _application?.canEdit == true;
  bool get _canSubmit => _editable && !_saving;

  @override
  void initState() { super.initState(); _initialize(); }

  @override
  void dispose() {
    for (final controller in [_contact, _business, _mobile, _email, _serviceArea, _teamSize, _normalCapacity, _peakCapacity, _notes, _inventorySummary, _minimumOrderQuantity]) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber?.trim();
      if (user == null || phone == null || phone.isEmpty) { throw StateError('Please sign in again before starting a Fabric Supplier application.'); }
      final accountId = await AppState.instance.fetchAccountIdForMobile(phone);
      if (accountId == null || accountId.trim().isEmpty) { throw StateError('Your SuiSakhi account could not be resolved.'); }
      final profiles = await AppState.instance.fetchActiveProfilesForAccount(accountId);
      Map<String, dynamic>? customer;
      for (final profile in profiles) { if ((profile['role'] ?? '').toString() == 'customer') { customer = profile; break; } }
      final profileId = (customer?['profileId'] ?? customer?['docId'])?.toString().trim();
      if (profileId == null || profileId.isEmpty) { throw StateError('Your active Customer profile could not be resolved.'); }
      final app = await PartnerService.createDraft(accountId: accountId, customerProfileId: profileId, partnerType: PartnerType.fabricSupplier, contactName: customer?['displayName']?.toString() ?? AppState.instance.displayName, mobileE164: phone, email: (customer?['email'] ?? user.email)?.toString());
      _accountId = accountId; _customerProfileId = profileId; _hydrateApplication(app);
      if (!mounted) return;
      setState(() { _loading = false; _error = null; });
    } catch (error) { if (!mounted) return; setState(() { _loading = false; _error = error.toString(); }); }
  }

  void _hydrateApplication(PartnerApplication app) {
    _application = app; _contact.text = app.contactName ?? ''; _business.text = app.businessName ?? ''; _mobile.text = app.mobileE164 ?? ''; _email.text = app.email ?? '';
    _hydrateBusiness(app); _hydrate(FabricSupplierPartnerDetails.fromOnboardingData(app.onboardingData));
  }

  void _hydrateBusiness(PartnerApplication app) {
    final extensions = app.onboardingData['extensions']; if (extensions is! Map) return;
    final category = extensions['fabricSupplier']; if (category is! Map) return;
    final workshop = category['workshopDetails']; if (workshop is! Map) return;
    final details = PartnerWorkshopDetails.fromMap(Map<String, dynamic>.from(workshop));
    _address = AddressDetails(addressLine1: details.addressLine1, addressLine2: details.addressLine2, locality: details.locality, cityName: details.city, stateName: details.state, pincode: details.pincode, countryCode: 'IN', placeId: details.placeId, latitude: details.latitude, longitude: details.longitude);
    _schedule = OperatingSchedule(operatingDays: details.operatingDays, openingTime: details.openingTime, closingTime: details.closingTime);
    _serviceArea.text = details.serviceAreaPincodes.join(', ');
  }

  void _hydrate(FabricSupplierPartnerDetails value) {
    _capabilities = value.capabilitySelection; _serviceArea.text = value.serviceArea ?? _serviceArea.text; _teamSize.text = value.teamSize?.toString() ?? ''; _normalCapacity.text = value.normalDailyCapacity?.toString() ?? ''; _peakCapacity.text = value.peakDailyCapacity?.toString() ?? ''; _notes.text = value.additionalNotes ?? '';
    _inventorySummary.text = value.inventorySummary?.toString() ?? '';
    _minimumOrderQuantity.text = value.minimumOrderQuantity?.toString() ?? '';
    _inventoryAvailable = value.inventoryAvailable;
    _catalogueAvailable = value.catalogueAvailable;
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  List<String> _csv(String value) => value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);

  FabricSupplierPartnerDetails _details() => FabricSupplierPartnerDetails(capabilitySelection: _capabilities, serviceArea: _serviceArea.text, teamSize: _int(_teamSize), normalDailyCapacity: _int(_normalCapacity), peakDailyCapacity: _int(_peakCapacity), inventorySummary: _inventorySummary.text, minimumOrderQuantity: _int(_minimumOrderQuantity), inventoryAvailable: _inventoryAvailable, catalogueAvailable: _catalogueAvailable, additionalNotes: _notes.text);

  PartnerWorkshopDetails _businessDetails() => PartnerWorkshopDetails(addressLine1: _address.addressLine1, addressLine2: _address.addressLine2, locality: _address.locality, city: _address.cityName, state: _address.stateName, pincode: _address.pincode, placeId: _address.placeId, latitude: _address.latitude, longitude: _address.longitude, serviceAreaPincodes: _csv(_serviceArea.text), operatingDays: _schedule.normalizedOperatingDays, openingTime: OperatingSchedule.normalizedTimeOrNull(_schedule.openingTime), closingTime: OperatingSchedule.normalizedTimeOrNull(_schedule.closingTime), teamSize: _int(_teamSize), normalDailyCapacity: _int(_normalCapacity), peakDailyCapacity: _int(_peakCapacity), additionalNotes: _notes.text.trim());

  Future<void> _save({required bool submit}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final app = _application; final accountId = _accountId; final profileId = _customerProfileId;
    if (app == null || accountId == null || profileId == null) { _message('Application context is unavailable.', true); return; }
    setState(() => _saving = true); var stage = 'basic details';
    try {
      await PartnerService.updateDraft(applicationId: app.id, accountId: accountId, customerProfileId: profileId, contactName: _contact.text, businessName: _business.text, mobileE164: _mobile.text, email: _email.text);
      stage = 'address and operating schedule';
      await PartnerService.updatePartnerBusinessDetails(applicationId: app.id, accountId: accountId, customerProfileId: profileId, partnerType: PartnerType.fabricSupplier, workshopDetails: _businessDetails());
      stage = 'Fabric Supplier capabilities and operations';
      await PartnerService.updateFabricSupplierDetails(applicationId: app.id, accountId: accountId, customerProfileId: profileId, fabricSupplierDetails: _details());
      if (submit) { stage = 'application submission'; await PartnerService.submitApplication(applicationId: app.id, accountId: accountId, customerProfileId: profileId); }
      if (!mounted) return; setState(() => _saving = false); _message(submit ? 'Fabric Supplier application submitted for Admin review.' : 'Fabric Supplier draft saved successfully.', false); if (submit) context.pop();
    } catch (error) { if (!mounted) return; setState(() => _saving = false); _message('Unable to save $stage.\n$error', true); }
  }

  Future<void> _applyAgain() async {
    final rejected = _application; final accountId = _accountId; final profileId = _customerProfileId;
    if (rejected == null || rejected.status != PartnerApplicationStatus.rejected || accountId == null || profileId == null) return;
    final confirmed = await showPartnerReapplyDialog(context: context, partnerLabel: 'Fabric Supplier'); if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try { final app = await PartnerService.reapplyFromRejected(rejectedApplicationId: rejected.id, accountId: accountId, customerProfileId: profileId); if (!mounted) return; _hydrateApplication(app); setState(() => _saving = false); _message('A new Fabric Supplier Draft was created. Review the copied information before submitting.', false); } catch (error) { if (!mounted) return; setState(() => _saving = false); _message('Unable to create a new application.\n$error', true); }
  }

  void _message(String text, bool error) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : const Color(0xFF2E7D32))); }
  Widget _field(String label, TextEditingController c, {TextInputType? type, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c, readOnly: !_editable, keyboardType: type, maxLines: lines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  Widget _card(String title, String description, List<Widget> children) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.headlineMedium), const SizedBox(height: 6), Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)), const SizedBox(height: 16), ...children]));
  Widget _actions() { final app = _application; if (app == null) return const SizedBox.shrink(); return PartnerApplicationLifecycleActions(application: app, saving: _saving, canSaveDraft: _editable && !_saving, canSubmit: _canSubmit, onSaveDraft: () => _save(submit: false), onSubmitForReview: () => _save(submit: true), onApplyAgain: _applyAgain, onContinueLater: () => context.pop()); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Fabric Supplier Application')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))));
    return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: const Text('Fabric Supplier Application'), centerTitle: true, elevation: 0), body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      PartnerApplicationStatusNotice(application: _application!, partnerLabel: 'Fabric Supplier'), const SizedBox(height: 14),
      _card('Common Partner Details', 'Common identity and contact information.', [PartnerBasicDetailsSection(contactNameController: _contact, businessNameController: _business, mobileController: _mobile, emailController: _email, editable: _editable, description: 'Common Partner identity and contact information.', businessNameLabel: 'Fabric Supplier business name')]), const SizedBox(height: 14),
      _card('Business / Service Address', 'Provide the primary address and service area.', [AddressFormSection(key: ValueKey('fabricSupplier-address-${_address.stateCode ?? _address.stateName ?? 'none'}-${_address.cityCode ?? _address.cityName ?? 'none'}'), metadataProvider: IndiaAddressMetadata.instance, initialValue: _address, enabled: _editable, sectionTitle: 'Business Address', addressLine1Label: 'Address', addressLine2Label: 'Address line 2', localityLabel: 'Locality or area', stateLabel: 'State', cityLabel: 'City', pincodeLabel: 'Pincode', addressLine1Required: true, addressLine2Required: false, localityRequired: false, landmarkRequired: false, stateRequired: true, cityRequired: true, pincodeRequired: true, showAddressLine2: true, showLocality: true, showLandmark: false, onChanged: (value) => _address = value), const SizedBox(height: 14), _field('Service-area pincodes', _serviceArea)]), const SizedBox(height: 14),
      _card('Operating Schedule', 'Select normal operating days and times.', [OperatingScheduleField(key: ValueKey('fabricSupplier-schedule-${_schedule.normalizedOperatingDays.join('-')}-${_schedule.openingTime ?? 'none'}-${_schedule.closingTime ?? 'none'}'), initialValue: _schedule, enabled: _editable, operatingDaysRequired: true, openingTimeRequired: true, closingTimeRequired: true, requireClosingAfterOpening: true, sectionTitle: 'Operating Schedule', operatingDaysLabel: 'Operating days', openingTimeLabel: 'Opening time', closingTimeLabel: 'Closing time', onChanged: (value) => _schedule = value)]), const SizedBox(height: 14),
      _card('Fabric Supply Profile', 'Select fabric categories, supply services and fulfillment capabilities.', [CapabilityMultiSelector(metadataProvider: FabricSupplierPartnerCapabilityMetadata.instance, partnerCategoryCode: FabricSupplierPartnerCapabilityMetadata.categoryCode, initialValue: _capabilities, enabled: _editable, minimumSelectionCount: 0, requireOtherExpertiseDescription: false, sectionTitle: 'Fabric Supplier capabilities', onChanged: (value) => setState(() => _capabilities = value)), SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _inventoryAvailable, onChanged: _editable ? (value) => setState(() => _inventoryAvailable = value) : null, title: const Text('Inventory available')), SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _catalogueAvailable, onChanged: _editable ? (value) => setState(() => _catalogueAvailable = value) : null, title: const Text('Catalogue available')),]), const SizedBox(height: 14),
      _card('Operations & Capacity', 'Provide capacity and operational information.', [_field('Team size', _teamSize, type: TextInputType.number), _field('Normal daily capacity', _normalCapacity, type: TextInputType.number), _field('Peak daily capacity', _peakCapacity, type: TextInputType.number), _field('Inventory / catalogue summary', _inventorySummary, lines: 3), _field('Minimum order quantity', _minimumOrderQuantity, type: TextInputType.number), _field('Additional notes', _notes, lines: 4)]), const SizedBox(height: 18), _actions(), const SizedBox(height: 24)
    ])));
  }
}
