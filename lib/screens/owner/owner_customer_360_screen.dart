import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'helpdesk_order_explorer_screen.dart';

class OwnerCustomer360Screen extends StatefulWidget {
  const OwnerCustomer360Screen({super.key});

  @override
  State<OwnerCustomer360Screen> createState() => _OwnerCustomer360ScreenState();
}

class _OwnerCustomer360ScreenState extends State<OwnerCustomer360Screen> {
  final _queryController = TextEditingController();
  List<Map<String, dynamic>> _customers = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _queryController.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Enter at least 3 characters to search.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _customers = const [];
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Your sign-in has expired. Sign in again and retry.';
        });
        return;
      }
      // Refresh the Firebase ID token before the admin callable. This refreshes
      // the existing session and does not send a phone verification SMS.
      await user.getIdToken(true);
      final result = await FirebaseFunctions.instance
          .httpsCallable('listHelpdeskOrders')
          .call(<String, dynamic>{
            'action': 'searchAdminCustomer360',
            'query': query,
          });
      final payload = Map<String, dynamic>.from(result.data as Map);
      final customers = (payload['customers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final code = error.code.toLowerCase();
      setState(() {
        _loading = false;
        _error = switch (code) {
          'permission-denied' =>
            'Configured Admin access is required to open a customer 360 view.',
          'not-found' =>
            'The Customer 360 search function is not deployed to the active Firebase project.',
          'unauthenticated' =>
            'Firebase did not receive your signed-in identity. Retry; if it persists, check the function access configuration.',
          _ =>
            error.message ??
                'Could not search customer records (${error.code}). Please retry.',
        };
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'user-disabled'
            ? 'This account is disabled. Contact an administrator.'
            : 'Could not refresh your sign-in. Sign in again and retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not search customer records. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('Customer 360°'),
      backgroundColor: const Color(0xFFF8F6FC),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find a customer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Search by registered phone, customer UID, account ID, or order reference.',
                  style: TextStyle(color: Color(0xFF777286)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _queryController,
                  onSubmitted: (_) => _search(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Phone, customer ID, or order number',
                    filled: true,
                    fillColor: const Color(0xFFF8F6FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_search_outlined),
                    label: Text(
                      _loading ? 'Searching…' : 'Open customer record',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _MessageCard(message: _error!, isError: true),
        ],
        if (_searched && !_loading && _error == null && _customers.isEmpty) ...[
          const SizedBox(height: 12),
          const _MessageCard(
            message:
                'No customer record matched that search. Try the full phone number or an order reference.',
          ),
        ],
        for (final customer in _customers) ...[
          const SizedBox(height: 12),
          _CustomerRecord(customer: customer),
        ],
      ],
    ),
  );
}

class _CustomerRecord extends StatelessWidget {
  const _CustomerRecord({required this.customer});

  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    final profiles = _mapList(customer['profiles']);
    final addresses = _mapList(customer['addresses']);
    final orders = _mapList(customer['orders']);
    final tickets = _mapList(customer['tickets']);
    final entries = <_ActivityEntry>[
      for (final order in orders)
        _ActivityEntry(
          date: _date(order['createdAt']),
          title:
              '${_serviceName(order['orderType'])} · ${order['status'] ?? 'Status unavailable'}',
          subtitle:
              '${order['orderNumber'] ?? order['orderId'] ?? ''} · ${order['summary'] ?? 'Order'}',
          icon: Icons.receipt_long_outlined,
          order: order,
        ),
      for (final ticket in tickets)
        _ActivityEntry(
          date: _date(ticket['updatedAt'] ?? ticket['createdAt']),
          title:
              '${ticket['category'] ?? 'Support case'} · ${ticket['status'] ?? 'Open'}',
          subtitle: ticket['subject']?.toString() ?? 'Support request',
          icon: Icons.support_agent_outlined,
          ticket: ticket,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text(customer['name'], 'Customer'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoLine(
                  label: 'Verified phone',
                  value: _text(customer['phone']),
                ),
                _InfoLine(label: 'Email', value: _text(customer['email'])),
                _InfoLine(label: 'Customer UID', value: _text(customer['uid'])),
                _InfoLine(
                  label: 'Account ID',
                  value: _text(customer['accountId']),
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(label: 'Profiles', count: profiles.length),
                    _CountChip(label: 'Orders', count: orders.length),
                    _CountChip(label: 'Support cases', count: tickets.length),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (profiles.isNotEmpty) ...[
          const _SectionTitle('Profiles'),
          Card(
            color: Colors.white,
            child: Column(
              children: profiles
                  .map(
                    (profile) => ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(
                        _text(
                          profile['displayName'] ?? profile['name'],
                          'Profile',
                        ),
                      ),
                      subtitle: Text(
                        [
                          _text(profile['role']),
                          _text(profile['partnerType']),
                          _text(
                            profile['status'] ?? profile['operationalStatus'],
                          ),
                        ].where((value) => value.isNotEmpty).join(' · '),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (addresses.isNotEmpty) ...[
          const _SectionTitle('Saved addresses'),
          Card(
            color: Colors.white,
            child: Column(
              children: addresses
                  .map(
                    (address) => ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        _text(
                          address['label'] ?? address['addressType'],
                          'Address',
                        ),
                      ),
                      subtitle: Text(
                        [
                              address['fullAddress'],
                              address['address'],
                              address['addressLine1'],
                              address['addressLine2'],
                              address['landmark'],
                              address['area'],
                              address['cityName'] ?? address['city'],
                              address['stateName'] ?? address['state'],
                              address['pincode'] ?? address['postalCode'],
                            ]
                            .whereType<Object>()
                            .map((value) => value.toString().trim())
                            .where((value) => value.isNotEmpty)
                            .join(', '),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const _SectionTitle('Customer activity'),
        if (entries.isEmpty)
          const _MessageCard(
            message:
                'No orders or support cases are linked to this customer yet.',
          ),
        for (final entry in entries.take(100))
          Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.title),
              subtitle: Text(entry.subtitle),
              trailing: Text(_shortDate(entry.date)),
              onTap: entry.order != null
                  ? () => _openOrder(context, entry.order!)
                  : entry.ticket != null
                  ? () => _showTicket(context, entry.ticket!)
                  : null,
            ),
          ),
      ],
    );
  }

  Future<void> _openOrder(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final type = order['orderType']?.toString() ?? '';
    if (!const {
      'tailoring',
      'measurements',
      'quick_care',
      'garment_care',
      'other',
    }.contains(type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This service record is visible here; detailed view is not available yet.',
          ),
        ),
      );
      return;
    }
    await showHelpdeskOrderDetails(
      context,
      orderId: _text(order['orderId']),
      orderType: type,
    );
  }

  Future<void> _showTicket(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text(ticket['subject'], 'Support case'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${ticket['category'] ?? 'Other'} · ${ticket['status'] ?? 'Open'}',
                ),
                const SizedBox(height: 14),
                Text(_text(ticket['message'])),
                if (ticket['requestDetails'] is Map) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Request details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final entry in (ticket['requestDetails'] as Map).entries)
                    Text('${entry.key}: ${entry.value}'),
                ],
                if (_text(ticket['response']).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Helpdesk response',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(ticket['response'].toString()),
                ],
                const SizedBox(height: 16),
                Text(
                  'Reference: ${ticket['id'] ?? ''}',
                  style: const TextStyle(color: Color(0xFF777286)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.order,
    this.ticket,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? ticket;
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(color: Color(0xFF777286))),
        ),
        Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      child: Text('$count', style: const TextStyle(fontSize: 11)),
    ),
    label: Text(label),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Card(
    color: isError ? const Color(0xFFFFEEEE) : Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: isError ? Colors.red.shade700 : null),
      ),
    ),
  );
}

List<Map<String, dynamic>> _mapList(Object? value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _serviceName(Object? value) => switch (value?.toString()) {
  'garment_care' => 'Garment Care',
  'quick_care' => 'Quick Care',
  'tailoring' => 'Tailoring',
  'measurements' => 'Measurements',
  'delivery' => 'Delivery',
  _ => 'Order',
};

DateTime _date(Object? value) {
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _shortDate(DateTime value) => value.millisecondsSinceEpoch == 0
    ? '—'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
