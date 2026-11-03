import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../services/customer_support_service.dart';
import '../../widgets/common/service_request_address_picker.dart';

const _rentalPink = Color(0xFFD20A68);
const _rentalInk = Color(0xFF182447);
const _rentalMuted = Color(0xFF777F99);
const _rentalBg = Color(0xFFFFF8FA);

class DressRentalRequestScreen extends StatefulWidget {
  const DressRentalRequestScreen({super.key});

  @override
  State<DressRentalRequestScreen> createState() =>
      _DressRentalRequestScreenState();
}

class _DressRentalRequestScreenState extends State<DressRentalRequestScreen> {
  final _eventDetails = TextEditingController();
  final _location = TextEditingController();
  final _ageGroup = TextEditingController();
  final _style = TextEditingController();
  final _notes = TextEditingController();

  static const _occasions = <({String label, String asset, IconData icon})>[
    (
      label: 'Dance / Stage Show',
      asset: 'rental_occasion_dance.png',
      icon: Icons.directions_run_rounded,
    ),
    (
      label: 'Annual Function',
      asset: 'rental_occasion_annual.png',
      icon: Icons.groups_2_outlined,
    ),
    (
      label: 'Wedding Events',
      asset: 'rental_occasion_wedding.png',
      icon: Icons.favorite_border_rounded,
    ),
    (
      label: 'Fashion Show',
      asset: 'rental_occasion_fashion.png',
      icon: Icons.photo_camera_outlined,
    ),
    (
      label: 'Themed Photoshoot',
      asset: 'rental_occasion_theme.png',
      icon: Icons.image_outlined,
    ),
    (
      label: 'Historical Characters',
      asset: 'rental_occasion_historical.png',
      icon: Icons.auto_awesome_outlined,
    ),
    (
      label: 'School / College',
      asset: 'rental_occasion_school.png',
      icon: Icons.school_outlined,
    ),
    (
      label: 'Corporate Events',
      asset: 'rental_occasion_corporate.png',
      icon: Icons.work_outline_rounded,
    ),
  ];
  static const _audiences = [
    'Group',
    'Child',
    'Adults',
    'Bride & Family',
    'Other',
  ];
  static const _durations = [
    '1 day',
    '2–3 days',
    '4–7 days',
    'More than a week',
    'Discuss with Helpdesk',
  ];
  static const _consultations = ['Home Visit', 'Video Consultation', 'Call Me'];

  String _occasion = 'Dance / Stage Show';
  String _who = 'Group';
  String _duration = 'Select duration';
  String _consultation = 'Home Visit';
  DateTime _eventDate = DateTime.now().add(const Duration(days: 60));
  Map<String, dynamic>? _address;
  int _outfits = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _eventDetails.dispose();
    _location.dispose();
    _ageGroup.dispose();
    _style.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _browseCollection() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Browse rental collection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                itemCount: _occasions.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final item = _occasions[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(sheetContext, item.label),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/${item.asset}',
                            fit: BoxFit.cover,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              color: Colors.white.withValues(alpha: 0.92),
                              child: Text(
                                item.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _occasion = selected);
  }

  Future<void> _submit() async {
    if (_eventDetails.text.trim().isEmpty || _location.text.trim().isEmpty) {
      _message('Add the event details and location or city.');
      return;
    }
    if (_duration == 'Select duration') {
      _message('Choose the rental duration.');
      return;
    }
    final savedAddress = _address;
    if (savedAddress == null) {
      _message('Choose an address from your profile first.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final addressText = _addressText(savedAddress);
      final date = _dateLabel(_eventDate);
      final age = _ageGroup.text.trim();
      final style = _style.text.trim();
      final notes = _notes.text.trim();
      final message = [
        'Offline quotation request — Dress Rental',
        'Occasion: $_occasion',
        'Event details: ${_eventDetails.text.trim()}',
        'Event date: $date',
        'Event location / city: ${_location.text.trim()}',
        'Approx. outfits: $_outfits',
        'For: $_who',
        if (age.isNotEmpty) 'Age group: $age',
        if (style.isNotEmpty) 'Style preference: $style',
        'Rental duration: $_duration',
        'Consultation preference: $_consultation',
        'Customer address: $addressText',
        if (notes.isNotEmpty) 'Additional notes: $notes',
        'Helpdesk to coordinate partner options and an offline quotation. No payment is due in the app.',
      ].join('\n');
      final ticketId = await CustomerSupportService.createServiceRequest(
        requestType: 'dress_rental',
        customerName: AppState.instance.profile?.name ?? '',
        subject: 'Dress rental request · $_occasion',
        message: message,
        details: {
          'occasion': _occasion,
          'eventDetails': _eventDetails.text.trim(),
          'eventDate': date,
          'eventLocation': _location.text.trim(),
          'outfitCount': _outfits,
          'audience': _who,
          'ageGroup': age,
          'stylePreference': style,
          'rentalDuration': _duration,
          'consultationPreference': _consultation,
          'addressId': savedAddress['addressId']?.toString() ?? '',
          'address': addressText,
          'notes': notes,
        },
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showSubmitted(ticketId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _message(
        error is FirebaseAuthException
            ? 'Sign in to send this request.'
            : 'The request could not be sent. Please try again.',
      );
    }
  }

  Future<void> _showSubmitted(String ticketId) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.mark_email_read_outlined, color: _rentalPink),
      title: const Text('Request sent to Helpdesk'),
      content: SelectableText(
        'Reference: $ticketId\n\nThe Helpdesk will coordinate with partners and share an offline quotation. No payment has been taken.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.push('/customer-help-support');
          },
          child: const Text('My requests'),
        ),
      ],
    ),
  );

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _addressText(Map<String, dynamic> address) =>
      (address['formattedAddress']?.toString().trim().isNotEmpty == true)
      ? address['formattedAddress'].toString().trim()
      : [
              address['addressLine1'],
              address['addressLine2'],
              address['locality'],
              address['landmark'],
              address['cityName'] ?? address['city'],
              address['stateName'] ?? address['state'],
              address['pincode'],
            ]
            .map((part) => part?.toString().trim() ?? '')
            .where((part) => part.isNotEmpty)
            .join(', ');

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _rentalBg,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          _hero(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: ServiceRequestSectionTitle('Choose Occasion'),
              ),
              TextButton.icon(
                onPressed: _showAllOccasions,
                iconAlignment: IconAlignment.end,
                label: const Text('See all categories'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            itemCount: _occasions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _occasionTile(_occasions[index]),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: ServiceRequestSectionTitle('Tell us your requirements'),
              ),
              TextButton.icon(
                onPressed: _browseCollection,
                icon: const Icon(Icons.checkroom_outlined, size: 18),
                label: const Text('Browse collection'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _fieldCard(
            'Event / Occasion Details',
            child: TextField(
              controller: _eventDetails,
              maxLength: 300,
              decoration: const InputDecoration(
                counterText: '',
                hintText:
                    'e.g. Annual function, dance show, historical drama...',
                prefixIcon: Icon(Icons.checkroom_outlined),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fieldCard(
                  'Event Date',
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_dateLabel(_eventDate)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldCard(
                  'Event Location / City',
                  child: TextField(
                    controller: _location,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'Venue or city...',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fieldCard(
                  'Number of Outfits Required',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stepButton(
                        Icons.remove,
                        _outfits > 1 ? () => setState(() => _outfits--) : null,
                      ),
                      Text(
                        '$_outfits',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _stepButton(Icons.add, () => setState(() => _outfits++)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldCard(
                  'Who is this for?',
                  child: _dropdown(
                    _who,
                    _audiences,
                    (value) => setState(() => _who = value),
                    hint: 'Select group',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fieldCard(
                  'Age Group (Optional)',
                  child: TextField(
                    controller: _ageGroup,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'e.g. Children, adults',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldCard(
                  'Style Preference (Optional)',
                  child: TextField(
                    controller: _style,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'Traditional, historical...',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fieldCard(
                  'Rental Duration',
                  child: _dropdown(
                    _duration,
                    _durations,
                    (value) => setState(() => _duration = value),
                    hint: 'Select duration',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldCard(
                  'Consultation Preference',
                  child: _dropdown(
                    _consultation,
                    _consultations,
                    (value) => setState(() => _consultation = value),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ServiceRequestAddressPicker(
            onChanged: (address) => _address = address,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            'Additional Notes',
            child: TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 400,
              decoration: const InputDecoration(
                counterText: '',
                hintText:
                    'Theme, character reference, size range, special instructions...',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _rentalPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.calendar_month_outlined),
              label: Text(
                _submitting ? 'Sending request…' : 'Submit Rental Request',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Helpdesk will connect you with suitable partners and share options and an offline quotation after your request. No payment is collected here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _rentalMuted, height: 1.35),
          ),
        ],
      ),
    ),
  );

  Widget _hero() => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: constraints.maxWidth * 390 / 870,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/dress_rental_request_hero.png',
            fit: BoxFit.fill,
          ),
          Positioned(
            left: -8,
            top: 0,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              color: _rentalPink,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _occasionTile(({String label, String asset, IconData icon}) item) {
    final selected = _occasion == item.label;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _occasion = item.label),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _rentalPink : const Color(0xFFF3E5ED),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Image.asset(
                'assets/images/${item.asset}',
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFFFE9F1),
                  child: Icon(item.icon, color: _rentalPink, size: 28),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Center(
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: selected ? _rentalPink : _rentalInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllOccasions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in _occasions)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/images/${item.asset}'),
              ),
              title: Text(item.label),
              trailing: _occasion == item.label
                  ? const Icon(Icons.check, color: _rentalPink)
                  : null,
              onTap: () {
                setState(() => _occasion = item.label);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  );

  Widget _fieldCard(String title, {required Widget child}) =>
      ServiceRequestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _rentalInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      );

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String> onChanged, {
    String? hint,
  }) => DropdownButtonFormField<String>(
    initialValue: items.contains(value) ? value : null,
    decoration: InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      border: InputBorder.none,
    ),
    isExpanded: true,
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )
        .toList(growable: false),
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );

  Widget _stepButton(IconData icon, VoidCallback? onPressed) => IconButton(
    onPressed: onPressed,
    color: _rentalPink,
    iconSize: 28,
    icon: Icon(
      icon == Icons.add
          ? Icons.add_circle_outline
          : Icons.remove_circle_outline,
    ),
  );
}
