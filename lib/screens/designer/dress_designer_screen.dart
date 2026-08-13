import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/measurement_unit.dart';
import '../../models/design_template.dart';
import '../../models/measurement.dart';
import '../../models/prd_catalog.dart';
import '../../services/claude_pricing_service.dart';
import '../../services/claude_smart_assistant_service.dart';
import '../../services/design_template_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_unit_toggle.dart';
import '../../services/order_draft_service.dart';

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

  @override
  State<DressDesignerScreen> createState() => _DressDesignerScreenState();
}

class _DressDesignerScreenState extends State<DressDesignerScreen> {
  String? _occasionId;
  String _selectedDressType = 'Kurti';
  bool _autoFillFromScan = true;
  //SUD
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<_OrderPerson> _orderPeople = [];
  String? _selectedOrderPersonId;
  bool _loadingOrderPeople = true;
  
  final List<_DesignerAddress> _deliveryAddresses = [];
  String? _selectedDeliveryAddressId;
  bool _loadingDeliveryAddresses = true;
  String? _deliveryAddressError;

  late final _clientNameController = TextEditingController(
    text: widget.initialClientName?.trim().isNotEmpty == true
        ? widget.initialClientName!.trim()
        : AppState.instance.displayName == 'Guest'
            ? ''
            : AppState.instance.displayName,
  );
  final _deliveryAddressController = TextEditingController();
  bool _aiLoading = false;
  PriceEstimate? _priceEstimate;

  /// null | 'fabric' | 'polish'
  String? _smartAssistBusy;
  String? _fabricStyleAiText;

  final _measurementFields = {
    'Chest': TextEditingController(text: '0'),
    'Waist': TextEditingController(text: '0'),
    'Hip': TextEditingController(text: '0'),
    'Shoulder': TextEditingController(text: '0'),
    'Length': TextEditingController(text: '0'),
    'Sleeve Length': TextEditingController(text: '0'),
  };

  final _dressTypes = [
    'Kurti',
    'Blouse',
    'Salwar Suit',
    'Lehenga',
    'Gown',
    'Kurta',
    'Shirt',
    'Sherwani',
  ];

  String _selectedFit = 'Regular';
  final _fitOptions = ['Slim', 'Regular', 'Loose'];

  final _notesController = TextEditingController();
  final _neckController = TextEditingController();
  final _sleeveStyleController = TextEditingController();
  final _backDesignController = TextEditingController();
  final _marginController = TextEditingController();
  bool _placeOrderLoading = false;
  bool _saveDraftLoading = false;
  String? _currentOrderDraftId;
  /// PRD Step 11 — advance 30–50%.
  int _advancePercent = 40;

  DesignTemplate? _selectedTemplate;
  String? _fabricChoice;
  Color _accentColor = AppColors.primary;

  /// Unit the numeric text fields are currently expressed in.
  MeasurementUnit _fieldsUnit = MeasurementUnit.cm;

  /// Avoid re-hydrating on unrelated [AppState] notifications.
  String? _measurementHydrationSignature;

  static const _fabricOptions = [
    'Cotton',
    'Silk',
    'Georgette',
    'Chiffon',
    'Linen',
    'Velvet',
    'Organza',
  ];

  static const _colorSwatches = <Color>[
    Color(0xFF5C35E5),
    Color(0xFF1A237E),
    Color(0xFF880E4F),
    Color(0xFF1B5E20),
    Color(0xFFB71C1C),
    Color(0xFF000000),
    Color(0xFFFFF8E1),
    Color(0xFF6A1B9A),
  ];

  String _colorHexRgb(Color c) {
    int ch(double x) => (x * 255.0).round().clamp(0, 255);
    final r = ch(c.r);
    final g = ch(c.g);
    final b = ch(c.b);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
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
        final accountId =
            await AppState.instance.fetchAccountIdForMobile(phone.trim());

        if (accountId != null && accountId.isNotEmpty) {
          final profiles =
              await AppState.instance.fetchActiveProfilesForAccount(accountId);

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

    String selectedId = _selectedOrderPersonId ?? 'self';

    final existingSelectedId = _selectedOrderPersonId?.trim();

    if (existingSelectedId != null &&
        existingSelectedId.isNotEmpty &&
        people.any((p) => p.id == existingSelectedId)) {
      selectedId = existingSelectedId;
    } else {
      final initialPersonId = widget.initialPersonId?.trim();
      final initialClientName = widget.initialClientName?.trim();

      if (initialPersonId != null &&
          initialPersonId.isNotEmpty &&
          people.any((p) => p.id == initialPersonId)) {
        selectedId = initialPersonId;
      } else if (initialClientName != null && initialClientName.isNotEmpty) {
        for (final p in people) {
          if (p.name.trim().toLowerCase() == initialClientName.toLowerCase()) {
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
          _deliveryAddressError = 'Unable to load addresses. Please sign in again.';
          _loadingDeliveryAddresses = false;
        });
        return;
      }

      final accountId =
          await AppState.instance.fetchAccountIdForMobile(phone.trim());

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
          .map(
            (doc) => _DesignerAddress.fromMap(
              doc.id,
              doc.data(),
            ),
          )
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

        final existingStillAvailable = existingSelectedId != null &&
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
        _deliveryAddressController.text =
            selectedAddress?.formattedAddress ?? '';

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

    final accountId =
        await AppState.instance.fetchAccountIdForMobile(phone.trim());

    if (accountId == null || accountId.isEmpty) {
      return null;
    }

    final profiles =
        await AppState.instance.fetchActiveProfilesForAccount(accountId);

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

    return {
      'accountId': accountId,
      'customerProfileId': customerProfileId,
    };
  }
 
    Future<void> _loadOrderDraft(String draftId) async {
    try {
      final doc = await _db.collection('order_drafts').doc(draftId).get();

      if (!doc.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft not found.'),
          ),
        );
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final status = (data['status'] ?? '').toString();
      if (status != 'draft') {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This draft is no longer active.'),
          ),
        );
        return;
      }

      final personId = data['personId']?.toString();
      final personName = data['personName']?.toString();
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

        if (personId != null && personId.isNotEmpty) {
          _selectedOrderPersonId = personId;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft loaded successfully'),
        ),
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
        const SnackBar(
          content: Text('Please select who this draft is for.'),
        ),
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
          content: Text('Please select a saved delivery address before saving draft.'),
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
          ? 'design_template'
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
        fabricChoice: _fabricChoice,
        designTemplateId: _selectedTemplate?.id,
        designTemplateTitle: _selectedTemplate?.title,
        designImageUrl: _selectedTemplate?.imageUrl,
        designSource: designSource,
        advancePercent: _advancePercent,
        occasionCategory: _occasionId,
        kidsFlow: widget.isKidsFlow,
      );

      if (!mounted) return;

      setState(() {
        _currentOrderDraftId = draftId;
        _saveDraftLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully'),
        ),
      );
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
    _loadOrderPeople();
    _loadDeliveryAddresses();
    _occasionId = widget.initialOccasionId ?? OccasionCategory.dailyWear.name;

    final orderDraftId = widget.initialOrderDraftId?.trim();
    if (orderDraftId != null && orderDraftId.isNotEmpty) {
      unawaited(_loadOrderDraft(orderDraftId));
    }

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
    if (_notesController.text.trim().isNotEmpty) {
      parts.add(_notesController.text.trim());
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

  String? _occasionLabel() {
    final id = _occasionId;
    if (id == null) return null;
    for (final o in OccasionCategory.values) {
      if (o.name == id) return o.displayName;
    }
    return null;
  }

  double _defaultPriceFromRates() {
    for (final r in AppState.instance.rates) {
      if (r.dressType == _selectedDressType) return r.basePrice;
    }
    return 350;
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

    setState(() => _placeOrderLoading = true);
    await AppState.instance.setProfileDeliveryAddress(addr);
    final measurements = _measurementsInCmForOrders();
    final selectedPerson = _selectedOrderPerson();

    if (_isIncompleteSelfProfile(selectedPerson)) {
      setState(() => _placeOrderLoading = false);
      await _showCompleteProfilePrompt();
      return;
    }

    final id = await OrderService.createCoreTailoringOrder(
      dressType: _selectedDressType,
      price: _defaultPriceFromRates(),
      fit: _selectedFit,
      measurements: measurements,
      notes: _composeDetailNotes(),
      clientName: _clientNameController.text.trim(),
      personId: selectedPerson?.id,
      personName: selectedPerson?.name,
      relationship: selectedPerson?.relationship,
      occasionCategory: _occasionId,
      kidsFlow: widget.isKidsFlow,
      advancePercent: _advancePercent,
      designTemplateId: _selectedTemplate?.id,
      designTemplateTitle: _selectedTemplate?.title,
      designImageUrl: _selectedTemplate?.imageUrl,
      fabricChoice: _fabricChoice,
      accentColorHex: _colorHexRgb(_accentColor),
      deliveryAddress: addr,
      fabricDescription: (_fabricChoice != null || _selectedTemplate != null)
          ? [
              if (_fabricChoice != null) _fabricChoice!,
              if (_selectedTemplate != null) 'Design: ${_selectedTemplate!.title}',
              'Accent: ${_colorHexRgb(_accentColor)}',
            ].join(' · ')
          : null,
    );
    if (!mounted) return;
    setState(() => _placeOrderLoading = false);

    if (id != null) {
      final measurementDraftId = widget.initialMeasurementDraftId?.trim();

      if (measurementDraftId != null && measurementDraftId.isNotEmpty) {
        unawaited(
          _db.collection('measurements').doc(measurementDraftId).set(
            {
              'status': 'order_created',
              'linkedOrderId': id,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ),
        );
      }

      if (_currentOrderDraftId != null &&
          _currentOrderDraftId!.trim().isNotEmpty) {
        unawaited(
          _db.collection('order_drafts').doc(_currentOrderDraftId!.trim()).set(
            {
              'status': 'converted_to_order',
              'linkedOrderId': id,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ),
        );
      }

      unawaited(AppState.instance
          .saveDressDesignerMeasurements(_allMeasurementsCmForStorage()));
          
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created — pay the advance online to confirm.'),
        ),
      );
      context.push('/checkout/$id');
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
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.secondary,
            ),
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
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery address', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Select where the completed order should be delivered.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
          ),
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
                      selectedAddress.dropdownLabel,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                selectedAddress.formattedAddress,
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
    final price = _defaultPriceFromRates();
    final adv = price * _advancePercent / 100.0;
    final bal = (price - adv).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advance payment', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '30–50% advance is paid online only (card, UPI, net banking) right after you place the order. Balance is due later per shop policy.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 30, label: Text('30%')),
            ButtonSegment(value: 40, label: Text('40%')),
            ButtonSegment(value: 50, label: Text('50%')),
          ],
          selected: {_advancePercent},
          onSelectionChanged: (s) =>
              setState(() => _advancePercent = s.first),
        ),
        const SizedBox(height: 10),
        Text(
          'Order ₹${price.toStringAsFixed(0)} · Advance ₹${adv.toStringAsFixed(0)} · '
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
        title: const Text('Design Your Dress'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
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
            _buildAutoFillToggle(),
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
                            'Measurements for This Order',
                            style: AppTextStyles.headlineMedium,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Review AI or saved measurements. You can adjust values before placing the order.',
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
              builder: (context, _) => _buildMeasurementInputs(),
            ),
            const SizedBox(height: 24),
            _buildCustomizationSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
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
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.label_rounded, size: 20, color: AppColors.primary),
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
          onChanged: (v) => setState(() => _occasionId = v),
        ),
      ],
    );
  }

  Widget _buildCustomizationSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Measurement customization', style: AppTextStyles.headlineMedium),
      subtitle: Text(
        'Neck, sleeves, back, margin (PRD Step 4)',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
      ),
      children: [
        TextField(
          controller: _neckController,
          decoration: const InputDecoration(
            labelText: 'Neck depth (front / back)',
            hintText: 'e.g. Front 7", back 8"',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sleeveStyleController,
          decoration: const InputDecoration(
            labelText: 'Sleeve style',
            hintText: 'Cap / half / full, embellishments',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _backDesignController,
          decoration: const InputDecoration(
            labelText: 'Back design',
            hintText: 'Deep / closed / dori',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _marginController,
          decoration: const InputDecoration(
            labelText: 'Margin for alteration',
            hintText: 'Extra seam allowance',
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
            });
          },
        ),
        const SizedBox(height: 6),
        Text(
          'This profile will be used for measurements and order history.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildDressTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dress Type', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dressTypes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final selected = _selectedDressType == _dressTypes[i];
              return GestureDetector(
                onTap: () => setState(() => _selectedDressType = _dressTypes[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    _dressTypes[i],
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAutoFillToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _autoFillFromScan
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _autoFillFromScan ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_fix_high_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-fill from Body Scan', style: AppTextStyles.titleMedium),
                Text('Use your camera measurements',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(
            value: _autoFillFromScan,
            onChanged: (v) => setState(() => _autoFillFromScan = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
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
                  onTap: () => setState(() => _selectedFit = fit),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      fit,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: selected ? Colors.white : AppColors.textSecondary,
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

  Widget _buildDesignLookSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Design, fabric & look preview', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Pick an owner-uploaded flat, then fabric and colour. Preview tints the sketch — not photo-real try-on.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<DesignTemplate>>(
          stream: DesignTemplateService.watchTemplates(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Could not load design images.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final templates = snap.data!;
            if (templates.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No design flats yet. Your tailor can add them under Owner → Dress designs. You can still place an order.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                ),
              );
            }
            return SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final t = templates[i];
                  final sel = _selectedTemplate?.id == t.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTemplate = t),
                    child: Container(
                      width: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.divider,
                          width: sel ? 2.5 : 1,
                        ),
                        color: AppColors.surface,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: t.imageUrl.isEmpty
                                ? ColoredBox(
                                    color: AppColors.surfaceVariant,
                                    child: Icon(Icons.image_not_supported_outlined,
                                        color: AppColors.textHint, size: 28),
                                  )
                                : Image.network(
                                    t.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => ColoredBox(
                                      color: AppColors.surfaceVariant,
                                      child: Icon(Icons.broken_image_outlined,
                                          color: AppColors.textHint),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelMedium.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Fabric', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _fabricOptions.map((f) {
            final on = _fabricChoice == f;
            return FilterChip(
              label: Text(f),
              selected: on,
              onSelected: (_) => setState(() => _fabricChoice = on ? null : f),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Accent colour', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colorSwatches.map((sw) {
            final on = _accentColor == sw;
            return GestureDetector(
              onTap: () => setState(() => _accentColor = sw),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: sw,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.divider,
                    width: on ? 3 : 1,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _buildLookPreviewCard(),
      ],
    );
  }

  Future<void> _showDesignPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final h = MediaQuery.sizeOf(sheetCtx).height * 0.72;
        return SafeArea(
          child: SizedBox(
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Select a design',
                    style: AppTextStyles.headlineMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pick a design flat from your shop. You can still change fabric and accent colour above.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<DesignTemplate>>(
                    stream: DesignTemplateService.watchTemplates(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load designs. Check your connection.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textHint),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final templates = snap.data!;
                      if (templates.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No design flats yet. Your tailor can add them under '
                            'Owner → Dress designs. You can still place an order.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textHint),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: templates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = templates[i];
                          final sel = _selectedTemplate?.id == t.id;
                          return Material(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() => _selectedTemplate = t);
                                Navigator.pop(sheetCtx);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: t.imageUrl.isEmpty
                                            ? ColoredBox(
                                                color: AppColors.surfaceVariant,
                                                child: Icon(
                                                  Icons.image_not_supported_outlined,
                                                  color: AppColors.textHint,
                                                ),
                                              )
                                            : Image.network(
                                                t.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    ColoredBox(
                                                  color:
                                                      AppColors.surfaceVariant,
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: AppColors.textHint,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        t.title,
                                        style: AppTextStyles.titleMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (sel)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                        size: 26,
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
  }

  Widget _buildLookPreviewCard() {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final photoUrl = AppState.instance.profile?.photoUrl;
        final template = _selectedTemplate;
        final hasFlat =
            template != null && template.imageUrl.trim().isNotEmpty;

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
              Text('Your look preview', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                hasFlat
                    ? 'Your photo + tinted design flat (${_colorHexRgb(_accentColor)}). Tap the design to change it.'
                    : 'Tap the box on the right to choose a design, or use the thumbnails above.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(
                            photoUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _previewAvatarFallback(),
                          )
                        : _previewAvatarFallback(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasFlat
                            ? Material(
                                color: AppColors.surfaceVariant,
                                child: InkWell(
                                  onTap: _showDesignPickerSheet,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      _accentColor.withValues(alpha: 0.48),
                                      BlendMode.srcATop,
                                    ),
                                    child: Image.network(
                                      template.imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => ColoredBox(
                                        color: AppColors.surfaceVariant,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: AppColors.textHint,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Material(
                                color: AppColors.surfaceVariant,
                                child: InkWell(
                                  onTap: _showDesignPickerSheet,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 36,
                                            color: AppColors.primary
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Tap to select a design',
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Opens list of design flats',
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color: AppColors.textHint),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _previewAvatarFallback() {
    return Container(
      width: 76,
      height: 76,
      color: AppColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        AppState.instance.initials,
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _buildMeasurementInputs() {
    final u = AppState.instance.measurementUnit;
    final step = MeasurementFormat.stepDisplay(u);
    final suffix = u.abbrev;
    String fmtNum(double v) =>
        u == MeasurementUnit.cm ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
    return Column(
      children: _measurementFields.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  style: AppTextStyles.titleMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: entry.value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    suffixText: suffix,
                    suffixStyle: AppTextStyles.bodySmall,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _SmallIconBtn(
                    icon: Icons.remove,
                    onTap: () {
                      final val = double.tryParse(entry.value.text) ?? 0;
                      if (val > step) {
                        entry.value.text = fmtNum(val - step);
                      } else if (val > 0) {
                        entry.value.text = fmtNum(0);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _SmallIconBtn(
                    icon: Icons.add,
                    onTap: () {
                      final val = double.tryParse(entry.value.text) ?? 0;
                      entry.value.text = fmtNum(val + step);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Special Instructions', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
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

  Future<void> _onFabricStyleTips() async {
    setState(() {
      _smartAssistBusy = 'fabric';
      _fabricStyleAiText = null;
    });
    final occ = _occasionLabel();
    final r = await ClaudeSmartAssistantService.fabricAndStylingTips(
      dressType: _selectedDressType,
      occasionLabel: (occ == null || occ.isEmpty) ? 'General' : occ,
      fit: _selectedFit,
      fabricChoice: _fabricChoice,
      designTemplateTitle: _selectedTemplate?.title,
      accentColorHex: _colorHexRgb(_accentColor),
    );
    if (!mounted) return;
    setState(() => _smartAssistBusy = null);
    if (r.success) {
      setState(() => _fabricStyleAiText = r.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.text)));
    }
  }

  Future<void> _onPolishNotesForTailor() async {
    setState(() => _smartAssistBusy = 'polish');
    final r = await ClaudeSmartAssistantService.polishCustomerNotes(
      draft: _notesController.text,
      dressType: _selectedDressType,
      fit: _selectedFit,
    );
    if (!mounted) return;
    setState(() => _smartAssistBusy = null);
    if (!r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.text)));
      return;
    }
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Polished notes'),
        content: SingleChildScrollView(
          child: Text(r.text, style: AppTextStyles.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace notes'),
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
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Text('Smart assist', style: AppTextStyles.headlineMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Fabric & styling ideas and clearer notes for your tailor.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
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
                      : 'Fabric & style tips',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _smartAssistBusy != null ? null : _onPolishNotesForTailor,
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
                      : 'Polish notes for tailor',
                ),
              ),
            ],
          ),
          if (_fabricStyleAiText != null) ...[
            const SizedBox(height: 14),
            Text(
              _fabricStyleAiText!,
              style: AppTextStyles.bodySmall.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _getAiPrice() async {
    setState(() {
      _aiLoading = true;
      _priceEstimate = null;
    });
    final measurements = _measurementsInCmForOrders();
    final result = await ClaudePricingService.estimate(
      dressType: _selectedDressType,
      fit: _selectedFit,
      measurements: measurements,
      notes: _composeDetailNotes(),
      shopRates: AppState.instance.rates,
    );
    if (mounted) {
      setState(() {
        _priceEstimate = result;
        _aiLoading = false;
      });
    }
  }

  Widget _buildAiPricing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Price Estimation',
                style: AppTextStyles.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _aiLoading ? null : _getAiPrice,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Get estimate',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        if (_priceEstimate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _priceEstimate!.success
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _priceEstimate!.success
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _priceEstimate!.success
                      ? Icons.auto_awesome_rounded
                      : Icons.info_outline_rounded,
                  color: _priceEstimate!.success
                      ? AppColors.success
                      : AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _priceEstimate!.text,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
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
  final String state;
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
    required this.state,
    required this.pincode,
    required this.isDefault,
  });

  factory _DesignerAddress.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return _DesignerAddress(
      addressId: data['addressId']?.toString() ?? id,
      addressType: data['addressType']?.toString() ?? 'Home',
      name: data['name']?.toString() ?? '',
      mobileNumber: data['mobileNumber']?.toString() ?? '',
      addressLine1: data['addressLine1']?.toString() ?? '',
      addressLine2: data['addressLine2']?.toString() ?? '',
      landmark: data['landmark']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
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

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}