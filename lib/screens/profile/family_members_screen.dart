import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _accountId;
  String? _customerProfileId;
  String? _error;

  static const List<String> _relationships = [
    'Mother',
    'Daughter',
    'Sister',
    'Relative',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerProfilePath();
  }

  Future<void> _loadCustomerProfilePath() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone == null || phone.trim().isEmpty) {
        setState(() {
          _error = 'Mobile number not found. Please login again.';
          _loading = false;
        });
        return;
      }

      final accountId =
          await AppState.instance.fetchAccountIdForMobile(phone.trim());

      if (accountId == null || accountId.isEmpty) {
        setState(() {
          _error = 'Account not found. Please login again.';
          _loading = false;
        });
        return;
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
        setState(() {
          _error = 'Customer profile not found. Please login again.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load family members. Please try again.';
        _loading = false;
      });
    }
  }

  CollectionReference<Map<String, dynamic>>? get _familyMembersRef {
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (accountId == null || customerProfileId == null) {
      return null;
    }

    return _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles')
        .doc(customerProfileId)
        .collection('family_members');
  }

  String _normalizeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeMobile(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('91') && digitsOnly.length == 12) {
      return digitsOnly.substring(2);
    }

    if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      return digitsOnly.substring(1);
    }

    return digitsOnly;
  }

  Future<String?> _validateFamilyMemberBeforeSave({
    required CollectionReference<Map<String, dynamic>> ref,
    required String name,
    required String relationship,
    required String mobileNumber,
    DocumentSnapshot<Map<String, dynamic>>? existingDoc,
  }) async {
    final normalizedName = _normalizeText(name);
    final normalizedRelationship = _normalizeText(relationship);
    final normalizedMobile = _normalizeMobile(mobileNumber);

    final snap = await ref.get();

    for (final doc in snap.docs) {
      if (existingDoc != null && doc.id == existingDoc.id) {
        continue;
      }

      final data = doc.data();
      final status = (data['status'] ?? 'active').toString();

        if (status == 'archived') {
          continue;
        }

      final existingName = _normalizeText(data['name']?.toString() ?? '');
      final existingRelationship =
          _normalizeText(data['relationship']?.toString() ?? '');
      final existingMobile =
          _normalizeMobile(data['mobileNumber']?.toString() ?? '');

      if (normalizedRelationship == 'mother' &&
          existingRelationship == 'mother') {
        return 'Mother is already added. Please edit the existing Mother record.';
      }

      if (existingName == normalizedName &&
          existingRelationship == normalizedRelationship) {
        return '$relationship with the same name already exists.';
      }

      if (normalizedMobile.isNotEmpty &&
          existingMobile.isNotEmpty &&
          existingMobile == normalizedMobile) {
        return 'This mobile number is already used by another family member.';
      }
    }

    return null;
  }

  Future<void> _openFamilyMemberForm({
    DocumentSnapshot<Map<String, dynamic>>? existingDoc,
  }) async {
    final ref = _familyMembersRef;
    if (ref == null) return;

    final data = existingDoc?.data();

    final nameController = TextEditingController(
      text: data?['name']?.toString() ?? '',
    );
    final mobileController = TextEditingController(
      text: data?['mobileNumber']?.toString() ?? '',
    );
    final dobController = TextEditingController(
      text: data?['dateOfBirth']?.toString() ?? '',
    );
    final heightController = TextEditingController(
      text: data?['heightCm'] == null ? '' : data!['heightCm'].toString(),
    );
    final weightController = TextEditingController(
      text: data?['weightKg'] == null ? '' : data!['weightKg'].toString(),
    );
    final notesController = TextEditingController(
      text: data?['notes']?.toString() ?? '',
    );

  final existingRelationship = data?['relationship']?.toString();

  String relationship = _relationships.contains(existingRelationship)
      ? existingRelationship!
      : 'Mother';

    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                Navigator.pop(sheetContext, false);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                            Expanded(
                              child: Text(
                                existingDoc == null
                                    ? 'Add Family Member'
                                    : 'Edit Family Member',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: relationship,
                          decoration: const InputDecoration(
                            labelText: 'Relationship',
                            prefixIcon: Icon(Icons.family_restroom),
                            border: OutlineInputBorder(),
                          ),
                          items: _relationships
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() {
                              relationship = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            helperText: 'Optional, 10-digit Indian mobile number',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final raw = value?.trim() ?? '';

                            if (raw.isEmpty) {
                              return null;
                            }

                            final mobile = _normalizeMobile(raw);

                            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
                              return 'Enter valid 10-digit mobile number';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dobController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            helperText: 'Optional',
                            prefixIcon: Icon(Icons.cake_outlined),
                            border: OutlineInputBorder(),
                          ),
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate:
                                  DateTime(now.year - 20, now.month, now.day),
                              firstDate: DateTime(1940),
                              lastDate: now,
                            );

                            if (picked == null) return;

                            dobController.text =
                                '${picked.day.toString().padLeft(2, '0')}/'
                                '${picked.month.toString().padLeft(2, '0')}/'
                                '${picked.year}';
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: heightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Height',
                                  helperText: 'cm, optional',
                                  prefixIcon: Icon(Icons.height_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return null;

                                  final height = double.tryParse(text);
                                  if (height == null ||
                                      height < 40 ||
                                      height > 250) {
                                    return 'Invalid';
                                  }

                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: weightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Weight',
                                  helperText: 'kg, optional',
                                  prefixIcon:
                                      Icon(Icons.monitor_weight_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return null;

                                  final weight = double.tryParse(text);
                                  if (weight == null ||
                                      weight < 5 ||
                                      weight > 250) {
                                    return 'Invalid';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            helperText: 'Optional',
                            prefixIcon: Icon(Icons.notes_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              final duplicateError = await _validateFamilyMemberBeforeSave(
                                ref: ref,
                                existingDoc: existingDoc,
                                name: nameController.text.trim(),
                                relationship: relationship,
                                mobileNumber: mobileController.text.trim(),
                              );

                              if (duplicateError != null) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(
                                      content: Text(duplicateError),
                                    ),
                                  );
                                }
                                return;
                              }

                              final heightText = heightController.text.trim();
                              final weightText = weightController.text.trim();
                              final mobileDigits = _normalizeMobile(mobileController.text.trim());

                              final payload = <String, dynamic>{
                                'name': nameController.text.trim(),
                                'relationship': relationship,
                                'mobileNumber': mobileDigits.isEmpty
                                    ? FieldValue.delete()
                                    : '+91 $mobileDigits',
                                'mobileE164': mobileDigits.isEmpty
                                    ? FieldValue.delete()
                                    : '+91$mobileDigits',
                                'dateOfBirth':
                                    dobController.text.trim().isEmpty
                                        ? FieldValue.delete()
                                        : dobController.text.trim(),
                                'heightCm': heightText.isEmpty
                                    ? FieldValue.delete()
                                    : double.tryParse(heightText),
                                'weightKg': weightText.isEmpty
                                    ? FieldValue.delete()
                                    : double.tryParse(weightText),
                                'notes': notesController.text.trim().isEmpty
                                    ? FieldValue.delete()
                                    : notesController.text.trim(),
                                'status': 'active',
                                'updatedAt': FieldValue.serverTimestamp(),
                              };

                              if (existingDoc == null) {
                                final docRef = ref.doc();
                                await docRef.set({
                                  'familyMemberId': docRef.id,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  ...payload,
                                }, SetOptions(merge: true));
                              } else {
                                await existingDoc.reference.set(
                                  payload,
                                  SetOptions(merge: true),
                                );
                              }

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              existingDoc == null
                                  ? 'Save Member'
                                  : 'Update Member',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(sheetContext, false);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingDoc == null
                ? 'Family member added successfully'
                : 'Family member updated successfully',
          ),
        ),
      );
    }

    // Delay disposal until bottom sheet close animation and final rebuild complete.
    // This prevents "TextEditingController was used after being disposed".
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      nameController.dispose();
      mobileController.dispose();
      dobController.dispose();
      heightController.dispose();
      weightController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _archiveFamilyMember(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final name = data?['name']?.toString() ?? 'this member';

    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive Family Member?'),
          content: Text(
            'Archive $name?\n\n'
            'Orders, measurements, drafts and history will be preserved. '
            'This family member will not appear for new measurements or new orders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FB2),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (shouldArchive != true) return;

    await doc.reference.set(
      {
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Family member archived'),
      ),
    );
  }
  //SUD
  @override
  Widget build(BuildContext context) {
    final ref = _familyMembersRef;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        title: const Text('Family Members'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F5FC),
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
              : ref == null
                  ? const Center(
                      child: Text('Unable to load family members'),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ref.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Unable to load family members. Please try again.',
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = (snapshot.data?.docs ?? []).where((doc) {
                        final data = doc.data();
                        final status = (data['status'] ?? 'active').toString();
                        return status == 'active';
                      }).toList();

                      docs.sort((a, b) {
                        final aTime = a.data()['createdAt'];
                        final bTime = b.data()['createdAt'];

                        if (aTime is Timestamp && bTime is Timestamp) {
                          return aTime.compareTo(bTime);
                        }

                        return a.id.compareTo(b.id);
                      });

                        if (docs.isEmpty) {
                          return const _EmptyFamilyMembersState();
                        }

                          return ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              110 + MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            return _FamilyMemberCard(
                              name: data['name']?.toString() ?? '',
                              relationship:
                                  data['relationship']?.toString() ?? '',
                              mobileNumber:
                                  data['mobileNumber']?.toString() ?? '',
                              dateOfBirth:
                                  data['dateOfBirth']?.toString() ?? '',
                              heightCm: data['heightCm'],
                              weightKg: data['weightKg'],
                              notes: data['notes']?.toString() ?? '',
                              onEdit: () {
                                _openFamilyMemberForm(existingDoc: doc);
                              },
                              onArchive: () {
                                _archiveFamilyMember(doc);
                              },
                            );
                          },
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFamilyMemberForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}

class _EmptyFamilyMembersState extends StatelessWidget {
  const _EmptyFamilyMembersState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6DDF1)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom,
              size: 56,
              color: Color(0xFF7B3FB2),
            ),
            SizedBox(height: 16),
            Text(
              'No family members added yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add family members to manage measurements and future tailoring orders for them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  final String name;
  final String relationship;
  final String mobileNumber;
  final String dateOfBirth;
  final dynamic heightCm;
  final dynamic weightKg;
  final String notes;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _FamilyMemberCard({
    required this.name,
    required this.relationship,
    required this.mobileNumber,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    required this.notes,
    required this.onEdit,
    required this.onArchive,
  });

  String _numberText(dynamic value, String suffix) {
    if (value is num) {
      return '${value.toStringAsFixed(0)} $suffix';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final height = _numberText(heightCm, 'cm');
    final weight = _numberText(weightKg, 'kg');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6DDF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFF3EAFB),
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFF7B3FB2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        relationship,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Archive',
                  onPressed: onArchive,
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF7B3FB2),
                  ),
                ),
              ],
            ),
            if (mobileNumber.isNotEmpty ||
                dateOfBirth.isNotEmpty ||
                height.isNotEmpty ||
                weight.isNotEmpty ||
                notes.isNotEmpty) ...[
              const Divider(height: 22),
              if (mobileNumber.isNotEmpty)
                _DetailLine(
                  icon: Icons.phone_outlined,
                  text: mobileNumber,
                ),
              if (dateOfBirth.isNotEmpty)
                _DetailLine(
                  icon: Icons.cake_outlined,
                  text: dateOfBirth,
                ),
              if (height.isNotEmpty)
                _DetailLine(
                  icon: Icons.height_outlined,
                  text: height,
                ),
              if (weight.isNotEmpty)
                _DetailLine(
                  icon: Icons.monitor_weight_outlined,
                  text: weight,
                ),
              if (notes.isNotEmpty)
                _DetailLine(
                  icon: Icons.notes_outlined,
                  text: notes,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF7B3FB2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}