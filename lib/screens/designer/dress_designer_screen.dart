import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/measurement_unit.dart';
import '../../models/design_template.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_version.dart';
import '../../models/catalogue_design_view.dart';
//Design MetadataService is used to fetch the design metadata for the selected template, which includes information like the design title and occasion category. This metadata is then used to calculate the garment measurements and ease based on the selected fit preference and context.
import '../../services/design_metadata_service.dart';
import '../../services/occasion_metadata_service.dart';
import '../../models/fabric_metadata.dart';
import '../../models/occasion_metadata.dart';
import '../../services/fabric_metadata_service.dart';
import '../../models/fabric_estimate.dart';
import '../../services/fabric_estimation_service.dart';
import '../../models/price_estimate.dart';
import '../../services/price_estimation_service.dart';
import '../../services/dress_customization_estimation_service.dart';
import '../../models/measurement.dart';
import '../../models/prd_catalog.dart';
import '../../services/claude_smart_assistant_service.dart';
import '../../services/design_template_service.dart';
import '../../services/catalogue_design_service.dart';
import '../../services/customer_wishlist_service.dart';
import '../../services/customer_fabric_asset_service.dart';
import '../../models/design_metadata.dart';
import '../../services/order_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_unit_toggle.dart';
import '../../services/order_draft_service.dart';
import '../../services/garment_measurement_engine.dart';
import '../../services/customer_measurement_history_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/catalogue/catalogue_fabric_preview_button.dart';

import '../../models/customer_design.dart';
import '../../services/customer_design_service.dart';

class _DressFitSuggestion {
  const _DressFitSuggestion({
    required this.field,
    required this.value,
    required this.reason,
  });

  final String field;
  final String value;
  final String reason;
}

class DressDesignerScreen extends StatefulWidget {
  const DressDesignerScreen({
    super.key,
    this.initialOccasionId,
    this.isKidsFlow = false,
    this.initialClientName,
    this.initialPersonId,
    this.initialRelationship,
    this.initialMeasurementDraftId,
    this.initialOrderDraftId,
    this.startInBrowseMode = false,
  });

  /// [OccasionCategory.name] from PRD Step 2, e.g. `dailyWear`.
  final String? initialOccasionId;
  final bool isKidsFlow;

  /// Optional context passed from Measurement Context screen.
  final String? initialClientName;
  final String? initialPersonId;
  final String? initialRelationship;
  final String? initialMeasurementDraftId;
  final String? initialOrderDraftId;
  final bool startInBrowseMode;

  @override
  State<DressDesignerScreen> createState() => _DressDesignerScreenState();
}

class _DressDesignerScreenState extends State<DressDesignerScreen> {
  late bool _showOrderForm;
  bool _orderContextInitialized = false;
  String? _occasionId;
  String _selectedDressType = 'Kurti';
  final bool _autoFillFromScan = true;
  //SUD
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<_OrderPerson> _orderPeople = [];
  BodyMeasurements? _latestBodyMeasurementsForSuggestion;
  CustomerMeasurementRecord? _customerMeasurementReference;
  String? _selectedOrderPersonId;
  String? _resumeDraftPersonName;
  String? _resumeDraftRelationship;
  bool _loadingOrderPeople = true;

  final List<_DesignerAddress> _deliveryAddresses = [];
  String? _selectedDeliveryAddressId;
  bool _loadingDeliveryAddresses = true;
  String? _deliveryAddressError;
  String? _resumeDraftDeliveryAddressSnapshot;
  bool _usingResumeDraftDeliveryAddressSnapshot = false;

  late final _clientNameController = TextEditingController(
    text: widget.initialClientName?.trim().isNotEmpty == true
        ? widget.initialClientName!.trim()
        : AppState.instance.displayName == 'Guest'
        ? ''
        : AppState.instance.displayName,
  );
  final _deliveryAddressController = TextEditingController();
  GarmentMeasurementEstimate? _garmentMeasurementEstimate;
  FabricEstimate? _fabricEstimate;
  CustomerFabricPreviewSelection? _pendingCustomerFabricSelection;
  _SavedWishlistFabricSelection? _selectedWishlistFabricSelection;
  PriceEstimate? _priceEstimate;

  /// null | 'fit' | 'fabric' | 'polish'
  String? _smartAssistBusy;
  String? _fabricStyleAiText;
  String? _fabricStyleContextKey;
  String? _fitAssistantContextKey;
  String? _fitAssistantSummary;
  List<_DressFitSuggestion> _fitAssistantSuggestions = const [];

  final _measurementFields = {
    'Chest': TextEditingController(text: '0'),
    'Waist': TextEditingController(text: '0'),
    'Hip': TextEditingController(text: '0'),
    'Shoulder': TextEditingController(text: '0'),
    'Length': TextEditingController(text: '0'),
    'Sleeve Length': TextEditingController(text: '0'),
  };

  static const List<String> _dressTypes = [
    'Kurti',
    'Kurta Set',
    'Salwar Suit',
    'Anarkali Suit',
    'Lehenga Choli',
    'Gown',
    'Blouse',
    'Saree Blouse',
    'Top / Tunic',
    'Shirt',
    'Palazzo / Pant',
    'Skirt',
    'Other',
  ];

  String _selectedFit = 'Regular';
  final _fitOptions = ['Slim', 'Regular', 'Loose'];

  final _notesController = TextEditingController();
  final _neckController = TextEditingController();
  final _sleeveStyleController = TextEditingController();
  final _backDesignController = TextEditingController();
  final _marginController = TextEditingController();
  final _customFabricController = TextEditingController();
  String? _selectedNeckStyle;
  String? _selectedSleeveStyle;
  String? _selectedBackDesign;
  String? _selectedAlterationMargin;
  String? _selectedLiningPreference;

  static const List<String> _neckStyleOptions = [
    'Round Neck',
    'V Neck',
    'Boat Neck',
    'Square Neck',
    'Collar Neck',
    'Keyhole Neck',
    'Princess Neck',
    'Pot Neck',
    'Other',
  ];

  static const List<String> _sleeveStyleOptions = [
    'Sleeveless',
    'Cap Sleeve',
    'Short Sleeve',
    'Elbow Sleeve',
    'Three Quarter Sleeve',
    'Full Sleeve',
    'Puff Sleeve',
    'Bell Sleeve',
    'Other',
  ];

  static const List<String> _backDesignOptions = [
    'Standard Back',
    'Round Back',
    'U Back',
    'V Back',
    'Deep Back',
    'Button Back',
    'Tie / Dori Back',
    'Closed Back',
    'Other',
  ];

  static const List<String> _alterationMarginOptions = [
    'No Extra Margin',
    'Standard Margin',
    'Extra Margin',
    'Tailor Recommendation',
  ];

  static const List<String> _liningPreferenceOptions = [
    'Not Required',
    'Required',
    'As Recommended',
    'Tailor to Confirm',
  ];

  bool _placeOrderLoading = false;
  bool _saveDraftLoading = false;
  String? _currentOrderDraftId;

  /// PRD Step 11 — advance 30–50%.
  int _advancePercent = 50;

  DesignTemplate? _selectedTemplate;
  String? _fabricChoice;
  final Color _accentColor = AppColors.primary;

  /// Unit the numeric text fields are currently expressed in.
  MeasurementUnit _fieldsUnit = MeasurementUnit.cm;

  /// Avoid re-hydrating on unrelated [AppState] notifications.
  String? _measurementHydrationSignature;

  static const List<String> _fabricOptions = [
    'Cotton',
    'Silk',
    'Georgette',
    'Chiffon',
    'Linen',
    'Velvet',
    'Organza',
    'Rayon / Viscose',
    'Crepe',
    'Satin',
    'Net / Tulle',
    'Brocade',
    'Denim',
    'Polyester Blend',
    'Wool Blend',
    'Other',
  ];
  String _colorHexRgb(Color color) {
    int channel(double value) {
      return (value * 255.0).round().clamp(0, 255);
    }

    final red = channel(color.r);
    final green = channel(color.g);
    final blue = channel(color.b);

    return '#${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }

  Future<void> _loadOrderPeople() async {
    try {
      final profile = AppState.instance.profile;
      final customerName = profile?.name.trim().isNotEmpty == true
          ? profile!.name.trim()
          : AppState.instance.displayName;

      final people = <_OrderPerson>[
        _OrderPerson(
          id: 'self',
          name: customerName,
          relationship: 'Self',
          isSelf: true,
        ),
      ];

      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone != null && phone.trim().isNotEmpty) {
        final accountId = await AppState.instance.fetchAccountIdForMobile(
          phone.trim(),
        );

        if (accountId != null && accountId.isNotEmpty) {
          final profiles = await AppState.instance
              .fetchActiveProfilesForAccount(accountId);

          Map<String, dynamic>? customerProfile;
          for (final p in profiles) {
            final role = (p['role'] ?? '').toString();
            if (role == 'customer') {
              customerProfile = p;
              break;
            }
          }

          final customerProfileId =
              customerProfile?['profileId']?.toString() ??
              customerProfile?['docId']?.toString();

          if (customerProfileId != null &&
              customerProfileId.trim().isNotEmpty) {
            final familySnap = await _db
                .collection('accounts')
                .doc(accountId)
                .collection('profiles')
                .doc(customerProfileId)
                .collection('family_members')
                .where('status', isEqualTo: 'active')
                .get();

            for (final doc in familySnap.docs) {
              final data = doc.data();

              people.add(
                _OrderPerson(
                  id: doc.id,
                  name: data['name']?.toString() ?? 'Family Member',
                  relationship: data['relationship']?.toString() ?? 'Other',
                  isSelf: false,
                ),
              );
            }
          }
        }
      }

      String selectedId = 'self';

      final existingSelectedId = _selectedOrderPersonId?.trim();
      final draftPersonName = _resumeDraftPersonName?.trim();
      final draftRelationship = _resumeDraftRelationship?.trim();
      final existingClientName = _clientNameController.text.trim();

      if (existingSelectedId != null &&
          existingSelectedId.isNotEmpty &&
          people.any((p) => p.id == existingSelectedId)) {
        selectedId = existingSelectedId;
      } else if (draftPersonName != null && draftPersonName.isNotEmpty) {
        for (final p in people) {
          final sameName =
              p.name.trim().toLowerCase() == draftPersonName.toLowerCase();

          final sameRelationship =
              draftRelationship == null ||
              draftRelationship.isEmpty ||
              p.relationship.trim().toLowerCase() ==
                  draftRelationship.toLowerCase();

          if (sameName && sameRelationship) {
            selectedId = p.id;
            break;
          }
        }

        if (selectedId == 'self') {
          for (final p in people) {
            if (p.name.trim().toLowerCase() == draftPersonName.toLowerCase()) {
              selectedId = p.id;
              break;
            }
          }
        }
      } else if (existingClientName.isNotEmpty) {
        for (final p in people) {
          if (p.name.trim().toLowerCase() == existingClientName.toLowerCase()) {
            selectedId = p.id;
            break;
          }
        }
      } else {
        final initialPersonId = widget.initialPersonId?.trim();
        final initialClientName = widget.initialClientName?.trim();

        if (initialPersonId != null &&
            initialPersonId.isNotEmpty &&
            people.any((p) => p.id == initialPersonId)) {
          selectedId = initialPersonId;
        } else if (initialClientName != null && initialClientName.isNotEmpty) {
          for (final p in people) {
            if (p.name.trim().toLowerCase() ==
                initialClientName.toLowerCase()) {
              selectedId = p.id;
              break;
            }
          }
        }
      }

      final selectedPerson = people.firstWhere(
        (p) => p.id == selectedId,
        orElse: () => people.first,
      );

      if (!mounted) return;

      setState(() {
        _orderPeople
          ..clear()
          ..addAll(people);
        _selectedOrderPersonId = selectedPerson.id;
        _clientNameController.text = selectedPerson.name;
        _loadingOrderPeople = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingOrderPeople = false;
      });
    }
  }

  Future<void> _loadDeliveryAddresses() async {
    setState(() {
      _loadingDeliveryAddresses = true;
      _deliveryAddressError = null;
    });

    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone == null || phone.trim().isEmpty) {
        setState(() {
          _deliveryAddressError =
              'Unable to load addresses. Please sign in again.';
          _loadingDeliveryAddresses = false;
        });
        return;
      }

      final accountId = await AppState.instance.fetchAccountIdForMobile(
        phone.trim(),
      );

      if (accountId == null || accountId.isEmpty) {
        setState(() {
          _deliveryAddressError = 'Unable to find account for saved addresses.';
          _loadingDeliveryAddresses = false;
        });
        return;
      }

      final snap = await _db
          .collection('accounts')
          .doc(accountId)
          .collection('addresses')
          .where('status', isEqualTo: 'active')
          .get();

      final addresses = snap.docs
          .map((doc) => _DesignerAddress.fromMap(doc.id, doc.data()))
          .toList();

      addresses.sort((a, b) {
        if (a.isDefault == b.isDefault) {
          return a.addressType.compareTo(b.addressType);
        }
        return a.isDefault ? -1 : 1;
      });

      String? selectedId;

      if (addresses.isNotEmpty) {
        final existingSelectedId = _selectedDeliveryAddressId;

        final existingStillAvailable =
            existingSelectedId != null &&
            addresses.any((address) => address.addressId == existingSelectedId);

        if (existingStillAvailable) {
          selectedId = existingSelectedId;
        } else {
          final defaultAddress = addresses.where((a) => a.isDefault).toList();

          selectedId = defaultAddress.isNotEmpty
              ? defaultAddress.first.addressId
              : addresses.first.addressId;
        }
      }

      final selectedAddress = selectedId == null
          ? null
          : addresses.firstWhere(
              (a) => a.addressId == selectedId,
              orElse: () => addresses.first,
            );

      setState(() {
        _deliveryAddresses
          ..clear()
          ..addAll(addresses);

        _selectedDeliveryAddressId = selectedId;
        if (!_usingResumeDraftDeliveryAddressSnapshot) {
          _deliveryAddressController.text =
              selectedAddress?.formattedAddress ?? '';
        }

        _loadingDeliveryAddresses = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deliveryAddressError = 'Unable to load saved addresses.';
        _loadingDeliveryAddresses = false;
      });
    }
  }

  _OrderPerson? _selectedOrderPerson() {
    if (_orderPeople.isEmpty) return null;

    final selectedId = _selectedOrderPersonId ?? _orderPeople.first.id;

    return _orderPeople.firstWhere(
      (person) => person.id == selectedId,
      orElse: () => _orderPeople.first,
    );
  }

  bool _isIncompleteSelfProfile(_OrderPerson? person) {
    if (person == null || !person.isSelf) {
      return false;
    }

    final name = person.name.trim().toLowerCase();

    return name.isEmpty ||
        name == 'user' ||
        name == 'guest' ||
        name == 'customer';
  }

  Future<void> _showCompleteProfilePrompt() async {
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text(
            'Please add your name in your profile before placing or saving an order for yourself.\n\n'
            'You can still place orders for family members if their details are already added.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update Profile'),
            ),
          ],
        );
      },
    );

    if (goToProfile == true && mounted) {
      context.push('/account');
    }
  }

  Future<Map<String, String>?> _loadAccountAndCustomerProfileForDraft() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    final accountId = await AppState.instance.fetchAccountIdForMobile(
      phone.trim(),
    );

    if (accountId == null || accountId.isEmpty) {
      return null;
    }

    final profiles = await AppState.instance.fetchActiveProfilesForAccount(
      accountId,
    );

    Map<String, dynamic>? customerProfile;

    for (final profile in profiles) {
      final role = (profile['role'] ?? '').toString();
      if (role == 'customer') {
        customerProfile = profile;
        break;
      }
    }

    final customerProfileId =
        customerProfile?['profileId']?.toString() ??
        customerProfile?['docId']?.toString();

    if (customerProfileId == null || customerProfileId.trim().isEmpty) {
      return null;
    }

    return {'accountId': accountId, 'customerProfileId': customerProfileId};
  }

  Future<_CustomerDesignOwnerContext?>
  _resolveSelectedCustomerDesignOwner() async {
    final selectedPerson = _selectedOrderPerson();

    if (selectedPerson == null) {
      return null;
    }

    final accountContext = await _loadAccountAndCustomerProfileForDraft();

    if (accountContext == null) {
      return null;
    }

    final accountId = accountContext['accountId']?.trim() ?? '';

    final customerProfileId = accountContext['customerProfileId']?.trim() ?? '';

    if (accountId.isEmpty || customerProfileId.isEmpty) {
      return null;
    }

    final resolvedProfileId = selectedPerson.isSelf
        ? customerProfileId
        : selectedPerson.id.trim();

    if (resolvedProfileId.isEmpty || resolvedProfileId == 'self') {
      return null;
    }

    return _CustomerDesignOwnerContext(
      accountId: accountId,
      profileId: resolvedProfileId,
      profileName: selectedPerson.name.trim().isEmpty
          ? 'Customer'
          : selectedPerson.name.trim(),
    );
  }

  Future<void> _loadOrderDraft(String draftId) async {
    try {
      final doc = await _db.collection('order_drafts').doc(draftId).get();

      if (!doc.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft not found.')));
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final status = (data['status'] ?? '').toString();
      if (status != 'draft') {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This draft is no longer active.')),
        );
        return;
      }

      final personId = data['personId']?.toString();
      final personName = data['personName']?.toString();
      final relationship = data['relationship']?.toString();
      final occasionCategory = data['occasionCategory']?.toString();
      final dressType = data['dressType']?.toString();
      final fitPreference = data['fitPreference']?.toString();
      final fabricChoice = data['fabricChoice']?.toString();
      final deliveryAddressId = data['deliveryAddressId']?.toString();
      final deliveryAddress = data['deliveryAddress']?.toString();
      final notes = data['notes']?.toString();
      final advancePercentRaw = data['advancePercent'];

      final measurementsRaw = data['measurements'];

      if (!mounted) return;

      setState(() {
        _currentOrderDraftId = draftId;
        _resumeDraftPersonName = personName;
        _resumeDraftRelationship = relationship;

        String? resolvedPersonId;

        if (personId != null &&
            personId.isNotEmpty &&
            _orderPeople.any((p) => p.id == personId)) {
          resolvedPersonId = personId;
        } else if (personName != null && personName.isNotEmpty) {
          for (final p in _orderPeople) {
            final sameName =
                p.name.trim().toLowerCase() == personName.toLowerCase();

            final sameRelationship =
                relationship == null ||
                relationship.isEmpty ||
                p.relationship.trim().toLowerCase() ==
                    relationship.toLowerCase();

            if (sameName && sameRelationship) {
              resolvedPersonId = p.id;
              break;
            }
          }

          if (resolvedPersonId == null) {
            for (final p in _orderPeople) {
              if (p.name.trim().toLowerCase() == personName.toLowerCase()) {
                resolvedPersonId = p.id;
                break;
              }
            }
          }
        }

        // Important fallback for old/recovered drafts.
        // If draft person cannot be found in active family members,
        // create a snapshot person so the dropdown still shows the saved draft owner.
        if ((resolvedPersonId == null || resolvedPersonId.isEmpty) &&
            personName != null &&
            personName.isNotEmpty) {
          final snapshotPersonId = personId != null && personId.isNotEmpty
              ? personId
              : 'draft_person_$draftId';

          if (!_orderPeople.any((p) => p.id == snapshotPersonId)) {
            _orderPeople.add(
              _OrderPerson(
                id: snapshotPersonId,
                name: personName,
                relationship: relationship?.isNotEmpty == true
                    ? relationship!
                    : 'Other',
                isSelf: false,
              ),
            );
          }

          resolvedPersonId = snapshotPersonId;
        }

        if (resolvedPersonId != null && resolvedPersonId.isNotEmpty) {
          _selectedOrderPersonId = resolvedPersonId;
        }

        if (personName != null && personName.isNotEmpty) {
          _clientNameController.text = personName;
        }
        if (occasionCategory != null && occasionCategory.isNotEmpty) {
          _occasionId = occasionCategory;
        }

        if (dressType != null && dressType.isNotEmpty) {
          _selectedDressType = dressType;
        }

        if (fitPreference != null && fitPreference.isNotEmpty) {
          _selectedFit = fitPreference;
        }

        if (fabricChoice != null && fabricChoice.isNotEmpty) {
          _fabricChoice = fabricChoice;
        }

        if (deliveryAddressId != null && deliveryAddressId.isNotEmpty) {
          _selectedDeliveryAddressId = deliveryAddressId;
        }

        if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
          _deliveryAddressController.text = deliveryAddress;
          _resumeDraftDeliveryAddressSnapshot = deliveryAddress;
          _usingResumeDraftDeliveryAddressSnapshot = true;
        }

        if (notes != null) {
          _notesController.text = notes;
        }

        if (advancePercentRaw is num) {
          final value = advancePercentRaw.round();
          if (value >= 30 && value <= 50) {
            _advancePercent = value;
          }
        }

        if (measurementsRaw is Map) {
          final unit = AppState.instance.measurementUnit;

          for (final entry in measurementsRaw.entries) {
            final key = entry.key.toString();
            final value = entry.value?.toString();

            if (value == null || value.trim().isEmpty) continue;

            final cm = double.tryParse(value);
            final controller = _measurementFields[key];

            if (cm != null && controller != null) {
              controller.text = MeasurementFormat.cmToDisplayText(cm, unit);
            }
          }
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft loaded successfully')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load draft. Please try again.'),
        ),
      );
    }
  }

  Future<void> _saveOrderDraft() async {
    if (_saveDraftLoading) return;

    final selectedPerson = _selectedOrderPerson();

    if (selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who this draft is for.')),
      );
      return;
    }

    if (_isIncompleteSelfProfile(selectedPerson)) {
      await _showCompleteProfilePrompt();
      return;
    }
    final deliveryAddress = _deliveryAddressController.text.trim();

    if (_selectedDeliveryAddressId == null || deliveryAddress.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a saved delivery address before saving draft.',
          ),
        ),
      );
      return;
    }

    setState(() => _saveDraftLoading = true);

    try {
      final accountContext = await _loadAccountAndCustomerProfileForDraft();

      if (accountContext == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save draft. Account details not found.'),
          ),
        );

        setState(() => _saveDraftLoading = false);
        return;
      }

      final measurements = _measurementsInCmForOrders();

      final designSource = _selectedTemplate != null
          ? (_selectedTemplate!.catalogueVersionId == null
                ? 'design_template'
                : 'catalogue_design')
          : 'manual_design_details';

      final draftId = await OrderDraftService.saveDraft(
        draftId: _currentOrderDraftId,
        accountId: accountContext['accountId']!,
        customerProfileId: accountContext['customerProfileId']!,
        personId: selectedPerson.id,
        personName: selectedPerson.name,
        relationship: selectedPerson.relationship,
        measurementDraftId: widget.initialMeasurementDraftId,
        deliveryAddressId: _selectedDeliveryAddressId,
        deliveryAddress: deliveryAddress,
        dressType: _selectedDressType,
        fitPreference: _selectedFit,
        measurements: measurements,
        notes: _composeDetailNotes(),
        fabricChoice:
            _fabricChoice == 'Other' &&
                _customFabricController.text.trim().isNotEmpty
            ? _customFabricController.text.trim()
            : _fabricChoice,
        designTemplateId: _selectedTemplate?.id,
        designTemplateTitle: _selectedTemplate?.title,
        designImageUrl: _selectedTemplate?.imageUrl,
        catalogueVersionId: _selectedTemplate?.catalogueVersionId,
        catalogueCommercialType: _selectedTemplate?.catalogueCommercialType,
        approvedDesignCharge: _selectedTemplate?.catalogueVersionId == null
            ? null
            : _approvedCatalogueDesignCharge,
        designSource: designSource,
        advancePercent: _advancePercent,
        occasionCategory: _occasionId,
        kidsFlow: widget.isKidsFlow,
        fabricPurchaseEstimate: _fabricEstimate?.toMap(),
        fabricPreviewSelection: _pendingCustomerFabricSelection,
        customerFabricAssets: _pendingCustomerFabricSelection == null
            ? _matchingSavedWishlistFabricSelection?.customerFabricAssets
            : null,
      );

      if (!mounted) return;

      setState(() {
        _currentOrderDraftId = draftId;
        _saveDraftLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved successfully')));
    } catch (_) {
      if (!mounted) return;

      setState(() => _saveDraftLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save draft. Please try again.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _showOrderForm = !widget.startInBrowseMode;
    _occasionId = widget.initialOccasionId ?? OccasionCategory.dailyWear.name;
    if (_showOrderForm) _initializeOrderContext();
  }

  void _initializeOrderContext() {
    if (_orderContextInitialized) return;
    _orderContextInitialized = true;
    unawaited(_initializeDesignerScreen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fieldsUnit = AppState.instance.measurementUnit;
      _syncNumericDefaultsToProfileUnit();
      AppState.instance.addListener(_onAppMeasurementUnitChanged);
      AppState.instance.addListener(_onAppMeasurementsFromAppState);
      _hydrateMeasurementFields();
      _measurementHydrationSignature = _measurementDataSignature();
    });
  }

  void _openOrderForm() {
    if (!_showOrderForm) setState(() => _showOrderForm = true);
    _initializeOrderContext();
  }

  Future<void> _initializeDesignerScreen() async {
    await _loadOrderPeople();
    await _loadDeliveryAddresses();

    final orderDraftId = widget.initialOrderDraftId?.trim();

    if (orderDraftId != null && orderDraftId.isNotEmpty) {
      await _loadOrderDraft(orderDraftId);
      return;
    }

    if (!_hasMeasurementDraftContext) {
      await _loadLatestMeasurementsForSelectedPerson();
    }
  }

  String _measurementDataSignature() {
    final saved = AppState.instance.savedDressMeasurementsCm;
    final keys = saved.keys.toList()..sort();
    final savedPart = keys.map((k) => '$k:${saved[k]}').join('|');
    final m = AppState.instance.measurements;
    final bodyPart = m == null
        ? 'noScan'
        : '${m.capturedAt.millisecondsSinceEpoch}:'
              '${m.chest}:${m.waist}:${m.hips}:${m.shoulder}:${m.armLength}';
    return '$savedPart::$bodyPart';
  }

  void _onAppMeasurementsFromAppState() {
    if (!mounted) return;
    final sig = _measurementDataSignature();
    if (sig == _measurementHydrationSignature) return;
    _measurementHydrationSignature = sig;
    _hydrateMeasurementFields();
  }

  /// Centimetres from [BodyMeasurements] for each dress-designer row (garment Length has no body scan).
  static double? _bodyCmForDesignerKey(String key, BodyMeasurements bm) {
    switch (key) {
      case 'Chest':
        return bm.chest;
      case 'Waist':
        return bm.waist;
      case 'Hip':
        return bm.hips;
      case 'Shoulder':
        return bm.shoulder;
      case 'Sleeve Length':
        return bm.armLength;
      case 'Length':
        return null;
      default:
        return null;
    }
  }

  bool get _hasOrderDraftContext {
    return widget.initialOrderDraftId?.trim().isNotEmpty == true ||
        _currentOrderDraftId?.trim().isNotEmpty == true;
  }

  bool get _hasMeasurementDraftContext {
    return widget.initialMeasurementDraftId?.trim().isNotEmpty == true;
  }

  BodyMeasurements? _bodyMeasurementsFromFirestoreValues(
    Map<String, dynamic>? values,
  ) {
    if (values == null || values.isEmpty) return null;

    double? read(String key) {
      final value = values[key];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final height = read('height');
    final chest = read('chest');
    final waist = read('waist');
    final hips = read('hips');
    final shoulder = read('shoulder');
    final armLength = read('armLength');
    final neck = read('neck');
    final thigh = read('thigh');
    final inseam = read('inseam');

    final hasAnyValue = [
      height,
      chest,
      waist,
      hips,
      shoulder,
      armLength,
      neck,
      thigh,
      inseam,
    ].any((value) => value != null && value > 0);

    if (!hasAnyValue) return null;

    return BodyMeasurements(
      height: height,
      chest: chest,
      waist: waist,
      hips: hips,
      shoulder: shoulder,
      armLength: armLength,
      neck: neck,
      thigh: thigh,
      inseam: inseam,
      capturedAt: DateTime.now(),
    );
  }

  void _clearDesignerMeasurementFields() {
    for (final controller in _measurementFields.values) {
      controller.clear();
    }

    _latestBodyMeasurementsForSuggestion = null;
    _garmentMeasurementEstimate = null;
  }

  void _applyBodyMeasurementsToDesignerFields(BodyMeasurements measurements) {
    final unit = AppState.instance.measurementUnit;

    void setCm(String key, double? cm) {
      final controller = _measurementFields[key];
      if (controller == null) return;

      if (cm != null && cm > 0) {
        controller.text = MeasurementFormat.cmToDisplayText(cm, unit);
      } else {
        controller.clear();
      }
    }

    setCm('Chest', measurements.chest);
    setCm('Waist', measurements.waist);
    setCm('Hip', measurements.hips);
    setCm('Shoulder', measurements.shoulder);
    setCm('Sleeve Length', measurements.armLength);

    // Garment length is dress-specific. Do not guess it from body height.
    _measurementFields['Length']?.clear();

    // Keep the complete body measurement object for formula suggestions.
    // Height is not shown in the order measurement card, but formulas need it.
    _latestBodyMeasurementsForSuggestion = measurements;

    _fieldsUnit = unit;
  }

  Future<void> _loadLatestMeasurementsForSelectedPerson() async {
    if (_hasOrderDraftContext || _hasMeasurementDraftContext) {
      return;
    }

    final selectedPerson = _selectedOrderPerson();
    if (selectedPerson == null) {
      _clearDesignerMeasurementFields();
      if (mounted) setState(() {});
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber;
      if (phone == null || phone.trim().isEmpty) {
        _clearDesignerMeasurementFields();
        if (mounted) setState(() {});
        return;
      }

      final accountId = await AppState.instance.fetchAccountIdForMobile(
        phone.trim(),
      );

      if (accountId == null || accountId.isEmpty) {
        _clearDesignerMeasurementFields();
        if (mounted) setState(() {});
        return;
      }

      BodyMeasurements? loadedMeasurements;
      final customerUid = user?.uid;
      if (customerUid != null && customerUid.isNotEmpty) {
        try {
          loadedMeasurements =
              await CustomerMeasurementHistoryService.loadLatestTailorConfirmed(
                customerUid: customerUid,
                personId: selectedPerson.id,
                personName: selectedPerson.name,
              );
        } catch (_) {
          // Keep the existing measurement-record lookup as a fallback if
          // historical orders are temporarily unavailable.
        }
      }

      if (loadedMeasurements == null) {
        final snap = await _db
            .collection('measurements')
            .where('accountId', isEqualTo: accountId)
            .where('personId', isEqualTo: selectedPerson.id)
            .get();

        final usableDocs = snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .where((data) {
              final status = (data['status'] ?? '').toString();

              return status == 'ai_estimated' ||
                  status == 'customer_review_required' ||
                  status == 'partner_review_required' ||
                  status == 'verified' ||
                  status == 'accepted' ||
                  status == 'order_created';
            })
            .toList();

        usableDocs.sort((a, b) {
          final aTime = a['updatedAt'];
          final bTime = b['updatedAt'];

          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }

          return 0;
        });

        for (final data in usableDocs) {
          final values = data['measurementValues'];

          if (values is Map<String, dynamic>) {
            loadedMeasurements = _bodyMeasurementsFromFirestoreValues(values);
          } else if (values is Map) {
            loadedMeasurements = _bodyMeasurementsFromFirestoreValues(
              Map<String, dynamic>.from(values),
            );
          }

          if (loadedMeasurements != null) break;
        }
      }

      if (!mounted) return;

      setState(() {
        if (loadedMeasurements == null) {
          _clearDesignerMeasurementFields();
        } else {
          _applyBodyMeasurementsToDesignerFields(loadedMeasurements);
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _clearDesignerMeasurementFields();
      });
    }
  }

  /// Merges Firestore [savedDressMeasurementsCm] with camera body scan.
  ///
  /// Saved values win only when **non-zero** (so an all-zero save from a prior visit
  /// does not wipe scan data when opening from My Measurements → Design a dress).
  void _hydrateMeasurementFields() {
    final u = AppState.instance.measurementUnit;
    final saved = AppState.instance.savedDressMeasurementsCm;
    final bm = AppState.instance.measurements;
    final useScan = _autoFillFromScan && bm != null;

    void setCm(String key, double cm) {
      final c = _measurementFields[key];
      if (c != null) {
        c.text = MeasurementFormat.cmToDisplayText(cm, u);
      }
    }

    for (final key in _measurementFields.keys) {
      final raw = saved[key];
      final savedCm = raw != null ? double.tryParse(raw) : null;
      final savedNonZero = savedCm != null && savedCm.abs() > 1e-6;

      if (savedNonZero) {
        setCm(key, savedCm);
        continue;
      }

      if (useScan) {
        final fromBody = _bodyCmForDesignerKey(key, bm);

        if (fromBody != null && fromBody > 0) {
          setCm(key, fromBody);
        } else {
          _measurementFields[key]?.clear();
        }

        continue;
      }

      if (savedCm != null && savedCm > 0) {
        setCm(key, savedCm);
      } else {
        _measurementFields[key]?.clear();
      }
    }

    _fieldsUnit = u;
    if (mounted) setState(() {});
  }

  Map<String, String> _allMeasurementsCmForStorage() {
    final u = AppState.instance.measurementUnit;
    return {
      for (final e in _measurementFields.entries)
        e.key: MeasurementFormat.parseToCm(e.value.text, u).toStringAsFixed(1),
    };
  }

  void _syncNumericDefaultsToProfileUnit() {
    final u = AppState.instance.measurementUnit;
    if (u == MeasurementUnit.cm) {
      _fieldsUnit = u;
      return;
    }
    for (final c in _measurementFields.values) {
      final v = double.tryParse(c.text.trim());
      if (v == null) continue;
      c.text = MeasurementFormat.cmToDisplayText(v, u);
    }
    _fieldsUnit = u;
  }

  void _onAppMeasurementUnitChanged() {
    final u = AppState.instance.measurementUnit;
    if (u == _fieldsUnit) return;
    for (final c in _measurementFields.values) {
      final v = double.tryParse(c.text.trim());
      if (v == null) continue;
      final cm = _fieldsUnit.toCm(v);
      c.text = MeasurementFormat.cmToDisplayText(cm, u);
    }
    _fieldsUnit = u;
    if (mounted) setState(() {});
  }

  Map<String, String> _measurementsInCmForOrders() {
    final u = AppState.instance.measurementUnit;
    return Map.fromEntries(
      _measurementFields.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) {
            final cm = MeasurementFormat.parseToCm(e.value.text, u);
            return MapEntry(e.key, cm.toStringAsFixed(1));
          }),
    );
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppMeasurementUnitChanged);
    AppState.instance.removeListener(_onAppMeasurementsFromAppState);
    if (AppState.instance.currentUserId != null) {
      unawaited(
        AppState.instance.saveDressDesignerMeasurements(
          _allMeasurementsCmForStorage(),
          notify: false,
        ),
      );
    }
    _clientNameController.dispose();
    _deliveryAddressController.dispose();
    for (final c in _measurementFields.values) {
      c.dispose();
    }
    _notesController.dispose();
    _neckController.dispose();
    _sleeveStyleController.dispose();
    _backDesignController.dispose();
    _marginController.dispose();
    _customFabricController.dispose();
    super.dispose();
  }

  String _composeDetailNotes() {
    final parts = <String>[];
    if (_neckController.text.trim().isNotEmpty) {
      parts.add('Neck depth (front/back): ${_neckController.text.trim()}');
    }
    if (_sleeveStyleController.text.trim().isNotEmpty) {
      parts.add('Sleeve style: ${_sleeveStyleController.text.trim()}');
    }
    if (_backDesignController.text.trim().isNotEmpty) {
      parts.add('Back design: ${_backDesignController.text.trim()}');
    }
    if (_marginController.text.trim().isNotEmpty) {
      parts.add('Margin for alteration: ${_marginController.text.trim()}');
    }
    if (_selectedLiningPreference?.trim().isNotEmpty == true) {
      parts.add('Lining / Astar: ${_selectedLiningPreference!.trim()}');
    }
    if (_notesController.text.trim().isNotEmpty) {
      parts.add(_notesController.text.trim());
    }
    final customerReference = _customerMeasurementReference;
    if (customerReference != null) {
      final values = customerReference.values.entries
          .map((entry) => '${entry.key}: ${entry.value} ${customerReference.unit}')
          .join(', ');
      final sourceOrderId = customerReference.sourceOrderId?.trim();
      parts.add(
        'Customer measurement reference (for Tailor review; not final or partner-confirmed): ${customerReference.title}'
        '${sourceOrderId?.isNotEmpty == true ? ' · Previous order $sourceOrderId' : ''}'
        '${values.isEmpty ? '' : ' — $values'}',
      );
    }
    if (_selectedTemplate != null) {
      parts.add('Design flat: ${_selectedTemplate!.title}');
    }
    if (_fabricChoice != null) {
      parts.add('Fabric: $_fabricChoice');
    }
    if (_selectedTemplate != null || _fabricChoice != null) {
      parts.add('Accent colour: ${_colorHexRgb(_accentColor)}');
    }
    return parts.join('\n');
  }

  Future<void> _chooseSavedMeasurementReference() async {
    final person = _selectedOrderPerson();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (person == null || uid == null || phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer profile first.')),
      );
      return;
    }
    try {
      final accountId = await AppState.instance.fetchAccountIdForMobile(
        phone.trim(),
      );
      if (accountId == null || accountId.isEmpty) {
        throw StateError('Customer account was not found');
      }
      final records = await CustomerMeasurementHistoryService.loadHistory(
        customerUid: uid,
        accountId: accountId,
        personId: person.id,
        personName: person.name,
        limit: 10,
      );
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved measurement references found.')),
        );
        return;
      }
      final selected = await showModalBottomSheet<CustomerMeasurementRecord>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .78,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Choose a measurement reference',
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'This will be added to the Tailor instructions as a customer reference. It will not replace order measurements or partner confirmation.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final record in records)
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(record.title),
                    subtitle: Text(
                      '${record.isCustomerReference ? 'Customer reference' : 'Tailor confirmed'} · ${record.values.length} fields · ${_shortMeasurementDate(record.capturedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(record),
                  ),
                ),
            ],
          ),
        ),
      );
      if (selected != null && mounted) {
        setState(() => _customerMeasurementReference = selected);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load measurement history. Please try again.')),
      );
    }
  }

  String? _occasionLabel() {
    final id = _occasionId;
    if (id == null) return null;

    for (final o in OccasionCategory.values) {
      if (o.name == id) return o.displayName;
    }

    // Backward compatibility for older saved drafts/orders.
    if (id == 'weddingBridal') {
      return 'Bridal / Heavy Occasion';
    }

    return null;
  }

  double _defaultPriceFromRates() {
    for (final r in AppState.instance.rates) {
      if (r.dressType == _selectedDressType) return r.basePrice;
    }
    return 350;
  }

  double get _approvedCatalogueDesignCharge {
    final template = _selectedTemplate;
    if (template?.catalogueVersionId == null ||
        template?.catalogueCommercialType == 'free') {
      return 0;
    }
    return template?.priceInr ?? 0;
  }

  double get _orderTotalFromRates =>
      _defaultPriceFromRates() + _approvedCatalogueDesignCharge;

  Future<bool> _confirmOrderOutsideBusinessHours() async {
    var startHour = 9;
    var endHour = 21;
    var timeZone = 'Asia/Kolkata';
    try {
      final snapshot = await _db
          .collection('config')
          .doc('order_assignment')
          .get();
      final config = snapshot.data() ?? const <String, dynamic>{};
      timeZone = config['dispatchTimeZone']?.toString() ?? timeZone;
      final configuredStart = config['dispatchStartHour'];
      final configuredEnd = config['dispatchEndHour'];
      if (configuredStart is num) {
        startHour = configuredStart.toInt().clamp(0, 23).toInt();
      }
      if (configuredEnd is num) {
        endHour = configuredEnd.toInt().clamp(1, 24).toInt();
      }
    } catch (_) {
      // Keep order placement available if the optional hours read fails.
    }

    final localNow = DateTime.now();
    final businessNow = timeZone == 'Asia/Kolkata'
        ? DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30))
        : localNow;
    final now = TimeOfDay(hour: businessNow.hour, minute: businessNow.minute);
    final minuteOfDay = now.hour * 60 + now.minute;
    if (minuteOfDay >= startHour * 60 && minuteOfDay < endHour * 60) {
      return true;
    }
    if (!mounted) return false;

    final openingTime = TimeOfDay(hour: startHour, minute: 0).format(context);
    final closingTime = endHour == 24
        ? '12:00 AM'
        : TimeOfDay(hour: endHour, minute: 0).format(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Outside customer ordering hours'),
            content: Text(
              'The customer ordering window is $openingTime–$closingTime. '
              'You can still place this order now. A PIN-matched Tailor can '
              'review it when available, and the customer decision deadline '
              'will not expire while ordering is closed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _placeOrderInApp() async {
    final addr = _deliveryAddressController.text.trim();

    if (_selectedDeliveryAddressId == null || addr.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a saved delivery address before placing the order.',
          ),
        ),
      );
      return;
    }

    if (!await _confirmOrderOutsideBusinessHours() || !mounted) return;

    setState(() => _placeOrderLoading = true);
    await AppState.instance.setProfileDeliveryAddress(addr);
    final measurements = _measurementsInCmForOrders();
    final selectedPerson = _selectedOrderPerson();
    var deliveryPincode = '';
    String? deliveryCityCode;
    String? deliveryCityName;
    String? deliveryStateCode;
    String? deliveryStateName;
    for (final savedAddress in _deliveryAddresses) {
      if (savedAddress.addressId == _selectedDeliveryAddressId) {
        deliveryPincode = savedAddress.pincode.trim();
        deliveryCityCode = savedAddress.cityCode;
        deliveryCityName = savedAddress.city;
        deliveryStateCode = savedAddress.stateCode;
        deliveryStateName = savedAddress.state;
        break;
      }
    }

    if (_isIncompleteSelfProfile(selectedPerson)) {
      setState(() => _placeOrderLoading = false);
      await _showCompleteProfilePrompt();
      return;
    }

    final requestedOrderId = _db.collection('orders').doc().id;
    Map<String, dynamic>? customerFabricAssets =
        _matchingSavedWishlistFabricSelection?.customerFabricAssets;
    var orderFabricAssetsWereUploaded = false;
    String? id;
    try {
      if (_pendingCustomerFabricSelection != null) {
        customerFabricAssets = await CustomerFabricAssetService.uploadSelection(
          customerUid: FirebaseAuth.instance.currentUser!.uid,
          scopeType: 'orders',
          scopeId: requestedOrderId,
          selection: _pendingCustomerFabricSelection!,
        );
        orderFabricAssetsWereUploaded = true;
      } else if (customerFabricAssets != null) {
        customerFabricAssets = await CustomerFabricAssetService
            .copySavedSelectionToOrder(
              customerUid: FirebaseAuth.instance.currentUser!.uid,
              orderId: requestedOrderId,
              savedAssets: customerFabricAssets,
            );
        orderFabricAssetsWereUploaded = true;
      }
      id = await OrderService.createCoreTailoringOrder(
        orderId: requestedOrderId,
        dressType: _selectedDressType,
        price: _orderTotalFromRates,
        stitchingBaseCharge: _defaultPriceFromRates(),
        fit: _selectedFit,
        measurements: measurements,
        notes: _composeDetailNotes(),
        clientName: _clientNameController.text.trim(),
        personId: selectedPerson?.id,
        personName: selectedPerson?.name,
        relationship: selectedPerson?.relationship,
        occasionCategory: _occasionId,
        kidsFlow: widget.isKidsFlow,
        designTemplateId: _selectedTemplate?.id,
        designTemplateTitle: _selectedTemplate?.title,
        designImageUrl: _selectedTemplate?.imageUrl,
        catalogueVersionId: _selectedTemplate?.catalogueVersionId,
        catalogueCommercialType: _selectedTemplate?.catalogueCommercialType,
        approvedDesignCharge: _selectedTemplate?.catalogueVersionId == null
            ? null
            : _approvedCatalogueDesignCharge,
        fabricPurchaseEstimate: _fabricEstimate?.toMap(),
        customerFabricAssets: customerFabricAssets,
        designSource: _selectedTemplate == null
            ? 'manual_design_details'
            : _selectedTemplate!.catalogueVersionId == null
            ? 'design_template'
            : 'catalogue_design',
        fabricChoice:
            _fabricChoice == 'Other' &&
                _customFabricController.text.trim().isNotEmpty
            ? _customFabricController.text.trim()
            : _fabricChoice,
        accentColorHex: _colorHexRgb(_accentColor),
        deliveryAddress: addr,
        deliveryPincode: deliveryPincode,
        deliveryCityCode: deliveryCityCode,
        deliveryCityName: deliveryCityName,
        deliveryStateCode: deliveryStateCode,
        deliveryStateName: deliveryStateName,
        fabricDescription: (_fabricChoice != null || _selectedTemplate != null)
            ? [
                ?_fabricChoice,
                if (_selectedTemplate != null)
                  'Design: ${_selectedTemplate!.title}',
                'Accent: ${_colorHexRgb(_accentColor)}',
              ].join(' · ')
            : null,
      );
    } catch (error) {
      if (orderFabricAssetsWereUploaded) {
        await CustomerFabricAssetService.deleteAssets(customerFabricAssets);
      }
      if (!mounted) return;
      setState(() => _placeOrderLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place the order: $error')),
      );
      return;
    }
    if (id == null) {
      if (orderFabricAssetsWereUploaded) {
        await CustomerFabricAssetService.deleteAssets(customerFabricAssets);
      }
    } else {
      _pendingCustomerFabricSelection = null;
    }
    if (!mounted) return;
    setState(() => _placeOrderLoading = false);

    if (id != null) {
      final measurementDraftId = widget.initialMeasurementDraftId?.trim();

      if (measurementDraftId != null && measurementDraftId.isNotEmpty) {
        unawaited(
          _db.collection('measurements').doc(measurementDraftId).set({
            'status': 'order_created',
            'linkedOrderId': id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      }

      if (_currentOrderDraftId != null &&
          _currentOrderDraftId!.trim().isNotEmpty) {
        unawaited(
          _db.collection('order_drafts').doc(_currentOrderDraftId!.trim()).set({
            'status': 'converted_to_order',
            'linkedOrderId': id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      }

      unawaited(
        AppState.instance.saveDressDesignerMeasurements(
          _allMeasurementsCmForStorage(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request sent — we will let you know when a Tailor accepts.',
          ),
        ),
      );
      context.push('/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to place an order')),
      );
    }
  }

  Widget _buildDeliveryAddressSection() {
    if (_loadingDeliveryAddresses) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery address', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }

    if (_deliveryAddressError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery address', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            _deliveryAddressError!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Manage Addresses',
            icon: Icons.location_on_outlined,
            onTap: () async {
              await context.push<void>('/customer-addresses');
              if (!mounted) return;
              _loadDeliveryAddresses();
            },
          ),
        ],
      );
    }

    if (_deliveryAddresses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery address', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Add a saved Home or Other address before placing an order.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Add Address',
            icon: Icons.add_location_alt_outlined,
            onTap: () async {
              await context.push<void>('/customer-addresses');
              if (!mounted) return;
              _loadDeliveryAddresses();
            },
          ),
        ],
      );
    }

    final selectedId =
        _selectedDeliveryAddressId ?? _deliveryAddresses.first.addressId;

    final selectedAddress = _deliveryAddresses.firstWhere(
      (address) => address.addressId == selectedId,
      orElse: () => _deliveryAddresses.first,
    );

    final displayedAddressText =
        _usingResumeDraftDeliveryAddressSnapshot &&
            _resumeDraftDeliveryAddressSnapshot?.trim().isNotEmpty == true
        ? _resumeDraftDeliveryAddressSnapshot!.trim()
        : selectedAddress.formattedAddress;

    final displayedAddressLabel = _usingResumeDraftDeliveryAddressSnapshot
        ? 'Draft saved address'
        : selectedAddress.dropdownLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery address', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Select where the completed order should be delivered.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedAddress.addressId,
          decoration: const InputDecoration(
            labelText: 'Saved address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: _deliveryAddresses
              .map(
                (address) => DropdownMenuItem<String>(
                  value: address.addressId,
                  child: Text(
                    address.dropdownLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;

            final selected = _deliveryAddresses.firstWhere(
              (address) => address.addressId == value,
              orElse: () => _deliveryAddresses.first,
            );

            setState(() {
              _selectedDeliveryAddressId = selected.addressId;
              _deliveryAddressController.text = selected.formattedAddress;
              _resumeDraftDeliveryAddressSnapshot = null;
              _usingResumeDraftDeliveryAddressSnapshot = false;
            });
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayedAddressLabel,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                displayedAddressText,
                style: AppTextStyles.bodySmall.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await context.push<void>('/customer-addresses');
              if (!mounted) return;
              _loadDeliveryAddresses();
            },
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('Manage Addresses'),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancePaymentSection() {
    final sewingPrice = _defaultPriceFromRates();
    final designPrice = _approvedCatalogueDesignCharge;
    final price = sewingPrice + designPrice;
    final adv = price * _advancePercent / 100.0;
    final bal = (price - adv).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advance payment', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'After a Tailor accepts your request, you can choose whether to proceed. If you proceed, the 50% advance is paid online; the balance is due later per shop policy.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 10),
        Text(
          '${designPrice > 0 ? 'Stitching ₹${sewingPrice.toStringAsFixed(0)} + approved design ₹${designPrice.toStringAsFixed(0)} · ' : ''}'
          'Order ₹${price.toStringAsFixed(0)} · 50% advance on acceptance ₹${adv.toStringAsFixed(0)} · '
          'Balance ₹${bal.toStringAsFixed(0)}',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _showOrderForm ? 'Custom Tailoring Order' : 'Smart Style Ideas',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            if (widget.startInBrowseMode && _showOrderForm) {
              setState(() => _showOrderForm = false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _showOrderForm
          ? _buildOrderFormBody(context)
          : _buildBrowseFirstBody(context),
    );
  }

  Widget _buildBrowseFirstBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Style Idea', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Explore approved designs, try your fabric and save favourites. '
            'Browsing is free; any paid design charge is applied only when you create an order.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          _buildOccasionSection(),
          const SizedBox(height: 20),
          _buildDressTypeSelector(),
          const SizedBox(height: 20),
          _buildFitSelector(),
          const SizedBox(height: 20),
          _buildDesignLookSection(approvedCatalogueOnly: true),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create Tailoring Order',
            icon: Icons.shopping_bag_outlined,
            onTap: _openOrderForm,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFormBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        40 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientNameField(),
          const SizedBox(height: 16),
          _buildOccasionSection(),
          const SizedBox(height: 24),
          _buildDressTypeSelector(),
          const SizedBox(height: 24),

          const SizedBox(height: 24),
          _buildFitSelector(),
          const SizedBox(height: 24),
          _buildDesignLookSection(),
          const SizedBox(height: 24),
          //SUD
          if (widget.initialMeasurementDraftId?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Draft: ${widget.initialMeasurementDraftId}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Measurements',
                          style: AppTextStyles.headlineMedium,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Saved body measurements for this profile. Use Suggest for dress-specific measurements.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const MeasurementUnitToggle(),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) => _buildMeasurementSummary(),
          ),
          const SizedBox(height: 24),
          _buildCustomizationSection(),
          const SizedBox(height: 24),
          _buildNotesSection(),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) => _buildMeasurementActionsAndResults(),
          ),
          const SizedBox(height: 24),
          _buildSmartAssistSection(),
          const SizedBox(height: 24),
          _buildAiPricing(),
          const SizedBox(height: 24),
          _buildDeliveryAddressSection(),
          const SizedBox(height: 24),
          _buildAdvancePaymentSection(),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _placeOrderLoading ? 'Placing order…' : 'Place order in app',
            icon: Icons.shopping_bag_outlined,
            onTap: _placeOrderLoading ? () {} : _placeOrderInApp,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: _saveDraftLoading ? 'Saving draft…' : 'Save as Draft',
            icon: Icons.bookmark_border_rounded,
            onTap: _saveDraftLoading
                ? () {}
                : () {
                    unawaited(_saveOrderDraft());
                  },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOccasionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Occasion / category', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        if (widget.initialOccasionId != null && _occasionLabel() != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.label_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.isKidsFlow ? 'Kids' : 'Ladies'} · ${_occasionLabel()}',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: _occasionId ?? OccasionCategory.dailyWear.name,
          decoration: const InputDecoration(
            labelText: 'Occasion',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: OccasionCategory.values
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.name,
                  child: Text(o.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _occasionId = value;
              _selectedTemplate = null;
              _garmentMeasurementEstimate = null;
              _fabricEstimate = null;
              _priceEstimate = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCustomizationSection() {
    void clearGeneratedEstimates() {
      _garmentMeasurementEstimate = null;
      _fabricEstimate = null;
      _priceEstimate = null;
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Dress Customization', style: AppTextStyles.headlineMedium),
      subtitle: Text(
        'Select neck, sleeve, back design, margin and lining preferences.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
      ),
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('neck-style-${_selectedNeckStyle ?? 'unset'}'),
          initialValue: _selectedNeckStyle,
          decoration: const InputDecoration(
            labelText: 'Neck Style',
            hintText: 'Select neck style',
            prefixIcon: Icon(Icons.checkroom_outlined),
          ),
          items: _neckStyleOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedNeckStyle = value;

              if (value == 'Other') {
                _neckController.clear();
              } else {
                _neckController.text = value ?? '';
              }

              clearGeneratedEstimates();
            });
          },
        ),
        if (_selectedNeckStyle == 'Other') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _neckController,
            decoration: const InputDecoration(
              labelText: 'Other neck details',
              hintText: 'e.g. custom neckline and front/back depth',
            ),
            onChanged: (_) {
              setState(clearGeneratedEstimates);
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('sleeve-style-${_selectedSleeveStyle ?? 'unset'}'),
          initialValue: _selectedSleeveStyle,
          decoration: const InputDecoration(
            labelText: 'Sleeve Style',
            hintText: 'Select sleeve style',
            prefixIcon: Icon(Icons.dry_cleaning_outlined),
          ),
          items: _sleeveStyleOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedSleeveStyle = value;

              if (value == 'Other') {
                _sleeveStyleController.clear();
              } else {
                _sleeveStyleController.text = value ?? '';
              }

              clearGeneratedEstimates();
            });
          },
        ),
        if (_selectedSleeveStyle == 'Other') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _sleeveStyleController,
            decoration: const InputDecoration(
              labelText: 'Other sleeve details',
              hintText: 'e.g. layered sleeve with lace border',
            ),
            onChanged: (_) {
              setState(clearGeneratedEstimates);
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('back-design-${_selectedBackDesign ?? 'unset'}'),
          initialValue: _selectedBackDesign,
          decoration: const InputDecoration(
            labelText: 'Back Design',
            hintText: 'Select back design',
            prefixIcon: Icon(Icons.view_agenda_outlined),
          ),
          items: _backDesignOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedBackDesign = value;

              if (value == 'Other') {
                _backDesignController.clear();
              } else {
                _backDesignController.text = value ?? '';
              }

              clearGeneratedEstimates();
            });
          },
        ),
        if (_selectedBackDesign == 'Other') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _backDesignController,
            decoration: const InputDecoration(
              labelText: 'Other back design details',
              hintText: 'e.g. custom deep back with dori',
            ),
            onChanged: (_) {
              setState(clearGeneratedEstimates);
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('alteration-margin-${_selectedAlterationMargin ?? 'unset'}'),
          initialValue: _selectedAlterationMargin,
          decoration: const InputDecoration(
            labelText: 'Alteration Margin',
            hintText: 'Select alteration margin',
            prefixIcon: Icon(Icons.straighten_outlined),
          ),
          items: _alterationMarginOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAlterationMargin = value;
              _marginController.text = value ?? '';
              clearGeneratedEstimates();
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('lining-${_selectedLiningPreference ?? 'unset'}'),
          initialValue: _selectedLiningPreference,
          decoration: const InputDecoration(
            labelText: 'Lining / Astar',
            hintText: 'Select lining preference',
            prefixIcon: Icon(Icons.layers_outlined),
          ),
          items: _liningPreferenceOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedLiningPreference = value;
              clearGeneratedEstimates();
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Special or uncommon requests can be added in Special Instructions below.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildClientNameField() {
    if (_loadingOrderPeople) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order For', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }

    if (_orderPeople.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order For', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _clientNameController,
            readOnly: true,
            decoration: const InputDecoration(
              hintText: 'Customer',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      );
    }

    final selectedId = _selectedOrderPersonId ?? _orderPeople.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order For', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedId),
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: 'Select profile',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: _orderPeople
              .map(
                (person) => DropdownMenuItem<String>(
                  value: person.id,
                  child: Text(
                    '${person.name} (${person.relationship})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;

            final selectedPerson = _orderPeople.firstWhere(
              (person) => person.id == value,
              orElse: () => _orderPeople.first,
            );

            setState(() {
              _selectedOrderPersonId = selectedPerson.id;
              _clientNameController.text = selectedPerson.name;
              _customerMeasurementReference = null;
              _garmentMeasurementEstimate = null;
              _fabricEstimate = null;
              _priceEstimate = null;
            });
            unawaited(_loadLatestMeasurementsForSelectedPerson());
          },
        ),
        const SizedBox(height: 6),
        Text(
          'This profile will be used for measurements and order history.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildDressTypeSelector() {
    final dressTypes = _dressTypes.contains(_selectedDressType)
        ? _dressTypes
        : [..._dressTypes, _selectedDressType];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dress Type', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedDressType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
          ),
          items: dressTypes
              .map(
                (dressType) => DropdownMenuItem<String>(
                  value: dressType,
                  child: Text(dressType),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedDressType = value;
              _garmentMeasurementEstimate = null;
              _fabricEstimate = null;
              _priceEstimate = null;
              _selectedTemplate = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fit Preference', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: _fitOptions.map((fit) {
            final selected = _selectedFit == fit;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: fit != _fitOptions.last ? 10 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedFit = fit;
                    _garmentMeasurementEstimate = null;
                    _fabricEstimate = null;
                    _priceEstimate = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      fit,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Metadata-based hints for recommended fabrics based on the selected dress type.
  Widget _buildRecommendedFabricHint() {
    final metadata = DesignMetadataService.defaultForDressType(
      _selectedDressType,
    );
    final fabrics = metadata.recommendedFabrics;

    if (fabrics.isEmpty) {
      return const SizedBox.shrink();
    }

    final liningText = metadata.liningRequired
        ? 'Lining recommended'
        : 'Lining usually not required';

    final complexityText = switch (metadata.complexity) {
      DesignComplexity.low => 'Low complexity',
      DesignComplexity.medium => 'Medium complexity',
      DesignComplexity.high => 'High complexity',
    };

    final silhouetteText = _designSilhouetteLabel(metadata.silhouette);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended for $_selectedDressType: ${fabrics.join(', ')}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Design details: $silhouetteText · $complexityText · $liningText',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabricMetadataHint() {
    final fabric = _fabricChoice;

    if (fabric == null || fabric.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final fabricForMetadata =
        fabric == 'Other' && _customFabricController.text.trim().isNotEmpty
        ? _customFabricController.text.trim()
        : fabric;

    final metadata = FabricMetadataService.forFabric(fabricForMetadata);

    final liningText = metadata.liningRecommended
        ? 'Lining / astar recommended'
        : 'Lining usually not required';

    final preWashText = metadata.preWashRecommended
        ? 'Pre-wash recommended'
        : 'Pre-wash usually not required';

    final shrinkageText = switch (metadata.shrinkageRisk) {
      ShrinkageRisk.none => 'No shrinkage risk',
      ShrinkageRisk.low => 'Low shrinkage risk',
      ShrinkageRisk.medium => 'Medium shrinkage risk',
      ShrinkageRisk.high => 'High shrinkage risk',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fabric guidance: $shrinkageText · $liningText · $preWashText',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => context.push('/fabric-help'),
            icon: const Icon(Icons.video_call_outlined, size: 18),
            label: const Text('Ask a Tailor about fabric'),
          ),

          if (_fabricChoice == 'Other') ...[
            const SizedBox(height: 4),
            Text(
              'Custom fabric entered. Tailor review is recommended before cutting.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _designSilhouetteLabel(DesignSilhouette silhouette) {
    switch (silhouette) {
      case DesignSilhouette.straight:
        return 'Straight silhouette';
      case DesignSilhouette.aLine:
        return 'A-line silhouette';
      case DesignSilhouette.anarkali:
        return 'Anarkali silhouette';
      case DesignSilhouette.fitAndFlare:
        return 'Fit & flare silhouette';
      case DesignSilhouette.gathered:
        return 'Gathered silhouette';
      case DesignSilhouette.layered:
        return 'Layered silhouette';
      case DesignSilhouette.umbrella:
        return 'Umbrella silhouette';
      case DesignSilhouette.princessCut:
        return 'Princess cut';
      case DesignSilhouette.other:
        return 'Custom silhouette';
    }
  }

  List<DesignTemplate> _filteredDesignTemplates(
    List<DesignTemplate> templates,
  ) {
    return templates
        .where((template) => template.isActive)
        .where((template) => template.matchesDressType(_selectedDressType))
        .where((template) => template.matchesOccasion(_occasionId))
        .toList();
  }

  void _selectDesignTemplate(DesignTemplate template) {
    setState(() {
      if (_selectedTemplate?.id != template.id ||
          _selectedTemplate?.catalogueVersionId !=
              template.catalogueVersionId) {
        _pendingCustomerFabricSelection = null;
        _selectedWishlistFabricSelection = null;
      }
      _selectedTemplate = template;

      // Design changes invalidate all previously generated estimates.
      _garmentMeasurementEstimate = null;
      _fabricEstimate = null;
      _priceEstimate = null;
    });
  }

  _SavedWishlistFabricSelection? get _matchingSavedWishlistFabricSelection {
    final template = _selectedTemplate;
    final selection = _selectedWishlistFabricSelection;
    if (template == null || selection == null) return null;
    if (selection.designId != template.id ||
        selection.catalogueVersionId != template.catalogueVersionId) {
      return null;
    }
    return selection;
  }

  Widget _previewImageError() => ColoredBox(
    color: AppColors.surfaceVariant,
    child: Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 48,
        color: AppColors.textHint,
      ),
    ),
  );

  Widget _buildDesignLookSection({bool approvedCatalogueOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          approvedCatalogueOnly ? 'Choose a Design' : 'Design Catalog',
          style: AppTextStyles.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          approvedCatalogueOnly
              ? 'Browse published free and paid designs. Preview the views, try your fabric and save favourites. No charge is collected while you explore.'
              : 'Browse free and paid designs, preview the front and back, and try a fabric photo. You can save a favourite or create a stitching order when you are ready.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 14),
        const SizedBox(height: 16),
        _buildLookPreviewCard(),
        if (!approvedCatalogueOnly) ...[
          const SizedBox(height: 16),
          Text('Fabric Type', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _fabricOptions.contains(_fabricChoice)
                ? _fabricChoice
                : null,
            decoration: InputDecoration(
              hintText: 'Select fabric type',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
            ),
            items: _fabricOptions
                .map(
                  (fabric) => DropdownMenuItem<String>(
                    value: fabric,
                    child: Text(fabric),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _fabricChoice = value;
                _pendingCustomerFabricSelection = null;
                _garmentMeasurementEstimate = null;
                _fabricEstimate = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildRecommendedFabricHint(),
          _buildFabricMetadataHint(),
          const SizedBox(height: 20),
          if (_fabricChoice == 'Other') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _customFabricController,
              decoration: const InputDecoration(
                labelText: 'Fabric details',
                hintText: 'e.g. Khadi cotton, Banarasi silk, stretch lycra',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ],
    );
  }

  DesignTemplate _customerDesignAsTemplate(CustomerDesign design) {
    return DesignTemplate(
      id: design.id,
      title: design.title,
      imageUrl: design.imageUrl,
      catalogType: DesignCatalogType.customerUpload,
      dressType: design.dressType,
      occasionIds: design.occasionId?.trim().isNotEmpty == true
          ? [design.occasionId!.trim()]
          : const [],
      priceInr: null,
      createdBy: null,
      ownerProfileId: design.profileId,
      isActive: design.isActive,
    );
  }

  Future<void> _uploadOwnDesign() async {
    final messenger = ScaffoldMessenger.of(context);

    final ownerContext = await _resolveSelectedCustomerDesignOwner();

    if (!mounted) {
      return;
    }

    if (ownerContext == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not resolve the selected profile. '
            'Please select who this order is for and try again.',
          ),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final notesController = TextEditingController();

    try {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Upload Own Design'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploading privately for '
                    '${ownerContext.profileName}.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dress Type: $_selectedDressType\n'
                    'Occasion: ${_occasionLabel() ?? 'General'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Design title',
                      hintText: 'e.g. Boutique Anarkali Reference',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes for tailor (optional)',
                      hintText:
                          'Mention important elements to follow from the reference.',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The uploaded design will remain private '
                    'to the selected profile.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Choose Image'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true || !mounted) {
        return;
      }

      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext, ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (source == null || !mounted) {
        return;
      }

      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );

      if (file == null || !mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Uploading design for '
            '${ownerContext.profileName}...',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      try {
        final uploadedDesign = await CustomerDesignService.uploadDesign(
          accountId: ownerContext.accountId,
          profileId: ownerContext.profileId,
          title: titleController.text,
          dressType: _selectedDressType,
          occasionId: _occasionId,
          notes: notesController.text,
          file: file,
        );

        if (!mounted) {
          return;
        }

        if (uploadedDesign == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Could not upload the design. '
                'Please check sign-in and Firebase rules.',
              ),
            ),
          );
          return;
        }

        final uploadedTemplate = _customerDesignAsTemplate(uploadedDesign);

        _selectDesignTemplate(uploadedTemplate);

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Design uploaded privately for '
              '${ownerContext.profileName} and selected.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        messenger.showSnackBar(
          SnackBar(content: Text('Could not upload the design: $error')),
        );
      }
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showDesignPickerSheet() async {
    var selectedCatalogFilter = 'all';
    final browseOnly = widget.startInBrowseMode && !_showOrderForm;

    final shouldUploadOwnDesign = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;

            return SafeArea(
              child: SizedBox(
                height: sheetHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        selectedCatalogFilter == 'wishlist'
                            ? 'Select from My Wishlist'
                            : 'Select $_selectedDressType Design',
                        style: AppTextStyles.headlineMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        selectedCatalogFilter == 'wishlist'
                            ? 'Your saved designs across all garment types.'
                            : 'Showing ${_occasionLabel() ?? 'matching'} '
                                  '$_selectedDressType designs from the '
                                  'SuiSakhi catalog.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: selectedCatalogFilter == 'all',
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCatalogFilter = 'all';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Free'),
                            selected: selectedCatalogFilter == 'free',
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCatalogFilter = 'free';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Premium'),
                            selected: selectedCatalogFilter == 'premium',
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCatalogFilter = 'premium';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('My Wishlist'),
                            selected: selectedCatalogFilter == 'wishlist',
                            onSelected: (_) {
                              setSheetState(() {
                                selectedCatalogFilter = 'wishlist';
                              });
                            },
                          ),
                          if (!browseOnly)
                            ChoiceChip(
                              label: const Text('My Uploads'),
                              selected: selectedCatalogFilter == 'uploads',
                              onSelected: (_) {
                                setSheetState(() {
                                  selectedCatalogFilter = 'uploads';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (!browseOnly)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext, true);
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload Own Design'),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: selectedCatalogFilter == 'wishlist'
                          ? _buildWishlistDesigns(sheetContext)
                          : [
                              'all',
                              'free',
                              'premium',
                            ].contains(selectedCatalogFilter)
                          ? _buildApprovedDesigns(
                              sheetContext,
                              selectedCatalogFilter,
                            )
                          : StreamBuilder<List<DesignTemplate>>(
                              stream: DesignTemplateService.watchTemplates(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        'Could not load designs. '
                                        'Check your connection.',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textHint,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final matchingTemplates =
                                    _filteredDesignTemplates(snapshot.data!);

                                final templates = matchingTemplates.where((
                                  template,
                                ) {
                                  switch (selectedCatalogFilter) {
                                    case 'uploads':
                                      return false;

                                    case 'free':
                                      return template.isFree;

                                    case 'premium':
                                      return template.isPremium;

                                    case 'all':
                                    default:
                                      return true;
                                  }
                                }).toList();

                                if (templates.isEmpty) {
                                  final filterLabel =
                                      selectedCatalogFilter == 'uploads'
                                      ? 'uploaded'
                                      : selectedCatalogFilter == 'premium'
                                      ? 'premium'
                                      : selectedCatalogFilter == 'free'
                                      ? 'free'
                                      : 'matching';

                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        selectedCatalogFilter == 'uploads'
                                            ? 'No uploaded designs found for this profile yet.\n\n'
                                                  'Use "Upload Own Design" to add your personal design references.'
                                            : 'No $filterLabel '
                                                  '${_occasionLabel() ?? ''} '
                                                  '$_selectedDressType designs '
                                                  'are available yet.\n\n'
                                                  'Try another catalog filter, occasion or dress type. '
                                                  'You can still continue without selecting a catalog design.',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textHint,
                                              height: 1.4,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  itemCount: templates.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final template = templates[index];

                                    final isSelected =
                                        _selectedTemplate?.id == template.id;

                                    return Material(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          _selectDesignTemplate(template);
                                          Navigator.pop(sheetContext);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: SizedBox(
                                                  width: 76,
                                                  height: 76,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      template.imageUrl.isEmpty
                                                          ? ColoredBox(
                                                              color: AppColors
                                                                  .surfaceVariant,
                                                              child: Icon(
                                                                Icons
                                                                    .image_not_supported_outlined,
                                                                color: AppColors
                                                                    .textHint,
                                                              ),
                                                            )
                                                          : Image.network(
                                                              template.imageUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, _, _) => ColoredBox(
                                                                color: AppColors
                                                                    .surfaceVariant,
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image_outlined,
                                                                  color: AppColors
                                                                      .textHint,
                                                                ),
                                                              ),
                                                            ),
                                                      Positioned(
                                                        top: 4,
                                                        left: 4,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 3,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                template
                                                                    .isPremium
                                                                ? AppColors
                                                                      .accent
                                                                : AppColors
                                                                      .primary,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            template.isPremium
                                                                ? 'PREMIUM'
                                                                : 'FREE',
                                                            style: AppTextStyles
                                                                .labelMedium
                                                                .copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 8,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      template.title,
                                                      style: AppTextStyles
                                                          .titleMedium,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      template.dressType
                                                                  ?.trim()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? template.dressType!
                                                          : _selectedDressType,
                                                      style: AppTextStyles
                                                          .bodySmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textHint,
                                                          ),
                                                    ),
                                                    if (template.isPremium) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        template.priceInr !=
                                                                null
                                                            ? '₹${template.priceInr!.toStringAsFixed(0)}'
                                                            : 'Price to be confirmed',
                                                        style: AppTextStyles
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppColors
                                                                  .accent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isSelected)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  child: Icon(
                                                    Icons.check_circle_rounded,
                                                    color: AppColors.primary,
                                                    size: 26,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (shouldUploadOwnDesign == true && mounted) {
      await _uploadOwnDesign();
    }
  }

  Widget _buildApprovedDesigns(
    BuildContext sheetContext,
    String selectedCatalogFilter,
  ) {
    return StreamBuilder<List<CatalogueDesign>>(
      stream: CatalogueDesignService.watchPublishedDesigns(
        occasionCode: _occasionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load published catalogue designs.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final designs = snapshot.data!
            .where(_matchesSelectedGarment)
            .where((design) {
              final commercialType = design.commercial.commercialType;
              return switch (selectedCatalogFilter) {
                'free' => commercialType == CatalogueCommercialType.free,
                'premium' => commercialType != CatalogueCommercialType.free,
                _ => true,
              };
            })
            .toList(growable: false);
        if (designs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No free or paid designs are published for $_selectedDressType yet.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: designs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final design = designs[index];
            return FutureBuilder<PublishedCatalogueBundle?>(
              future: CatalogueDesignService.getPublishedBundle(design),
              builder: (context, bundleSnapshot) {
                final bundle = bundleSnapshot.data;
                final view = bundle?.primaryView;
                final imageUrl = view?.bestPreviewUrl ?? '';
                final selected = _selectedTemplate?.id == design.designId;
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(13),
                        ),
                        child: SizedBox(
                          width: 86,
                          height: 116,
                          child: imageUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFFF0EDF8),
                                  child: Icon(Icons.image_outlined),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFF0EDF8),
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                design.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                design.commercial.commercialType ==
                                        CatalogueCommercialType.free
                                    ? 'FREE'
                                    : 'PAID',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (design.commercial.commercialType !=
                                  CatalogueCommercialType.free)
                                Text(
                                  '₹${(design.commercial.approvedDesignCharge ?? 0).toStringAsFixed(0)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                '${bundle?.views.length ?? 0} design view(s)',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                              Wrap(
                                spacing: 2,
                                children: [
                                  TextButton(
                                    onPressed: bundle == null
                                        ? null
                                        : () => _showCatalogueDesignPreview(
                                            design,
                                            bundle,
                                          ),
                                    child: const Text('View'),
                                  ),
                                  TextButton(
                                    onPressed: bundle == null
                                        ? null
                                        : () {
                                            _selectCatalogueDesign(
                                              design,
                                              bundle,
                                            );
                                            Navigator.pop(sheetContext);
                                          },
                                    child: const Text('Select'),
                                  ),
                                  TextButton.icon(
                                    onPressed: bundle == null
                                        ? null
                                        : () async {
                                            try {
                                              await CustomerWishlistService.saveDesign(
                                                designId: design.designId,
                                                catalogueVersionId:
                                                    bundle.version.versionId,
                                                fabricPreviewSelection:
                                                    _pendingCustomerFabricSelection
                                                                ?.designId ==
                                                            design.designId &&
                                                        _pendingCustomerFabricSelection
                                                                ?.catalogueVersionId ==
                                                            bundle
                                                                .version
                                                                .versionId
                                                    ? _pendingCustomerFabricSelection
                                                    : null,
                                              );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Saved to your wishlist.',
                                                  ),
                                                ),
                                              );
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Could not save design: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.favorite_border),
                                    label: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!bundleSnapshot.hasData && !bundleSnapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWishlistDesigns(BuildContext sheetContext) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CustomerWishlistService.watchItems(),
      builder: (context, wishlistSnapshot) {
        if (wishlistSnapshot.hasError) {
          return const Center(child: Text('Could not load your wishlist.'));
        }
        if (!wishlistSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final savedItems = wishlistSnapshot.data!.docs;
        if (savedItems.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your wishlist is empty. Save a design while browsing to find it here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return FutureBuilder<List<_WishlistDesignOption>>(
          future: _loadWishlistDesignOptions(savedItems),
          builder: (context, optionsSnapshot) {
            if (optionsSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Could not load the designs saved in your wishlist.',
                ),
              );
            }
            if (!optionsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final options = optionsSnapshot.data!;
            if (options.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No available designs were found in your wishlist. '
                    'Saved designs remain visible here when their approved '
                    'catalogue versions are available.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                final design = option.design;
                final catalogueImageUrl =
                    option.bundle.primaryView?.bestPreviewUrl ?? '';
                final fabricPreviewUrls = option.fabricSelection?.previews
                    .where((preview) => preview.imageUrl.isNotEmpty)
                    .toList(growable: false) ??
                    const <_WishlistFabricPreview>[];
                final fabricPreviewUrl = fabricPreviewUrls.isEmpty
                    ? null
                    : fabricPreviewUrls.first.imageUrl;
                final imageUrl = fabricPreviewUrl ?? catalogueImageUrl;
                final isFree =
                    design.commercial.commercialType ==
                    CatalogueCommercialType.free;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 76,
                          height: 88,
                          child: imageUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFFF0EDF8),
                                  child: Icon(Icons.image_outlined),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFF0EDF8),
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              design.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFree
                                  ? 'FREE · ${_wishlistGarmentTypeLabel(design)}'
                                  : 'PAID · ${_wishlistGarmentTypeLabel(design)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (!isFree)
                              Text(
                                '₹${(design.commercial.approvedDesignCharge ?? 0).toStringAsFixed(0)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (option.fabricSelection?.previews.isNotEmpty ==
                                true)
                              Text(
                                'Your fabric preview · ${option.fabricSelection!.previews.length} view(s)',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          final selectedType = _dressTypeForWishlistDesign(
                            design,
                          );
                          String? matchingOccasion;
                          for (final code in design.occasionCodes) {
                            if (OccasionCategory.values.any(
                              (occasion) => occasion.name == code,
                            )) {
                              matchingOccasion = code;
                              break;
                            }
                          }
                          setState(() {
                            _selectedDressType = selectedType;
                            if (matchingOccasion != null &&
                                !design.occasionCodes.contains(_occasionId)) {
                              _occasionId = matchingOccasion;
                            }
                            _garmentMeasurementEstimate = null;
                            _fabricEstimate = null;
                            _priceEstimate = null;
                          });
                          _selectCatalogueDesign(
                            design,
                            option.bundle,
                            wishlistSelection: option.fabricSelection,
                          );
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Select'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<_WishlistDesignOption>> _loadWishlistDesignOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> savedItems,
  ) async {
    final results = await Future.wait(
      savedItems.map((savedItem) async {
        final savedData = savedItem.data();
        final designId = savedData['designId']?.toString().trim() ?? '';
        final versionId =
            savedData['catalogueVersionId']?.toString().trim() ?? '';
        if (designId.isEmpty) return null;
        final designDocument = await _db
            .collection('designs')
            .doc(designId)
            .get();
        if (!designDocument.exists) return null;
        final design = CatalogueDesign.fromDoc(designDocument);
        final bundle = await _loadWishlistCatalogueBundle(design, versionId);
        if (bundle == null) return null;
        final fabricSelection = await _loadWishlistFabricSelection(
          savedItem.id,
          savedData,
          designId,
          bundle.version.versionId,
        );
        return _WishlistDesignOption(
          design: design,
          bundle: bundle,
          fabricSelection: fabricSelection,
        );
      }),
    );
    return results.whereType<_WishlistDesignOption>().toList(growable: false);
  }

  Future<PublishedCatalogueBundle?> _loadWishlistCatalogueBundle(
    CatalogueDesign design,
    String savedVersionId,
  ) async {
    if (!design.isPublished) return null;

    final active = await CatalogueDesignService.getPublishedBundle(design);
    if (savedVersionId.isEmpty) return active;
    if (active?.version.versionId == savedVersionId) return active;

    final versionRef = _db
        .collection('designs')
        .doc(design.designId)
        .collection('versions')
        .doc(savedVersionId);
    final versionSnapshot = await versionRef.get();
    if (!versionSnapshot.exists) return null;

    final version = CatalogueDesignVersion.fromMap({
      ...versionSnapshot.data()!,
      'designId': design.designId,
      'versionId': versionSnapshot.id,
    });
    final viewSnapshot = await versionRef
        .collection('views')
        .orderBy('displayOrder')
        .get();
    final views = viewSnapshot.docs
        .where((document) => document.data()['excludedFromVersion'] != true)
        .map((document) => CatalogueDesignView.fromMap(document.data()))
        .toList(growable: false);
    final publishedViews = views.isNotEmpty
        ? views
        : version.legacyView == null
        ? const <CatalogueDesignView>[]
        : <CatalogueDesignView>[version.legacyView!];
    if (publishedViews.isEmpty) return null;
    return PublishedCatalogueBundle(version: version, views: publishedViews);
  }

  Future<_SavedWishlistFabricSelection?> _loadWishlistFabricSelection(
    String itemId,
    Map<String, dynamic> savedData,
    String designId,
    String versionId,
  ) async {
    final rawMetadata = savedData['fabricMetadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : const <String, dynamic>{};
    final rawPreviews = metadata['previews'];
    final previewAssets = rawPreviews is Iterable
        ? rawPreviews
              .whereType<Map>()
              .map((asset) => Map<String, dynamic>.from(asset))
              .toList()
        : <Map<String, dynamic>>[];
    if (previewAssets.isEmpty) {
      final legacyPreviewPath =
          savedData['fabricPreviewStoragePath']?.toString().trim() ?? '';
      if (legacyPreviewPath.isNotEmpty) {
        previewAssets.add({
          'storagePath': legacyPreviewPath,
          'viewType': metadata['viewType']?.toString() ?? 'front',
        });
      }
    }
    final fabricPhotoPath =
        savedData['fabricPhotoStoragePath']?.toString().trim() ?? '';
    if (previewAssets.isEmpty && fabricPhotoPath.isEmpty) return null;

    final views = <_WishlistFabricPreview>[];
    for (final asset in previewAssets) {
      final path = asset['storagePath']?.toString().trim() ?? '';
      if (path.isEmpty) continue;
      String url = '';
      try {
        url = await CustomerFabricAssetService.downloadUrl(path);
      } catch (_) {
        // Keep the secure Storage reference even if this preview cannot load.
      }
      views.add(
        _WishlistFabricPreview(
          storagePath: path,
          imageUrl: url,
          viewType: asset['viewType']?.toString() ?? 'garment',
          contentType: asset['contentType']?.toString(),
          byteSize: asset['byteSize'] is num
              ? (asset['byteSize'] as num).toInt()
              : null,
        ),
      );
    }

    final normalizedPreviews = views
        .map((view) => view.toAssetMap())
        .toList(growable: false);
    final fabricPhoto = fabricPhotoPath.isEmpty
        ? null
        : <String, dynamic>{'storagePath': fabricPhotoPath};
    return _SavedWishlistFabricSelection(
      wishlistItemId: itemId,
      designId: designId,
      catalogueVersionId: versionId,
      previews: views,
      customerFabricAssets: {
        'designId': designId,
        'catalogueVersionId': versionId,
        'wishlistItemId': itemId,
        'source': 'customerWishlist',
        'fabricPhoto': ?fabricPhoto,
        if (normalizedPreviews.isNotEmpty) ...{
          'selectedPreview': normalizedPreviews.first,
          'previews': normalizedPreviews,
        },
      },
    );
  }

  bool _matchesSelectedGarment(CatalogueDesign design) {
    final code = _catalogueCodeForDressType(_selectedDressType);
    if (design.garmentTypeCodes.contains(code)) return true;
    return code == 'blouse' && design.garmentTypeCodes.contains('sareeBlouse');
  }

  String _catalogueCodeForDressType(String dressType) {
    final selected = dressType.trim().toLowerCase();
    return switch (selected) {
      'kurti' => 'kurti',
      'kurta set' => 'kurtaSet',
      'salwar suit' => 'salwarSuit',
      'anarkali suit' => 'anarkali',
      'lehenga choli' => 'lehengaCholi',
      'gown' => 'gown',
      'blouse' => 'blouse',
      'saree blouse' => 'sareeBlouse',
      'top / tunic' => 'topTunic',
      'shirt' => 'shirt',
      'palazzo / pant' => 'palazzoPant',
      'skirt' => 'skirt',
      'dress / one piece' => 'dress',
      'other' => 'other',
      _ => selected,
    };
  }

  String _dressTypeForWishlistDesign(CatalogueDesign design) {
    const labelsByCode = <String, String>{
      'kurti': 'Kurti',
      'kurtaSet': 'Kurta Set',
      'salwarSuit': 'Salwar Suit',
      'anarkali': 'Anarkali Suit',
      'lehengaCholi': 'Lehenga Choli',
      'gown': 'Gown',
      'blouse': 'Blouse',
      'sareeBlouse': 'Saree Blouse',
      'topTunic': 'Top / Tunic',
      'shirt': 'Shirt',
      'palazzoPant': 'Palazzo / Pant',
      'skirt': 'Skirt',
      'dress': 'Dress / One Piece',
      'coat': 'Coat',
      'other': 'Other',
    };
    String? fallbackLabel;
    for (final code in design.garmentTypeCodes) {
      final label = labelsByCode[code];
      if (label == 'Other') {
        fallbackLabel = label;
      } else if (label != null) {
        return label;
      }
    }
    if (fallbackLabel != null) return fallbackLabel;
    return design.garmentTypeCodes.isEmpty
        ? 'Other'
        : _humanizeCatalogueCode(design.garmentTypeCodes.first);
  }

  String _wishlistGarmentTypeLabel(CatalogueDesign design) =>
      _dressTypeForWishlistDesign(design);

  String _humanizeCatalogueCode(String code) {
    final words = code.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return words
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  void _selectCatalogueDesign(
    CatalogueDesign design,
  PublishedCatalogueBundle bundle, {
    _SavedWishlistFabricSelection? wishlistSelection,
  }) {
    final primary = bundle.primaryView;
    if (primary == null || primary.bestPreviewUrl?.trim().isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This approved design has no preview image.'),
        ),
      );
      return;
    }
    final isFree =
        design.commercial.commercialType == CatalogueCommercialType.free;
    _selectDesignTemplate(
      DesignTemplate(
        id: design.designId,
        title: design.title,
        imageUrl: primary.bestPreviewUrl!,
        catalogType: isFree
            ? DesignCatalogType.free
            : DesignCatalogType.premium,
        dressType: _selectedDressType,
        occasionIds: design.occasionCodes,
        priceInr: design.commercial.approvedDesignCharge,
        createdBy: design.submittedByUid,
        ownerProfileId: design.ownerProfileId,
        catalogueVersionId: bundle.version.versionId,
        catalogueCommercialType: design.commercial.commercialType.name,
        constructionMetadata: design.constructionMetadata,
      ),
    );
    setState(() {
      _selectedWishlistFabricSelection = wishlistSelection;
      if (wishlistSelection != null) {
        _pendingCustomerFabricSelection = null;
      }
    });
  }

  Future<void> _saveSelectedDesignToWishlist() async {
    final template = _selectedTemplate;
    final versionId = template?.catalogueVersionId?.trim() ?? '';
    if (template == null || versionId.isEmpty) return;
    try {
      await CustomerWishlistService.saveDesign(
        designId: template.id,
        catalogueVersionId: versionId,
        fabricPreviewSelection:
            _pendingCustomerFabricSelection?.designId == template.id &&
                _pendingCustomerFabricSelection?.catalogueVersionId == versionId
            ? _pendingCustomerFabricSelection
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Design saved to your wishlist.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save design: $error')),
        );
      }
    }
  }

  Future<void> _showCatalogueDesignPreview(
    CatalogueDesign design,
    PublishedCatalogueBundle bundle,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(design.title),
        content: SizedBox(
          width: 380,
          height: 420,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  itemCount: bundle.views.length,
                  itemBuilder: (context, index) {
                    final view = bundle.views[index];
                    final url = view.bestPreviewUrl;
                    return Column(
                      children: [
                        Expanded(
                          child: url == null
                              ? const Icon(Icons.image_not_supported_outlined)
                              : Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(view.viewType.label),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bundle.views.any(
                      (view) =>
                          view.viewType == CatalogueDesignViewType.back ||
                          view.viewType ==
                              CatalogueDesignViewType.combinedFrontBack,
                    )
                    ? 'Showing the views approved for this design.'
                    : 'Only the published view is available. A missing back view is not fabricated or shown.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              _selectCatalogueDesign(design, bundle);
              Navigator.pop(dialogContext);
            },
            child: const Text('Select design'),
          ),
        ],
      ),
    );
  }

  Widget _buildLookPreviewCard() {
    final template = _selectedTemplate;
    final fabricSelection = _pendingCustomerFabricSelection;
    final savedFabricSelection = _matchingSavedWishlistFabricSelection;
    final hasMatchingPendingPreview =
        template != null &&
        fabricSelection != null &&
        fabricSelection.designId == template.id &&
        fabricSelection.catalogueVersionId == template.catalogueVersionId;
    final pendingPreviews = hasMatchingPendingPreview
        ? fabricSelection.previews
        : const <CustomerFabricViewPreview>[];
    final savedPreviewViews = savedFabricSelection?.previews
            .where((preview) => preview.imageUrl.isNotEmpty)
            .toList(growable: false) ??
        const <_WishlistFabricPreview>[];
    final previewCount = pendingPreviews.isNotEmpty
        ? pendingPreviews.length
        : savedPreviewViews.length;
    final hasMatchingFabricPreview = previewCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected Design', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            template == null
                ? 'Choose a design from the SuiSakhi catalog before generating an estimate.'
                : 'This original design remains the tailoring reference. '
                      'You can change the design before placing the order.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (template == null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.checkroom_outlined,
                    size: 42,
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No design selected',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse free and premium designs filtered for '
                    '${_occasionLabel() ?? 'your occasion'} and '
                    '$_selectedDressType.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDesignPickerSheet,
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: Text(
                  widget.startInBrowseMode && !_showOrderForm
                      ? 'Browse approved designs'
                      : 'Browse Design Catalog',
                ),
              ),
            ),
          ] else ...[
            if (hasMatchingFabricPreview) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.texture_outlined, size: 16),
                  label: Text(
                    'Your fabric · $previewCount view${previewCount == 1 ? '' : 's'}',
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 0.82,
                child: PageView.builder(
                  itemCount: previewCount + 1,
                  itemBuilder: (context, index) {
                    final isCustomerPreview = index < previewCount;
                    final previewLabel = isCustomerPreview
                        ? pendingPreviews.isNotEmpty
                              ? pendingPreviews[index].viewType
                              : savedPreviewViews[index].viewType
                        : 'Original catalogue design · tailor reference';
                    Widget image;
                    if (isCustomerPreview && pendingPreviews.isNotEmpty) {
                      image = Image.memory(
                        pendingPreviews[index].bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _previewImageError(),
                      );
                    } else if (isCustomerPreview) {
                      image = Image.network(
                        savedPreviewViews[index].imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _previewImageError(),
                      );
                    } else if (template.imageUrl.trim().isEmpty) {
                      image = _previewImageError();
                    } else {
                      image = Image.network(
                        template.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _previewImageError(),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: image),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(previewLabel),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (template.catalogueVersionId?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              CatalogueFabricPreviewButton(
                designId: template.id,
                versionId: template.catalogueVersionId!,
                onSelectionChanged: (selection) => setState(() {
                  _pendingCustomerFabricSelection = selection;
                  _selectedWishlistFabricSelection = null;
                }),
              ),
              if (_pendingCustomerFabricSelection != null &&
                  _pendingCustomerFabricSelection!.designId == template.id) ...[
                const SizedBox(height: 6),
                Text(
                  'This is an AI visual approximation. The tailor receives both this customer reference and the original catalogue construction reference. Fabric photo and preview are stored only when you save the design or start an order.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    height: 1.3,
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: _saveSelectedDesignToWishlist,
                icon: const Icon(Icons.favorite_border_rounded),
                label: const Text('Save design to wishlist'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: template.isPremium
                        ? AppColors.accent
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.catalogueVersionId != null
                        ? 'PAID'
                        : template.isPremium
                        ? 'PREMIUM'
                        : 'FREE',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        template.dressType?.trim().isNotEmpty == true
                            ? template.dressType!
                            : _selectedDressType,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      if (template.isPremium) ...[
                        const SizedBox(height: 3),
                        Text(
                          template.priceInr != null
                              ? 'Design price: '
                                    '₹${template.priceInr!.toStringAsFixed(0)}'
                              : 'Design price to be confirmed',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDesignPickerSheet,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Change Design'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BodyMeasurements? _bodyMeasurementsFromDesignerFields() {
    final latest = _latestBodyMeasurementsForSuggestion;
    if (latest != null) {
      return latest;
    }
    final unit = AppState.instance.measurementUnit;

    double? readCm(String key) {
      final text = _measurementFields[key]?.text.trim();
      if (text == null || text.isEmpty) return null;

      final value = double.tryParse(text);
      if (value == null || value <= 0) return null;

      return unit.toCm(value);
    }

    final chest = readCm('Chest');
    final waist = readCm('Waist');
    final hips = readCm('Hip');
    final shoulder = readCm('Shoulder');
    final armLength = readCm('Sleeve Length');

    final hasAnyValue = [
      chest,
      waist,
      hips,
      shoulder,
      armLength,
    ].any((value) => value != null && value > 0);

    if (!hasAnyValue) return null;

    return BodyMeasurements(
      chest: chest,
      waist: waist,
      hips: hips,
      shoulder: shoulder,
      armLength: armLength,
      capturedAt: DateTime.now(),
    );
  }

  GarmentMeasurementEstimate _estimateGarmentMeasurementsLocally({
    required BodyMeasurements body,
    required DesignMetadata designMetadata,
    required FabricMetadata fabricMetadata,
    required OccasionMetadata occasionMetadata,
  }) {
    return GarmentMeasurementEngine.estimate(
      body: body,
      dressType: _selectedDressType,
      fitPreference: _selectedFit,
      occasionCategory: _occasionLabel(),
      designTitle: _selectedTemplate?.title,
      designMetadata: designMetadata,
      occasionMetadata: occasionMetadata,
      fabricMetadata: fabricMetadata,
    );
  }

  void _suggestGarmentMeasurements() {
    final body = _bodyMeasurementsFromDesignerFields();

    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No saved measurement is available for this profile. Use Take New Measurement to choose AI Camera or another available method before generating the estimate.',
          ),
        ),
      );
      return;
    }

    final designMetadata =
        _selectedTemplate?.constructionMetadata ??
        DesignMetadataService.defaultForDressType(_selectedDressType);

    final fabricForMetadata = _effectiveFabricChoice;

    final fabricMetadata = FabricMetadataService.forFabric(fabricForMetadata);

    final occasionMetadata = OccasionMetadataService.forOccasion(
      occasionId: _occasionId,
      occasionLabel: _occasionLabel() ?? 'General',
    );

    final customizationEstimate = DressCustomizationEstimationService.estimate(
      neckStyle: _selectedNeckStyle,
      sleeveStyle: _selectedSleeveStyle,
      backDesign: _selectedBackDesign,
      alterationMargin: _selectedAlterationMargin,
      liningPreference: _selectedLiningPreference,
    );

    final garmentEstimate = _estimateGarmentMeasurementsLocally(
      body: body,
      designMetadata: designMetadata,
      occasionMetadata: occasionMetadata,
      fabricMetadata: fabricMetadata,
    );

    final fabricEstimate = FabricEstimationService.estimate(
      dressType: _selectedDressType,
      body: body,
      designMetadata: designMetadata,
      occasionMetadata: occasionMetadata,
      fabricMetadata: fabricMetadata,
      customizationEstimate: customizationEstimate,
    );

    final priceEstimate = PriceEstimationService.estimate(
      dressType: _selectedDressType,
      fabricEstimate: fabricEstimate,
      designMetadata: designMetadata,
      occasionMetadata: occasionMetadata,
      fabricMetadata: fabricMetadata,
      customizationAmount: customizationEstimate.additionalStitchingAmount,
    );

    setState(() {
      _garmentMeasurementEstimate = garmentEstimate;
      _fabricEstimate = fabricEstimate;
      _priceEstimate = priceEstimate;
    });
  }

  Widget _buildGarmentSuggestionCard() {
    final estimate = _garmentMeasurementEstimate;
    if (estimate == null) return const SizedBox.shrink();

    final unit = AppState.instance.measurementUnit;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_occasionLabel() ?? 'General'} • ${estimate.dressType} • ${estimate.formulaVersion}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...estimate.valuesCm.entries.map((entry) {
            final displayValue = MeasurementFormat.formatWithUnit(
              entry.value,
              unit,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.key, style: AppTextStyles.bodyMedium),
                  ),
                  Text(
                    displayValue,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (estimate.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Guidance notes',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${estimate.notes.length} tailoring notes available',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                children: estimate.notes
                    .map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '• $note',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementSummary() {
    final unit = AppState.instance.measurementUnit;
    final suffix = unit.abbrev;

    final hasAnyMeasurement = _measurementFields.values.any(
      (controller) => controller.text.trim().isNotEmpty,
    );

    if (!hasAnyMeasurement) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          'No saved measurements found for this profile. '
          'Use Take New Measurement to choose AI Camera or another available method.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            height: 1.35,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _buildMeasurementSummaryRow('Chest', 'Waist', suffix),
          const SizedBox(height: 8),
          _buildMeasurementSummaryRow('Hip', 'Shoulder', suffix),
          const SizedBox(height: 8),
          _buildMeasurementSummaryRow('Length', 'Sleeve Length', suffix),
        ],
      ),
    );
  }

  Widget _buildMeasurementActionsAndResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Generate Dress Estimate', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Generate dress-specific measurements, fabric requirement '
          'and an estimated stitching price using the selections above.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _suggestGarmentMeasurements,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Dress Estimate'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final person = _selectedOrderPerson();

                if (person == null) {
                  context.push('/measurement-context');
                  return;
                }

                context.push(
                  '/measurement-context'
                  '?clientName=${Uri.encodeComponent(person.name)}'
                  '&personId=${Uri.encodeComponent(person.id)}'
                  '&relationship=${Uri.encodeComponent(person.relationship)}',
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Take New Measurement'),
            ),
          ],
        ),
        _buildGarmentSuggestionCard(),
      ],
    );
  }

  Widget _buildMeasurementSummaryRow(
    String leftKey,
    String rightKey,
    String suffix,
  ) {
    String formatValue(String key) {
      final value = _measurementFields[key]?.text.trim() ?? '';

      if (value.isEmpty || value == '0') {
        return '--';
      }

      return '$value $suffix';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '$leftKey: ${formatValue(leftKey)}',
            style: AppTextStyles.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$rightKey: ${formatValue(rightKey)}',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Special Instructions', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _chooseSavedMeasurementReference,
          icon: const Icon(Icons.straighten_outlined),
          label: Text(
            _customerMeasurementReference == null
                ? 'Add saved measurement reference'
                : 'Change saved measurement reference',
          ),
        ),
        if (_customerMeasurementReference != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_customerMeasurementReference!.title} · ${_customerMeasurementReference!.values.length} fields. Added as a customer note for Tailor review.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove reference',
                  onPressed: () => setState(
                    () => _customerMeasurementReference = null,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Add notes for your tailor (e.g., add pockets, embroidery style, dupatta length...)',
          ),
        ),
      ],
    );
  }

  String? get _effectiveFabricChoice {
    if (_fabricChoice == 'Other' &&
        _customFabricController.text.trim().isNotEmpty) {
      return _customFabricController.text.trim();
    }
    return _fabricChoice;
  }

  String _smartAssistContextKey() {
    final measurementText = _measurementFields.entries
        .map((entry) => '${entry.key}:${entry.value.text.trim()}')
        .join(';');
    return [
      _selectedOrderPersonId ?? '',
      _occasionId ?? '',
      _selectedDressType,
      _selectedFit,
      _selectedTemplate?.id ?? '',
      _selectedTemplate?.catalogueVersionId ?? '',
      _effectiveFabricChoice ?? '',
      _selectedNeckStyle ?? '',
      _selectedSleeveStyle ?? '',
      _selectedBackDesign ?? '',
      _selectedAlterationMargin ?? '',
      _selectedLiningPreference ?? '',
      measurementText,
    ].join('|');
  }

  String? _neckStyleFromMetadata(DesignNeckType type) => switch (type) {
    DesignNeckType.round => 'Round Neck',
    DesignNeckType.vNeck => 'V Neck',
    DesignNeckType.boat => 'Boat Neck',
    DesignNeckType.square => 'Square Neck',
    DesignNeckType.keyhole => 'Keyhole Neck',
    DesignNeckType.collar => 'Collar Neck',
    DesignNeckType.other => null,
  };

  String? _sleeveStyleFromMetadata(DesignSleeveType type) => switch (type) {
    DesignSleeveType.sleeveless => 'Sleeveless',
    DesignSleeveType.cap => 'Cap Sleeve',
    DesignSleeveType.half => 'Short Sleeve',
    DesignSleeveType.threeQuarter => 'Three Quarter Sleeve',
    DesignSleeveType.full => 'Full Sleeve',
    DesignSleeveType.puff => 'Puff Sleeve',
    DesignSleeveType.other => null,
  };

  List<_DressFitSuggestion> _buildLocalDressFitSuggestions() {
    final suggestions = <_DressFitSuggestion>[];
    final template = _selectedTemplate;
    final construction = template?.constructionMetadata;
    final metadata = construction ??
        DesignMetadataService.defaultForDressType(_selectedDressType);
    final fabric = _effectiveFabricChoice == null
        ? null
        : FabricMetadataService.forFabric(_effectiveFabricChoice);
    final occasion = OccasionMetadataService.forOccasion(
      occasionId: _occasionId,
      occasionLabel: _occasionLabel() ?? 'General',
    );

    // Suggest design-specific neckline and sleeve settings only when the
    // published catalogue version includes construction metadata.
    if (construction != null) {
      final neckStyle = _neckStyleFromMetadata(construction.neckType);
      if (neckStyle != null && _selectedNeckStyle != neckStyle) {
        suggestions.add(
          _DressFitSuggestion(
            field: 'neckStyle',
            value: neckStyle,
            reason: 'Matches the selected catalogue design details.',
          ),
        );
      }
      final sleeveStyle = _sleeveStyleFromMetadata(construction.sleeveType);
      if (sleeveStyle != null && _selectedSleeveStyle != sleeveStyle) {
        suggestions.add(
          _DressFitSuggestion(
            field: 'sleeveStyle',
            value: sleeveStyle,
            reason: 'Matches the selected catalogue design details.',
          ),
        );
      }
    }

    final liningRecommended =
        metadata.liningRequired ||
        occasion.liningRecommended ||
        (fabric?.liningRecommended ?? false);
    final liningValue = metadata.liningRequired ? 'Required' : 'As Recommended';
    if (liningRecommended && _selectedLiningPreference != liningValue) {
      final reason = metadata.liningRequired
          ? 'The catalogue construction details call for lining.'
          : fabric?.liningRecommended == true
          ? '${fabric!.fabricName} may benefit from lining for coverage and finish.'
          : '${occasion.displayName} designs often benefit from a lining review.';
      suggestions.add(
        _DressFitSuggestion(
          field: 'liningPreference',
          value: liningValue,
          reason: reason,
        ),
      );
    }

    final needsTailorReview =
        metadata.complexity == DesignComplexity.high ||
        occasion.tailorReviewRecommended ||
        fabric?.weight == FabricWeight.heavy ||
        fabric?.behavior == FabricBehavior.delicate;
    if (needsTailorReview &&
        _selectedAlterationMargin != 'Tailor Recommendation') {
      suggestions.add(
        const _DressFitSuggestion(
          field: 'alterationMargin',
          value: 'Tailor Recommendation',
          reason: 'Ask the tailor to confirm movement and alteration allowance before cutting.',
        ),
      );
    }

    return suggestions.take(3).toList(growable: false);
  }

  void _onDressFitAssistant() {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a design before using the fit assistant.'),
        ),
      );
      return;
    }
    final body = _bodyMeasurementsFromDesignerFields();
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A saved measurement is needed for a fit review. Use Take New Measurement if this profile has no measurement yet.',
          ),
        ),
      );
      return;
    }
    final designMetadata =
        _selectedTemplate!.constructionMetadata ??
        DesignMetadataService.defaultForDressType(_selectedDressType);
    final fabricMetadata = FabricMetadataService.forFabric(
      _effectiveFabricChoice,
    );
    final occasionMetadata = OccasionMetadataService.forOccasion(
      occasionId: _occasionId,
      occasionLabel: _occasionLabel() ?? 'General',
    );
    // Reuse the same local engine as Generate Dress Estimate without
    // populating the estimate card or changing the customer's selections.
    final estimate =
        _garmentMeasurementEstimate ??
        _estimateGarmentMeasurementsLocally(
          body: body,
          designMetadata: designMetadata,
          occasionMetadata: occasionMetadata,
          fabricMetadata: fabricMetadata,
        );

    final designName = _selectedTemplate!.title;
    final suggestions = _buildLocalDressFitSuggestions();
    final summary =
        'Your ${_selectedFit.toLowerCase()} fit estimate for $designName '
        'is based on the available saved measurements and contains ${estimate.valuesCm.length} garment-specific values (formula ${estimate.formulaVersion}). '
        'Your selected design and saved body measurements are unchanged. Ask your tailor to confirm comfort and movement before cutting.';
    setState(() {
      _fitAssistantSummary = summary;
      _fitAssistantSuggestions = suggestions;
      _fitAssistantContextKey = _smartAssistContextKey();
    });
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your current selections look consistent with the available design guidance.'),
        ),
      );
    }
  }

  String _fitSuggestionLabel(String field) => switch (field) {
    'neckStyle' => 'Neck style',
    'sleeveStyle' => 'Sleeve style',
    'alterationMargin' => 'Alteration margin',
    'liningPreference' => 'Lining / astar',
    _ => 'Suggestion',
  };

  Future<void> _reviewFitSuggestions() async {
    final suggestions = _fitAssistantSuggestions;
    if (suggestions.isEmpty) return;
    final selectedIndexes = <int>{};
    final approved = await showModalBottomSheet<List<_DressFitSuggestion>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review fit suggestions', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Choose only the changes you want. Saved measurements and the original catalogue design stay unchanged.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return CheckboxListTile(
                          value: selectedIndexes.contains(index),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${_fitSuggestionLabel(suggestion.field)}: ${suggestion.value}',
                            style: AppTextStyles.titleMedium,
                          ),
                          subtitle: Text(suggestion.reason),
                          onChanged: (selected) => setSheetState(() {
                            if (selected == true) {
                              selectedIndexes.add(index);
                            } else {
                              selectedIndexes.remove(index);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Not now'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: selectedIndexes.isEmpty
                            ? null
                            : () => Navigator.pop(
                                sheetContext,
                                [
                                  for (var i = 0; i < suggestions.length; i++)
                                    if (selectedIndexes.contains(i)) suggestions[i],
                                ],
                              ),
                        child: Text('Apply ${selectedIndexes.length} selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (approved != null && approved.isNotEmpty && mounted) {
      _applyDressFitSuggestions(approved);
    }
  }

  void _applyDressFitSuggestions(List<_DressFitSuggestion> suggestions) {
    setState(() {
      for (final suggestion in suggestions) {
        switch (suggestion.field) {
          case 'neckStyle':
            _selectedNeckStyle = suggestion.value;
            _neckController.text = suggestion.value;
            break;
          case 'sleeveStyle':
            _selectedSleeveStyle = suggestion.value;
            _sleeveStyleController.text = suggestion.value;
            break;
          case 'backDesign':
            _selectedBackDesign = suggestion.value;
            _backDesignController.text = suggestion.value;
            break;
          case 'alterationMargin':
            _selectedAlterationMargin = suggestion.value;
            _marginController.text = suggestion.value;
            break;
          case 'liningPreference':
            _selectedLiningPreference = suggestion.value;
            break;
        }
      }
      _garmentMeasurementEstimate = null;
      _fabricEstimate = null;
      _priceEstimate = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your selected suggestions were applied. Generate the estimate again to refresh it.',
        ),
      ),
    );
  }

  Future<void> _onFabricStyleTips() async {
    if (_smartAssistBusy != null) return;
    final contextKey = _smartAssistContextKey();
    setState(() {
      _smartAssistBusy = 'fabric';
      _fabricStyleAiText = null;
    });
    final occ = _occasionLabel();
    final r = await ClaudeSmartAssistantService.fabricAndStylingTips(
      dressType: _selectedDressType,
      occasionLabel: (occ == null || occ.isEmpty) ? 'General' : occ,
      fit: _selectedFit,
      fabricChoice:
          _fabricChoice == 'Other' &&
              _customFabricController.text.trim().isNotEmpty
          ? _customFabricController.text.trim()
          : _fabricChoice,
      designTemplateTitle: _selectedTemplate?.title,
      accentColorHex: _colorHexRgb(_accentColor),
    );
    if (!mounted) return;
    setState(() => _smartAssistBusy = null);
    if (r.success) {
      setState(() {
        _fabricStyleAiText = r.text;
        _fabricStyleContextKey = contextKey;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Smart Assist is currently unavailable. Please try again later.',
          ),
        ),
      );
    }
  }

  String _fabricGuidanceNoteBlock(String suggestionText) =>
      'Customer-approved fabric & styling guidance:\n${suggestionText.trim()}';

  void _addFabricSuggestionsToNotes() {
    final suggestionText = _fabricStyleAiText;
    if (suggestionText == null ||
        _fabricStyleContextKey != _smartAssistContextKey()) {
      return;
    }
    final block = _fabricGuidanceNoteBlock(suggestionText);
    final existing = _notesController.text.trim();
    if (existing.contains(block)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('These suggestions are already in your instructions.'),
        ),
      );
      return;
    }
    _notesController.text = existing.isEmpty ? block : '$existing\n\n$block';
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approved guidance added to tailor instructions.'),
      ),
    );
  }

  Future<void> _onPolishNotesForTailor() async {
    if (_smartAssistBusy != null) return;
    final currentDraft = _notesController.text.trim();
    if (currentDraft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the instructions you want improved first.'),
        ),
      );
      return;
    }
    setState(() => _smartAssistBusy = 'polish');
    final r = await ClaudeSmartAssistantService.polishCustomerNotes(
      draft: currentDraft,
      dressType: _selectedDressType,
      fit: _selectedFit,
    );
    if (!mounted) return;
    setState(() => _smartAssistBusy = null);
    if (!r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Smart Assist is currently unavailable. Please try again later.',
          ),
        ),
      );

      return;
    }
    if (_notesController.text.trim() != currentDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your instructions changed. Please run Improve Tailor Instructions again.',
          ),
        ),
      );
      return;
    }
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review improved instructions'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(ctx).height * 0.55,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your current instructions', style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text(currentDraft, style: AppTextStyles.bodySmall),
                const SizedBox(height: 18),
                Text('Suggested wording', style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text(r.text, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                Text(
                  'Your current text stays unchanged unless you approve the suggested wording. You can edit it afterward.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use suggested wording'),
          ),
        ],
      ),
    );
    if (apply == true && mounted) {
      _notesController.text = r.text;
      setState(() {});
    }
  }

  Widget _buildSmartAssistSection() {
    final contextKey = _smartAssistContextKey();
    final hasCurrentFitReview =
        _fitAssistantSummary != null && _fitAssistantContextKey == contextKey;
    final hasCurrentFabricTips =
        _fabricStyleAiText != null && _fabricStyleContextKey == contextKey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Smart Assist · Optional', style: AppTextStyles.headlineMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Get fit, fabric and tailor-note guidance. Review every suggestion; nothing changes until you approve it.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _smartAssistBusy != null
                    ? null
                    : _onDressFitAssistant,
                icon: const Icon(Icons.accessibility_new_rounded, size: 20),
                label: const Text('Dress Fit Assistant'),
              ),
              OutlinedButton.icon(
                onPressed: _smartAssistBusy != null ? null : _onFabricStyleTips,
                icon: _smartAssistBusy == 'fabric'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.style_outlined, size: 20),
                label: Text(
                  _smartAssistBusy == 'fabric'
                      ? 'Getting tips…'
                      : 'Suggest Fabric & Styling',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _smartAssistBusy != null
                    ? null
                    : _onPolishNotesForTailor,
                icon: _smartAssistBusy == 'polish'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note_rounded, size: 20),
                label: Text(
                  _smartAssistBusy == 'polish'
                      ? 'Updating notes…'
                      : 'Improve Tailor Instructions',
                ),
              ),
            ],
          ),
          if (hasCurrentFitReview) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fit review', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    _fitAssistantSummary!,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fit review uses the same local measurement engine; body measurement values are not sent to the assistant.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_fitAssistantSuggestions.isEmpty)
                    Text(
                      'No selection changes are suggested from the available catalogue and fabric guidance.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _reviewFitSuggestions,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(
                        'Review ${_fitAssistantSuggestions.length} suggestion${_fitAssistantSuggestions.length == 1 ? '' : 's'}',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (hasCurrentFabricTips) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fabric & styling ideas', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _fabricStyleAiText!,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _addFabricSuggestionsToNotes,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(
                      _notesController.text.contains(
                            _fabricGuidanceNoteBlock(_fabricStyleAiText!),
                          )
                          ? 'Added to Tailor Instructions'
                          : 'Add approved guidance to Tailor Instructions',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiPricing() {
    final fabricEstimate = _fabricEstimate;
    final priceEstimate = _priceEstimate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Estimate', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Fabric and stitching estimates are guidance only. '
            'Final price will be confirmed after design, fabric, '
            'customization and tailor review.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (fabricEstimate == null || priceEstimate == null) ...[
            Text(
              'Tap “Suggest” in the Measurements section to generate '
              'garment, fabric and stitching estimates.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.straighten_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estimated fabric required',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                Text(
                  '${fabricEstimate.estimatedMeters.toStringAsFixed(1)} m',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fabric formula ${fabricEstimate.formulaVersion} • '
              'Confidence ${fabricEstimate.confidence}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.currency_rupee_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated stitching price',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${priceEstimate.minimumAmount.toStringAsFixed(0)} '
                        'to '
                        '₹${priceEstimate.maximumAmount.toStringAsFixed(0)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Price formula ${priceEstimate.formulaVersion} • '
              'Confidence ${priceEstimate.confidence}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Estimate details',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${fabricEstimate.notes.length + priceEstimate.notes.length} '
                  'calculation notes available',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                children: [
                  ...fabricEstimate.notes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '• $note',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...priceEstimate.notes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '• $note',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fabric purchase cost is not included. '
              'Final stitching price will be confirmed after tailor review.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerDesignOwnerContext {
  const _CustomerDesignOwnerContext({
    required this.accountId,
    required this.profileId,
    required this.profileName,
  });

  final String accountId;
  final String profileId;
  final String profileName;
}

class _OrderPerson {
  final String id;
  final String name;
  final String relationship;
  final bool isSelf;

  const _OrderPerson({
    required this.id,
    required this.name,
    required this.relationship,
    required this.isSelf,
  });
}

class _DesignerAddress {
  final String addressId;
  final String addressType;
  final String name;
  final String mobileNumber;
  final String addressLine1;
  final String addressLine2;
  final String landmark;
  final String city;
  final String? cityCode;
  final String state;
  final String? stateCode;
  final String pincode;
  final bool isDefault;

  const _DesignerAddress({
    required this.addressId,
    required this.addressType,
    required this.name,
    required this.mobileNumber,
    required this.addressLine1,
    required this.addressLine2,
    required this.landmark,
    required this.city,
    this.cityCode,
    required this.state,
    this.stateCode,
    required this.pincode,
    required this.isDefault,
  });

  factory _DesignerAddress.fromMap(String id, Map<String, dynamic> data) {
    final city = data['city']?.toString() ?? data['cityName']?.toString() ?? '';
    final state =
        data['state']?.toString() ?? data['stateName']?.toString() ?? '';
    final metadata = IndiaAddressMetadata.instance;
    final stateCode =
        data['stateCode']?.toString() ?? metadata.stateCodeForLabel(state);
    final cityCode =
        data['cityCode']?.toString() ??
        metadata.cityCodeForLabel(stateCode: stateCode, cityLabel: city);

    return _DesignerAddress(
      addressId: data['addressId']?.toString() ?? id,
      addressType: data['addressType']?.toString() ?? 'Home',
      name: data['name']?.toString() ?? '',
      mobileNumber: data['mobileNumber']?.toString() ?? '',
      addressLine1: data['addressLine1']?.toString() ?? '',
      addressLine2: data['addressLine2']?.toString() ?? '',
      landmark: data['landmark']?.toString() ?? '',
      city: city,
      cityCode: cityCode,
      state: state,
      stateCode: stateCode,
      pincode: data['pincode']?.toString() ?? '',
      isDefault: data['isDefault'] == true,
    );
  }

  String get dropdownLabel {
    final suffix = isDefault ? 'Default' : addressType;
    return '$addressType - $city ($suffix)';
  }

  String get formattedAddress {
    final parts = <String>[
      if (name.trim().isNotEmpty) name.trim(),
      if (mobileNumber.trim().isNotEmpty) mobileNumber.trim(),
      if (addressLine1.trim().isNotEmpty) addressLine1.trim(),
      if (addressLine2.trim().isNotEmpty) addressLine2.trim(),
      if (landmark.trim().isNotEmpty) 'Landmark: ${landmark.trim()}',
      [
        if (city.trim().isNotEmpty) city.trim(),
        if (state.trim().isNotEmpty) state.trim(),
        if (pincode.trim().isNotEmpty) pincode.trim(),
      ].join(', '),
    ];

    return parts.where((part) => part.trim().isNotEmpty).join('\n');
  }
}

class _WishlistDesignOption {
  const _WishlistDesignOption({
    required this.design,
    required this.bundle,
    this.fabricSelection,
  });

  final CatalogueDesign design;
  final PublishedCatalogueBundle bundle;
  final _SavedWishlistFabricSelection? fabricSelection;
}

class _SavedWishlistFabricSelection {
  const _SavedWishlistFabricSelection({
    required this.wishlistItemId,
    required this.designId,
    required this.catalogueVersionId,
    required this.previews,
    required this.customerFabricAssets,
  });

  final String wishlistItemId;
  final String designId;
  final String catalogueVersionId;
  final List<_WishlistFabricPreview> previews;
  final Map<String, dynamic> customerFabricAssets;
}

class _WishlistFabricPreview {
  const _WishlistFabricPreview({
    required this.storagePath,
    required this.imageUrl,
    required this.viewType,
    this.contentType,
    this.byteSize,
  });

  final String storagePath;
  final String imageUrl;
  final String viewType;
  final String? contentType;
  final int? byteSize;

  Map<String, dynamic> toAssetMap() => {
    'storagePath': storagePath,
    'viewType': viewType,
    if (contentType != null) 'contentType': contentType,
    if (byteSize != null) 'byteSize': byteSize,
  };
}

String _shortMeasurementDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
