import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  final List<_MeasurementPerson> _people = [];
  _MeasurementPerson? _selectedPerson;

  String _selectedMethod = 'ai_camera';

  static const List<_MeasurementMethod> _methods = [
    _MeasurementMethod(
      id: 'ai_camera',
      title: 'AI Camera Measurement',
      subtitle: 'Use existing camera/body scan flow',
      icon: Icons.camera_alt_outlined,
    ),
    _MeasurementMethod(
      id: 'design_existing',
      title: 'Design from Measurements',
      subtitle: 'Use existing dress designer flow',
      icon: Icons.design_services_outlined,
    ),
    _MeasurementMethod(
      id: 'manual',
      title: 'Enter Manually',
      subtitle: 'Manual measurement entry - coming soon',
      icon: Icons.edit_note_outlined,
    ),
    _MeasurementMethod(
      id: 'video_call',
      title: 'Video Call with Tailor',
      subtitle: 'Remote guided measurement - coming soon',
      icon: Icons.video_call_outlined,
    ),
    _MeasurementMethod(
      id: 'home_visit',
      title: 'Home Visit',
      subtitle: 'Measurement partner visit - coming soon',
      icon: Icons.home_work_outlined,
    ),
    _MeasurementMethod(
      id: 'nearest_tailor',
      title: 'Nearest Tailor for Measurement',
      subtitle: 'Measurement only, not stitching assignment',
      icon: Icons.location_on_outlined,
    ),
    _MeasurementMethod(
      id: 'old_dress',
      title: 'Old Dress Reference',
      subtitle: 'Upload/send old dress reference - coming soon',
      icon: Icons.checkroom_outlined,
    ),
    _MeasurementMethod(
      id: 'history',
      title: 'Use Previous Measurement',
      subtitle: 'Select from measurement history - coming soon',
      icon: Icons.history_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPeople();
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

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;

        _people
          ..clear()
          ..addAll(people);
        _selectedPerson = people.first;
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
          content: Text('Unable to create measurement draft. Please try again.'),
        ),
      );
      return;
    }

    final draftId = await MeasurementDraftService.createDraft(
      accountId: accountId,
      customerProfileId: customerProfileId,
      personId: person.id,
      personName: person.name,
      relationship: person.relationship,
      source: _selectedMethod,
    );

    if (!mounted) return;

    switch (_selectedMethod) {
      case 'ai_camera':
        context.push(
          '/camera'
          '?draftId=${Uri.encodeComponent(draftId)}'
          '&clientName=${Uri.encodeComponent(person.name)}'
          '&personId=${Uri.encodeComponent(person.id)}'
          '&relationship=${Uri.encodeComponent(person.relationship)}',
        );
        break;

      case 'design_existing':
        context.push(
          '/designer'
          '?draftId=${Uri.encodeComponent(draftId)}'
          '&clientName=${Uri.encodeComponent(person.name)}'
          '&personId=${Uri.encodeComponent(person.id)}'
          '&relationship=${Uri.encodeComponent(person.relationship)}',
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This measurement method will be added next'),
          ),
        );
    }
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

                    const _SectionTitle(title: 'Who is this measurement for?'),
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
              'Select the person and measurement method. Wear type, template, fabric and final confirmation will be connected step by step.',
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
