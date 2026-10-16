import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/garment_measurement_catalog.dart';
import '../../services/customer_measurement_history_service.dart';
import '../../services/measurement_draft_service.dart';
import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class MeasurementContextScreen extends StatefulWidget {
  const MeasurementContextScreen({super.key});

  @override
  State<MeasurementContextScreen> createState() =>
      _MeasurementContextScreenState();
}

class _MeasurementContextScreenState extends State<MeasurementContextScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  String? _accountId;
  String? _customerProfileId;
  String? _initialPersonId;
  String? _initialClientName;
  String? _initialRelationship;

  final List<_MeasurementPerson> _people = [];
  _MeasurementPerson? _selectedPerson;
  final Map<String, TextEditingController> _manualControllers = {
    for (final spec in GarmentMeasurementCatalog.all)
      spec.key: TextEditingController(),
  };
  final TextEditingController _manualNoteController = TextEditingController();

  String _selectedMethod = 'ai_camera';
  String _manualUnit = 'cm';
  bool _savingReference = false;

  static const List<_MeasurementMethod> _methods = [
    _MeasurementMethod(
      id: 'ai_camera',
      title: 'AI Camera Measurement',
      subtitle: 'Use existing camera/body scan flow',
      icon: Icons.camera_alt_outlined,
    ),
    _MeasurementMethod(
      id: 'manual',
      title: 'Enter Manually',
      subtitle: 'Enter any of the 22 saved measurement fields',
      icon: Icons.edit_note_outlined,
    ),
    _MeasurementMethod(
      id: 'video_call',
      title: 'Video Call with Tailor',
      subtitle: 'A tailor will be assigned automatically when you place an order',
      icon: Icons.video_call_outlined,
    ),
    _MeasurementMethod(
      id: 'home_visit',
      title: 'Home Visit',
      subtitle: 'A measurement partner will be assigned automatically when you place an order',
      icon: Icons.home_work_outlined,
    ),
    _MeasurementMethod(
      id: 'old_dress',
      title: 'Old Dress Reference',
      subtitle: 'Choose a previous order and keep its image and measurement reference',
      icon: Icons.checkroom_outlined,
    ),
    _MeasurementMethod(
      id: 'history',
      title: 'All Measurement History',
      subtitle: 'View the latest 10 saved or tailor-confirmed measurements',
      icon: Icons.history_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final params = GoRouterState.of(context).uri.queryParameters;

    _initialPersonId ??= params['personId'];
    _initialClientName ??= params['clientName'];
    _initialRelationship ??= params['relationship'];
  }

  @override
  void dispose() {
    for (final controller in _manualControllers.values) {
      controller.dispose();
    }
    _manualNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = AppState.instance.profile;
      final customerName = profile?.name.trim().isNotEmpty == true
          ? profile!.name.trim()
          : AppState.instance.displayName;

      final people = <_MeasurementPerson>[
        _MeasurementPerson(
          id: 'self',
          name: customerName,
          relationship: 'Self',
          isSelf: true,
        ),
      ];

      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone == null || phone.trim().isEmpty) {
        setState(() {
          _people
            ..clear()
            ..addAll(people);
          _selectedPerson = people.first;
          _loading = false;
        });
        return;
      }

      final accountId =
          await AppState.instance.fetchAccountIdForMobile(phone.trim());

      if (accountId == null || accountId.isEmpty) {
        setState(() {
          _people
            ..clear()
            ..addAll(people);
          _selectedPerson = people.first;
          _loading = false;
        });
        return;
      }

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

      if (customerProfileId != null && customerProfileId.trim().isNotEmpty) {
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
            _MeasurementPerson(
              id: doc.id,
              name: data['name']?.toString() ?? 'Family Member',
              relationship: data['relationship']?.toString() ?? 'Other',
              isSelf: false,
            ),
          );
        }
      }

      final initialPersonId = _initialPersonId?.trim();
      final initialClientName = _initialClientName?.trim();

      _MeasurementPerson selectedPerson = people.first;

      if (initialPersonId != null &&
          initialPersonId.isNotEmpty &&
          people.any((p) => p.id == initialPersonId)) {
        selectedPerson = people.firstWhere((p) => p.id == initialPersonId);
      } else if (initialClientName != null && initialClientName.isNotEmpty) {
        for (final p in people) {
          if (p.name.trim().toLowerCase() == initialClientName.toLowerCase()) {
            selectedPerson = p;
            break;
          }
        }
      }

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;

        _people
          ..clear()
          ..addAll(people);
        _selectedPerson = selectedPerson;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load measurement context. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _continue() async {
    final person = _selectedPerson;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (person == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a person for measurement'),
        ),
      );
      return;
    }

    if (accountId == null || customerProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to continue. Please try again.'),
        ),
      );
      return;
    }

    switch (_selectedMethod) {
      case 'ai_camera':
        final draftId = await MeasurementDraftService.createDraft(
          accountId: accountId,
          customerProfileId: customerProfileId,
          personId: person.id,
          personName: person.name,
          relationship: person.relationship,
          source: _selectedMethod,
        );

        if (!mounted) return;

        context.push(
          '/camera'
          '?draftId=${Uri.encodeComponent(draftId)}'
          '&clientName=${Uri.encodeComponent(person.name)}'
          '&personId=${Uri.encodeComponent(person.id)}'
          '&relationship=${Uri.encodeComponent(person.relationship)}',
        );
        break;

      case 'manual':
        await _showManualMeasurementEntry(person);
        break;

      case 'history':
        await _showMeasurementHistory(person);
        break;

      case 'old_dress':
        await _showOldDressReferences(person);
        break;

      case 'video_call':
      case 'home_visit':
        await _showAutomaticAssignmentInfo();
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a measurement method.'),
          ),
        );
    }
  }

  Future<void> _showAutomaticAssignmentInfo() async {
    final isHomeVisit = _selectedMethod == 'home_visit';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHomeVisit ? 'Home visit' : 'Video call with tailor'),
        content: Text(
          'When you place your tailoring order, the app will automatically assign an available ${isHomeVisit ? 'measurement partner for a home visit' : 'tailor for a video measurement'} based on your service area. You do not need to book the partner here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualMeasurementEntry(_MeasurementPerson person) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            20,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter measurements', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'For ${person.name}. These are saved as your reference only; the Tailor confirms final measurements.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cm', label: Text('cm')),
                    ButtonSegment(value: 'in', label: Text('in')),
                  ],
                  selected: {_manualUnit},
                  onSelectionChanged: (selection) => setSheetState(
                    () => _manualUnit = selection.first,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final spec in GarmentMeasurementCatalog.all)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: TextField(
                            controller: _manualControllers[spec.key],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: spec.key,
                              suffixText: _manualUnit,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      TextField(
                        controller: _manualNoteController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Reference note (optional)',
                          hintText: 'Add a note for your own reference',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _savingReference
                        ? null
                        : () => _saveManualReference(
                            person,
                            setSheetState,
                            context,
                          ),
                    icon: _savingReference
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save customer reference'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveManualReference(
    _MeasurementPerson person,
    StateSetter setSheetState,
    BuildContext sheetContext,
  ) async {
    final values = <String, double>{};
    for (final spec in GarmentMeasurementCatalog.all) {
      final raw = _manualControllers[spec.key]!.text.trim();
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      final maximum = _manualUnit == 'cm' ? 500 : 200;
      if (value == null || !value.isFinite || value <= 0 || value > maximum) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check ${spec.label}; enter a valid $_manualUnit value.')),
        );
        return;
      }
      values[spec.key] = value;
    }
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one measurement.')),
      );
      return;
    }
    final saved = await _saveReferenceRecord(
      person: person,
      source: 'manual_customer_reference',
      values: values,
      unit: _manualUnit,
      title: 'Manual customer reference',
      note: _manualNoteController.text.trim(),
      setSaving: (saving) {
        if (sheetContext.mounted) {
          setSheetState(() => _savingReference = saving);
        }
      },
    );
    if (saved && sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  Future<void> _showMeasurementHistory(_MeasurementPerson person) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final accountId = _accountId;
    if (uid == null || accountId == null) {
      _showLoadError();
      return;
    }
    try {
      final history = await CustomerMeasurementHistoryService.loadHistory(
        customerUid: uid,
        accountId: accountId,
        personId: person.id,
        personName: person.name,
        limit: 10,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (sheetContext) => _HistorySheet(
          records: history,
          onUse: (record) async {
            final saved = await _saveReferenceRecord(
              person: person,
              source: 'previous_measurement_reference',
              values: _numericValues(record.values),
              unit: record.unit,
              title: record.title,
              note: 'Saved from measurement history: ${record.title}',
              referenceImageUrl: record.referenceImageUrl,
              sourceOrderId: record.sourceOrderId,
              referenceOfId: record.id,
              setSaving: (_) {},
            );
            if (saved && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        ),
      );
    } catch (_) {
      _showLoadError();
    }
  }

  Future<void> _showOldDressReferences(_MeasurementPerson person) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showLoadError();
      return;
    }
    try {
      final references =
          await CustomerMeasurementHistoryService.loadDressReferences(
        customerUid: uid,
        personId: person.id,
        personName: person.name,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (sheetContext) => _DressReferenceSheet(
          references: references,
          onSave: (reference) async {
            final saved = await _saveReferenceRecord(
              person: person,
              source: 'old_dress_reference',
              values: _numericValues(reference.values),
              unit: reference.unit,
              title: reference.title,
              note: 'Old dress reference from order ${reference.orderId}',
              referenceImageUrl: reference.imageUrl,
              sourceOrderId: reference.orderId,
              setSaving: (_) {},
            );
            if (saved && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        ),
      );
    } catch (_) {
      _showLoadError();
    }
  }

  Map<String, double> _numericValues(Map<String, String> values) => {
        for (final entry in values.entries)
          if (double.tryParse(entry.value) case final value? when value > 0)
            entry.key: value,
      };

  Future<bool> _saveReferenceRecord({
    required _MeasurementPerson person,
    required String source,
    required Map<String, double> values,
    required String unit,
    required String title,
    required String note,
    String? referenceImageUrl,
    String? sourceOrderId,
    String? referenceOfId,
    required void Function(bool saving) setSaving,
  }) async {
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;
    if (accountId == null || customerProfileId == null) {
      _showLoadError();
      return false;
    }
    setSaving(true);
    try {
      final ref = _db.collection('measurements').doc();
      await ref.set({
        'draftId': ref.id,
        'accountId': accountId,
        'customerProfileId': customerProfileId,
        'personId': person.id,
        'personName': person.name,
        'relationship': person.relationship,
        'source': source,
        'status': 'customer_reference',
        'referenceOnly': true,
        'measurementValues': values,
        'measurementUnit': unit,
        'customerNote': note,
        'referenceTitle': title,
        if (referenceImageUrl?.trim().isNotEmpty == true)
          'referenceImageUrl': referenceImageUrl!.trim(),
        if (sourceOrderId?.trim().isNotEmpty == true)
          'sourceOrderId': sourceOrderId!.trim(),
        if (referenceOfId?.trim().isNotEmpty == true)
          'referenceOfId': referenceOfId!.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer reference saved.')),
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save this reference. Please try again.'),
          ),
        );
      }
      return false;
    } finally {
      setSaving(false);
    }
  }

  void _showLoadError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load this information. Please try again.')),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Measurement'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _InfoCard(),
                    const SizedBox(height: 20),

                    const _SectionTitle(title: 'Measurement For'),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Select the person whose measurements you want to capture.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                    for (final person in _people)
                      _PersonCard(
                        person: person,
                        selected: _selectedPerson?.id == person.id,
                        onTap: () {
                          setState(() {
                            _selectedPerson = person;
                          });
                        },
                      ),

                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Select Measurement Method'),
                    for (final method in _methods)
                      _MethodCard(
                        method: method,
                        selected: _selectedMethod == method.id,
                        onTap: () {
                          setState(() {
                            _selectedMethod = method.id;
                          });
                        },
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _continue,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}

class _MeasurementPerson {
  final String id;
  final String name;
  final String relationship;
  final bool isSelf;

  const _MeasurementPerson({
    required this.id,
    required this.name,
    required this.relationship,
    required this.isSelf,
  });
}

class _MeasurementMethod {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _MeasurementMethod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFF3EAFB),
            child: Icon(
              Icons.straighten_outlined,
              color: Color(0xFF7B3FB2),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your saved measurements and references are for your guidance. Customer-entered values do not replace the final measurement confirmed by your Tailor or measurement partner.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final _MeasurementPerson person;
  final bool selected;
  final VoidCallback onTap;

  const _PersonCard({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      icon: person.isSelf ? Icons.person_outline : Icons.family_restroom,
      title: person.name,
      subtitle: person.relationship,
    );
  }
}

class _MethodCard extends StatelessWidget {
  final _MeasurementMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      icon: method.icon,
      title: method.title,
      subtitle: method.subtitle,
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFF3EAFB) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE6DDF1),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      selected ? AppColors.primary : const Color(0xFFF3EAFB),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF7B3FB2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.records, required this.onUse});

  final List<CustomerMeasurementRecord> records;
  final ValueChanged<CustomerMeasurementRecord> onUse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All Measurement History', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Latest 10 records. Tailor-confirmed values remain the final fit reference.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text('No saved measurement history is available.'),
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final entries = record.values.entries.take(4).toList();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.title, style: AppTextStyles.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDate(record.capturedAt)} · ${_measurementStatusLabel(record)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                              if (entries.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  entries
                                      .map((entry) => '${_shortLabel(entry.key)}: ${entry.value} ${record.unit}')
                                      .join('   ·   '),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                              if (record.values.length > entries.length)
                                Text(
                                  '+ ${record.values.length - entries.length} more measurements',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => onUse(record),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: const Text('Keep as customer reference'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DressReferenceSheet extends StatelessWidget {
  const _DressReferenceSheet({
    required this.references,
    required this.onSave,
  });

  final List<CustomerDressReference> references;
  final ValueChanged<CustomerDressReference> onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Old Dress Reference', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Choose a previous order to keep its garment image and any saved measurements as your reference.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: references.isEmpty
                  ? const Center(
                      child: Text('No previous orders are available for this person.'),
                    )
                  : ListView.separated(
                      itemCount: references.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final reference = references[index];
                        final image = reference.imageUrl;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 76,
                                  height: 92,
                                  child: image?.isNotEmpty == true
                                      ? Image.network(
                                          image!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) =>
                                              _dressPlaceholder(),
                                        )
                                      : _dressPlaceholder(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reference.title, style: AppTextStyles.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${reference.date == null ? 'Previous order' : _formatDate(reference.date!)} · ${reference.status}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                    Text(
                                      reference.values.isEmpty
                                          ? 'No saved measurements on this order'
                                          : '${reference.values.length} saved measurement fields',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    TextButton.icon(
                                      onPressed: () => onSave(reference),
                                      icon: const Icon(Icons.bookmark_add_outlined),
                                      label: const Text('Keep this reference'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _dressPlaceholder() => Container(
      color: const Color(0xFFF3EAFB),
      child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _shortLabel(String key) {
  final label = key.replaceFirst(RegExp(r'^\s*\d+\s*[·.\-:]?\s*'), '');
  return label.length > 22 ? '${label.substring(0, 19)}…' : label;
}

String _measurementStatusLabel(CustomerMeasurementRecord record) {
  if (record.isCustomerReference) return 'Customer reference';
  if (record.source == 'partner_confirmed') return 'Tailor confirmed';
  if (record.source == 'ai_camera') return 'AI estimate · review needed';
  return 'Needs confirmation';
}
