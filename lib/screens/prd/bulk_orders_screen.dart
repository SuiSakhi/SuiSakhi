import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../services/customer_support_service.dart';
import '../../widgets/common/service_request_address_picker.dart';

const _bulkPink = Color(0xFFD20A68);
const _bulkInk = Color(0xFF182447);
const _bulkMuted = Color(0xFF777F99);
const _bulkBg = Color(0xFFFFF8FA);

class BulkOrdersScreen extends StatefulWidget {
  const BulkOrdersScreen({super.key});

  @override
  State<BulkOrdersScreen> createState() => _BulkOrdersScreenState();
}

class _BulkOrdersScreenState extends State<BulkOrdersScreen> {
  final _eventDetails = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  String _package = 'Wedding Package';
  String _eventType = 'Wedding';
  String _who = 'Bride & Family';
  String _consultation = 'Home Visit';
  DateTime _eventDate = DateTime.now().add(const Duration(days: 60));
  Map<String, dynamic>? _address;
  int _outfits = 25;
  bool _submitting = false;

  static const _eventTypes = [
    'Wedding',
    'Engagement',
    'Reception',
    'Family Function',
    'Corporate Event',
    'School / College',
    'Dance / Stage Show',
    'Other',
  ];
  static const _audiences = [
    'Bride & Family',
    'Friends & Family',
    'Students',
    'Colleagues',
    'Other',
  ];

  @override
  void dispose() {
    _eventDetails.dispose();
    _location.dispose();
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

  Future<void> _submit() async {
    if (_eventDetails.text.trim().isEmpty || _location.text.trim().isEmpty) {
      _message('Add the event details and venue or city.');
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
      final notes = _notes.text.trim();
      final message = [
        'Offline quotation request — Bulk Orders',
        'Package: $_package',
        'Event type: $_eventType',
        'Event details: ${_eventDetails.text.trim()}',
        'Approx. outfits: $_outfits',
        'For: $_who',
        'Event date: $date',
        'Venue / city: ${_location.text.trim()}',
        'Consultation preference: $_consultation',
        'Customer address: $addressText',
        if (notes.isNotEmpty) 'Additional notes: $notes',
        'Helpdesk to coordinate partner options and an offline quotation. No payment is due in the app.',
      ].join('\n');
      final ticketId = await CustomerSupportService.createServiceRequest(
        requestType: 'bulk_order',
        customerName: AppState.instance.profile?.name ?? '',
        subject: 'Bulk order request · $_eventType',
        message: message,
        details: {
          'packageType': _package,
          'eventType': _eventType,
          'eventDetails': _eventDetails.text.trim(),
          'outfitCount': _outfits,
          'audience': _who,
          'eventDate': date,
          'eventLocation': _location.text.trim(),
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
      icon: const Icon(Icons.mark_email_read_outlined, color: _bulkPink),
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

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
    backgroundColor: _bulkBg,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          _hero(),
          const SizedBox(height: 10),
          _sectionTitle('Package Type'),
          const SizedBox(height: 8),
          Row(
            children: [
              _packageTile(
                'Wedding Package',
                'Bridal & family outfits',
                Icons.favorite_border,
              ),
              const SizedBox(width: 10),
              _packageTile(
                'Event Package',
                'Functions, school, corporate',
                Icons.groups_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle('Event Type'),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final tileWidth = (constraints.maxWidth - spacing * 3) / 4;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final type in _eventTypes)
                    SizedBox(
                      width: tileWidth,
                      height: 76,
                      child: _eventTypeTile(type),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _sectionTitle('Approx. Number of Outfits'),
          const SizedBox(height: 6),
          Row(
            children: [
              _stepButton(
                Icons.remove,
                _outfits > 1 ? () => setState(() => _outfits--) : null,
              ),
              Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF3E5ED)),
                ),
                child: Text(
                  '$_outfits',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _bulkInk,
                  ),
                ),
              ),
              _stepButton(Icons.add, () => setState(() => _outfits++)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAF2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.groups_outlined, color: _bulkPink, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get special pricing for larger orders',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _bulkPink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionTitle('Who is this for?'),
          const SizedBox(height: 6),
          _audienceDropdown(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _fieldCard(
                  'Event Date',
                  icon: Icons.calendar_month_outlined,
                  child: TextButton(
                    onPressed: _pickDate,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.fromHeight(38),
                      alignment: Alignment.centerLeft,
                      foregroundColor: _bulkInk,
                    ),
                    child: Text(_dateLabel(_eventDate)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldCard(
                  'Location / City',
                  icon: Icons.location_on_outlined,
                  child: TextField(
                    controller: _location,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'Venue or city for logistics',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fieldCard(
            'Event / Occasion Details',
            icon: Icons.event_note_outlined,
            child: TextField(
              controller: _eventDetails,
              maxLength: 300,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'e.g. Annual function, dance show, wedding...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Consultation Preference'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _consultationTile(
                  'Home Visit',
                  'Our expert visits you',
                  Icons.home_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _consultationTile(
                  'Video Consultation',
                  'Discuss online',
                  Icons.videocam_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _consultationTile(
                  'Call Me',
                  'We’ll schedule a suitable time',
                  Icons.call_outlined,
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
            icon: Icons.description_outlined,
            child: TextField(
              controller: _notes,
              maxLines: 3,
              maxLength: 400,
              decoration: const InputDecoration(
                counterText: '',
                hintText:
                    'Requirements, outfit types, theme, fabric preferences...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _bulkPink,
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
                _submitting ? 'Sending request…' : 'Book Consultation Request',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Helpdesk will coordinate with partner services and share available options and an offline quotation. No payment is collected here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _bulkMuted, height: 1.35),
          ),
        ],
      ),
    ),
  );

  Widget _hero() => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: constraints.maxWidth * 408 / 870,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bulk_request_hero.png', fit: BoxFit.fill),
          Positioned(
            left: -8,
            top: 0,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              color: _bulkPink,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _packageTile(String title, String subtitle, IconData icon) {
    final selected = _package == title;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _package = title),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFEAF2) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF82B5)
                  : const Color(0xFFF3E5ED),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? _bulkPink : const Color(0xFFD8D8E6),
                size: 20,
              ),
              const SizedBox(width: 7),
              Icon(icon, color: _bulkPink, size: 27),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _bulkInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _bulkMuted,
                        fontSize: 10,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed) => IconButton(
    onPressed: onPressed,
    color: _bulkPink,
    iconSize: 28,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    icon: Icon(
      icon == Icons.add
          ? Icons.add_circle_outline
          : Icons.remove_circle_outline,
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontFamily: 'serif',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Color(0xFF86104B),
      height: 1.05,
    ),
  );

  IconData _eventTypeIcon(String type) => switch (type) {
    'Wedding' => Icons.favorite_border_rounded,
    'Engagement' => Icons.diamond_outlined,
    'Reception' => Icons.celebration_outlined,
    'Family Function' => Icons.groups_2_outlined,
    'Corporate Event' => Icons.work_outline_rounded,
    'School / College' => Icons.school_outlined,
    'Dance / Stage Show' => Icons.directions_run_rounded,
    _ => Icons.more_horiz_rounded,
  };

  Widget _eventTypeTile(String type) {
    final selected = _eventType == type;
    return InkWell(
      onTap: () => setState(() => _eventType = type),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFF82B5) : const Color(0xFFF8EDF1),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A6E2141),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 9, 3, 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_eventTypeIcon(type), color: _bulkPink, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      type,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? _bulkPink : _bulkInk,
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              const Positioned(
                top: 6,
                left: 6,
                child: Icon(Icons.check_circle, color: _bulkPink, size: 15),
              ),
          ],
        ),
      ),
    );
  }

  Widget _consultationTile(String title, String subtitle, IconData icon) {
    final selected = _consultation == title;
    return InkWell(
      onTap: () => setState(() => _consultation = title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 82,
        padding: const EdgeInsets.fromLTRB(22, 8, 5, 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFF82B5) : const Color(0xFFF8EDF1),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A6E2141),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Icon(icon, color: _bulkPink, size: 23),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _bulkPink : _bulkInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _bulkMuted,
                          fontSize: 9,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                left: -1,
                top: -2,
                child: Icon(Icons.check_circle, color: _bulkPink, size: 15),
              ),
          ],
        ),
      ),
    );
  }

  Widget _audienceDropdown() => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F4FC),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFEAE4F4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_outlined, color: _bulkPink, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _who,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _audiences
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _who = value);
              },
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fieldCard(
    String title, {
    required IconData icon,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _bulkInk,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 5),
      Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A6E2141),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _bulkPink, size: 21),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    ],
  );
}
