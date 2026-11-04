import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'helpdesk_order_explorer_screen.dart';

class OwnerSupportInboxScreen extends StatefulWidget {
  const OwnerSupportInboxScreen({super.key});

  @override
  State<OwnerSupportInboxScreen> createState() =>
      _OwnerSupportInboxScreenState();
}

class _OwnerSupportInboxScreenState extends State<OwnerSupportInboxScreen> {
  String _selectedQueue = 'All';
  String _selectedSection = 'Customer orders';
  String _selectedOrderQueue = 'All';
  String _selectedOrderGroup = 'All groups';
  final _orderSearch = TextEditingController();
  List<Map<String, dynamic>> _orders = const [];
  bool _ordersLoading = true;
  bool _ordersLoaded = false;
  bool _ordersRequestActive = false;
  String? _ordersError;
  Timer? _refreshTimer;

  static const _statuses = [
    'Open',
    'In Progress',
    'Escalated',
    'Waiting Customer',
    'Resolved',
    'Closed',
  ];
  static const _queues = [
    'All',
    'Open Ticket',
    'In-Progress',
    'Escalation',
    'Close Ticket',
  ];
  static const _orderQueues = ['All', 'Needs partner', 'In progress', 'Closed'];
  static const _orderGroups = [
    'All groups',
    'Quick Care',
    'Garment Care',
    'Tailoring',
    'Measurements & Delivery',
    'Other orders',
  ];
  static const _teams = <String, String>{
    'orders': 'Tailoring / Orders',
    'measurements': 'Measurements',
    'design_and_fabric': 'Design & Fabric',
    'payments': 'Payments',
    'garment_care': 'Garment Care',
    'quick_care': 'Quick Care',
    'delivery': 'Delivery',
    'customer_support': 'General Support',
  };

  @override
  void initState() {
    super.initState();
    _loadCustomerOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadCustomerOrders(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orderSearch.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerOrders() async {
    if (_ordersRequestActive) return;
    _ordersRequestActive = true;
    if (!_ordersLoaded && mounted) setState(() => _ordersLoading = true);
    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('listHelpdeskOrders')
          .call(<String, dynamic>{'limit': 500});
      final payload = Map<String, dynamic>.from(response.data as Map);
      final orders = (payload['orders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _ordersError = null;
        _ordersLoading = false;
        _ordersLoaded = true;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _ordersError = error.code == 'permission-denied'
            ? 'Helpdesk access is required to view customer orders.'
            : error.message ?? 'Could not load customer orders.';
        _ordersLoading = false;
        _ordersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ordersError = 'Could not load customer orders. Pull down to retry.';
        _ordersLoading = false;
        _ordersLoaded = true;
      });
    } finally {
      _ordersRequestActive = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('Helpdesk'),
      backgroundColor: const Color(0xFFF8F6FC),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          // Helpdesk staff enter this route with go('/support') after
          // workspace selection, so there is no useful route beneath it.
          // Popping can reopen LoginScreen, which restores the same saved
          // Helpdesk destination and sends the user straight back here.
          if (GoRouterState.of(context).uri.path == '/support') {
            context.go('/home');
            return;
          }
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/owner');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: [
        IconButton(
          tooltip: 'Track all customer orders',
          onPressed: () => context.push('/support/orders'),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                selected: _selectedSection == 'Customer orders',
                onSelected: (_) =>
                    setState(() => _selectedSection = 'Customer orders'),
                label: Text('Customer orders (${_orders.length})'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                selected: _selectedSection == 'Support tickets',
                onSelected: (_) =>
                    setState(() => _selectedSection = 'Support tickets'),
                label: const Text('Support tickets'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedSection == 'Customer orders'
              ? _buildCustomerOrders(context)
              : _buildSupportTickets(context),
        ),
      ],
    ),
  );

  Widget _buildSupportTickets(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Support requests are available to configured support staff and administrators.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final tickets = snapshot.data!.docs;
      final counts = <String, int>{for (final queue in _queues) queue: 0};
      for (final ticket in tickets) {
        counts['All'] = (counts['All'] ?? 0) + 1;
        final status = ticket.data()['status']?.toString() ?? 'Open';
        final queue = _queueForStatus(status);
        counts[queue] = (counts[queue] ?? 0) + 1;
      }
      final filtered = tickets.where((ticket) {
        return _selectedQueue == 'All' ||
            _queueForStatus(ticket.data()['status']?.toString() ?? 'Open') ==
                _selectedQueue;
      }).toList();
      return Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _queues.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final queue = _queues[index];
                return ChoiceChip(
                  selected: _selectedQueue == queue,
                  onSelected: (_) => setState(() => _selectedQueue = queue),
                  label: Text('$queue (${counts[queue] ?? 0})'),
                );
              },
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.support_agent_outlined,
                            size: 48,
                            color: Color(0xFFAAA4B5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedQueue == 'All'
                                ? 'No support requests yet.'
                                : 'No ${_selectedQueue.toLowerCase()} requests.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedQueue == 'All'
                                ? 'New customer and service requests will appear here.'
                                : 'Requests will appear here when their status changes.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF777286)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ticket = filtered[index];
                      return _SupportRequestCard(
                        ticketId: ticket.id,
                        data: ticket.data(),
                        onTap: () => _editTicket(
                          context,
                          ticketId: ticket.id,
                          data: ticket.data(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  Widget _buildCustomerOrders(BuildContext context) {
    final groupOrders = _selectedOrderGroup == 'All groups'
        ? _orders
        : _orders
              .where((order) => _orderGroup(order) == _selectedOrderGroup)
              .toList();
    final counts = <String, int>{
      for (final queue in _orderQueues)
        queue: queue == 'All'
            ? groupOrders.length
            : groupOrders
                  .where((order) => _orderBelongsToQueue(order, queue))
                  .length,
    };
    final filtered = groupOrders.where((order) {
      final matchesQueue =
          _selectedOrderQueue == 'All' ||
          _orderBelongsToQueue(order, _selectedOrderQueue);
      final query = _orderSearch.text.trim().toLowerCase();
      final searchable = [
        order['orderNumber'],
        order['orderId'],
        order['customerName'],
        order['customerPhone'],
        order['customerUid'],
        order['summary'],
        order['status'],
        order['orderType'],
        order['assignmentStatus'],
        order['workflowStatus'],
        order['servicePincode'],
        order['deliveryAddress'],
      ].join(' ').toLowerCase();
      return matchesQueue && (query.isEmpty || searchable.contains(query));
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: TextField(
            controller: _orderSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search order, customer, service or PIN code',
              suffixIcon: _orderSearch.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _orderSearch.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _orderGroups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final group = _orderGroups[index];
              final count = group == 'All groups'
                  ? _orders.length
                  : _orders
                        .where((order) => _orderGroup(order) == group)
                        .length;
              return ChoiceChip(
                selected: _selectedOrderGroup == group,
                onSelected: (_) => setState(() => _selectedOrderGroup = group),
                label: Text('$group ($count)'),
              );
            },
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _orderQueues.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final queue = _orderQueues[index];
              return ChoiceChip(
                selected: _selectedOrderQueue == queue,
                onSelected: (_) => setState(() => _selectedOrderQueue = queue),
                label: Text(
                  '${queue == 'All' ? 'All orders' : queue} (${counts[queue]})',
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _ordersLoading
              ? const Center(child: CircularProgressIndicator())
              : _ordersError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_ordersError!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loadCustomerOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 46,
                          color: Color(0xFFAAA4B5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          groupOrders.isEmpty
                              ? 'No customer orders yet.'
                              : _selectedOrderQueue == 'All'
                              ? 'No orders match this search.'
                              : 'No ${_selectedOrderQueue.toLowerCase()} orders${_selectedOrderGroup == 'All groups' ? '' : ' in ${_selectedOrderGroup.toLowerCase()}'}.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'New QuickCare, Garment Care and Tailoring orders will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF777286)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCustomerOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      final orderId = order['orderId']?.toString() ?? '';
                      final type = order['orderType']?.toString() ?? '';
                      final status = _orderStatus(order);
                      return Card(
                        color: Colors.white,
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFBE7F0),
                            child: Icon(
                              _orderIcon(type),
                              color: const Color(0xFFB70D5C),
                            ),
                          ),
                          title: Text(
                            order['summary']?.toString().trim().isNotEmpty ==
                                    true
                                ? order['summary'].toString()
                                : '${_orderTypeLabel(type)} order',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${_orderTypeLabel(type)} · ${order['customerName'] ?? 'Customer'}'
                            '${order['customerPhone']?.toString().trim().isNotEmpty == true ? ' · ${order['customerPhone']}' : ''}\n'
                            '${order['orderNumber'] ?? orderId} · $status'
                            '${order['servicePincode']?.toString().trim().isNotEmpty == true ? '\nPIN ${order['servicePincode']}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showHelpdeskOrderDetails(
                            context,
                            orderId: orderId,
                            orderType: type,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _orderGroup(Map<String, dynamic> order) {
    final type = order['orderType']?.toString();
    return switch (type) {
      'quick_care' => 'Quick Care',
      'garment_care' => 'Garment Care',
      'tailoring' => 'Tailoring',
      'measurements' || 'delivery' => 'Measurements & Delivery',
      _ => 'Other orders',
    };
  }

  bool _orderBelongsToQueue(Map<String, dynamic> order, String queue) {
    final type = order['orderType']?.toString();
    final workflow = (order['workflowStatus'] ?? order['status'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\s-]'), '');
    final assignment = (order['assignmentStatus'] ?? '')
        .toString()
        .toLowerCase();
    final closed = [
      'completed',
      'cancelled',
      'delivered',
      'closed',
      'resolved',
    ];
    final active = [
      'accepted',
      'inprogress',
      'paused',
      'awaitingcustomerapproval',
      'paymentpending',
    ];
    if (queue == 'Closed') {
      return closed.contains(workflow) || assignment == 'cancelled';
    }
    if (queue == 'In progress') {
      return active.contains(workflow) ||
          assignment == 'accepted' ||
          (type != 'quick_care' && workflow.contains('progress'));
    }
    if (queue == 'Needs partner') {
      if (type == 'quick_care') {
        return ![...active, ...closed].contains(workflow) &&
            !['accepted', 'completed', 'cancelled'].contains(assignment);
      }
      return !closed.contains(workflow) &&
          (workflow.contains('pending') || workflow.contains('partner'));
    }
    return true;
  }

  String _orderStatus(Map<String, dynamic> order) {
    final type = order['orderType']?.toString();
    final workflow = (order['workflowStatus'] ?? order['status'] ?? 'Unknown')
        .toString();
    if (type != 'quick_care') return workflow;
    final assignment = (order['assignmentStatus'] ?? 'searching').toString();
    final label = switch (workflow.toLowerCase()) {
      'requestsubmitted' => 'Request submitted',
      'partnerassigned' => 'Partner assigned',
      'accepted' => 'Accepted',
      'inprogress' => 'In progress',
      'paused' => 'Paused',
      'awaitingcustomerapproval' => 'Quote awaiting approval',
      'paymentpending' => 'Payment pending',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => workflow,
    };
    final needsPartner = [
      'searching',
      'available',
      'unassigned',
      'reassigning',
    ].contains(assignment.toLowerCase());
    return needsPartner
        ? '$label · Needs partner'
        : '$label · ${assignment.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match[0]!.toLowerCase()}').trim()}';
  }

  String _orderTypeLabel(String type) => switch (type) {
    'quick_care' => 'QuickCare',
    'garment_care' => 'Garment Care',
    'tailoring' => 'Tailoring',
    _ => 'Customer service',
  };

  IconData _orderIcon(String type) => switch (type) {
    'quick_care' => Icons.home_repair_service_outlined,
    'garment_care' => Icons.local_laundry_service_outlined,
    'tailoring' => Icons.design_services_outlined,
    _ => Icons.receipt_long_outlined,
  };

  static Future<void> _editTicket(
    BuildContext context, {
    required String ticketId,
    required Map<String, dynamic> data,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => _EditSupportTicketSheet(ticketId: ticketId, data: data),
    );
  }

  static String _queueForStatus(String status) => switch (status) {
    'Open' => 'Open Ticket',
    'In Progress' => 'In-Progress',
    'Escalated' => 'Escalation',
    'Closed' || 'Resolved' => 'Close Ticket',
    _ => 'Open Ticket',
  };
}

class _EditSupportTicketSheet extends StatefulWidget {
  const _EditSupportTicketSheet({required this.ticketId, required this.data});

  final String ticketId;
  final Map<String, dynamic> data;

  @override
  State<_EditSupportTicketSheet> createState() =>
      _EditSupportTicketSheetState();
}

class _EditSupportTicketSheetState extends State<_EditSupportTicketSheet> {
  late final TextEditingController _responseController;
  late String _status;
  late String _assignedTeam;
  late final List<Map<String, dynamic>> _customerComments;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _responseController = TextEditingController(
      text: widget.data['response']?.toString() ?? '',
    );
    _status =
        _OwnerSupportInboxScreenState._statuses.contains(widget.data['status'])
        ? widget.data['status'].toString()
        : 'Open';
    _assignedTeam =
        _OwnerSupportInboxScreenState._teams.containsKey(
          widget.data['assignedTeam'],
        )
        ? widget.data['assignedTeam'].toString()
        : 'customer_support';
    _customerComments =
        (widget.data['customerComments'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  String _saveError(Object error) {
    if (error is FirebaseAuthException) {
      return error.code == 'user-disabled'
          ? 'This account is disabled. Contact an administrator.'
          : 'Could not refresh your sign-in. Sign in again and retry.';
    }
    if (error is FirebaseFunctionsException) {
      switch (error.code.toLowerCase()) {
        case 'not-found':
          return 'The Helpdesk update function is not deployed to the active Firebase project.';
        case 'permission-denied':
          return 'This signed-in account is not configured for Admin or Helpdesk access.';
        case 'unauthenticated':
          return 'Firebase did not receive your signed-in identity. Retry; if it persists, check the function access configuration.';
        case 'invalid-argument':
          return error.message ??
              'Check the status, team, and reply, then retry.';
        default:
          return 'Save failed (${error.code}): ${error.message ?? 'Please retry.'}';
      }
    }
    return 'Could not save this request: $error';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-token-expired');
      }
      // Refresh the existing Firebase session; this does not request a phone OTP.
      await user.getIdToken(true);
      await FirebaseFunctions.instance
          .httpsCallable('listHelpdeskOrders')
          .call(<String, dynamic>{
            'action': 'updateHelpdeskTicket',
            'ticketId': widget.ticketId,
            'status': _status,
            'assignedTeam': _assignedTeam,
            'response': _responseController.text.trim(),
          });
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _saveError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.data['subject']?.toString() ?? 'Support request',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close ticket editor',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.data['customerName'] ?? 'Customer'} · ${widget.data['category'] ?? 'Other'}',
                      style: const TextStyle(color: Color(0xFF777286)),
                    ),
                    if (const {
                      'bulk_order',
                      'dress_rental',
                    }.contains(widget.data['requestType'])) ...[
                      const SizedBox(height: 6),
                      SelectableText('Helpdesk reference: ${widget.ticketId}'),
                    ],
                    if ((widget.data['linkedOrderId']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${switch (widget.data['linkedOrderType']) {
                          'garment_care' => 'Garment Care order',
                          'quick_care' => 'Quick Care order',
                          _ => 'Tailoring order',
                        }}: ${widget.data['linkedOrderId']}',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => showHelpdeskOrderDetails(
                            context,
                            orderId: widget.data['linkedOrderId'].toString(),
                            orderType: switch (widget.data['linkedOrderType']) {
                              'garment_care' => 'garment_care',
                              'quick_care' => 'quick_care',
                              _ => 'tailoring',
                            },
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open linked order details'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SelectableText(widget.data['message']?.toString() ?? ''),
                    if (_customerComments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Customer comments',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      for (final comment in _customerComments)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(comment['text']?.toString() ?? ''),
                        ),
                    ],
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _OwnerSupportInboxScreenState._statuses
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _assignedTeam,
                      decoration: const InputDecoration(
                        labelText: 'Route to service team',
                      ),
                      items: _OwnerSupportInboxScreenState._teams.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _assignedTeam = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _responseController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Reply to customer',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save update'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SupportRequestCard extends StatelessWidget {
  const _SupportRequestCard({
    required this.ticketId,
    required this.data,
    required this.onTap,
  });

  final String ticketId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['subject']?.toString() ?? 'Support request',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _AdminStatusChip(status: data['status']?.toString() ?? 'Open'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${data['customerName'] ?? 'Customer'} · ${data['category'] ?? 'Other'}',
              style: const TextStyle(color: Color(0xFF777286), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              data['message']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 16),
                const SizedBox(width: 5),
                Text(
                  'Queue: ${data['assignedTeam'] ?? 'customer_support'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                Text(
                  ticketId.length > 8 ? ticketId.substring(0, 8) : ticketId,
                  style: const TextStyle(
                    color: Color(0xFF777286),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminStatusChip extends StatelessWidget {
  const _AdminStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF5B35D5).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: Color(0xFF5B35D5),
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
