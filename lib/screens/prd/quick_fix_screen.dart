import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../models/address_details.dart';
import '../../models/prd_catalog.dart';
import '../../services/garment_care_service.dart';
import '../../services/order_service.dart';

/// Customer booking flow for Quick Care & Home Services.
///
/// The screen follows the approved service-catalogue layout while keeping the
/// request inside the existing Quick Care order module.
class QuickFixScreen extends StatefulWidget {
  const QuickFixScreen({super.key});

  @override
  State<QuickFixScreen> createState() => _QuickFixScreenState();
}

class _QuickFixScreenState extends State<QuickFixScreen> {
  final Set<String> _selected = {};
  final _notes = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;
  bool _loadingAddresses = true;
  String? _addressError;
  String _slot = 'Next day — 10am–2pm';
  bool _express = false;
  bool _submitting = false;
  Timer? _sameDayExpressCutoffTimer;

  static const _visitFee = 49.0;
  static const _expressFee = 99.0;
  static const _slots = [
    'Same day (Express) — 2pm–6pm',
    'Next day — 10am–2pm',
    'Next day — 2pm–6pm',
    'Choose later (admin will call)',
  ];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _scheduleSameDayExpressCutoff();
  }

  void _scheduleSameDayExpressCutoff() {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, 14);
    if (!now.isBefore(cutoff)) return;
    _sameDayExpressCutoffTimer = Timer(cutoff.difference(now), () {
      if (!mounted) return;
      setState(() {
        if (_isExpressSlot) _slot = _slots[1];
      });
    });
  }

  @override
  void dispose() {
    _sameDayExpressCutoffTimer?.cancel();
    _notes.dispose();
    _address.dispose();
    _landmark.dispose();
    _pincode.dispose();
    super.dispose();
  }

  bool get _needsQuote => _selected.any(
    (id) => QuickFixService.byId(id)?.requiresPartnerQuote ?? false,
  );

  bool get _isExpressSlot => _slot.startsWith('Same day');

  bool get _sameDayExpressAvailable {
    final now = DateTime.now();
    return now.isBefore(DateTime(now.year, now.month, now.day, 14));
  }

  List<String> get _availableSlots => _slots
      .where((slot) => !slot.startsWith('Same day') || _sameDayExpressAvailable)
      .toList(growable: false);

  DateTime? get _scheduledStartAt {
    final now = DateTime.now();
    if (_slot.startsWith('Same day')) {
      return DateTime(now.year, now.month, now.day, 14);
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (_slot.startsWith('Next day') && _slot.contains('10am')) {
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
    }
    if (_slot.startsWith('Next day') && _slot.contains('2pm')) {
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14);
    }
    return null;
  }

  List<QuickFixService> get _bookableServices {
    const visibleIds = {
      'pico_fall',
      'rafu',
      'zip',
      'button',
      'minor_alt',
      'express_stitch',
    };
    final ids = <String>{
      ...visibleIds,
      ..._selected.where((id) => id != 'other_quote'),
    };
    return QuickFixService.catalog
        .where((service) => ids.contains(service.id))
        .toList(growable: false);
  }

  Map<String, dynamic>? get _selectedAddress {
    for (final address in _addresses) {
      if (address['addressId']?.toString() == _selectedAddressId) {
        return address;
      }
    }
    return null;
  }

  Future<void> _loadAddresses() async {
    if (mounted) {
      setState(() {
        _loadingAddresses = true;
        _addressError = null;
      });
    }
    try {
      final addresses = await GarmentCareService.customerAddresses();
      if (!mounted) return;
      final previousId = _selectedAddressId;
      final selectedId =
          addresses.any(
            (address) => address['addressId']?.toString() == previousId,
          )
          ? previousId
          : addresses.isEmpty
          ? null
          : addresses.first['addressId']?.toString();
      setState(() {
        _addresses = addresses;
        _selectedAddressId = selectedId;
        _loadingAddresses = false;
      });
      _syncAddressSnapshot();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = [];
        _loadingAddresses = false;
        _addressError = 'Saved addresses could not be loaded. Please retry.';
      });
    }
  }

  void _syncAddressSnapshot() {
    final selected = _selectedAddress;
    if (selected == null) {
      _address.clear();
      _landmark.clear();
      _pincode.clear();
      return;
    }
    final details = AddressDetails.fromMap(selected);
    final formattedAddress = selected['formattedAddress']?.toString().trim();
    _address.text = formattedAddress?.isNotEmpty == true
        ? formattedAddress!
        : details.formattedAddress;
    _landmark.text = details.landmark?.trim() ?? '';
    _pincode.text = details.pincode?.trim() ?? '';
  }

  void _selectSavedAddress(String? addressId) {
    if (addressId == null) return;
    setState(() => _selectedAddressId = addressId);
    _syncAddressSnapshot();
  }

  Future<void> _openAddressManager() async {
    await context.push<void>('/customer-addresses');
    if (mounted) await _loadAddresses();
  }

  double get _estimate {
    var serviceTotal = 0.0;
    for (final id in _selected) {
      final service = QuickFixService.byId(id);
      if (service != null && !service.requiresPartnerQuote) {
        serviceTotal += service.midEstimate;
      }
    }
    if (_selected.isEmpty) return 0;
    return serviceTotal +
        _visitFee +
        ((_express || _isExpressSlot) ? _expressFee : 0);
  }

  Future<void> _submit() async {
    if (_isExpressSlot && !_sameDayExpressAvailable) {
      setState(() => _slot = _slots[1]);
      _showMessage(
        'Same-day Express booking closes at 2pm. Please choose a next-day slot.',
      );
      return;
    }
    if (_selected.isEmpty) {
      _showMessage('Choose at least one service to continue.');
      return;
    }
    if (_needsQuote && _notes.text.trim().isEmpty) {
      _showMessage('Describe the service you need a quote for.');
      return;
    }
    if (_selectedAddress == null || _address.text.trim().isEmpty) {
      _showMessage('Choose a saved address for the service visit.');
      return;
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(_pincode.text.trim())) {
      _showMessage('Enter a valid 6-digit service PIN code.');
      return;
    }

    setState(() => _submitting = true);
    final id = await OrderService.createQuickFixOrder(
      serviceIds: _selected.toList(),
      estimatedTotal: _estimate,
      notes: _notes.text.trim(),
      slotLabel: _slot,
      addressLine: _address.text.trim(),
      addressId: _selectedAddressId,
      landmark: _landmark.text.trim(),
      pincode: _pincode.text.trim(),
      express: _express || _isExpressSlot,
      scheduledAt: _scheduledStartAt,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id != null) {
      _showMessage(
        'Quick Care request submitted. Payment is due after service.',
      );
      context.push('/orders?module=quickFix');
    } else {
      _showMessage('Sign in to submit a service request.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleService(QuickFixService service) {
    setState(() {
      if (!_selected.add(service.id)) _selected.remove(service.id);
    });
  }

  void _showPricing() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Estimated service pricing',
                      style: _sectionTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...QuickFixService.catalog.map(
                      (service) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Navigator.of(context).pop();
                          _toggleService(service);
                        },
                        title: Text(service.title),
                        subtitle: Text(service.subtitle),
                        trailing: Text(
                          service.requiresPartnerQuote
                              ? 'Quote'
                              : '₹${service.minInr}–₹${service.maxInr}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Home visit'),
                      trailing: Text('₹49'),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Express scheduling'),
                      trailing: Text('+₹99'),
                    ),
                    Text(
                      'These are estimates. The partner confirms any final quote before starting work. You pay after the service is completed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 62,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Care & Home Services',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Small fixes. Big convenience.',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Home',
            child: InkWell(
              onTap: () => context.go('/home'),
              child: Image.asset(
                'assets/images/quick_care/header_home.png',
                width: 58,
                height: 54,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          _heroCard(context),
          const SizedBox(height: 4),
          _trackOrdersLink(context),
          const SizedBox(height: 4),
          _sectionHeader(
            'Available Services',
            action: 'See pricing',
            onAction: _showPricing,
          ),
          const SizedBox(height: 4),
          _serviceGrid(context),
          const SizedBox(height: 4),
          _featuredService(context, QuickFixService.byId('wardrobe')!),
          const SizedBox(height: 10),
          Text('Book Quick Care & Home Services', style: _sectionTitle),
          const SizedBox(height: 6),
          _selectedServiceDetails(context),
          const SizedBox(height: 2),
          _otherServiceOption(),
          const SizedBox(height: 9),
          Text('Preferred Time Slot', style: _sectionTitle),
          const SizedBox(height: 6),
          _timeSlots(context),
          const SizedBox(height: 8),
          _expressCard(context),
          const SizedBox(height: 9),
          Text('Address', style: _sectionTitle),
          const SizedBox(height: 6),
          _addressFields(),
          const SizedBox(height: 9),
          if (!_needsQuote) ...[
            Text('Additional Notes', style: _sectionTitle),
            const SizedBox(height: 6),
            _inputCard(
              controller: _notes,
              hint: 'Urgency, fabric type, special instructions…',
              icon: Icons.description_outlined,
              maxLines: 2,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _bookingBar(context),
    );
  }

  Widget _heroCard(BuildContext context) {
    final imageWidth = (MediaQuery.sizeOf(context).width - 32) * 0.53;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE4EE), Color(0xFFFFF4F5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: imageWidth,
            child: Image.asset(
              'assets/images/quick_care/hero_tools.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFEAF1),
                    const Color(0xFFFFEAF1).withValues(alpha: 0.96),
                    const Color(0xFFFFEAF1).withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 0.84],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 10, 4, 7),
            child: SizedBox(
              width: imageWidth * 1.03,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Expert care\nat your doorstep',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.primaryDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _benefit('Convenient home visit'),
                  _benefit('Per-task pricing (estimate)'),
                  _benefit('Quick & reliable service'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackOrdersLink(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      height: 34,
      child: TextButton.icon(
        onPressed: () => context.push('/orders?module=quickFix'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF9C1453),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.receipt_long_outlined, size: 17),
        label: const Text('Your Orders · Track your order'),
      ),
    ),
  );

  Widget _benefit(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 14,
          color: Color(0xFFDE0A69),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(
    String title, {
    String? action,
    VoidCallback? onAction,
  }) => Row(
    children: [
      Expanded(child: Text(title, style: _sectionTitle)),
      if (action != null)
        TextButton.icon(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded),
          label: Text(action),
        ),
    ],
  );

  Widget _serviceGrid(BuildContext context, {bool includeExtras = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 340 ? 2 : 3;
          final services = includeExtras
              ? QuickFixService.catalog
                    .where(
                      (service) =>
                          service.id == 'saree_draping' ||
                          service.id == 'other_quote',
                    )
                    .toList()
              : QuickFixService.catalog
                    .where(
                      (service) => const {
                        'pico_fall',
                        'rafu',
                        'zip',
                        'button',
                        'minor_alt',
                        'express_stitch',
                      }.contains(service.id),
                    )
                    .toList();
          return GridView.builder(
            itemCount: services.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 7,
              mainAxisSpacing: 4,
              mainAxisExtent: 82,
            ),
            itemBuilder: (context, index) =>
                _serviceTile(context, services[index]),
          );
        },
      );

  Widget _featuredService(BuildContext context, QuickFixService service) {
    final imageWidth = MediaQuery.sizeOf(context).width * 0.37;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _toggleService(service),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEAF0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: imageWidth,
                height: 68,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  child: Image.asset(
                    _serviceImage(service.id),
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'assets/images/quick_care/wardrobe_hanger.png',
                width: 52,
                height: 52,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFF9C1453),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Organize, maintain, repair\nand keep your wardrobe ready',
                      maxLines: 2,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceTile(BuildContext context, QuickFixService service) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleService(service),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 47,
                width: double.infinity,
                child: Image.asset(
                  _serviceImage(service.id),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            service.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF102451),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _serviceSubtitle(service.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
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

  Widget _selectedServiceDetails(BuildContext context) {
    return Column(
      children: _bookableServices
          .map(
            (service) => Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleService(service),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          _serviceImage(service.id),
                          width: 44,
                          height: 38,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF102451),
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              service.requiresPartnerQuote
                                  ? 'Partner quote after assessment'
                                  : 'Estimated price: ₹${service.minInr} – ₹${service.maxInr}',
                              style: GoogleFonts.poppins(
                                color: AppColors.textSecondary,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: _selected.contains(service.id),
                        activeColor: const Color(0xFFCE075F),
                        visualDensity: VisualDensity.compact,
                        onChanged: (_) => _toggleService(service),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _otherServiceOption() {
    final service = QuickFixService.byId('other_quote')!;
    final selected = _selected.contains(service.id);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleService(service),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAF1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.note_add_outlined,
                      color: Color(0xFFCE075F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF102451),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          service.subtitle,
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: selected,
                    activeColor: const Color(0xFFCE075F),
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => _toggleService(service),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(height: 2),
          _inputCard(
            controller: _notes,
            hint: 'Please specify the service you need…',
            icon: Icons.description_outlined,
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _timeSlots(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 330 ? 2 : 4;
      final width = (constraints.maxWidth - 6 * (columns - 1)) / columns;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _availableSlots.map((slot) {
          final selected = slot == _slot;
          final parts = slot.split(' — ');
          return SizedBox(
            width: width,
            child: InkWell(
              onTap: () {
                if (slot.startsWith('Same day') && !_sameDayExpressAvailable) {
                  return;
                }
                setState(() => _slot = slot);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 43),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFF5F8) : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF18AB2)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? AppColors.primary : AppColors.textHint,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parts.first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                              fontSize: 9.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (parts.length > 1)
                            Text(
                              parts.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 9,
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
        }).toList(),
      );
    },
  );

  Widget _expressCard(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.bolt_rounded, color: Color(0xFFDE0A69), size: 23),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Express fee (+₹99)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                'Priority scheduling when available',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _express,
          onChanged: (value) => setState(() => _express = value),
          activeTrackColor: const Color(0xFFE7508B),
        ),
      ],
    ),
  );

  Widget _addressFields() {
    if (_loadingAddresses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEAF0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _addressError ?? 'Add a saved address for the home visit.',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            TextButton.icon(
              onPressed: _addressError == null
                  ? _openAddressManager
                  : _loadAddresses,
              icon: Icon(
                _addressError == null
                    ? Icons.add_location_alt_outlined
                    : Icons.refresh_rounded,
                color: const Color(0xFFDE0A69),
              ),
              label: Text(
                _addressError == null ? 'Add or choose address' : 'Retry',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9C1453),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final selected = _selectedAddress;
    final addressDetails = selected == null
        ? null
        : AddressDetails.fromMap(selected);
    final formattedAddress = selected?['formattedAddress']?.toString().trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAF0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedAddressId,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.home_outlined,
                color: Color(0xFFDE0A69),
                size: 20,
              ),
              labelText: 'Saved home address',
              labelStyle: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            items: _addresses
                .map(
                  (address) => DropdownMenuItem<String>(
                    value: address['addressId']?.toString(),
                    child: Text(
                      address['addressType']?.toString() ?? 'Address',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _selectSavedAddress,
          ),
          if (selected != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 4, bottom: 4),
              child: Text(
                formattedAddress?.isNotEmpty == true
                    ? formattedAddress!
                    : addressDetails?.formattedAddress ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: Text(
                'PIN code: ${addressDetails?.pincode ?? 'Not available'}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9C1453),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Divider(height: 1, color: Colors.white),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openAddressManager,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: const Color(0xFF9C1453),
              ),
              icon: const Icon(Icons.location_on_outlined, size: 17),
              label: Text(
                'Use a different or new address',
                style: GoogleFonts.poppins(fontSize: 10.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF8DCE7)),
    ),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    ),
  );

  Widget _bookingBar(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.98),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Estimated price',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Estimate only. Partner confirms the price before work starts.',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                Text(
                  _selected.isEmpty
                      ? 'Choose services to see the estimate'
                      : _needsQuote
                      ? 'Partner quote pending · visit ₹49'
                      : 'Service + visit ₹49${(_express || _isExpressSlot) ? ' + express ₹99' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 8.5,
                  ),
                ),
                Text(
                  _selected.isEmpty ? '₹0' : '₹${_estimate.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFBF0054),
                    fontSize: 19,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_submitting)
                      const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.bolt_rounded, size: 19),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Submit Service Request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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

  String _serviceImage(String id) => switch (id) {
    'pico_fall' || 'saree_draping' => 'assets/images/quick_care/pico_fall.png',
    'rafu' => 'assets/images/quick_care/rafu.png',
    'zip' => 'assets/images/quick_care/zip.png',
    'button' => 'assets/images/quick_care/button.png',
    'minor_alt' => 'assets/images/quick_care/minor_alt.png',
    'express_stitch' => 'assets/images/quick_care/express_stitch.png',
    'wardrobe' => 'assets/images/quick_care/wardrobe.png',
    _ => 'assets/images/quick_care/hero_tools.png',
  };

  String _serviceSubtitle(String id) => switch (id) {
    'pico_fall' => 'Neat finish for sarees',
    'rafu' => 'Fix tears like new',
    'zip' => 'Smooth & durable',
    'button' => 'Replace or fix',
    'minor_alt' => 'Size & fit adjustments',
    'express_stitch' => 'Quick turnaround',
    _ => QuickFixService.byId(id)?.subtitle ?? '',
  };

  TextStyle get _sectionTitle => GoogleFonts.playfairDisplay(
    color: const Color(0xFF102451),
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}
