import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/address_details.dart';
import '../../services/garment_care_service.dart';

class ServiceRequestAddressPicker extends StatefulWidget {
  const ServiceRequestAddressPicker({super.key, required this.onChanged});

  final ValueChanged<Map<String, dynamic>?> onChanged;

  @override
  State<ServiceRequestAddressPicker> createState() =>
      _ServiceRequestAddressPickerState();
}

class _ServiceRequestAddressPickerState
    extends State<ServiceRequestAddressPicker> {
  List<Map<String, dynamic>> _addresses = const [];
  String? _selectedId;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? get _selected {
    for (final address in _addresses) {
      if (address['addressId']?.toString() == _selectedId) return address;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await GarmentCareService.customerAddresses();
      if (!mounted) return;
      final previous = _selectedId;
      final selectedId =
          addresses.any(
            (address) => address['addressId']?.toString() == previous,
          )
          ? previous
          : addresses.isEmpty
          ? null
          : addresses.first['addressId']?.toString();
      setState(() {
        _addresses = addresses;
        _selectedId = selectedId;
        _loading = false;
      });
      widget.onChanged(_selected);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = const [];
        _loading = false;
        _error = 'Saved addresses could not be loaded. Please retry.';
      });
      widget.onChanged(null);
    }
  }

  Future<void> _openAddresses() async {
    await context.push<void>('/customer-addresses');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final details = selected == null ? null : AddressDetails.fromMap(selected);
    final formatted = selected?['formattedAddress']?.toString().trim();

    return _RequestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Address from your profile'),
          const SizedBox(height: 10),
          if (_loading)
            const LinearProgressIndicator()
          else if (_addresses.isEmpty)
            Text(
              _error ?? 'Add a saved address before sending this request.',
              style: const TextStyle(color: Color(0xFF777286)),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.home_outlined),
                labelText: 'Saved address',
                border: OutlineInputBorder(),
              ),
              items: _addresses
                  .map(
                    (address) => DropdownMenuItem<String>(
                      value: address['addressId']?.toString(),
                      child: Text(
                        address['addressType']?.toString() ?? 'Address',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _selectedId = value);
                widget.onChanged(_selected);
              },
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Text(
                formatted?.isNotEmpty == true
                    ? formatted!
                    : details?.formattedAddress ?? '',
                style: const TextStyle(color: Color(0xFF777286)),
              ),
              if ((details?.pincode ?? '').trim().isNotEmpty)
                Text(
                  'PIN code: ${details!.pincode}',
                  style: const TextStyle(
                    color: Color(0xFF9C1453),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loading
                ? null
                : (_error == null ? _openAddresses : _load),
            icon: Icon(
              _error == null ? Icons.add_location_alt_outlined : Icons.refresh,
            ),
            label: Text(_error == null ? 'Manage saved addresses' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class ServiceRequestCard extends StatelessWidget {
  const ServiceRequestCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _RequestCard(child: child);
}

class ServiceRequestSectionTitle extends StatelessWidget {
  const ServiceRequestSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => _SectionTitle(text);
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C6E2141),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF86104B),
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );
}
