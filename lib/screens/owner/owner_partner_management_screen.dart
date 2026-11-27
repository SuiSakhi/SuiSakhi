import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'helpdesk_order_explorer_screen.dart' show showHelpdeskOrderDetails;

class OwnerPartnerManagementScreen extends StatefulWidget {
  const OwnerPartnerManagementScreen({super.key});

  @override
  State<OwnerPartnerManagementScreen> createState() =>
      _OwnerPartnerManagementScreenState();
}

class _OwnerPartnerManagementScreenState
    extends State<OwnerPartnerManagementScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _partners = const [];
  bool _loading = true;
  bool _requestActive = false;
  bool _truncated = false;
  String? _error;
  String _selectedGroup = 'All groups';
  String _selectedStatus = 'All partners';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_requestActive) return;
    _requestActive = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const _PartnerManagementError(
          'Your sign-in has expired. Sign in again and retry.',
        );
      }
      await user.getIdToken(true);
      final response = await FirebaseFunctions.instance
          .httpsCallable('listHelpdeskOrders')
          .call(<String, dynamic>{'action': 'getAdminPartnerManagement'});
      final payload = Map<String, dynamic>.from(response.data as Map);
      final partners = (payload['partners'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _partners = partners;
        _truncated = payload['truncated'] == true;
        _loading = false;
      });
    } on _PartnerManagementError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (error.code.toLowerCase()) {
          'permission-denied' =>
            'Configured Admin access is required to view Partner management.',
          'unauthenticated' =>
            'Firebase could not verify your sign-in. Sign in again and retry.',
          'not-found' =>
            'The Partner management update is not deployed to the active staging project yet.',
          _ =>
            error.message ??
                'Partner management could not be loaded (${error.code}). Please retry.',
        };
      });
    } on FirebaseAuthException {
      if (mounted) {
        setState(() {
          _error = 'Could not refresh your sign-in. Sign in again and retry.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Partner management could not be loaded. Please retry.';
          _loading = false;
        });
      }
    } finally {
      _requestActive = false;
    }
  }

  List<String> get _groups => <String>{
    'All groups',
    ..._partners.map((partner) => _text(partner['groupLabel'], 'Other')),
  }.toList(growable: false);

  List<Map<String, dynamic>> get _visiblePartners {
    final query = _searchController.text.trim().toLowerCase();
    return _partners
        .where((partner) {
          if (_selectedGroup != 'All groups' &&
              _text(partner['groupLabel']) != _selectedGroup) {
            return false;
          }
          final isActive = partner['isActive'] == true;
          if (_selectedStatus == 'Active' && !isActive) return false;
          if (_selectedStatus == 'Inactive' && isActive) return false;
          if (_selectedStatus == 'Needs follow-up' &&
              partner['needsAttention'] != true) {
            return false;
          }
          final availabilityTracked = partner['availabilityTracked'] == true;
          final isAvailable = partner['isAvailable'] == true;
          if (_selectedStatus == 'Online' &&
              (!availabilityTracked || !isAvailable)) {
            return false;
          }
          if (_selectedStatus == 'Offline' &&
              (!availabilityTracked || isAvailable)) {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack = <String>[
            partner['name']?.toString() ?? '',
            partner['contactName']?.toString() ?? '',
            partner['phone']?.toString() ?? '',
            partner['partnerType']?.toString() ?? '',
            partner['sourceApplicationId']?.toString() ?? '',
            partner['servicePincode']?.toString() ?? '',
            partner['serviceAreaPincodes']?.toString() ?? '',
            partner['serviceArea']?.toString() ?? '',
            partner['locality']?.toString() ?? '',
            partner['city']?.toString() ?? '',
            partner['serviceAddress']?.toString() ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Map<String, int> _groupCounts(String group) {
    final partners = _partners.where(
      (partner) =>
          group == 'All groups' || _text(partner['groupLabel']) == group,
    );
    var total = 0;
    var active = 0;
    var recentlySeen = 0;
    var followUp = 0;
    for (final partner in partners) {
      total++;
      if (partner['isActive'] == true) active++;
      if (partner['seenRecently'] == true) recentlySeen++;
      if (partner['needsAttention'] == true) followUp++;
    }
    return {
      'total': total,
      'active': active,
      'recentlySeen': recentlySeen,
      'followUp': followUp,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('Partner management'),
      backgroundColor: const Color(0xFFF8F6FC),
      actions: [
        IconButton(
          tooltip: 'Refresh partners and assignments',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Partner operations',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Onboarding, availability, recent activity and current assigned work by service group.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (_loading && _partners.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null) ...[
              _InfoCard(message: _error!, error: true, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (_truncated)
              const _InfoCard(
                message:
                    'The current view reached its display limit. Refine the search or contact the system administrator for the full partner list.',
              ),
            _SummaryStrip(counts: _groupCounts('All groups')),
            const SizedBox(height: 14),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final counts = _groupCounts(group);
                  return _GroupSummaryCard(
                    group: group,
                    counts: counts,
                    selected: _selectedGroup == group,
                    onTap: () => setState(() => _selectedGroup = group),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText:
                    'Search partner, PIN, area, contact or application ID',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in [
                  'All partners',
                  'Active',
                  'Inactive',
                  'Needs follow-up',
                  'Online',
                  'Offline',
                ])
                  ChoiceChip(
                    label: Text(status),
                    selected: _selectedStatus == status,
                    onSelected: (_) => setState(() => _selectedStatus = status),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_visiblePartners.length} partners',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_visiblePartners.isEmpty && _error == null)
              const _InfoCard(message: 'No partners match these filters yet.'),
            for (final partner in _visiblePartners)
              _PartnerCard(
                partner: partner,
                onTap: () => _showPartnerDetails(partner),
              ),
          ],
        ],
      ),
    ),
  );

  void _showPartnerDetails(Map<String, dynamic> partner) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF4F7),
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .92,
          child: _PartnerDetailsSheet(partner: partner),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Partners', counts['total'] ?? 0, AppColors.primary),
      ('Active', counts['active'] ?? 0, AppColors.success),
      ('Seen recently', counts['recentlySeen'] ?? 0, AppColors.accent),
      ('Follow-up', counts['followUp'] ?? 0, AppColors.error),
    ];
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${metrics[index].$2}',
                    style: TextStyle(
                      color: metrics[index].$3,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metrics[index].$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({
    required this.group,
    required this.counts,
    required this.selected,
    required this.onTap,
  });

  final String group;
  final Map<String, int> counts;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      width: 192,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.primaryLight : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${counts['active'] ?? 0} active / ${counts['total'] ?? 0} total',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            '${counts['recentlySeen'] ?? 0} recently active · ${counts['followUp'] ?? 0} to review',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (counts['followUp'] ?? 0) > 0
                  ? AppColors.error
                  : AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.onTap});

  final Map<String, dynamic> partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = partner['isActive'] == true;
    final followUp = partner['needsAttention'] == true;
    final lastSeen = _dateLabel(partner['lastSeenAt']);
    final availabilityTracked = partner['availabilityTracked'] == true;
    final isAvailable = partner['isAvailable'] == true;
    final availabilityLabel = !availabilityTracked
        ? 'Not tracked'
        : isAvailable
        ? 'Online'
        : 'Offline';
    final availabilityColor = !availabilityTracked
        ? AppColors.textSecondary
        : isAvailable
        ? AppColors.success
        : AppColors.error;
    final area = _text(partner['serviceAreaLabel']);
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: followUp
                    ? const Color(0xFFFFE8E7)
                    : active
                    ? AppColors.surfaceVariant
                    : const Color(0xFFF0EEF4),
                child: Icon(
                  _groupIcon(_text(partner['groupLabel'])),
                  size: 21,
                  color: followUp
                      ? AppColors.error
                      : active
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _text(partner['name'], 'Partner'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_text(partner['groupLabel'], 'Other')} · ${partner['openWorkCount'] ?? 0} open work items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (area.isNotEmpty)
                      Text(
                        area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      'Last active: $lastSeen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        _StatusBadge(
                          label: followUp
                              ? 'Review'
                              : active
                              ? 'Active'
                              : 'Inactive',
                          color: followUp
                              ? AppColors.error
                              : active
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        _StatusBadge(
                          label: availabilityLabel,
                          color: availabilityColor,
                        ),
                      ],
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
}

class _PartnerDetailsSheet extends StatelessWidget {
  const _PartnerDetailsSheet({required this.partner});

  final Map<String, dynamic> partner;

  @override
  Widget build(BuildContext context) {
    final work = (partner['work'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final active = partner['isActive'] == true;
    final needsAttention = partner['needsAttention'] == true;
    final availabilityTracked = partner['availabilityTracked'] == true;
    final isAvailable = partner['isAvailable'] == true;
    final schedule =
        (partner['operatingSchedule'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
    final days = <String>{
      for (final slot in schedule) _titleCase(_text(slot['day'])),
    }.join(', ');
    final hours = schedule.isEmpty
        ? 'Not configured'
        : schedule
              .map((slot) => '${_text(slot['start'])}–${_text(slot['end'])}')
              .toSet()
              .join(', ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Center(
          child: Container(
            width: 54,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF6B5A61),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _text(partner['name'], 'Partner'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Text(
          '${_text(partner['groupLabel'], 'Other')} · ${_titleCase(_text(partner['partnerType']))}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        _StatusBadge(
          label: needsAttention
              ? 'Needs Admin follow-up'
              : active
              ? 'Active partner'
              : 'Inactive partner',
          color: needsAttention
              ? AppColors.error
              : active
              ? AppColors.success
              : AppColors.textSecondary,
        ),
        if (needsAttention) ...[
          const SizedBox(height: 10),
          const _InfoCard(
            message:
                'No partner activity was recorded for one configured operating day. Review the partner and assigned work; this alert does not deactivate the account.',
            error: true,
          ),
        ],
        const SizedBox(height: 14),
        _DetailSection(
          title: 'Onboarding and status',
          children: [
            _DetailRow('Joined via', _text(partner['joinedVia'], 'Unknown')),
            _DetailRow('Joined / approved', _dateLabel(partner['joinedAt'])),
            _DetailRow(
              'Application submitted',
              _dateLabel(partner['applicationSubmittedAt']),
            ),
            _DetailRow(
              'Application reference',
              _text(partner['sourceApplicationId'], 'Unavailable'),
            ),
            _DetailRow(
              'Application status',
              _titleCase(_text(partner['applicationStatus'], 'Unknown')),
            ),
            _DetailRow(
              'Applicant profile',
              _text(partner['applicantCustomerProfileId'], 'Not linked'),
            ),
            if (_text(partner['referralSource']).isNotEmpty)
              _DetailRow('Referral source', _text(partner['referralSource'])),
            _DetailRow(
              'Contact',
              _text(partner['contactName'], 'Not provided'),
            ),
            _DetailRow('Phone', _text(partner['phone'], 'Not provided')),
            _DetailRow(
              'Approval',
              _titleCase(_text(partner['approvalStatus'], 'Unknown')),
            ),
            _DetailRow(
              'KYC',
              _titleCase(_text(partner['kycStatus'], 'Unknown')),
            ),
          ],
        ),
        _DetailSection(
          title: 'Availability and activity',
          children: [
            _DetailRow(
              'Order availability',
              availabilityTracked
                  ? (isAvailable ? 'Available for work' : 'Not available')
                  : 'Not tracked for this partner type',
            ),
            _DetailRow(
              'Service area',
              _text(partner['serviceAreaLabel'], 'Not provided'),
            ),
            if (_text(partner['serviceAddress']).isNotEmpty)
              _DetailRow('Work address', _text(partner['serviceAddress'])),
            _DetailRow(
              'Operating days',
              days.isEmpty ? 'Not configured' : days,
            ),
            _DetailRow('Operating hours', hours),
            _DetailRow('Last active', _dateLabel(partner['lastSeenAt'])),
            _DetailRow(
              'Inactivity review',
              partner['scheduleConfigured'] == true &&
                      partner['lastSeenMillis'] != null
                  ? _elapsedLabel(partner['inactivityOpenMillis'])
                  : partner['lastSeenMillis'] == null
                  ? 'Activity tracking starts on the partner’s next app visit'
                  : 'Schedule not configured; review manually',
            ),
          ],
        ),
        _DetailSection(
          title: 'Current assigned work (${work.length})',
          children: work.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No open work is assigned to this partner.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ]
              : work.map((item) => _WorkTile(work: item)).toList(),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(top: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 6, child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});
  final Map<String, dynamic> work;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F6FC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(work['title'], _text(work['workType'], 'Partner work')),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${_text(work['workType'])} · Order ${_text(work['orderNumber'], _text(work['orderId']))}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (_text(work['customerName']).isNotEmpty)
          Text('Customer: ${_text(work['customerName'])}'),
        if (_text(work['customerPhone']).isNotEmpty)
          Text('Contact: ${_text(work['customerPhone'])}'),
        if (_text(work['customerAddress']).isNotEmpty ||
            _text(work['servicePincode']).isNotEmpty)
          Text(
            'Service area: ${[_text(work['customerAddress']), _text(work['servicePincode'])].where((value) => value.isNotEmpty).toSet().join(' · ')}',
          ),
        Text(
          'Delivery / completion: ${_dateLabel(work['expectedCompletionAt'])}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (_text(work['orderId']).isNotEmpty &&
            _text(work['orderType']).isNotEmpty)
          TextButton.icon(
            onPressed: () => showHelpdeskOrderDetails(
              context,
              orderId: _text(work['orderId']),
              orderType: _text(work['orderType']),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open full order & customer details'),
          ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.sync_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _titleCase(_text(work['stage'], 'Stage unavailable')),
              ),
            ),
            Text(
              _dateLabel(work['createdAt']),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message, this.error = false, this.onRetry});
  final String message;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEBEA) : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: error ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ),
        if (onRetry != null)
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}

class _PartnerManagementError implements Exception {
  const _PartnerManagementError(this.message);
  final String message;
}

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _titleCase(String value) {
  final normalized = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();
  if (normalized.isEmpty) return 'Unknown';
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _dateLabel(dynamic value) {
  final date = value is DateTime
      ? value
      : value is String
      ? DateTime.tryParse(value)
      : null;
  if (date == null) return 'Not recorded yet';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

String _elapsedLabel(dynamic value) {
  final millis = (value as num?)?.toInt();
  if (millis == null || millis <= 0) {
    return 'Activity is within operating hours';
  }
  final hours = millis ~/ Duration.millisecondsPerHour;
  final days = hours ~/ 24;
  final remHours = hours % 24;
  return days > 0
      ? '$days operating days + $remHours hrs'
      : '$hours operating hrs';
}

IconData _groupIcon(String group) => switch (group.toLowerCase()) {
  'tailoring' => Icons.content_cut_rounded,
  'garment care' => Icons.local_laundry_service_outlined,
  'quick care' => Icons.handyman_outlined,
  'delivery' => Icons.delivery_dining_rounded,
  'measurements' => Icons.straighten_rounded,
  _ => Icons.storefront_outlined,
};
