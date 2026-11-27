import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/metadata/garment_care_catalog_metadata.dart';
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
import '../../services/smart_assist_service.dart';
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
import '../../core/garment_measurement_catalog.dart';
import '../../services/customer_measurement_history_service.dart';
import '../../widgets/catalogue/catalogue_fabric_preview_button.dart';

import '../../models/customer_design.dart';
import '../../services/customer_design_service.dart';
import '../../services/order_instruction_media_service.dart';
import '../../services/order_instruction_transcription_service.dart';
import '../../widgets/orders/order_instruction_media_preview_dialog.dart';
import '../../widgets/smart_assist/speech_playback_button.dart';

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

class _FabricEstimateReturn {
  const _FabricEstimateReturn({
    required this.garmentMeasurements,
    required this.fabricEstimate,
    required this.priceEstimate,
    required this.dressType,
    required this.fit,
    required this.occasionId,
    required this.fabricChoice,
    required this.customFabric,
    required this.designTemplate,
  });

  final GarmentMeasurementEstimate garmentMeasurements;
  final FabricEstimate fabricEstimate;
  final PriceEstimate priceEstimate;
  final String dressType;
  final String fit;
  final String? occasionId;
  final String? fabricChoice;
  final String customFabric;
  final DesignTemplate? designTemplate;
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
    this.estimateOnly = false,
    this.initialDressType,
    this.initialFit,
    this.initialCatalogueDesignId,
    this.initialFabricChoice,
    this.initialCustomFabric,
    this.returnToOrder = false,
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
  final bool estimateOnly;
  final String? initialDressType;
  final String? initialFit;
  final String? initialCatalogueDesignId;
  final String? initialFabricChoice;
  final String? initialCustomFabric;
  final bool returnToOrder;

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
  CustomerMeasurementRecord? _customerMeasurementProfileReference;
  CustomerMeasurementRecord? _customerMeasurementReference;
  String? _selectedOrderPersonId;
  String? _resumeDraftPersonName;
  String? _resumeDraftRelationship;
  bool _loadingOrderPeople = true;
  final Set<String> _expandedSections = {
    'order-design-fabric',
    'order-measurements',
    'order-summary',
    'estimate-design-fabric',
    'estimate-measurements',
  };

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
  bool _selectedDesignFromWishlist = false;
  PriceEstimate? _priceEstimate;

  /// null | 'fit' | 'fabric' | 'polish'
  String? _smartAssistBusy;
  String? _fabricStyleAiText;
  String? _fabricStyleApprovedContent;
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
    'Top / Tunic',
    'Shirt',
    'Palazzo / Pant',
    'Skirt',
    'Other',
  ];

  String _selectedFit = 'Regular';
  final _fitOptions = ['Slim', 'Regular', 'Loose'];

  final _notesController = TextEditingController();
  final _fabricPurchasedMetersController = TextEditingController();
  final _neckController = TextEditingController();
  final _sleeveStyleController = TextEditingController();
  final _backDesignController = TextEditingController();
  final _marginController = TextEditingController();
  final _customFabricController = TextEditingController();
  final AudioRecorder _instructionAudioRecorder = AudioRecorder();
  Timer? _instructionAudioTimer;
  bool _recordingInstructionAudio = false;
  bool _transcribingInstructionAudio = false;
  int _instructionAudioSeconds = 0;
  XFile? _instructionAudioFile;
  XFile? _instructionVideoFile;
  List<Map<String, dynamic>> _draftInstructionMedia = const [];
  final Set<String> _removedDraftInstructionMediaPaths = {};
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

  static const List<String> _fabricOptions =
      GarmentCareCatalogMetadata.materialTypes;
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
      final fabricPurchasedMeters = data['fabricPurchasedMeters'];
      final instructionMediaRaw = data['instructionMedia'];
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
          _selectedDressType = _canonicalDressType(dressType);
        }

        if (fitPreference != null && fitPreference.isNotEmpty) {
          _selectedFit = fitPreference;
        }

        if (fabricChoice != null && fabricChoice.isNotEmpty) {
          _fabricChoice = fabricChoice;
        }
        if (fabricPurchasedMeters is num) {
          _fabricPurchasedMetersController.text = fabricPurchasedMeters
              .toString();
        }
        _draftInstructionMedia = instructionMediaRaw is List
            ? instructionMediaRaw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const [];
        _removedDraftInstructionMediaPaths.clear();

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
    if (_transcribingInstructionAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for voice-note transcription to finish.'),
        ),
      );
      return;
    }
    if (_recordingInstructionAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop your voice note before saving.')),
      );
      return;
    }
    if (!_isFabricPurchasedMetersValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the fabric quantity in metres or leave it blank.',
          ),
        ),
      );
      return;
    }

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
    List<Map<String, dynamic>>? uploadedInstructionMedia;
    final originalDraftMediaPaths =
        _draftInstructionMedia
            .map((item) => item['storagePath']?.toString() ?? '')
            .where((path) => path.isNotEmpty)
            .toSet()
          ..addAll(_removedDraftInstructionMediaPaths);

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

      final customerUid = FirebaseAuth.instance.currentUser?.uid;
      if (customerUid == null) {
        throw StateError('Sign in to save an order draft.');
      }
      final draftId = _currentOrderDraftId?.trim().isNotEmpty == true
          ? _currentOrderDraftId!.trim()
          : _db.collection('order_drafts').doc().id;
      final savedInstructionMedia =
          await OrderInstructionMediaService.uploadDraftMedia(
            customerUid: customerUid,
            draftId: draftId,
            existingMedia: _draftInstructionMedia,
            audioFile: _instructionAudioFile,
            videoFile: _instructionVideoFile,
          );
      uploadedInstructionMedia = savedInstructionMedia;
      final retainedPaths = savedInstructionMedia
          .map((item) => item['storagePath']?.toString() ?? '')
          .toSet();
      final replacedDraftPaths = _draftInstructionMedia
          .map((item) => item['storagePath']?.toString() ?? '')
          .where((path) => path.isNotEmpty && !retainedPaths.contains(path))
          .followedBy(_removedDraftInstructionMediaPaths)
          .where((path) => !retainedPaths.contains(path))
          .toSet()
          .toList(growable: false);
      final savedDraftId = await OrderDraftService.saveDraft(
        draftId: draftId,
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
        fabricPurchasedMeters: _fabricPurchasedMeters,
        instructionMedia: savedInstructionMedia,
        fabricPreviewSelection: _pendingCustomerFabricSelection,
        customerFabricAssets: _pendingCustomerFabricSelection == null
            ? _matchingSavedWishlistFabricSelection?.customerFabricAssets
            : null,
      );

      if (!mounted) return;

      await _deleteLocalInstructionFiles();
      setState(() {
        _currentOrderDraftId = savedDraftId;
        _draftInstructionMedia = savedInstructionMedia;
        _removedDraftInstructionMediaPaths.clear();
        _instructionAudioFile = null;
        _instructionVideoFile = null;
        _saveDraftLoading = false;
      });
      await OrderInstructionMediaService.deletePaths(replacedDraftPaths);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved successfully')));
    } catch (error) {
      if (uploadedInstructionMedia != null) {
        await OrderInstructionMediaService.deletePaths(
          uploadedInstructionMedia
              .map((item) => item['storagePath']?.toString() ?? '')
              .where(
                (path) =>
                    path.isNotEmpty && !originalDraftMediaPaths.contains(path),
              ),
        );
      }
      if (!mounted) return;

      setState(() => _saveDraftLoading = false);

      final message =
          error is FirebaseException &&
              error.plugin == 'firebase_storage' &&
              (error.code.toLowerCase().contains('permission') ||
                  error.code.toLowerCase().contains('unauthorized'))
          ? 'Firebase Storage blocked an attached upload. Ask the app administrator to check Storage rules for recordings and fabric references.'
          : 'Unable to save draft. Please try again.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void initState() {
    super.initState();

    _showOrderForm = !widget.startInBrowseMode;
    _occasionId = widget.initialOccasionId ?? OccasionCategory.dailyWear.name;
    _selectedOrderPersonId = widget.initialPersonId;
    final initialDressType = widget.initialDressType?.trim() ?? '';
    if (initialDressType.isNotEmpty) {
      _selectedDressType = _canonicalDressType(initialDressType);
    }
    final initialFit = widget.initialFit?.trim() ?? '';
    if (_fitOptions.contains(initialFit)) _selectedFit = initialFit;
    final initialFabricChoice = widget.initialFabricChoice?.trim() ?? '';
    if (_fabricOptions.contains(initialFabricChoice)) {
      _fabricChoice = initialFabricChoice;
    }
    _customFabricController.text = widget.initialCustomFabric?.trim() ?? '';
    if (_showOrderForm || widget.estimateOnly) _initializeOrderContext();
  }

  String _canonicalDressType(String dressType) {
    return dressType.trim().toLowerCase() == 'saree blouse'
        ? 'Blouse'
        : dressType.trim();
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
    if (widget.estimateOnly) {
      await _loadLatestMeasurementsForSelectedPerson();
      await _loadInitialCatalogueDesign();
      return;
    }
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

  Future<void> _loadInitialCatalogueDesign() async {
    final designId = widget.initialCatalogueDesignId?.trim() ?? '';
    if (designId.isEmpty) return;
    try {
      final document = await _db.collection('designs').doc(designId).get();
      if (!document.exists || !mounted) return;
      final design = CatalogueDesign.fromDoc(document);
      if (!_matchesSelectedGarment(design)) return;
      final bundle = await CatalogueDesignService.getPublishedBundle(design);
      if (bundle == null || !mounted) return;
      _selectCatalogueDesign(design, bundle);
    } catch (error) {
      debugPrint('[FabricEstimate] Could not restore selected design: $error');
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
    Map<String, dynamic>? values, {
    String? measurementUnit,
  }) {
    if (values == null || values.isEmpty) return null;

    double? read(String key) {
      final value = values[key];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    double? readReferenceField(int number) {
      final spec = GarmentMeasurementCatalog.all[number - 1];
      Object? raw = values[spec.key];
      if (raw == null) {
        for (final entry in values.entries) {
          if (entry.key.toString().toLowerCase().contains(
            spec.label.toLowerCase(),
          )) {
            raw = entry.value;
            break;
          }
        }
      }
      final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (parsed == null) return null;
      return measurementUnit?.toLowerCase() == 'in' ? parsed * 2.54 : parsed;
    }

    final height = read('height') ?? readReferenceField(7);
    final chest = read('chest') ?? readReferenceField(3);
    final waist = read('waist') ?? readReferenceField(5);
    final hips = read('hips') ?? readReferenceField(6);
    final shoulder =
        read('shoulder') ?? readReferenceField(19) ?? readReferenceField(11);
    final armLength = read('armLength') ?? readReferenceField(10);
    final neck = read('neck') ?? readReferenceField(1);
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
      CustomerMeasurementRecord? customerMeasurementProfileReference;
      final customerUid = user?.uid;
      if (customerUid != null && customerUid.isNotEmpty) {
        try {
          final history = await CustomerMeasurementHistoryService.loadHistory(
            customerUid: customerUid,
            accountId: accountId,
            personId: selectedPerson.id,
            personName: selectedPerson.name,
            limit: 10,
          );
          for (final record in history) {
            if (record.isCustomerReference) {
              customerMeasurementProfileReference = record;
              break;
            }
          }
        } catch (_) {
          // Keep the existing order measurement fallback if history is unavailable.
        }
      }
      if (!widget.estimateOnly &&
          customerUid != null &&
          customerUid.isNotEmpty) {
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
                  status == 'order_created' ||
                  (widget.estimateOnly && status == 'customer_reference');
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
            loadedMeasurements = _bodyMeasurementsFromFirestoreValues(
              values,
              measurementUnit: data['measurementUnit']?.toString(),
            );
          } else if (values is Map) {
            loadedMeasurements = _bodyMeasurementsFromFirestoreValues(
              Map<String, dynamic>.from(values),
              measurementUnit: data['measurementUnit']?.toString(),
            );
          }

          if (loadedMeasurements != null) break;
        }
      }

      if (!mounted) return;

      setState(() {
        _customerMeasurementProfileReference =
            customerMeasurementProfileReference;
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
    _instructionAudioTimer?.cancel();
    unawaited(_instructionAudioRecorder.dispose());
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
    _fabricPurchasedMetersController.dispose();
    _neckController.dispose();
    _sleeveStyleController.dispose();
    _backDesignController.dispose();
    _marginController.dispose();
    _customFabricController.dispose();
    super.dispose();
  }

  double? get _fabricPurchasedMeters {
    final raw = _fabricPurchasedMetersController.text.trim();
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  bool get _isFabricPurchasedMetersValid {
    final raw = _fabricPurchasedMetersController.text.trim();
    if (raw.isEmpty) return true;
    return _fabricPurchasedMeters != null;
  }

  Future<void> _deleteLocalInstructionFiles() async {
    for (final file in [_instructionAudioFile, _instructionVideoFile]) {
      if (file == null) continue;
      try {
        await File(file.path).delete();
      } catch (_) {
        // Temporary files are cleaned up by the platform when needed.
      }
    }
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
    final customerProfileReference = _customerMeasurementProfileReference;
    if (customerProfileReference != null) {
      final values = customerProfileReference.values.entries
          .map(
            (entry) =>
                '${entry.key}: ${entry.value} ${customerProfileReference.unit}',
          )
          .join(', ');
      parts.add(
        'Customer measurement reference (customer-provided; Tailor to review and confirm before cutting): ${customerProfileReference.title}'
        '${values.isEmpty ? '' : ' — $values'}',
      );
    }
    final customerReference = _customerMeasurementReference;
    if (customerReference != null &&
        customerReference.id != customerProfileReference?.id) {
      final values = customerReference.values.entries
          .map(
            (entry) => '${entry.key}: ${entry.value} ${customerReference.unit}',
          )
          .join(', ');
      final sourceOrderId = customerReference.sourceOrderId?.trim();
      parts.add(
        'Historical measurement reference (for comparison only; reconfirm before stitching): ${customerReference.title}'
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
    if (person == null ||
        uid == null ||
        phone == null ||
        phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer profile first.')),
      );
      return;
    }
    try {
      final accountContext = await _loadAccountAndCustomerProfileForDraft();
      final accountId = accountContext?['accountId']?.trim() ?? '';
      final customerProfileId =
          accountContext?['customerProfileId']?.trim() ?? '';
      if (accountId.isEmpty || customerProfileId.isEmpty) {
        throw StateError('Customer account was not found');
      }
      final loadedRecords = await CustomerMeasurementHistoryService.loadHistory(
        customerUid: uid,
        accountId: accountId,
        customerProfileId: customerProfileId,
        personId: person.id,
        personName: person.name,
        limit: 10,
      );
      final records = loadedRecords
          .where((record) => record.measurementType != 'ai_estimate')
          .toList(growable: false);
      if (!mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No manual or Tailor-confirmed measurement records are available.',
            ),
          ),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a measurement reference',
                        style: AppTextStyles.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop<CustomerMeasurementRecord>(null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Text(
                  'Past manual and Tailor-confirmed records can be added for comparison. AI camera estimates stay out of Tailor instructions; current measurements and Tailor confirmation remain the fit reference.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        title: Text(record.title),
                        subtitle: Text(
                          '${record.isCustomerReference ? 'Customer reference' : 'Tailor confirmed'} · ${record.values.length} fields · ${_shortMeasurementDate(record.capturedAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop<CustomerMeasurementRecord>(record),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop<CustomerMeasurementRecord>(null),
                      child: const Text('Cancel'),
                    ),
                  ),
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
        const SnackBar(
          content: Text(
            'Unable to load measurement history. Please try again.',
          ),
        ),
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

  double _customerPriceFromRates() {
    for (final r in AppState.instance.rates) {
      if (r.dressType == _selectedDressType) {
        return r.customerPrice ?? r.basePrice;
      }
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
      _customerPriceFromRates() + _approvedCatalogueDesignCharge;

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
    if (_placeOrderLoading || _saveDraftLoading) return;

    final addr = _deliveryAddressController.text.trim();

    if (_recordingInstructionAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop your voice note before ordering.')),
      );
      return;
    }
    if (_transcribingInstructionAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for voice-note transcription to finish.'),
        ),
      );
      return;
    }

    if (!_isFabricPurchasedMetersValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the fabric quantity in metres or leave it blank.',
          ),
        ),
      );
      return;
    }

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

    setState(() => _placeOrderLoading = true);
    final confirmed = await _confirmOrderOutsideBusinessHours();
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _placeOrderLoading = false);
      return;
    }

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
    List<Map<String, dynamic>>? orderInstructionMedia;
    var orderInstructionMediaWereUploaded = false;
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
        customerFabricAssets =
            await CustomerFabricAssetService.copySavedSelectionToOrder(
              customerUid: FirebaseAuth.instance.currentUser!.uid,
              orderId: requestedOrderId,
              savedAssets: customerFabricAssets,
            );
        orderFabricAssetsWereUploaded = true;
      }
      final customerUid = FirebaseAuth.instance.currentUser?.uid;
      if (customerUid == null) {
        throw StateError('Sign in to attach instructions to this order.');
      }
      orderInstructionMedia =
          await OrderInstructionMediaService.uploadOrderMedia(
            customerUid: customerUid,
            orderId: requestedOrderId,
            savedDraftMedia: _draftInstructionMedia,
            audioFile: _instructionAudioFile,
            videoFile: _instructionVideoFile,
          );
      orderInstructionMediaWereUploaded = orderInstructionMedia.isNotEmpty;
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
        fabricPurchasedMeters: _fabricPurchasedMeters,
        instructionMedia: orderInstructionMedia,
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
        fabricDescription:
            (_fabricChoice != null ||
                _selectedTemplate != null ||
                _fabricPurchasedMeters != null)
            ? [
                ?_fabricChoice,
                if (_selectedTemplate != null)
                  'Design: ${_selectedTemplate!.title}',
                if (_fabricPurchasedMeters != null)
                  'Fabric purchased: ${_fabricPurchasedMeters!.toStringAsFixed(2)} m',
                'Accent: ${_colorHexRgb(_accentColor)}',
              ].join(' · ')
            : null,
      );
    } catch (error) {
      if (orderFabricAssetsWereUploaded) {
        await CustomerFabricAssetService.deleteAssets(customerFabricAssets);
      }
      if (orderInstructionMediaWereUploaded) {
        await OrderInstructionMediaService.deletePaths(
          orderInstructionMedia!.map(
            (item) => item['storagePath']?.toString() ?? '',
          ),
        );
      }
      if (!mounted) return;
      setState(() => _placeOrderLoading = false);
      final message =
          error is FirebaseException &&
              error.plugin == 'firebase_storage' &&
              (error.code.toLowerCase().contains('permission') ||
                  error.code.toLowerCase().contains('unauthorized'))
          ? 'Firebase Storage blocked an attached upload. Ask the app administrator to check Storage rules for recordings and fabric references before placing the order.'
          : 'Could not place the order: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (id == null) {
      if (orderFabricAssetsWereUploaded) {
        await CustomerFabricAssetService.deleteAssets(customerFabricAssets);
      }
      if (orderInstructionMediaWereUploaded) {
        await OrderInstructionMediaService.deletePaths(
          orderInstructionMedia.map(
            (item) => item['storagePath']?.toString() ?? '',
          ),
        );
      }
    } else {
      _pendingCustomerFabricSelection = null;
    }
    if (!mounted) return;

    if (id != null) {
      await _deleteLocalInstructionFiles();
      await OrderInstructionMediaService.deletePaths({
        ..._draftInstructionMedia
            .map((item) => item['storagePath']?.toString() ?? '')
            .where((path) => path.isNotEmpty),
        ..._removedDraftInstructionMediaPaths,
      });
      _draftInstructionMedia = const [];
      _removedDraftInstructionMediaPaths.clear();
      _instructionAudioFile = null;
      _instructionVideoFile = null;
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
      context.go('/orders');
    } else {
      setState(() => _placeOrderLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to place an order')),
      );
    }
  }

  Widget _buildDeliveryAddressSection({bool showHeading = true}) {
    if (_loadingDeliveryAddresses) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text('Delivery address', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
          ],
          const LinearProgressIndicator(),
        ],
      );
    }

    if (_deliveryAddressError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text('Delivery address', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
          ],
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
          if (showHeading) ...[
            Text('Delivery address', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
          ],
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
        if (showHeading) ...[
          Text('Delivery address', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
        ],
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

  Widget _buildAdvancePaymentSection({bool showHeading = true}) {
    final sewingPrice = _customerPriceFromRates();
    final designPrice = _approvedCatalogueDesignCharge;
    final price = sewingPrice + designPrice;
    final adv = price * _advancePercent / 100.0;
    final bal = (price - adv).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text('Advance payment', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
        ],
        _buildOrderSummaryDetails(),
        const SizedBox(height: 14),
        Text(
          'After a Tailor accepts your request, you can choose whether to proceed. If you proceed, the $_advancePercent% advance is paid online; the balance is due later per shop policy.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Price',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (designPrice > 0)
                      Text(
                        'Stitching ₹${sewingPrice.toStringAsFixed(0)} + approved design ₹${designPrice.toStringAsFixed(0)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '₹${price.toStringAsFixed(0)}',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Pay $_advancePercent% advance on Tailor acceptance · ₹${adv.toStringAsFixed(0)}  |  Balance ₹${bal.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryDetails() {
    final pairedDetails = <List<MapEntry<String, String>>>[
      [
        MapEntry('Order for', _selectedOrderPerson()?.name ?? 'Not selected'),
        MapEntry('Occasion', _occasionLabel() ?? 'Daily Wear'),
      ],
      [
        MapEntry('Dress Type', _selectedDressType),
        MapEntry('Design', _selectedTemplate?.title ?? 'Not selected'),
      ],
      [
        MapEntry('Fabric Type', _effectiveFabricChoice ?? 'Not selected'),
        MapEntry(
          'Fabric purchased (optional)',
          _fabricPurchasedMeters == null
              ? 'Not provided'
              : '${_fabricPurchasedMeters!.toStringAsFixed(1)} m',
        ),
      ],
      [
        MapEntry('Fit Preference', _selectedFit),
        MapEntry(
          'Measurement Reference',
          _customerMeasurementProfileReference?.title ??
              _customerMeasurementReference?.title ??
              'Tailor to confirm',
        ),
      ],
    ];

    final instructionSummary = _orderInstructionSummary();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var index = 0; index < pairedDetails.length; index++) ...[
            if (index > 0) Divider(height: 1, color: AppColors.divider),
            _buildOrderSummaryPair(
              pairedDetails[index][0],
              pairedDetails[index][1],
            ),
          ],
          Divider(height: 1, color: AppColors.divider),
          _buildOrderSummaryFullWidth(
            'Customization',
            _orderCustomizationSummary(),
            maxLines: 4,
          ),
          Divider(height: 1, color: AppColors.divider),
          _buildOrderSummaryPair(
            MapEntry('Special Instructions', instructionSummary),
            MapEntry('Delivery Address', _selectedAddressSummary()),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryPair(
    MapEntry<String, String> first,
    MapEntry<String, String> second,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildOrderSummaryMetric(first, rightPadding: 8)),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.divider,
          ),
          Expanded(child: _buildOrderSummaryMetric(second, leftPadding: 8)),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryFullWidth(
    String label,
    String value, {
    int maxLines = 2,
  }) {
    return _buildOrderSummaryMetric(MapEntry(label, value), maxLines: maxLines);
  }

  Widget _buildOrderSummaryMetric(
    MapEntry<String, String> item, {
    double leftPadding = 4,
    double rightPadding = 4,
    int maxLines = 3,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(leftPadding, 8, rightPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.key,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  String _orderCustomizationSummary() {
    String selected(String? value, TextEditingController otherDetails) {
      final choice = value?.trim() ?? '';
      if (choice.isEmpty) return '';
      if (choice == 'Other' && otherDetails.text.trim().isNotEmpty) {
        return otherDetails.text.trim();
      }
      return choice;
    }

    final parts = <String>[
      if (selected(_selectedNeckStyle, _neckController).isNotEmpty)
        'Neck: ${selected(_selectedNeckStyle, _neckController)}',
      if (selected(_selectedSleeveStyle, _sleeveStyleController).isNotEmpty)
        'Sleeve: ${selected(_selectedSleeveStyle, _sleeveStyleController)}',
      if (selected(_selectedBackDesign, _backDesignController).isNotEmpty)
        'Back: ${selected(_selectedBackDesign, _backDesignController)}',
      if (_selectedAlterationMargin != null)
        'Margin: $_selectedAlterationMargin',
      if (_selectedLiningPreference != null)
        'Lining: $_selectedLiningPreference',
    ];
    return parts.isEmpty ? 'No preferences selected' : parts.join(' · ');
  }

  String _orderInstructionSummary() {
    final parts = <String>[
      if (_notesController.text.trim().isNotEmpty) 'Text note added',
      if (_instructionAudioFile != null ||
          _draftInstructionMedia.any(
            (item) =>
                item['kind'] == 'audio' &&
                !_removedDraftInstructionMediaPaths.contains(
                  item['storagePath']?.toString(),
                ),
          ))
        'Voice note added',
      if (_instructionVideoFile != null ||
          _draftInstructionMedia.any(
            (item) =>
                item['kind'] == 'video' &&
                !_removedDraftInstructionMediaPaths.contains(
                  item['storagePath']?.toString(),
                ),
          ))
        'Video note added',
    ];
    return parts.isEmpty ? 'None added' : parts.join(' · ');
  }

  String _selectedAddressSummary() {
    if (_loadingDeliveryAddresses) return 'Loading saved addresses…';
    if (_usingResumeDraftDeliveryAddressSnapshot &&
        _resumeDraftDeliveryAddressSnapshot?.trim().isNotEmpty == true) {
      return 'Draft saved address';
    }
    for (final address in _deliveryAddresses) {
      if (address.addressId == _selectedDeliveryAddressId) {
        return address.dropdownLabel;
      }
    }
    return _deliveryAddresses.isEmpty
        ? 'Add a saved address to continue.'
        : 'Choose where the order should be delivered.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.estimateOnly
              ? 'AI Measurement & Fabric Estimation'
              : _showOrderForm
              ? 'Place New Stitching Order'
              : 'Smart Style Ideas',
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
      body: widget.estimateOnly
          ? _buildEstimateOnlyBody()
          : _showOrderForm
          ? _buildOrderFormBody(context)
          : _buildBrowseFirstBody(context),
      bottomNavigationBar: !widget.estimateOnly && _showOrderForm
          ? _buildOrderActionBar()
          : null,
    );
  }

  Widget _buildEstimateOnlyBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderNotice(
            'Create a guidance estimate only. This screen does not place or change a stitching order. For accurate fitting, please contact SuiSakhi Helpdesk or have a tailor confirm the measurements.',
          ),
          const SizedBox(height: 12),
          _buildAccordionSection(
            sectionKey: 'estimate-profile',
            title: 'Estimate For',
            subtitle: 'Choose the customer profile for this estimate.',
            icon: Icons.person_outline_rounded,
            child: _buildClientNameField(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'estimate-occasion-dress',
            title: 'Occasion & Dress Type',
            subtitle:
                '${_occasionLabel() ?? 'Daily Wear'} · $_selectedDressType',
            icon: Icons.event_available_outlined,
            isComplete: _occasionId != null && _selectedDressType.isNotEmpty,
            child: Column(
              children: [
                _buildOccasionSection(showHeading: false),
                const SizedBox(height: 14),
                _buildDressTypeSelector(showHeading: false),
              ],
            ),
          ),
          _buildAccordionSection(
            sectionKey: 'estimate-design-fabric',
            title: 'Design & Fabric',
            subtitle:
                _selectedTemplate?.title ??
                'Choose a catalog design and fabric.',
            icon: Icons.checkroom_outlined,
            isComplete: _selectedTemplate != null && _fabricChoice != null,
            child: _buildDesignLookSection(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'estimate-fit',
            title: 'Fit Preference',
            subtitle: 'Selected fit: $_selectedFit',
            icon: Icons.accessibility_new_rounded,
            isComplete: _selectedFit.isNotEmpty,
            child: _buildFitSelector(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'estimate-measurements',
            title: 'Measurement Source',
            subtitle: 'Review saved measurements or add a new estimate.',
            icon: Icons.straighten_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Measurements for this screen are used for guidance only.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (context, _) => _buildMeasurementSummary(),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (context, _) => _buildMeasurementActionsAndResults(),
                ),
              ],
            ),
          ),
          _buildSmartAssistSection(
            showFitAssistant: false,
            showTailorInstructions: false,
          ),
          const SizedBox(height: 12),
          _buildAiPricing(),
          if (widget.returnToOrder &&
              _garmentMeasurementEstimate != null &&
              _fabricEstimate != null &&
              _priceEstimate != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _returnEstimateToOrder,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Use estimate and return to order'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push(
              '/fabric-help?topic=measurement_help&question=I%20need%20help%20with%20my%20measurements%20and%20fit.',
            ),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Contact SuiSakhi Helpdesk for measurement help'),
          ),
        ],
      ),
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
        16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAccordionSection(
            sectionKey: 'order-profile',
            title: 'Order For (Profile)',
            subtitle:
                _selectedOrderPerson()?.name ?? 'Select a customer profile.',
            icon: Icons.person_outline_rounded,
            isComplete: _selectedOrderPerson() != null,
            child: _buildClientNameField(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'order-occasion-dress',
            title: 'Occasion & Dress Type',
            subtitle:
                '${_occasionLabel() ?? 'Daily Wear'} · $_selectedDressType',
            icon: Icons.event_available_outlined,
            isComplete: _occasionId != null && _selectedDressType.isNotEmpty,
            child: Column(
              children: [
                _buildOccasionSection(showHeading: false),
                const SizedBox(height: 14),
                _buildDressTypeSelector(showHeading: false),
              ],
            ),
          ),
          _buildAccordionSection(
            sectionKey: 'order-design-fabric',
            title: 'Design & Fabric',
            subtitle:
                _selectedTemplate?.title ??
                'Choose a catalog design and fabric.',
            icon: Icons.checkroom_outlined,
            isComplete: _selectedTemplate != null || _fabricChoice != null,
            child: _buildDesignLookSection(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'order-fit',
            title: 'Fit Preference',
            subtitle: 'Selected fit: $_selectedFit',
            icon: Icons.accessibility_new_rounded,
            isComplete: _selectedFit.isNotEmpty,
            child: _buildFitSelector(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'order-measurements',
            title: 'Measurements (Reference)',
            subtitle:
                _customerMeasurementProfileReference?.title ??
                _customerMeasurementReference?.title ??
                'Saved measurements are for Tailor review.',
            icon: Icons.straighten_outlined,
            isComplete:
                _customerMeasurementProfileReference != null ||
                _customerMeasurementReference != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All 22 customer measurement fields are shown. Green checks mark fields recommended for $_selectedDressType. Your Tailor will review and confirm fit details before cutting.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Saved measurements')),
                    const MeasurementUnitToggle(),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (context, _) => _buildMeasurementSummary(),
                ),
                const SizedBox(height: 12),
                _buildSavedMeasurementReferenceControl(),
              ],
            ),
          ),
          _buildCustomizationSection(),
          _buildAccordionSection(
            sectionKey: 'order-instructions',
            title: 'Special Instructions',
            subtitle: 'Add notes or a voice/video note for your Tailor.',
            icon: Icons.note_alt_outlined,
            isComplete:
                _notesController.text.trim().isNotEmpty ||
                _instructionAudioFile != null ||
                _instructionVideoFile != null ||
                _draftInstructionMedia.isNotEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotesSection(showHeading: false),
                const SizedBox(height: 14),
                _buildSmartAssistSection(showFabricStyling: false),
              ],
            ),
          ),
          _buildAccordionSection(
            sectionKey: 'order-delivery',
            title: 'Delivery / Visit Address',
            subtitle: _selectedAddressSummary(),
            icon: Icons.location_on_outlined,
            isComplete: _selectedDeliveryAddressId != null,
            child: _buildDeliveryAddressSection(showHeading: false),
          ),
          _buildAccordionSection(
            sectionKey: 'order-summary',
            title: 'Order Summary',
            subtitle: 'Review the order amount and advance terms.',
            icon: Icons.receipt_long_outlined,
            child: _buildAdvancePaymentSection(showHeading: false),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _saveDraftLoading || _placeOrderLoading
                      ? null
                      : () => unawaited(_saveOrderDraft()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border_rounded, size: 18),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _saveDraftLoading ? 'Saving…' : 'Save Draft',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _placeOrderLoading || _saveDraftLoading
                      ? null
                      : _placeOrderInApp,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _placeOrderLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 18),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Place Order',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: .25)),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(height: 1.4),
      ),
    );
  }

  Widget _buildAccordionSection({
    required String sectionKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    bool isComplete = false,
  }) {
    final expanded = _expandedSections.contains(sectionKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // A PageStorageKey here collides with scroll offsets saved by
            // TextFormField's internal Scrollables in the expanded content.
            // Keep the tile identity stable without sharing its PageStorage
            // slot with those descendants.
            key: ValueKey<String>('designer-section-$sectionKey'),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            initiallyExpanded: expanded,
            onExpansionChanged: (value) {
              setState(() {
                if (value) {
                  _expandedSections.add(sectionKey);
                } else {
                  _expandedSections.remove(sectionKey);
                }
              });
            },
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            title: Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                height: 1.25,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isComplete) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E9E4D),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
            children: [child],
          ),
        ),
      ),
    );
  }

  Widget _buildOccasionSection({bool showHeading = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text('Occasion / category', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
        ],
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

    return _buildAccordionSection(
      sectionKey: 'order-customization',
      title: 'Customization',
      subtitle: 'Neck, sleeve, back design, margin and lining preferences.',
      icon: Icons.design_services_outlined,
      isComplete:
          _selectedNeckStyle != null ||
          _selectedSleeveStyle != null ||
          _selectedBackDesign != null ||
          _selectedAlterationMargin != null ||
          _selectedLiningPreference != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            key: ValueKey(
              'alteration-margin-${_selectedAlterationMargin ?? 'unset'}',
            ),
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
      ),
    );
  }

  Widget _buildClientNameField({bool showHeading = true}) {
    if (_loadingOrderPeople) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text(
              widget.estimateOnly ? 'Estimate For' : 'Order For',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
          ],
          const LinearProgressIndicator(),
        ],
      );
    }

    if (_orderPeople.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text(
              widget.estimateOnly ? 'Estimate For' : 'Order For',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
          ],
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
        if (showHeading) ...[
          Text(
            widget.estimateOnly ? 'Estimate For' : 'Order For',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 8),
        ],
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
              _customerMeasurementProfileReference = null;
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
          widget.estimateOnly
              ? 'Measurements from this profile are used for this estimate only.'
              : 'This profile will be used for measurements and order history.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildDressTypeSelector({bool showHeading = true}) {
    final dressTypes = _dressTypes.contains(_selectedDressType)
        ? _dressTypes
        : [..._dressTypes, _selectedDressType];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text('Dress Type', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),
        ],
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

  Widget _buildFitSelector({bool showHeading = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text('Fit Preference', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),
        ],
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
            onPressed: () => context.push(
              '/fabric-help?topic=fabric_guidance&question=I%20need%20help%20choosing%20fabric%20for%20this%20design.',
            ),
            icon: const Icon(Icons.video_call_outlined, size: 18),
            label: const Text('Ask SuiSakhi Helpdesk about fabric'),
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
      _selectedDesignFromWishlist = false;
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

  Widget _buildDesignLookSection({
    bool approvedCatalogueOnly = false,
    bool showHeading = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            approvedCatalogueOnly ? 'Choose a Design' : 'Design Catalog',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            approvedCatalogueOnly
                ? 'Browse published free and paid designs. Preview the views, try your fabric and save favourites. No charge is collected while you explore.'
                : widget.estimateOnly
                ? 'Choose a published design, fabric and measurements to generate a guidance estimate.'
                : 'Browse published free and paid designs for this garment, preview the views and try a fabric photo. You can save a favourite or create a tailoring order when you are ready.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
        ],
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
          if (!widget.estimateOnly) ...[
            const SizedBox(height: 16),
            Text(
              'Fabric purchased for this order',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fabricPurchasedMetersController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. 3.5',
                suffixText: 'm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Leave blank if you have not purchased the fabric yet.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
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
                            : 'Showing published $_selectedDressType designs from the SuiSakhi catalog.',
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
      stream: CatalogueDesignService.watchPublishedDesigns(),
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
                'No published free or paid designs are available for $_selectedDressType yet.',
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
                                  color: Color(0xFFFCEAF1),
                                  child: Icon(Icons.image_outlined),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFFCEAF1),
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
                final fabricPreviewUrls =
                    option.fabricSelection?.previews
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
                                  color: Color(0xFFFCEAF1),
                                  child: Icon(Icons.image_outlined),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFFCEAF1),
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
                            selectedFromWishlist: true,
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
    return code == 'blouse' &&
        (design.garmentTypeCodes.contains('sareeBlouse') ||
            design.garmentTypeCodes.contains('saree blouse'));
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
      'saree blouse' => 'blouse',
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
      'sareeBlouse': 'Blouse',
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
    bool selectedFromWishlist = false,
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
      _selectedDesignFromWishlist = selectedFromWishlist;
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
              if (bundle.views.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Swipe to view all ${bundle.views.length} design views',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
    final savedPreviewViews =
        savedFabricSelection?.previews
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
                ? widget.estimateOnly
                      ? 'Choose a design from the SuiSakhi catalog before generating an estimate.'
                      : 'Choose a design from the SuiSakhi catalog before placing your order.'
                : widget.estimateOnly
                ? 'This original design is the tailoring reference for this estimate.'
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
                    'Browse free and premium designs for $_selectedDressType.',
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
            if (previewCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.swipe_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swipe to compare each fabric view with the original design.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (template.catalogueVersionId?.trim().isNotEmpty == true &&
                !_selectedDesignFromWishlist) ...[
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
    final recommended = GarmentMeasurementCatalog.recommendedNumbers(
      _selectedDressType,
    );
    final hasAnyMeasurement = GarmentMeasurementCatalog.all.any(
      (spec) => _measurementValueCmForOrder(spec) != null,
    );

    return Container(
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
          if (!hasAnyMeasurement) ...[
            Text(
              'No saved values are available yet. The Tailor can review and confirm measurements after accepting the order.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (recommended.isEmpty)
            Text(
              'No standard measurement recommendations are set for $_selectedDressType. All 22 fields are shown for review.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Recommended for $_selectedDressType',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          for (
            var index = 0;
            index < GarmentMeasurementCatalog.all.length;
            index++
          ) ...[
            _buildCustomerMeasurementReferenceRow(
              GarmentMeasurementCatalog.all[index],
              recommended.contains(GarmentMeasurementCatalog.all[index].number),
              unit,
            ),
            if (index < GarmentMeasurementCatalog.all.length - 1)
              const Divider(height: 14),
          ],
        ],
      ),
    );
  }

  double? _measurementValueCmForOrder(GarmentMeasurementSpec spec) {
    final profileReference = _customerMeasurementProfileReference;
    if (profileReference != null) {
      for (final entry in profileReference.values.entries) {
        if (GarmentMeasurementCatalog.forAnyKey(entry.key)?.number !=
            spec.number) {
          continue;
        }
        final value = double.tryParse(entry.value);
        if (value == null || value <= 0 || !value.isFinite) return null;
        final recordUnit =
            measurementUnitFromStorage(profileReference.unit) ??
            MeasurementUnit.cm;
        return recordUnit.toCm(value);
      }
      return null;
    }

    final body = _latestBodyMeasurementsForSuggestion;
    final controllerKey = switch (spec.number) {
      3 => 'Chest',
      5 => 'Waist',
      6 => 'Hip',
      10 => 'Sleeve Length',
      18 => 'Length',
      19 => 'Shoulder',
      _ => null,
    };
    if (controllerKey != null) {
      final raw = _measurementFields[controllerKey]?.text.trim() ?? '';
      final value = double.tryParse(raw);
      if (value != null && value > 0 && value.isFinite) {
        return _fieldsUnit.toCm(value);
      }
    }
    return switch (spec.number) {
      1 => body?.neck,
      3 => body?.chest,
      5 => body?.waist,
      6 => body?.hips,
      7 => body?.height,
      9 => body?.inseam,
      10 => body?.armLength,
      19 => body?.shoulder,
      _ => null,
    };
  }

  Widget _buildCustomerMeasurementReferenceRow(
    GarmentMeasurementSpec spec,
    bool isRecommended,
    MeasurementUnit unit,
  ) {
    final valueCm = _measurementValueCmForOrder(spec);
    final value = valueCm == null
        ? '—'
        : '${MeasurementFormat.cmToDisplayText(valueCm, unit)} ${unit.abbrev}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: isRecommended
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  )
                : Text(
                    spec.number.toString().padLeft(2, '0'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              spec.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isRecommended
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight: isRecommended ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: valueCm == null
                  ? AppColors.textHint
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementActionsAndResults() {
    if (!widget.estimateOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Need an estimate first?', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Open AI Measurement & Fabric Estimation to choose a measurement source, review fabric needs and get an estimate.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openFabricEstimate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate Dress Estimate'),
          ),
        ],
      );
    }

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
              onPressed: () async {
                final person = _selectedOrderPerson();

                if (person == null) {
                  await context.push('/measurement-context?purpose=estimate');
                  if (mounted) await _loadLatestMeasurementsForSelectedPerson();
                  return;
                }

                await context.push(
                  '/measurement-context'
                  '?purpose=estimate'
                  '&clientName=${Uri.encodeComponent(person.name)}'
                  '&personId=${Uri.encodeComponent(person.id)}'
                  '&relationship=${Uri.encodeComponent(person.relationship)}',
                );
                if (mounted) await _loadLatestMeasurementsForSelectedPerson();
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

  Future<void> _openFabricEstimate() async {
    final queryParameters = <String, String>{
      'occasion': _occasionId ?? OccasionCategory.dailyWear.name,
      'dressType': _selectedDressType,
      'fit': _selectedFit,
      'returnToOrder': '1',
    };
    final person = _selectedOrderPerson();
    if (person != null) {
      queryParameters['clientName'] = person.name;
      queryParameters['personId'] = person.id;
      queryParameters['relationship'] = person.relationship;
    }
    final template = _selectedTemplate;
    if (template?.catalogueVersionId?.trim().isNotEmpty == true) {
      queryParameters['designId'] = template!.id;
    }
    if (_fabricChoice?.trim().isNotEmpty == true) {
      queryParameters['fabric'] = _fabricChoice!.trim();
    }
    if (_fabricChoice == 'Other' &&
        _customFabricController.text.trim().isNotEmpty) {
      queryParameters['customFabric'] = _customFabricController.text.trim();
    }
    final route = Uri(
      path: '/fabric-estimation',
      queryParameters: queryParameters,
    ).toString();
    final result = await context.push<_FabricEstimateReturn>(route);
    if (!mounted) return;
    await _loadLatestMeasurementsForSelectedPerson();
    if (result == null || !mounted) return;
    setState(() {
      final designChanged =
          _selectedTemplate?.id != result.designTemplate?.id ||
          _selectedTemplate?.catalogueVersionId !=
              result.designTemplate?.catalogueVersionId;
      if (designChanged) {
        _pendingCustomerFabricSelection = null;
        _selectedWishlistFabricSelection = null;
        _selectedDesignFromWishlist = false;
      }
      _selectedDressType = result.dressType;
      _selectedFit = result.fit;
      _occasionId = result.occasionId;
      _fabricChoice = result.fabricChoice;
      _customFabricController.text = result.customFabric;
      _selectedTemplate = result.designTemplate;
      _garmentMeasurementEstimate = result.garmentMeasurements;
      _fabricEstimate = result.fabricEstimate;
      _priceEstimate = result.priceEstimate;
    });
  }

  void _returnEstimateToOrder() {
    final garmentMeasurements = _garmentMeasurementEstimate;
    final fabricEstimate = _fabricEstimate;
    final priceEstimate = _priceEstimate;
    if (garmentMeasurements == null ||
        fabricEstimate == null ||
        priceEstimate == null) {
      return;
    }
    context.pop(
      _FabricEstimateReturn(
        garmentMeasurements: garmentMeasurements,
        fabricEstimate: fabricEstimate,
        priceEstimate: priceEstimate,
        dressType: _selectedDressType,
        fit: _selectedFit,
        occasionId: _occasionId,
        fabricChoice: _fabricChoice,
        customFabric: _customFabricController.text.trim(),
        designTemplate: _selectedTemplate,
      ),
    );
  }

  Widget _buildSavedMeasurementReferenceControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _chooseSavedMeasurementReference,
          icon: const Icon(Icons.straighten_outlined),
          label: Text(
            _customerMeasurementReference == null
                ? 'Use Past Measurements'
                : 'Change Past Measurement Reference',
          ),
        ),
        Text(
          'Optional: add a past measurement record for Tailor review. Current measurements stay unchanged.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        if (_customerMeasurementReference != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
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
                  onPressed: () =>
                      setState(() => _customerMeasurementReference = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection({bool showHeading = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text('Special Instructions', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText:
                'Add notes for your tailor (e.g., add pockets, embroidery style, dupatta length...)',
          ),
        ),
        const SizedBox(height: 16),
        _buildInstructionMediaSection(),
      ],
    );
  }

  Future<void> _startInstructionAudioRecording() async {
    try {
      if (!await _instructionAudioRecorder.hasPermission()) {
        _showInstructionMediaMessage(
          'Microphone permission is required to record a voice note.',
        );
        return;
      }
      final path =
          '${Directory.systemTemp.path}/suisakhi_order_note_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _instructionAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recordingInstructionAudio = true;
        _instructionAudioSeconds = 0;
      });
      _instructionAudioTimer?.cancel();
      _instructionAudioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recordingInstructionAudio) return;
        setState(() => _instructionAudioSeconds++);
        if (_instructionAudioSeconds >= 60) {
          unawaited(_stopInstructionAudioRecording());
        }
      });
    } catch (_) {
      _showInstructionMediaMessage('Could not start the voice recording.');
    }
  }

  Future<void> _stopInstructionAudioRecording() async {
    if (!_recordingInstructionAudio) return;
    _instructionAudioTimer?.cancel();
    _instructionAudioTimer = null;
    try {
      final path = await _instructionAudioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _recordingInstructionAudio = false;
        _instructionAudioSeconds = 0;
        if (path != null && path.isNotEmpty) {
          _instructionAudioFile = XFile(path);
        }
      });
      if (path == null || path.isEmpty) {
        _showInstructionMediaMessage('The voice note could not be saved.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recordingInstructionAudio = false;
        _instructionAudioSeconds = 0;
      });
      _showInstructionMediaMessage('The voice note could not be saved.');
    }
  }

  Future<void> _transcribeInstructionAudio() async {
    if (_recordingInstructionAudio || _transcribingInstructionAudio) return;
    final savedAudioPath = _draftInstructionMedia
        .where((item) => item['kind'] == 'audio')
        .map((item) => item['storagePath']?.toString().trim() ?? '')
        .firstWhere((path) => path.isNotEmpty, orElse: () => '');
    if (_instructionAudioFile == null && savedAudioPath.isEmpty) {
      _showInstructionMediaMessage(
        'Record a voice note before converting it to text.',
      );
      return;
    }
    final customerUid = FirebaseAuth.instance.currentUser?.uid;
    if (customerUid == null) {
      _showInstructionMediaMessage('Sign in to transcribe a voice note.');
      return;
    }

    String? temporaryStoragePath;
    setState(() => _transcribingInstructionAudio = true);
    try {
      var storagePath = savedAudioPath;
      final audioFile = _instructionAudioFile;
      if (audioFile != null) {
        final uploaded = await OrderInstructionMediaService.uploadDraftMedia(
          customerUid: customerUid,
          draftId: 'transcription_${DateTime.now().microsecondsSinceEpoch}',
          existingMedia: const [],
          audioFile: audioFile,
        );
        storagePath = uploaded
            .map((item) => item['storagePath']?.toString() ?? '')
            .firstWhere((path) => path.isNotEmpty, orElse: () => '');
        temporaryStoragePath = storagePath.isEmpty ? null : storagePath;
      }
      if (storagePath.isEmpty) {
        throw StateError('The voice note could not be uploaded.');
      }

      final transcript =
          await OrderInstructionTranscriptionService.transcribeStoragePath(
            storagePath,
          );
      if (transcript.isEmpty) {
        _showInstructionMediaMessage(
          'No clear speech was detected. Try again or type your instructions.',
        );
        return;
      }
      if (!mounted) return;

      final transcriptController = TextEditingController(text: transcript);
      String? reviewedTranscript;
      try {
        reviewedTranscript = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Review voice-note text'),
            content: SizedBox(
              width: double.maxFinite,
              child: TextField(
                controller: transcriptController,
                minLines: 4,
                maxLines: 9,
                decoration: const InputDecoration(
                  labelText: 'Transcript',
                  helperText:
                      'Edit any words before adding them to instructions.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  transcriptController.text.trim(),
                ),
                child: const Text('Add to instructions'),
              ),
            ],
          ),
        );
      } finally {
        transcriptController.dispose();
      }
      if (reviewedTranscript == null || reviewedTranscript.trim().isEmpty) {
        return;
      }
      _addVoiceTranscriptToInstructions(reviewedTranscript.trim());
      _showInstructionMediaMessage(
        'Transcript added to Special Instructions. Please review it before ordering.',
      );
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[VoiceTranscription] callable failed (${error.code}): ${error.message}',
      );
      _showInstructionMediaMessage(
        _voiceTranscriptionMessage(error.code, details: error.details),
      );
    } on FirebaseAuthException catch (error) {
      debugPrint(
        '[VoiceTranscription] token refresh failed (${error.code}): ${error.message}',
      );
      _showInstructionMediaMessage(_voiceTranscriptionAuthMessage(error.code));
    } on FirebaseException catch (error) {
      debugPrint(
        '[VoiceTranscription] ${error.plugin} failed (${error.code}): ${error.message}',
      );
      if (error.plugin == 'firebase_app_check') {
        _showInstructionMediaMessage(
          _voiceTranscriptionMessage('failed-precondition'),
        );
      } else {
        _showInstructionMediaMessage(
          error.code == 'permission-denied' || error.code == 'unauthorized'
              ? 'SuiSakhi could not access this voice note. Please save the draft and try again.'
              : 'The voice note could not be uploaded for transcription. Check your connection and try again.',
        );
      }
    } catch (error) {
      debugPrint('[VoiceTranscription] unexpected failure: $error');
      _showInstructionMediaMessage(
        'Could not transcribe the voice note. Please try again or type your instructions.',
      );
    } finally {
      if (temporaryStoragePath != null) {
        await OrderInstructionMediaService.deletePaths([temporaryStoragePath]);
      }
      if (mounted) setState(() => _transcribingInstructionAudio = false);
    }
  }

  String _voiceTranscriptionMessage(String code, {Object? details}) {
    switch (code) {
      case 'not-found':
        return 'Voice-to-text is not available yet. The transcription service may need to be deployed.';
      case 'failed-precondition':
        return 'App verification failed. Please update the app or contact Helpdesk.';
      case 'unauthenticated':
        if (details is Map && details['tokenRefreshRetried'] == true) {
          return 'Your saved sign-in is active, but the transcription service could not verify this request. Please try again, or contact Helpdesk if it continues.';
        }
        return 'Please sign in again before converting the voice note to text.';
      case 'permission-denied':
        return 'SuiSakhi could not access this voice note. Please save the draft and try again.';
      case 'resource-exhausted':
        return 'Too many transcription attempts. Please try again in a few minutes.';
      case 'unavailable':
        return 'The voice-to-text service is unavailable. Please try again later.';
      default:
        return 'Could not transcribe the voice note. Please try again or type your instructions.';
    }
  }

  String _voiceTranscriptionAuthMessage(String code) {
    switch (code) {
      case 'user-disabled':
      case 'user-not-found':
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Your sign-in has expired. Please sign in again before converting the voice note to text.';
      case 'network-request-failed':
        return 'Could not refresh your saved sign-in. Check your internet connection and try again.';
      default:
        return 'Could not verify your saved sign-in. Please check your connection and try again.';
    }
  }

  void _addVoiceTranscriptToInstructions(String transcript) {
    const marker = 'Voice note transcript:';
    final current = _notesController.text.trim();
    final markerIndex = current.indexOf(marker);
    final transcriptBlock = '$marker\n$transcript';
    if (markerIndex < 0) {
      _notesController.text = current.isEmpty
          ? transcriptBlock
          : '$current\n\n$transcriptBlock';
    } else {
      final blockEnd = current.indexOf('\n\n', markerIndex);
      final before = current.substring(0, markerIndex).trimRight();
      final after = blockEnd < 0
          ? ''
          : current.substring(blockEnd + 2).trimLeft();
      _notesController.text = [
        if (before.isNotEmpty) before,
        transcriptBlock,
        if (after.isNotEmpty) after,
      ].join('\n\n');
    }
    _notesController.selection = TextSelection.collapsed(
      offset: _notesController.text.length,
    );
    setState(() {});
  }

  Future<void> _recordInstructionVideo() async {
    if (_recordingInstructionAudio || _transcribingInstructionAudio) return;
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (file == null || !mounted) return;
      final length = await File(file.path).length();
      if (length <= 0 || length > OrderInstructionMediaService.maxVideoBytes) {
        _showInstructionMediaMessage(
          'The video must be smaller than 30 MB. Please record a shorter clip.',
        );
        return;
      }
      setState(() => _instructionVideoFile = file);
    } catch (_) {
      _showInstructionMediaMessage('Could not record the video note.');
    }
  }

  void _removeInstructionMedia(String kind) {
    final file = kind == 'audio'
        ? _instructionAudioFile
        : _instructionVideoFile;
    if (file != null) {
      unawaited(() async {
        try {
          await File(file.path).delete();
        } catch (_) {
          // Temporary files are cleaned up by the platform when needed.
        }
      }());
    }
    final removedPaths = _draftInstructionMedia
        .where((item) => item['kind'] == kind)
        .map((item) => item['storagePath']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    _removedDraftInstructionMediaPaths.addAll(removedPaths);
    setState(() {
      if (kind == 'audio') {
        _instructionAudioFile = null;
      } else {
        _instructionVideoFile = null;
      }
      _draftInstructionMedia = _draftInstructionMedia
          .where((item) => item['kind'] != kind)
          .toList(growable: false);
    });
  }

  void _showInstructionMediaMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _previewInstructionMedia(String kind) async {
    final localFile = kind == 'audio'
        ? _instructionAudioFile
        : _instructionVideoFile;
    Map<String, dynamic>? savedMedia;
    for (final item in _draftInstructionMedia) {
      if (item['kind'] == kind) {
        savedMedia = item;
        break;
      }
    }
    if (localFile == null && savedMedia == null) return;
    final savedStoragePath = savedMedia == null
        ? null
        : savedMedia['storagePath']?.toString();

    await showDialog<void>(
      context: context,
      builder: (_) => OrderInstructionMediaPreviewDialog(
        kind: kind,
        localFilePath: localFile?.path,
        storagePath: localFile == null ? savedStoragePath : null,
      ),
    );
  }

  ButtonStyle _compactOptionalActionButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minimumSize: const Size(0, 48),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: AppTextStyles.labelLarge.copyWith(
        fontSize: 14,
        letterSpacing: 0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildInstructionMediaSection() {
    Map<String, dynamic>? savedItem(String kind) {
      for (final item in _draftInstructionMedia) {
        if (item['kind'] == kind) return item;
      }
      return null;
    }

    final audio = _instructionAudioFile ?? savedItem('audio')?['fileName'];
    final video = _instructionVideoFile ?? savedItem('video')?['fileName'];
    final audioLabel = _instructionAudioFile?.name ?? audio?.toString();
    final videoLabel = _instructionVideoFile?.name ?? video?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice or video note (optional)',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Record up to 60 seconds of audio or a 30-second video. The recording will be shared with the Tailor assigned to this order. Convert English, Hindi, or Marathi speech to editable text with Google Speech-to-Text, then review it before adding it to your instructions.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              style: _compactOptionalActionButtonStyle(),
              onPressed: _transcribingInstructionAudio
                  ? null
                  : _recordingInstructionAudio
                  ? _stopInstructionAudioRecording
                  : _startInstructionAudioRecording,
              icon: Icon(
                _recordingInstructionAudio
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
                size: 18,
              ),
              label: Text(
                _recordingInstructionAudio
                    ? 'Stop voice note · ${_instructionAudioSeconds}s'
                    : audioLabel == null
                    ? 'Record voice note'
                    : 'Replace voice note',
              ),
            ),
            OutlinedButton.icon(
              style: _compactOptionalActionButtonStyle(),
              onPressed:
                  _recordingInstructionAudio || _transcribingInstructionAudio
                  ? null
                  : _recordInstructionVideo,
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: Text(
                videoLabel == null ? 'Record video' : 'Replace video',
              ),
            ),
            if (audioLabel != null)
              OutlinedButton.icon(
                style: _compactOptionalActionButtonStyle(),
                onPressed:
                    _recordingInstructionAudio || _transcribingInstructionAudio
                    ? null
                    : _transcribeInstructionAudio,
                icon: _transcribingInstructionAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.text_fields_rounded, size: 18),
                label: Text(
                  _transcribingInstructionAudio
                      ? 'Converting voice note…'
                      : 'Convert voice note to text',
                ),
              ),
          ],
        ),
        if (audioLabel != null || videoLabel != null) ...[
          const SizedBox(height: 8),
          if (audioLabel != null) _instructionMediaChip('Voice note', 'audio'),
          if (videoLabel != null) _instructionMediaChip('Video note', 'video'),
        ],
      ],
    );
  }

  Widget _instructionMediaChip(String label, String kind) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == 'audio' ? Icons.mic_rounded : Icons.videocam_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.bodySmall),
            IconButton(
              tooltip: kind == 'audio' ? 'Listen to $label' : 'View $label',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  _recordingInstructionAudio || _transcribingInstructionAudio
                  ? null
                  : () => _previewInstructionMedia(kind),
              icon: Icon(
                kind == 'audio'
                    ? Icons.play_circle_outline_rounded
                    : Icons.play_arrow_rounded,
                size: 20,
              ),
            ),
            IconButton(
              tooltip: 'Remove $label',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed:
                  _recordingInstructionAudio || _transcribingInstructionAudio
                  ? null
                  : () => _removeInstructionMedia(kind),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
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
    final metadata =
        construction ??
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
          reason:
              'Ask the tailor to confirm movement and alteration allowance before cutting.',
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
          content: Text(
            'Your current selections look consistent with the available design guidance.',
          ),
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
                  Text(
                    'Review fit suggestions',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose only the changes you want. Saved measurements and the original catalogue design stay unchanged.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
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
                            : () => Navigator.pop(sheetContext, [
                                for (var i = 0; i < suggestions.length; i++)
                                  if (selectedIndexes.contains(i))
                                    suggestions[i],
                              ]),
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
      _fabricStyleApprovedContent = null;
    });
    final occ = _occasionLabel();
    final r = await SmartAssistService.fabricAndStylingTips(
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
        _fabricStyleApprovedContent = r.approvedContent;
        _fabricStyleContextKey = contextKey;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.text)));
    }
  }

  String _fabricGuidanceNoteBlock(String suggestionText) =>
      'Customer-approved fabric & styling guidance:\n${suggestionText.trim()}';

  void _addFabricSuggestionsToNotes() {
    final suggestionText = _fabricStyleApprovedContent;
    if (suggestionText == null ||
        suggestionText.trim().isEmpty ||
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
    final sanitizedDraft =
        SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(currentDraft);
    final r = await SmartAssistService.polishCustomerNotes(
      draft: currentDraft,
      dressType: _selectedDressType,
      fit: _selectedFit,
    );
    if (!mounted) return;
    setState(() => _smartAssistBusy = null);
    if (!r.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.text)));

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
    if (r.approvedContent.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.text)));
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
                Text(
                  'Your current instructions',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(currentDraft, style: AppTextStyles.bodySmall),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Suggested wording',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    SpeechPlaybackButton(text: r.approvedContent),
                  ],
                ),
                const SizedBox(height: 6),
                Text(r.text, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                if (sanitizedDraft.hadRedactions) ...[
                  Text(
                    'Sensitive lines were not sent to Smart Assist. If you approve, those original lines will be kept unchanged after the improved wording.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
      if (_notesController.text.trim() != currentDraft) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your instructions changed while reviewing. Run Improve Tailor Instructions again.',
            ),
          ),
        );
        return;
      }
      final approvedText = approvedTailorNotes(
        approved: true,
        suggestedContent: r.approvedContent,
        original: sanitizedDraft,
      );
      if (approvedText == null) return;
      _notesController.text = approvedText;
      setState(() {});
    }
  }

  Widget _buildSmartAssistSection({
    bool showFitAssistant = true,
    bool showFabricStyling = true,
    bool showTailorInstructions = true,
  }) {
    final contextKey = _smartAssistContextKey();
    final hasCurrentFitReview =
        showFitAssistant &&
        _fitAssistantSummary != null &&
        _fitAssistantContextKey == contextKey;
    final hasCurrentFabricTips =
        showFabricStyling &&
        _fabricStyleApprovedContent?.trim().isNotEmpty == true &&
        _fabricStyleContextKey == contextKey;
    final guidanceTypes = [
      if (showFitAssistant) 'fit',
      if (showFabricStyling) 'fabric and styling',
      if (showTailorInstructions) 'tailor-note',
    ];
    final fitReviewSpeechText = hasCurrentFitReview
        ? [
            _fitAssistantSummary!,
            for (final suggestion in _fitAssistantSuggestions)
              '${_fitSuggestionLabel(suggestion.field)}: ${suggestion.value}. ${suggestion.reason}',
          ].join(' ')
        : '';
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
              Text(
                'Smart Assist · Optional',
                style: AppTextStyles.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Get ${guidanceTypes.join(', ')} guidance for your selections. Review every suggestion; nothing changes until you approve it.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (showFitAssistant)
                OutlinedButton.icon(
                  style: _compactOptionalActionButtonStyle(),
                  onPressed: _smartAssistBusy != null
                      ? null
                      : _onDressFitAssistant,
                  icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                  label: const Text('Dress Fit Assistant'),
                ),
              if (showFabricStyling)
                OutlinedButton.icon(
                  style: _compactOptionalActionButtonStyle(),
                  onPressed: _smartAssistBusy != null
                      ? null
                      : _onFabricStyleTips,
                  icon: _smartAssistBusy == 'fabric'
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.style_outlined, size: 18),
                  label: Text(
                    _smartAssistBusy == 'fabric'
                        ? 'Getting tips…'
                        : 'Suggest Fabric & Styling',
                  ),
                ),
              if (showTailorInstructions)
                OutlinedButton.icon(
                  style: _compactOptionalActionButtonStyle(),
                  onPressed: _smartAssistBusy != null
                      ? null
                      : _onPolishNotesForTailor,
                  icon: _smartAssistBusy == 'polish'
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_note_rounded, size: 18),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fit review',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      SpeechPlaybackButton(text: fitReviewSpeechText),
                    ],
                  ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fabric & styling ideas',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      SpeechPlaybackButton(text: _fabricStyleAiText!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fabricStyleAiText!,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                  ),
                  if (!widget.estimateOnly) ...[
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
          Text(
            widget.estimateOnly ? 'Estimate Summary' : 'Order Estimate',
            style: AppTextStyles.headlineMedium,
          ),
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
              widget.estimateOnly
                  ? 'Generate a dress estimate above to see garment measurements, fabric needs and an estimated stitching price.'
                  : 'Use Generate Dress Estimate above to create garment, fabric and stitching estimates.',
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
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => context.push(
              '/fabric-help?topic=estimate_help&question=Please%20help%20me%20understand%20this%20fabric%20and%20stitching%20estimate.',
            ),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Ask SuiSakhi Helpdesk about this estimate'),
          ),
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
