import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../services/customer_support_service.dart';
import '../../services/order_lifecycle_service.dart';

const _supportPurple = Color(0xFF5B35D5);
const _supportInk = Color(0xFF211D32);
const _supportMuted = Color(0xFF777286);
const _supportBackground = Color(0xFFF8F6FC);

class CustomerHelpSupportScreen extends StatelessWidget {
  const CustomerHelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileName = AppState.instance.profile?.name.trim() ?? '';
    final name = profileName.isNotEmpty
        ? profileName
        : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : 'there');

    return Scaffold(
      backgroundColor: _supportBackground,
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
        backgroundColor: _supportBackground,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Sign in to view customer support.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SmartHelpCard(
                  customerName: name,
                  onChat: () => _openAssistant(context, user.uid),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  title: 'Quick actions',
                  subtitle: 'Choose a topic and get help right away.',
                ),
                const SizedBox(height: 12),
                _QuickActionGrid(
                  onSelect: (action) =>
                      _handleQuickAction(context, action, customerName: name),
                ),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Order awareness',
                  subtitle:
                      'Live order details from your SuiSakhi account. Informational questions do not create a ticket.',
                  trailing: TextButton(
                    onPressed: () => context.push('/orders'),
                    child: const Text('All orders'),
                  ),
                ),
                const SizedBox(height: 10),
                _CustomerOrders(uid: user.uid, customerName: name),
                const SizedBox(height: 22),
                _SectionHeading(
                  title: 'My support requests',
                  subtitle: 'Follow a request you have already submitted.',
                  trailing: TextButton.icon(
                    onPressed: () => _openTicket(context, customerName: name),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ),
                const SizedBox(height: 10),
                const _CustomerTickets(),
                const SizedBox(height: 18),
                const _SafetyNote(),
              ],
            ),
    );
  }

  static void _handleQuickAction(
    BuildContext context,
    _QuickAction action, {
    required String customerName,
  }) {
    switch (action.id) {
      case 'track':
        context.push('/orders');
        break;
      case 'tailoring':
        _showTopic(
          context,
          title: 'Tailoring help',
          description:
              'Check your order journey, delivery estimate and saved order details. If a change needs a team member, send a request linked to the order.',
          primaryLabel: 'View my orders',
          onPrimary: () => context.push('/orders'),
          secondaryLabel: 'Request tailoring help',
          onSecondary: () => _openTicket(
            context,
            customerName: customerName,
            category: 'Order Issue',
          ),
        );
        break;
      case 'measurements':
        _showMeasurementHelp(context, customerName: customerName);
        break;
      case 'design_fabric':
        context.push('/fabric-help');
        break;
      case 'garment_care':
        context.push('/shop-explore?category=garment_care');
        break;
      case 'payments':
        _showTopic(
          context,
          title: 'Payments & refunds',
          description:
              'Payment and refund decisions are confirmed from your order and payment records. If a payment is missing or looks incorrect, share the order with support for review.',
          primaryLabel: 'View orders and payments',
          onPrimary: () => context.push('/orders'),
          secondaryLabel: 'Report a payment issue',
          onSecondary: () => _openTicket(
            context,
            customerName: customerName,
            category: 'Payment Issue',
          ),
        );
        break;
      case 'issue':
        _openTicket(context, customerName: customerName);
        break;
      case 'assistant':
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) _openAssistant(context, uid);
        break;
    }
  }

  static Future<void> _openTicket(
    BuildContext context, {
    required String customerName,
    String? category,
    String? linkedOrderId,
    String? initialSubject,
  }) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSupportTicketSheet(
        customerName: customerName,
        initialCategory: category,
        initialOrderId: linkedOrderId,
        initialSubject: initialSubject,
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your support request was submitted.')),
      );
    }
  }

  static void _showTopic(
    BuildContext context, {
    required String title,
    required String description,
    required String primaryLabel,
    required VoidCallback onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(color: _supportMuted)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onPrimary();
                },
                child: Text(primaryLabel),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onSecondary();
                },
                child: Text(secondaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showMeasurementHelp(
    BuildContext context, {
    required String customerName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measurement help',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you would like to continue. New partner or video assistance is coordinated with an order.',
              style: TextStyle(color: _supportMuted),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('View measurement history'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/measurements');
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten_rounded),
              title: const Text('Take a new measurement'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/measurement-context');
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call_outlined),
              title: const Text('Partner or video assistance'),
              subtitle: const Text(
                'Available options are coordinated with an order.',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/measurement-context');
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Request fit or alteration help'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openTicket(
                  context,
                  customerName: customerName,
                  category: 'Measurement Issue',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _openAssistant(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssistantSheet(
        uid: uid,
        onRaiseIssue: (category) => _openTicket(
          context,
          customerName: AppState.instance.profile?.name ?? 'Customer',
          category: category,
        ),
      ),
    );
  }
}

class _SmartHelpCard extends StatelessWidget {
  const _SmartHelpCard({required this.customerName, required this.onChat});

  final String customerName;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'good morning'
        : hour < 17
        ? 'good afternoon'
        : 'good evening';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFCEAF2),
                child: Icon(Icons.smart_toy_outlined, color: _supportPurple),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SuiSakhi Smart Help',
                      style: TextStyle(
                        color: _supportInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Your clothing care companion',
                      style: TextStyle(color: _supportMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F6EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Help centre',
                  style: TextStyle(
                    color: Color(0xFF28764A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '👋 Hi $customerName, $greeting',
            style: const TextStyle(
              color: _supportInk,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'How can we help you today?',
            style: TextStyle(color: _supportMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat with SuiSakhi Assistant'),
              style: FilledButton.styleFrom(
                backgroundColor: _supportPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.id, this.title, this.subtitle, this.icon);
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.onSelect});
  final ValueChanged<_QuickAction> onSelect;

  static const _items = [
    _QuickAction(
      'track',
      'Track My Order',
      'Status & delivery',
      Icons.inventory_2_outlined,
    ),
    _QuickAction(
      'tailoring',
      'Tailoring Help',
      'Orders & alterations',
      Icons.checkroom_outlined,
    ),
    _QuickAction(
      'measurements',
      'Measurement Help',
      'Fit & saved measurements',
      Icons.straighten_rounded,
    ),
    _QuickAction(
      'design_fabric',
      'Design & Fabric Help',
      'Styles & materials',
      Icons.palette_outlined,
    ),
    _QuickAction(
      'garment_care',
      'Garment Care Help',
      'Laundry & repairs',
      Icons.local_laundry_service_outlined,
    ),
    _QuickAction(
      'payments',
      'Payments & Refunds',
      'Charges & payment issues',
      Icons.payments_outlined,
    ),
    _QuickAction(
      'issue',
      'Report an Issue',
      'Create a support request',
      Icons.flag_outlined,
    ),
    _QuickAction(
      'assistant',
      'Chat with SuiSakhi',
      'Get guided help',
      Icons.chat_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.68,
    ),
    itemBuilder: (context, index) {
      final action = _items[index];
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelect(action),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: _supportPurple, size: 21),
                const SizedBox(height: 7),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _supportInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _supportMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _supportInk,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(color: _supportMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class _CustomerOrders extends StatelessWidget {
  const _CustomerOrders({required this.uid, required this.customerName});
  final String uid;
  final String customerName;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _MessageCard(
          icon: Icons.cloud_off_outlined,
          message:
              'Order details could not be loaded. Open My Orders to refresh or report an issue.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final docs = [...snapshot.data!.docs]
        ..sort((a, b) => _orderDate(b.data()).compareTo(_orderDate(a.data())));
      final active = docs.where((doc) => !_isClosed(doc.data())).toList();
      final shown = (active.isNotEmpty ? active : docs).take(4).toList();
      if (shown.isEmpty) {
        return const _MessageCard(
          icon: Icons.inventory_2_outlined,
          message: 'Your SuiSakhi orders will appear here once placed.',
        );
      }
      return Column(
        children: [
          for (final doc in shown)
            _OrderAwarenessCard(
              id: doc.id,
              data: doc.data(),
              customerName: customerName,
            ),
        ],
      );
    },
  );
}

class _OrderAwarenessCard extends StatelessWidget {
  const _OrderAwarenessCard({
    required this.id,
    required this.data,
    required this.customerName,
  });

  final String id;
  final Map<String, dynamic> data;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(data['status']?.toString() ?? '');
    final orderLabel = _orderLabel(id, data);
    final kind = _orderKind(data);
    final expected = _dateLabel(_expectedDate(data));
    final tailor = _firstText(data, const ['assignedTailorName', 'tailorName']);
    final closed = _isClosed(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFECE8F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: _supportPurple),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$kind · $orderLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _supportInk,
                  ),
                ),
              ),
              _StatusChip(label: status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(label: 'Current status', value: status),
          if (expected != null)
            _InfoLine(label: 'Expected completion', value: expected),
          if (tailor != null) _InfoLine(label: 'Tailor', value: tailor),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/orders'),
                icon: const Icon(Icons.timeline_rounded, size: 17),
                label: const Text('Track order'),
              ),
              if (!closed &&
                  data['assignmentStatus'] == 'finalized' &&
                  _orderKind(data).toLowerCase().contains('tailor'))
                OutlinedButton.icon(
                  onPressed: () => _contactTailor(context, id, customerName),
                  icon: const Icon(Icons.call_outlined, size: 17),
                  label: const Text('Contact tailor'),
                ),
              if (!closed)
                TextButton(
                  onPressed: () => _showOrderActions(
                    context,
                    id: id,
                    label: orderLabel,
                    customerName: customerName,
                  ),
                  child: const Text('More help'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showOrderActions(
    BuildContext context, {
    required String id,
    required String label,
    required String customerName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Request an address change'),
              subtitle: const Text(
                'Support will review it; the order is not changed automatically.',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                CustomerHelpSupportScreen._openTicket(
                  context,
                  customerName: customerName,
                  category: 'Delivery Issue',
                  linkedOrderId: id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Ask to contact the tailor'),
              subtitle: const Text('We will pass your request to the team.'),
              onTap: () {
                Navigator.pop(sheetContext);
                CustomerHelpSupportScreen._openTicket(
                  context,
                  customerName: customerName,
                  category: 'Order Issue',
                  linkedOrderId: id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Raise an issue'),
              onTap: () {
                Navigator.pop(sheetContext);
                CustomerHelpSupportScreen._openTicket(
                  context,
                  customerName: customerName,
                  linkedOrderId: id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Send an instruction to the tailor'),
              subtitle: const Text(
                'The team will review and pass it along when possible.',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                CustomerHelpSupportScreen._openTicket(
                  context,
                  customerName: customerName,
                  category: 'Order Issue',
                  linkedOrderId: id,
                  initialSubject: 'Please pass a note to my tailor',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _contactTailor(
    BuildContext context,
    String orderId,
    String customerName,
  ) async {
    try {
      final contacts =
          await OrderLifecycleService.getCustomerOrderPartnerContacts(orderId);
      if (!context.mounted) return;
      final phone = (contacts['tailorPhone'] ?? '').toString().trim();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tailor partner contact'),
          content: Text(
            phone.isEmpty
                ? 'A tailor contact is not available for this order yet.'
                : 'Call your SuiSakhi tailor partner at $phone?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (phone.isEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  CustomerHelpSupportScreen._openTicket(
                    context,
                    customerName: customerName,
                    category: 'Order Issue',
                    linkedOrderId: orderId,
                    initialSubject: 'Please help me contact my tailor',
                  );
                },
                child: const Text('Ask support'),
              )
            else
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final launched = await launchUrl(
                    Uri(scheme: 'tel', path: phone),
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the phone app.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
          ],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partner contacts are available after the order is confirmed.',
          ),
        ),
      );
    }
  }
}

class _CustomerTickets extends StatelessWidget {
  const _CustomerTickets();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: CustomerSupportService.watchMyTickets(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _MessageCard(
          icon: Icons.cloud_off_outlined,
          message: 'Support requests could not be loaded right now.',
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final tickets = [...snapshot.data!.docs]
        ..sort((a, b) => _orderDate(b.data()).compareTo(_orderDate(a.data())));
      if (tickets.isEmpty) {
        return const _MessageCard(
          icon: Icons.mark_email_read_outlined,
          message:
              'No support requests yet. Your submitted requests will show here.',
        );
      }
      return Column(
        children: [
          for (final ticket in tickets.take(5))
            _TicketCard(id: ticket.id, data: ticket.data()),
        ],
      );
    },
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFECE8F3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data['subject']?.toString() ?? 'Support request',
                style: const TextStyle(
                  color: _supportInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusChip(label: data['status']?.toString() ?? 'Open'),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${data['category'] ?? 'Other'} · ${_dateLabel(_orderDate(data)) ?? 'Submitted'}',
          style: const TextStyle(color: _supportMuted, fontSize: 12),
        ),
        const SizedBox(height: 7),
        Text(
          data['message']?.toString() ?? '',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _supportInk, fontSize: 13),
        ),
        if ((data['response']?.toString() ?? '').trim().isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            'Support update: ${data['response']}',
            style: const TextStyle(color: _supportMuted, fontSize: 13),
          ),
        ],
        if ((data['linkedOrderId']?.toString() ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Order reference: ${_orderLabel(data['linkedOrderId'].toString(), const {})}',
              style: const TextStyle(color: _supportMuted, fontSize: 12),
            ),
          ),
        Semantics(
          label: 'Support request reference $id',
          child: const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

class _CreateSupportTicketSheet extends StatefulWidget {
  const _CreateSupportTicketSheet({
    required this.customerName,
    this.initialCategory,
    this.initialOrderId,
    this.initialSubject,
  });

  final String customerName;
  final String? initialCategory;
  final String? initialOrderId;
  final String? initialSubject;

  @override
  State<_CreateSupportTicketSheet> createState() =>
      _CreateSupportTicketSheetState();
}

class _CreateSupportTicketSheetState extends State<_CreateSupportTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category;
  String? _orderId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category =
        CustomerSupportService.categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : CustomerSupportService.categories.last;
    _orderId = widget.initialOrderId;
    _subject.text = widget.initialSubject ?? '';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
            children: [
              const Text(
                'Create support request',
                style: TextStyle(
                  fontSize: 21,
                  color: _supportInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tell us what happened. The request starts as Open and will appear in My Support Requests.',
                style: TextStyle(color: _supportMuted),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: CustomerSupportService.categories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _category = value);
                      },
              ),
              const SizedBox(height: 12),
              _OrderLinkDropdown(
                selectedId: _orderId,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _orderId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subject,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'A short summary',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Add a short subject.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  hintText: 'Include details that can help the support team.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 5
                    ? 'Please add a little more detail.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Submitting…' : 'Submit request'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _supportPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CustomerSupportService.createTicket(
        customerName: widget.customerName,
        category: _category,
        subject: _subject.text,
        message: _message.text,
        linkedOrderId: _orderId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FirebaseException
            ? (error.message ?? 'Could not submit the request. Please retry.')
            : 'Could not submit the request. Please retry.';
      });
    }
  }
}

class _OrderLinkDropdown extends StatelessWidget {
  const _OrderLinkDropdown({required this.selectedId, required this.onChanged});
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final containsSelected = docs.any((doc) => doc.id == selectedId);
        return DropdownButtonFormField<String?>(
          key: ValueKey('${selectedId ?? 'none'}_$containsSelected'),
          initialValue: containsSelected ? selectedId : null,
          decoration: const InputDecoration(
            labelText: 'Related order (optional)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No order selected'),
            ),
            for (final doc in docs)
              DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(
                  _orderLabel(doc.id, doc.data()),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _AssistantSheet extends StatefulWidget {
  const _AssistantSheet({required this.uid, required this.onRaiseIssue});
  final String uid;
  final ValueChanged<String?> onRaiseIssue;

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatLine> _messages = [
    const _ChatLine(
      text:
          'Namaste! I can look up your order status and guide you with measurements, fabric, styling and support requests.',
      fromAssistant: true,
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _supportBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFCEAF2),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      color: _supportPurple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SuiSakhi Assistant',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Order-aware help and quick guidance',
                          style: TextStyle(color: _supportMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _PromptChip(
                        label: 'Where is my order?',
                        onTap: () => _send('Where is my order?'),
                      ),
                      _PromptChip(
                        label: 'Fabric advice',
                        onTap: () => _send('Which fabric is good for a kurti?'),
                      ),
                      _PromptChip(
                        label: 'Measurement help',
                        onTap: () => _send('I need measurement help'),
                      ),
                      _PromptChip(
                        label: 'What is in my wishlist?',
                        onTap: () => _send('What is in my wishlist?'),
                      ),
                      _PromptChip(
                        label: 'My garment care requests',
                        onTap: () => _send('Show my garment care requests'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final line in _messages) _ChatBubble(line: line),
                  if (_sending)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(_controller.text),
                        decoration: InputDecoration(
                          hintText: 'Ask SuiSakhi…',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending
                          ? null
                          : () => _send(_controller.text),
                      style: IconButton.styleFrom(
                        backgroundColor: _supportPurple,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatLine(text: text, fromAssistant: false));
      _sending = true;
    });

    final lower = text.toLowerCase();
    String reply;
    if (lower.contains('ticket') ||
        lower.contains('report an issue') ||
        lower.contains('raise an issue')) {
      reply =
          'I’ll open a support request form so you can choose the issue type and add details.';
      widget.onRaiseIssue(_inferTicketCategory(lower));
    } else if (_asksAboutOrder(lower)) {
      reply = await _orderReply();
    } else if (lower.contains('wishlist') || lower.contains('saved design')) {
      reply = await _wishlistReply();
    } else if (lower.contains('garment care') || lower.contains('laundry')) {
      reply = await _moduleOrderReply('care');
    } else if (lower.contains('rental')) {
      reply = await _moduleOrderReply('rental');
    } else if (lower.contains('fabric')) {
      reply =
          'For a daily-wear kurti, breathable cotton and cotton blends are common choices. Rayon or viscose can give a softer drape. The best choice depends on climate, care preference and the selected design; your tailor can confirm suitability before cutting.';
    } else if (lower.contains('sleeve') || lower.contains('style')) {
      reply =
          'For everyday wear, a 3/4 sleeve is a versatile option and works with many kurti designs. Sleeve length and ease can be noted for your tailor to review.';
    } else if (lower.contains('measurement') ||
        lower.contains('tight') ||
        lower.contains('fit')) {
      reply =
          'You can review saved measurement references in My Account → Measurements. If a stitched garment feels tight, tell us which area and link the order; support can route a fitting or alteration request.';
    } else if (lower.contains('payment') || lower.contains('refund')) {
      reply =
          'I can’t confirm a refund or payment outcome in chat. Please share the order and payment details in a Payment Issue request so the team can verify the records.';
    } else if (lower.contains('address') || lower.contains('tailor')) {
      reply =
          'I can pass along an address-change or tailor-contact request for review. It will not change the order until the team confirms it. Open Order Awareness and choose More help to link a specific order.';
    } else if (lower.contains('wedding') || lower.contains('bulk')) {
      reply =
          'For multiple outfits or an event package, open Bulk Orders from the home screen. The team can help with quantities, timing and coordination.';
    } else {
      reply =
          'I can help with order tracking, measurement guidance, fabric and style suggestions, garment care, payments, rentals and bulk orders. For a personal case, use Report an Issue so it reaches the support team.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatLine(text: reply, fromAssistant: true));
      _sending = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _asksAboutOrder(String text) =>
      text.contains('order') ||
      text.contains('ready') ||
      text.contains('delivery date') ||
      text.contains('status');

  Future<String> _orderReply() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.uid)
          .get();
      final orders = [...snapshot.docs]
        ..sort((a, b) => _orderDate(b.data()).compareTo(_orderDate(a.data())));
      final active = orders.where((doc) => !_isClosed(doc.data())).toList();
      if (active.isEmpty) {
        return orders.isEmpty
            ? 'I could not find an order in this account yet. If you placed one with another profile, switch to that profile or tell support the details.'
            : 'Your latest order is ${_orderLabel(orders.first.id, orders.first.data())} and its status is ${_statusLabel(orders.first.data()['status']?.toString() ?? '')}. There are no active orders right now.';
      }
      final doc = active.first;
      final data = doc.data();
      final label = _orderLabel(doc.id, data);
      final status = _statusLabel(data['status']?.toString() ?? '');
      final expected = _dateLabel(_expectedDate(data));
      final tailor = _firstText(data, const [
        'assignedTailorName',
        'tailorName',
      ]);
      return [
        'I can see $label.',
        'Current status: $status.',
        if (expected != null) 'Expected completion: $expected.',
        if (expected == null) 'No completion date is recorded yet.',
        if (tailor != null) 'Tailor: $tailor.',
        'You can open Order Awareness to track it, request an address change, ask the team to contact the tailor, or raise an issue.',
      ].join('\n');
    } catch (_) {
      return 'I could not load order details just now. Please open My Orders to refresh, or submit a support request if the problem continues.';
    }
  }

  Future<String> _wishlistReply() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('customer_wishlists')
          .doc(widget.uid)
          .collection('items')
          .get();
      final count = snapshot.docs.length;
      return count == 0
          ? 'Your wishlist is empty right now. Saved designs and fabric previews will appear in My Wishlist.'
          : 'I found $count saved ${count == 1 ? 'design' : 'designs'} in your wishlist. You can review or remove them from My Wishlist.';
    } catch (_) {
      return 'I could not load your wishlist just now. Open My Wishlist to refresh, or try again in a moment.';
    }
  }

  Future<String> _moduleOrderReply(String module) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.uid)
          .get();
      final matching =
          snapshot.docs.where((doc) {
            final kind = _orderKind(doc.data()).toLowerCase();
            return kind.contains(module);
          }).toList()..sort(
            (a, b) => _orderDate(b.data()).compareTo(_orderDate(a.data())),
          );
      if (matching.isEmpty) {
        final service = module == 'care' ? 'garment-care' : 'rental';
        return 'I do not see a $service order in your order records yet. Open the Fashion Store to browse services, or report a booking issue with its reference.';
      }
      final active = matching.where((doc) => !_isClosed(doc.data())).toList();
      final latest = (active.isNotEmpty ? active : matching).first;
      return 'I found ${matching.length} ${module == 'care' ? 'garment-care' : 'rental'} ${matching.length == 1 ? 'request' : 'requests'}. Latest: ${_orderLabel(latest.id, latest.data())} · ${_statusLabel(latest.data()['status']?.toString() ?? '')}.';
    } catch (_) {
      return 'I could not load that request history just now. Open My Orders to refresh or report an issue.';
    }
  }

  String? _inferTicketCategory(String text) {
    if (text.contains('payment') || text.contains('refund')) {
      return 'Payment Issue';
    }
    if (text.contains('measurement') ||
        text.contains('fit') ||
        text.contains('tight')) {
      return 'Measurement Issue';
    }
    if (text.contains('fabric')) return 'Fabric Issue';
    if (text.contains('design')) return 'Designer Issue';
    if (text.contains('delivery') ||
        text.contains('address') ||
        text.contains('pickup')) {
      return 'Delivery Issue';
    }
    if (text.contains('care') || text.contains('laundry')) {
      return 'Garment Care Issue';
    }
    if (text.contains('order') || text.contains('tailor')) return 'Order Issue';
    return null;
  }
}

class _ChatLine {
  const _ChatLine({required this.text, required this.fromAssistant});
  final String text;
  final bool fromAssistant;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.line});
  final _ChatLine line;

  @override
  Widget build(BuildContext context) => Align(
    alignment: line.fromAssistant
        ? Alignment.centerLeft
        : Alignment.centerRight,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .78,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: line.fromAssistant ? Colors.white : const Color(0xFFEAE4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        line.text,
        style: const TextStyle(color: _supportInk, height: 1.35),
      ),
    ),
  );
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    onPressed: onTap,
    labelStyle: const TextStyle(fontSize: 11, color: _supportPurple),
    side: const BorderSide(color: Color(0xFFD8CDFC)),
    backgroundColor: Colors.white,
    visualDensity: VisualDensity.compact,
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 148,
          child: Text(
            label,
            style: const TextStyle(color: _supportMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _supportInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('deliver') || normalized == 'resolved'
        ? const Color(0xFF27834F)
        : normalized.contains('cancel') || normalized == 'closed'
        ? const Color(0xFF797586)
        : _supportPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFECE8F3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _supportPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: const TextStyle(color: _supportMuted)),
        ),
      ],
    ),
  );
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9EC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF3E5C8)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, color: Color(0xFF9A6A16), size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Order status comes from your account records. Payment, refund and order changes are reviewed by the authorized team; chat does not approve or apply them.',
            style: TextStyle(
              color: Color(0xFF705A36),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

DateTime _orderDate(Map<String, dynamic> data) {
  final value = data['createdAt'] ?? data['orderDate'] ?? data['date'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _expectedDate(Map<String, dynamic> data) {
  for (final key in const [
    'deliveryDate',
    'expectedDeliveryDate',
    'estimatedDeliveryDate',
    'expectedCompletionAt',
  ]) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
  }
  return null;
}

String? _dateLabel(DateTime? date) {
  if (date == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _statusLabel(String raw) {
  final status = raw.trim();
  if (status.isEmpty) return 'Status unavailable';
  final normalized = status
      .toLowerCase()
      .replaceAll('_', '')
      .replaceAll(' ', '');
  return switch (normalized) {
    'pending' => 'Order placed',
    'pickedup' => 'Picked up',
    'attailor' => 'At tailor',
    'institching' || 'inprogress' => 'Stitching in progress',
    'qcpending' => 'Quality check',
    'qcpassed' => 'Quality check complete',
    'readyforpickup' => 'Ready for delivery',
    'outfordelivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

bool _isClosed(Map<String, dynamic> data) {
  final status = (data['status']?.toString() ?? '').toLowerCase();
  return const {
    'delivered',
    'cancelled',
    'closed',
    'completed',
  }.contains(status.replaceAll('_', '').replaceAll(' ', ''));
}

String _orderKind(Map<String, dynamic> data) {
  final raw = _firstText(data, const [
    'orderModuleType',
    'orderType',
    'serviceType',
    'category',
  ]);
  if (raw == null) return 'Order';
  final lower = raw.toLowerCase();
  if (lower.contains('care') || lower.contains('laundry')) {
    return 'Garment care';
  }
  if (lower.contains('rental')) return 'Rental';
  if (lower.contains('tailor') || lower.contains('core')) return 'Tailoring';
  return raw.replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2');
}

String _orderLabel(String id, Map<String, dynamic> data) {
  final known = _firstText(data, const [
    'orderNumber',
    'orderCode',
    'orderTrackingId',
    'bookingReference',
  ]);
  if (known != null) return known;
  final compact = id.length > 10 ? id.substring(0, 10) : id;
  return 'Order #$compact';
}

String? _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return null;
}
