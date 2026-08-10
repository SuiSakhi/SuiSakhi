import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';

class CustomerAddressesScreen extends StatefulWidget {
  const CustomerAddressesScreen({super.key});

  @override
  State<CustomerAddressesScreen> createState() =>
      _CustomerAddressesScreenState();
}

class _CustomerAddressesScreenState extends State<CustomerAddressesScreen> {
  static const Color _primaryColor = Color(0xFF7B3FB2);
  static const Color _backgroundColor = Color(0xFFF8F5FC);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<_CustomerAddress> _addresses = [];

  bool _loading = true;
  String? _error;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone == null || phone.trim().isEmpty) {
        setState(() {
          _error = 'Unable to load account. Please sign in again.';
          _loading = false;
        });
        return;
      }

      final accountId =
          await AppState.instance.fetchAccountIdForMobile(phone.trim());

      if (accountId == null || accountId.isEmpty) {
        setState(() {
          _error = 'Unable to find account for this mobile number.';
          _loading = false;
        });
        return;
      }

      final snap = await _db
          .collection('accounts')
          .doc(accountId)
          .collection('addresses')
          .where('status', isEqualTo: 'active')
          .get();

      final addresses = snap.docs.map((doc) {
        return _CustomerAddress.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();

      addresses.sort((a, b) {
        if (a.isDefault == b.isDefault) {
          return a.addressType.compareTo(b.addressType);
        }
        return a.isDefault ? -1 : 1;
      });

      setState(() {
        _accountId = accountId;
        _addresses
          ..clear()
          ..addAll(addresses);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load addresses. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddressForm({
    _CustomerAddress? existingAddress,
    int? editIndex,
  }) async {
    final accountId = _accountId;

    if (accountId == null || accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save address. Account not loaded.'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_CustomerAddress>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _AddressFormSheet(
          initialAddress: existingAddress,
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      final addressesRef = _db
          .collection('accounts')
          .doc(accountId)
          .collection('addresses');

      final shouldMakeDefault = result.isDefault || _addresses.isEmpty;

      if (shouldMakeDefault) {
        final activeSnap =
            await addressesRef.where('status', isEqualTo: 'active').get();

        final batch = _db.batch();

        for (final doc in activeSnap.docs) {
          batch.update(doc.reference, {
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      if (existingAddress != null) {
        final addressToSave = result.copyWith(
          addressId: existingAddress.addressId,
          isDefault: shouldMakeDefault,
        );

        await addressesRef.doc(existingAddress.addressId).set(
              addressToSave.toMap(),
              SetOptions(merge: true),
            );
      } else {
        final ref = addressesRef.doc();

        final addressToSave = result.copyWith(
          addressId: ref.id,
          isDefault: shouldMakeDefault,
        );

        await ref.set(
          addressToSave.toMap(includeCreatedAt: true),
        );
      }

      await _loadAddresses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingAddress == null
                ? 'Address added successfully'
                : 'Address updated successfully',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save address. Please try again.'),
        ),
      );
    }
  }

  Future<void> _setDefaultAddress(int index) async {
    final accountId = _accountId;

    if (accountId == null || accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update default address. Account not loaded.'),
        ),
      );
      return;
    }

    try {
      final selected = _addresses[index];

      final addressesRef = _db
          .collection('accounts')
          .doc(accountId)
          .collection('addresses');

      final activeSnap =
          await addressesRef.where('status', isEqualTo: 'active').get();

      final batch = _db.batch();

      for (final doc in activeSnap.docs) {
        batch.update(doc.reference, {
          'isDefault': doc.id == selected.addressId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _loadAddresses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default address updated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update default address. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteAddress(int index) async {
    final accountId = _accountId;

    if (accountId == null || accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete address. Account not loaded.'),
        ),
      );
      return;
    }

    final address = _addresses[index];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Address?'),
          content: Text(
            'Are you sure you want to delete this ${address.addressType} address?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;

    try {
      final addressesRef = _db
          .collection('accounts')
          .doc(accountId)
          .collection('addresses');

      final wasDefault = address.isDefault;

      await addressesRef.doc(address.addressId).set(
        {
          'status': 'inactive',
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _loadAddresses();

      if (wasDefault && _addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
        await addressesRef.doc(_addresses.first.addressId).set(
          {
            'isDefault': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        await _loadAddresses();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete address. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Addresses'),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _InfoCard(),
                      const SizedBox(height: 20),
                      if (_addresses.isEmpty)
                        _EmptyAddressState(
                          onAddAddress: () => _openAddressForm(),
                        )
                      else ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Saved Addresses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openAddressForm(),
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Add New'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _addresses.length; i++)
                          _AddressCard(
                            address: _addresses[i],
                            onEdit: () {
                              _openAddressForm(
                                existingAddress: _addresses[i],
                                editIndex: i,
                              );
                            },
                            onSetDefault: () => _setDefaultAddress(i),
                            onDelete: () => _deleteAddress(i),
                          ),
                        const SizedBox(height: 86),
                      ],
                    ],
                  ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address'),
        onPressed: () => _openAddressForm(),
      ),
    );
  }
}

class _CustomerAddress {
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

  const _CustomerAddress({
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

  _CustomerAddress copyWith({
    String? addressId,
    String? addressType,
    String? name,
    String? mobileNumber,
    String? addressLine1,
    String? addressLine2,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) {
    return _CustomerAddress(
      addressId: addressId ?? this.addressId,
      addressType: addressType ?? this.addressType,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
    Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
      return {
        'addressId': addressId,
        'addressType': addressType,
        'name': name,
        'mobileNumber': mobileNumber,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
        'isDefault': isDefault,
        'status': 'active',
        if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }
    
    factory _CustomerAddress.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return _CustomerAddress(
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

}

class _AddressFormSheet extends StatefulWidget {
  final _CustomerAddress? initialAddress;

  const _AddressFormSheet({
    required this.initialAddress,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();

}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;

  late String _addressType;
  late bool _isDefault;

  static const String _defaultCountryName = 'India';
  static const String _defaultCountryCode = '+91';

  static const List<String> _addressTypes = [
    'Home',
    'Other',
  ];
  static const List<String> _maharashtraCities = [
    'Pune',
    'Mumbai',
    'Nagpur',
    'Nashik',
    'Thane',
    'Kolhapur',
    'Aurangabad',
    'Amravati',
    'Solapur',
    'Satara',
    'Sangli',
    'Jalgaon',
    'Nanded',
    'Akola',
    'Latur',
    'Ahmednagar',
    'Wardha',
    'Chandrapur',
    'Yavatmal',
    'Ratnagiri',
    'Other',
  ];

  late String _selectedCity;

  bool get _isEditMode => widget.initialAddress != null;

  @override
  void initState() {
    super.initState();

    final address = widget.initialAddress;

    _nameCtrl = TextEditingController(text: address?.name ?? '');
    _mobileCtrl = TextEditingController(
        text: (address?.mobileNumber ?? '')
            .replaceFirst('+91 ', ''),
      );
    _line1Ctrl = TextEditingController(text: address?.addressLine1 ?? '');
    _line2Ctrl = TextEditingController(text: address?.addressLine2 ?? '');
    _landmarkCtrl = TextEditingController(text: address?.landmark ?? '');
    _cityCtrl = TextEditingController(text: address?.city ?? 'Pune');
    _stateCtrl = TextEditingController(text: address?.state ?? 'Maharashtra');
    _pincodeCtrl = TextEditingController(text: address?.pincode ?? '');
     
    final initialCity = address?.city ?? 'Pune';

    _selectedCity = _maharashtraCities.contains(initialCity)
        ? initialCity
        : 'Other';

    _cityCtrl.text = initialCity;
    _stateCtrl.text = 'Maharashtra';

    _addressType = address?.addressType ?? 'Home';
    _isDefault = address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  String _normalizeIndianMobile(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('91') && digitsOnly.length == 12) {
      return digitsOnly.substring(2);
    }

    if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      return digitsOnly.substring(1);
    }

    return digitsOnly;
  }

  void _saveAddress() {
    if (!_formKey.currentState!.validate()) return;

    final address = _CustomerAddress(
      addressId: widget.initialAddress?.addressId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      addressType: _addressType,
      name: _nameCtrl.text.trim(),
      mobileNumber:
      '$_defaultCountryCode ${_normalizeIndianMobile(_mobileCtrl.text.trim())}',
      addressLine1: _line1Ctrl.text.trim(),
      addressLine2: _line2Ctrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      isDefault: _isDefault,
    );

    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _isEditMode ? 'Edit Address' : 'Add New Address',
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
                const SizedBox(height: 6),
                Text(
                  _isEditMode
                      ? 'Update only this selected address.'
                      : 'Add a new address. Existing addresses will remain intact.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _addressType,
                  decoration: const InputDecoration(
                    labelText: 'Address Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _addressTypes
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _addressType = value);
                  },
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validatorMessage: 'Please enter full name',
                ),
                const SizedBox(height: 12),
                _TextFormPhoneField(
                  controller: _mobileCtrl,
                  countryName: _defaultCountryName,
                  countryCode: _defaultCountryCode,
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: _line1Ctrl,
                  label: 'Address Line 1',
                  icon: Icons.home_outlined,
                  validatorMessage: 'Please enter address line 1',
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: _line2Ctrl,
                  label: 'Address Line 2',
                  icon: Icons.apartment_outlined,
                  validatorMessage: 'Please enter address line 2',
                ),
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: _landmarkCtrl,
                  label: 'Landmark',
                  icon: Icons.place_outlined,
                  validatorMessage: 'Please enter landmark',
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _maharashtraCities
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedCity = value;

                          if (value != 'Other') {
                            _cityCtrl.text = value;
                          } else {
                            _cityCtrl.clear();
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _stateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                if (_selectedCity == 'Other') ...[
                  const SizedBox(height: 12),
                  _AddressTextField(
                    controller: _cityCtrl,
                    label: 'Enter City',
                    icon: Icons.edit_location_alt_outlined,
                    validatorMessage: 'Please enter city',
                  ),
                ],
                const SizedBox(height: 12),
                _AddressTextField(
                  controller: _pincodeCtrl,
                  label: 'Pincode',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  validatorMessage: 'Please enter pincode',
                  validator: (value) {
                    final pincode = (value ?? '').trim();

                    if (pincode.isEmpty) {
                      return 'Please enter pincode';
                    }

                    if (!RegExp(r'^\d{6}$').hasMatch(pincode)) {
                      return 'Enter valid 6-digit pincode';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Set as default address',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Only one address can be default at a time.',
                  ),
                  value: _isDefault,
                  activeThumbColor: const Color(0xFF7B3FB2),
                  onChanged: (value) {
                    setState(() => _isDefault = value);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveAddress,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEditMode ? 'Update Address' : 'Save Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B3FB2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _AddressTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String validatorMessage;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AddressTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validatorMessage,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return validatorMessage;
            }
            return null;
          },
    );
  }
}

class _TextFormPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String countryName;
  final String countryCode;

  const _TextFormPhoneField({
    required this.controller,
    required this.countryName,
    required this.countryCode,
  });

  String _normalizeIndianMobile(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('91') && digitsOnly.length == 12) {
      return digitsOnly.substring(2);
    }

    if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      return digitsOnly.substring(1);
    }

    return digitsOnly;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        prefixIcon: const Icon(Icons.phone_outlined),
        prefixText: '$countryCode ',
        helperText: '$countryName mobile number, 10 digits',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final mobile = _normalizeIndianMobile(value ?? '');

        if (mobile.isEmpty) {
          return 'Please enter mobile number';
        }

        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
          return 'Enter valid 10-digit Indian mobile number';
        }

        return null;
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Icons.location_on_outlined,
              color: Color(0xFF7B3FB2),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Addresses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Add Home or Other addresses for measurement, pickup, delivery, quick fix and partner services.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final _CustomerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = address.isDefault
        ? const Color(0xFF2E7D32)
        : const Color(0xFF7B3FB2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: address.isDefault
              ? const Color(0xFFC8E6C9)
              : const Color(0xFFE6DDF1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AddressTypeBadge(
                label: address.addressType,
                color: typeColor,
              ),
              const SizedBox(width: 8),
              if (address.isDefault) const _DefaultBadge(),
              const Spacer(),
              IconButton(
                tooltip: 'Edit Address',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF7B3FB2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            address.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address.mobileNumber,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            address.addressLine1,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          Text(
            address.addressLine2,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'Landmark: ${address.landmark}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${address.city}, ${address.state} - ${address.pincode}',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!address.isDefault)
                OutlinedButton.icon(
                  onPressed: onSetDefault,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Set Default'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7B3FB2),
                    side: const BorderSide(
                      color: Color(0xFF7B3FB2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressTypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _AddressTypeBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Default',
        style: TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyAddressState extends StatelessWidget {
  final VoidCallback onAddAddress;

  const _EmptyAddressState({
    required this.onAddAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE6DDF1),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EAFB),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.add_home_work_outlined,
              size: 42,
              color: Color(0xFF7B3FB2),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No addresses added yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first address to make pickup and delivery easier for your tailoring orders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FB2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text(
                'Add New Address',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onAddAddress,
            ),
          ),
        ],
      ),
    );
  }
}
