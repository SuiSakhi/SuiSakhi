import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../core/constants/app_colors.dart';

class QuickCareJobsScreen extends StatefulWidget {
  const QuickCareJobsScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    required this.partnerName,
  });

  final String accountId;
  final String profileId;
  final String partnerName;

  @override
  State<QuickCareJobsScreen> createState() => _QuickCareJobsScreenState();
}

class _QuickCareJobsScreenState extends State<QuickCareJobsScreen> {
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _available = const [];
  List<Map<String, dynamic>> _mine = const [];
  bool _loading = true;
  final Set<String> _busy = {};
  String _tab = 'Available';
  bool _availableForOrders = true;
  bool _savingAvailability = false;
  List<Map<String, dynamic>> _availabilitySlots = const [];
  bool _recording = false;
  String? _recordingOrderId;
  Timer? _refreshTimer;

  static const _dayCodes = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _available.isEmpty && _mine.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('getQuickCarePartnerJobs')
          .call(<String, dynamic>{
            'partnerAccountId': widget.accountId,
            'partnerProfileId': widget.profileId,
          });
      final payload = Map<String, dynamic>.from(response.data as Map);
      List<Map<String, dynamic>> read(String key) =>
          (payload[key] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
      final availability = Map<String, dynamic>.from(
        payload['availability'] as Map? ?? const {},
      );
      final slots = (availability['slots'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      if (!mounted) return;
      setState(() {
        _available = read('availableJobs');
        _mine = read('myJobs');
        _availableForOrders = availability['availableForOrders'] != false;
        _availabilitySlots = slots;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(_readableError(error));
    }
  }

  String get _profileQuery =>
      '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
      '&profileId=${Uri.encodeQueryComponent(widget.profileId)}'
      '&category=doorstepServices';

  Future<bool> _run(String orderId, Future<void> Function() operation) async {
    if (_busy.contains(orderId)) return false;
    setState(() => _busy.add(orderId));
    try {
      await operation();
      await _load();
      return true;
    } catch (error) {
      _message(_readableError(error));
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(orderId));
    }
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await FirebaseFunctions.instance.httpsCallable(name).call(data);
  }

  Future<void> _setAvailability(bool available) async {
    if (_savingAvailability) return;
    if (available && _availabilitySlots.isEmpty) {
      await _editAvailability(enableAfterSave: true);
      return;
    }
    await _saveAvailability(available, _availabilitySlots);
  }

  Future<void> _editAvailability({bool enableAfterSave = false}) async {
    final existingDays = _availabilitySlots
        .map((slot) => slot['day']?.toString())
        .whereType<String>()
        .toSet();
    final selectedDays = <String>{
      if (existingDays.isEmpty) ..._dayCodes.take(6),
      ...existingDays,
    };
    final first = _availabilitySlots.isNotEmpty
        ? _availabilitySlots.first
        : null;
    final startParts = (first?['start']?.toString() ?? '09:00').split(':');
    final endParts = (first?['end']?.toString() ?? '17:00').split(':');
    var start = TimeOfDay(
      hour: int.tryParse(startParts.first) ?? 9,
      minute: startParts.length > 1 ? int.tryParse(startParts[1]) ?? 0 : 0,
    );
    var end = TimeOfDay(
      hour: int.tryParse(endParts.first) ?? 17,
      minute: endParts.length > 1 ? int.tryParse(endParts[1]) ?? 0 : 0,
    );
    final slots = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('QuickCare availability'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select the days and hours you can take requests.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    for (var index = 0; index < _dayCodes.length; index++)
                      FilterChip(
                        label: Text(_dayLabels[index]),
                        selected: selectedDays.contains(_dayCodes[index]),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            selectedDays.add(_dayCodes[index]);
                          } else {
                            selectedDays.remove(_dayCodes[index]);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: dialogContext,
                            initialTime: start,
                          );
                          if (picked != null) {
                            setDialogState(() => start = picked);
                          }
                        },
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: Text('From ${start.format(dialogContext)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: dialogContext,
                            initialTime: end,
                          );
                          if (picked != null) {
                            setDialogState(() => end = picked);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text('Until ${end.format(dialogContext)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed:
                  selectedDays.isEmpty ||
                      _timeMinutes(end) <= _timeMinutes(start)
                  ? null
                  : () {
                      final startValue = _storedTime(start);
                      final endValue = _storedTime(end);
                      final result = _dayCodes
                          .where(selectedDays.contains)
                          .map(
                            (day) => <String, dynamic>{
                              'day': day,
                              'start': startValue,
                              'end': endValue,
                            },
                          )
                          .toList();
                      Navigator.pop(dialogContext, result);
                    },
              child: const Text('Save hours'),
            ),
          ],
        ),
      ),
    );
    if (slots != null) {
      await _saveAvailability(
        enableAfterSave ? true : _availableForOrders,
        slots,
      );
    }
  }

  Future<void> _saveAvailability(
    bool available,
    List<Map<String, dynamic>> slots,
  ) async {
    if (_savingAvailability) return;
    setState(() => _savingAvailability = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setQuickCarePartnerAvailability')
          .call(<String, dynamic>{
            ..._partnerPayload(),
            'availableForOrders': available,
            'availabilitySlots': slots,
          });
      if (!mounted) return;
      setState(() {
        _availableForOrders = available;
        _availabilitySlots = slots;
        _savingAvailability = false;
      });
      await _load();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _savingAvailability = false);
      _message(error.message ?? 'Could not save QuickCare availability.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingAvailability = false);
      _message('Could not save QuickCare availability. Please retry.');
    }
  }

  static int _timeMinutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static String _storedTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _partnerPayload() => {
    'partnerAccountId': widget.accountId,
    'partnerProfileId': widget.profileId,
  };

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _readableError(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'internal') {
        return 'Could not refresh QuickCare requests. Please try again shortly.';
      }
      return error.message ?? 'Could not update this Quick Care job.';
    }
    return 'Could not update this Quick Care job. Please retry.';
  }

  Future<void> _accept(Map<String, dynamic> order) async {
    final id = order['id'].toString();
    final accepted = await _run(
      id,
      () => _call('acceptQuickCareJob', {..._partnerPayload(), 'orderId': id}),
    );
    if (accepted && mounted) {
      _message('Request accepted. Verify the customer PIN before starting.');
    }
  }

  Future<void> _start(Map<String, dynamic> order) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _QuickCarePinDialog(),
    );
    if (pin == null || pin.length != 4) return;
    final id = order['id'].toString();
    final started = await _run(
      id,
      () => _call('startQuickCareJob', {
        ..._partnerPayload(),
        'orderId': id,
        'pin': pin,
      }),
    );
    if (started && mounted) {
      _message(
        'Work started. Capture before and after photos for the order record.',
      );
    }
  }

  Future<void> _pause(Map<String, dynamic> order) async {
    final reason = await _reasonDialog(
      title: 'Pause this service',
      hint: 'Why does the work need to continue later?',
      action: 'Pause service',
    );
    if (reason == null) return;
    final id = order['id'].toString();
    await _run(
      id,
      () => _call('updateQuickCareJob', {
        ..._partnerPayload(),
        'orderId': id,
        'action': 'pause',
        'reason': reason,
      }),
    );
  }

  Future<void> _resume(Map<String, dynamic> order) async {
    final id = order['id'].toString();
    await _run(
      id,
      () => _call('updateQuickCareJob', {
        ..._partnerPayload(),
        'orderId': id,
        'action': 'resume',
      }),
    );
  }

  Future<void> _proposeExtra(
    Map<String, dynamic> order, {
    bool serviceQuote = false,
  }) async {
    final details = await showDialog<(String, String)?>(
      context: context,
      builder: (_) => _QuickCareQuoteDialog(serviceQuote: serviceQuote),
    );
    if (details == null) return;
    final parsedAmount = int.tryParse(details.$1);
    if (parsedAmount == null || details.$2.length < 3) {
      _message('Enter an amount and a short reason.');
      return;
    }
    final id = order['id'].toString();
    await _run(
      id,
      () => _call('updateQuickCareJob', {
        ..._partnerPayload(),
        'orderId': id,
        'action': serviceQuote ? 'proposeServiceQuote' : 'proposeExtra',
        'amount': parsedAmount,
        'reason': details.$2,
      }),
    );
  }

  Future<void> _complete(Map<String, dynamic> order) async {
    final initial = ((order['estimatedPrice'] ?? order['price'] ?? 0) as num)
        .toStringAsFixed(0);
    final finalAmount = await showDialog<int?>(
      context: context,
      builder: (_) => _QuickCareFinalAmountDialog(initialAmount: initial),
    );
    if (finalAmount == null) return;
    final id = order['id'].toString();
    final completed = await _run(
      id,
      () => _call('updateQuickCareJob', {
        ..._partnerPayload(),
        'orderId': id,
        'action': 'complete',
        'finalAmount': finalAmount,
      }),
    );
    if (completed && mounted) {
      _message(
        'Payment pending. The customer must pay the final amount in the app.',
      );
    }
  }

  Future<String?> _reasonDialog({
    required String title,
    required String hint,
    required String action,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _QuickCareReasonDialog(title: title, hint: hint, action: action),
    );
    if (result != null && result.length < 3) {
      _message('Please add a short note.');
      return null;
    }
    return result;
  }

  Future<void> _photo(
    Map<String, dynamic> order,
    ImageSource source,
    String phase,
  ) async {
    final id = order['id'].toString();
    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;
    final attached = await _run(id, () async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in to attach evidence.');
      final path =
          'quickcare_evidence/$id/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await FirebaseStorage.instance
          .ref(path)
          .putData(
            await file.readAsBytes(),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'partnerUid': uid},
            ),
          );
      await _call('attachQuickCareEvidence', {
        ..._partnerPayload(),
        'orderId': id,
        'storagePath': path,
        'kind': 'photo',
        'note': phase,
      });
    });
    if (attached && mounted) _message('Photo evidence attached to the order.');
  }

  Future<void> _toggleVoiceNote(Map<String, dynamic> order) async {
    final id = order['id'].toString();
    if (_recording && _recordingOrderId == id) {
      final attached = await _run(id, () async {
        final path = await _recorder.stop();
        if (path == null) {
          throw StateError('The voice note could not be saved.');
        }
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw StateError('Sign in to attach evidence.');
        final storagePath =
            'quickcare_evidence/$id/$uid/${DateTime.now().microsecondsSinceEpoch}.m4a';
        await FirebaseStorage.instance
            .ref(storagePath)
            .putFile(
              File(path),
              SettableMetadata(
                contentType: 'audio/mp4',
                customMetadata: {'partnerUid': uid},
              ),
            );
        await _call('attachQuickCareEvidence', {
          ..._partnerPayload(),
          'orderId': id,
          'storagePath': storagePath,
          'kind': 'audio',
        });
      });
      if (mounted) {
        setState(() {
          _recording = false;
          _recordingOrderId = null;
        });
      }
      if (attached && mounted) _message('Voice note attached to the order.');
      return;
    }
    if (_recording) {
      _message('Finish the current voice note first.');
      return;
    }
    if (!await _recorder.hasPermission()) {
      _message('Microphone permission is required to record a voice note.');
      return;
    }
    final path =
        '${Directory.systemTemp.path}/quickcare_${id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) {
      setState(() {
        _recording = true;
        _recordingOrderId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _tab == 'Available' ? _available : _mine;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Care Partner',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              widget.partnerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Partner account',
            onPressed: () => context.push('/partner/account$_profileQuery'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  _topSummary(),
                  const SizedBox(height: 12),
                  _availabilityCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _tabButton('Available', _available.length),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _tabButton('My Jobs', _mine.length)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (jobs.isEmpty)
                    _emptyState()
                  else
                    for (final order in jobs) ...[
                      _jobCard(order),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
    );
  }

  Widget _topSummary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFB70D5C), Color(0xFFD6488A)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.home_repair_service_rounded,
          color: Colors.white,
          size: 34,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Local service requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_available.length} matching requests · ${_mine.length} assigned to you',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _availabilityCard() {
    final days = _availabilitySlots
        .map((slot) => slot['day']?.toString())
        .whereType<String>()
        .toSet();
    final hours = _availabilitySlots.isEmpty
        ? 'Set your service days and hours'
        : '${_dayLabels.asMap().entries.where((entry) => days.contains(_dayCodes[entry.key])).map((entry) => entry.value).join(', ')} · ${_formatStoredTime(_availabilitySlots.first['start'])}–${_formatStoredTime(_availabilitySlots.first['end'])}';
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFB70D5C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accepting new requests',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _availableForOrders ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _availableForOrders
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFF777286),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_savingAvailability)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: _availableForOrders,
                    onChanged: _setAvailability,
                  ),
              ],
            ),
            const Divider(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hours,
                    style: const TextStyle(
                      color: Color(0xFF777286),
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _savingAvailability ? null : _editAvailability,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Edit hours'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStoredTime(Object? value) {
    final parts = (value?.toString() ?? '09:00').split(':');
    final time = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    return time.format(context);
  }

  Widget _tabButton(String label, int count) => ChoiceChip(
    selected: _tab == label,
    onSelected: (_) => setState(() => _tab = label),
    label: SizedBox(
      width: double.infinity,
      child: Text('$label ($count)', textAlign: TextAlign.center),
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.only(top: 82),
    child: Column(
      children: [
        Icon(
          _tab == 'Available'
              ? Icons.search_off_rounded
              : Icons.assignment_outlined,
          size: 54,
          color: AppColors.textHint,
        ),
        const SizedBox(height: 12),
        Text(
          _tab == 'Available'
              ? _availableForOrders
                    ? 'No matching requests nearby'
                    : 'You are offline'
              : 'No jobs assigned yet',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _tab == 'Available'
              ? _availableForOrders
                    ? 'New requests matching your approved skills, PIN codes and availability hours will appear here.'
                    : 'Turn on Accepting new requests to receive work during your selected hours.'
              : 'Accepted and assigned Quick Care work will appear here.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF777286)),
        ),
      ],
    ),
  );

  Widget _jobCard(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '';
    final workflow =
        order['quickCareWorkflowStatus']?.toString() ?? 'requestSubmitted';
    final assignment =
        order['quickCareAssignmentStatus']?.toString() ?? 'searching';
    final isAvailable = _tab == 'Available';
    final busy = _busy.contains(id);
    final services = (order['quickFixServiceIds'] as List<dynamic>? ?? const [])
        .map((value) => _serviceName(value.toString()))
        .join(' · ');
    final address = (order['deliveryAddress'] ?? 'Customer service area')
        .toString();
    final pin = (order['deliveryPincode'] ?? '').toString();
    final serviceNotes = (order['serviceNotes'] ?? '').toString().trim();
    final quoteStatus = (order['quickCareQuoteStatus'] ?? '').toString();
    final needsServiceQuote =
        (order['quickFixServiceIds'] as List<dynamic>? ?? const []).contains(
          'other_quote',
        ) &&
        quoteStatus != 'customerAccepted';
    final evidence = order['quickCareEvidence'] as List<dynamic>? ?? const [];
    final appointment = _formatDate(
      order['quickCareScheduledAt'] ?? order['orderDate'],
    );
    final photoEvidence = evidence.whereType<Map>().toList();
    final hasBeforePhoto = photoEvidence.any(
      (item) => item['kind'] == 'photo' && item['note'] == 'before_work',
    );
    final hasAfterPhoto = photoEvidence.any(
      (item) => item['kind'] == 'photo' && item['note'] == 'after_work',
    );
    final canAttachEvidence =
        !isAvailable &&
        [
          'accepted',
          'inProgress',
          'paused',
          'awaitingCustomerApproval',
        ].contains(workflow);
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFF0F5),
                  child: Icon(
                    Icons.home_repair_service_outlined,
                    color: Color(0xFFB70D5C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        services.isEmpty ? 'Quick Care service' : services,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Order ${id.length > 8 ? id.substring(0, 8) : id}',
                        style: const TextStyle(
                          color: Color(0xFF777286),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(_statusLabel(workflow, assignment)),
              ],
            ),
            const SizedBox(height: 14),
            if (order['quickCareAssignmentOverride'] == true)
              _callout(
                'Manual Helpdesk assignment',
                ((order['quickCareAssignmentOverrideReasons']
                            as List<dynamic>? ??
                        const [])
                    .map((reason) => reason.toString())
                    .join(' · ')),
                Icons.info_outline_rounded,
              ),
            if (order['quickCarePilotFallback'] == true)
              _callout(
                'Pilot request · please verify details',
                ((order['quickCarePilotFallbackReasons'] as List<dynamic>? ??
                        const [])
                    .map((reason) => reason.toString())
                    .join(' · ')),
                Icons.info_outline_rounded,
              ),
            _detailLine(Icons.calendar_today_outlined, appointment),
            _detailLine(
              Icons.location_on_outlined,
              '$address${pin.isNotEmpty ? ' · $pin' : ''}',
            ),
            if (serviceNotes.isNotEmpty)
              _detailLine(
                Icons.notes_rounded,
                'Customer request: $serviceNotes',
              ),
            if ((order['serviceVisitLandmark']?.toString() ?? '')
                .trim()
                .isNotEmpty)
              _detailLine(
                Icons.place_outlined,
                'Landmark: ${order['serviceVisitLandmark']}',
              ),
            if (order['quickCarePauseReason'] != null && workflow == 'paused')
              _detailLine(
                Icons.pause_circle_outline,
                'Paused: ${order['quickCarePauseReason']}',
              ),
            if (workflow == 'awaitingCustomerApproval')
              _callout(
                'Additional quote pending customer approval',
                '₹${order['quickCareExtraChargeAmount'] ?? 0} · ${order['quickCareExtraChargeReason'] ?? ''}',
                Icons.hourglass_top_rounded,
              ),
            if (workflow == 'completed')
              _callout(
                'Completed',
                'Final amount ₹${order['quickCareFinalAmount'] ?? order['price'] ?? 0} · points pending review',
                Icons.check_circle_outline,
              ),
            if (workflow == 'paymentPending')
              _callout(
                'Payment pending',
                '₹${order['quickCareFinalAmount'] ?? order['price'] ?? 0} · Next action: the customer pays securely in the app. Only a verified payment closes this job.',
                Icons.payments_outlined,
              ),
            if (evidence.isNotEmpty)
              _detailLine(
                Icons.attach_file_rounded,
                '${evidence.length} evidence item${evidence.length == 1 ? '' : 's'} attached',
              ),
            if (canAttachEvidence) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (workflow == 'accepted')
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _photo(
                              order,
                              ImageSource.camera,
                              'before_work',
                            ),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        hasBeforePhoto ? 'Retake before photo' : 'Before photo',
                      ),
                    ),
                  if (workflow == 'inProgress' || workflow == 'paused')
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () =>
                                _photo(order, ImageSource.camera, 'after_work'),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        hasAfterPhoto ? 'Retake after photo' : 'After photo',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _toggleVoiceNote(order),
                    icon: Icon(
                      _recording && _recordingOrderId == id
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none_rounded,
                    ),
                    label: Text(
                      _recording && _recordingOrderId == id
                          ? 'Stop voice note'
                          : 'Record voice note',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (isAvailable)
              _primaryAction(
                'Accept request',
                Icons.check_rounded,
                busy ? null : () => _accept(order),
              )
            else if (workflow == 'partnerAssigned' ||
                workflow == 'accepted') ...[
              if (workflow == 'partnerAssigned')
                _primaryAction(
                  'Accept assignment',
                  Icons.check_rounded,
                  busy ? null : () => _accept(order),
                ),
              if (workflow == 'accepted')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasBeforePhoto)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Capture a before-work photo, then verify the customer PIN to start.',
                        ),
                      ),
                    if (needsServiceQuote)
                      _primaryAction(
                        'Send service quote',
                        Icons.request_quote_outlined,
                        busy
                            ? null
                            : () => _proposeExtra(order, serviceQuote: true),
                      )
                    else
                      _primaryAction(
                        'Verify customer PIN & start',
                        Icons.lock_open_rounded,
                        busy || !hasBeforePhoto ? null : () => _start(order),
                      ),
                  ],
                ),
            ] else if (workflow == 'inProgress') ...[
              if (!hasAfterPhoto)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Capture an after-work photo before completing this job.',
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _pause(order),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Pause work'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _proposeExtra(order),
                    icon: const Icon(Icons.currency_rupee_rounded),
                    label: const Text('Quote extra work'),
                  ),
                  FilledButton.icon(
                    onPressed: busy || !hasAfterPhoto
                        ? null
                        : () => _complete(order),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Complete'),
                  ),
                ],
              ),
            ] else if (workflow == 'paused')
              _primaryAction(
                'Continue work',
                Icons.play_arrow_rounded,
                busy ? null : () => _resume(order),
              )
            else if (workflow == 'paymentPending')
              const Text(
                'Next action: the customer pays the approved amount in the app. Keep this job open until the payment status is verified.',
                style: TextStyle(color: Color(0xFF777286)),
              )
            else if (workflow == 'awaitingCustomerApproval')
              const Text(
                'You can continue when the customer responds to the additional work quote.',
                style: TextStyle(color: Color(0xFF777286)),
              )
            else if (workflow == 'completed')
              const Text(
                'This job is closed. Customer rating will release any eligible points.',
                style: TextStyle(color: Color(0xFF777286)),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  String _serviceName(String value) => switch (value) {
    'pico_fall' => 'Saree Pico / Fall',
    'rafu' => 'Rafu',
    'zip' => 'Zip repair',
    'button' => 'Button fixing',
    'minor_alt' => 'Minor alterations',
    'express_stitch' => 'Express stitching',
    'wardrobe' => 'Wardrobe management',
    'saree_draping' => 'Saree draping',
    'other_quote' => 'Other service',
    _ => value,
  };

  String _statusLabel(String workflow, String assignment) => switch (workflow) {
    'requestSubmitted' => 'New request',
    'partnerAssigned' => 'Assigned',
    'accepted' => 'Accepted',
    'inProgress' => 'In progress',
    'paused' => 'Paused',
    'awaitingCustomerApproval' => 'Quote pending',
    'paymentPending' => 'Payment pending',
    'completed' => 'Completed',
    _ => assignment,
  };

  String _formatDate(Object? value) {
    DateTime? date;
    if (value is String) date = DateTime.tryParse(value)?.toLocal();
    if (value is DateTime) date = value.toLocal();
    if (date == null) return 'Appointment time to be confirmed';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} · $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _detailLine(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF5F5A6B))),
        ),
      ],
    ),
  );

  Widget _statusChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFB70D5C),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _callout(String title, String text, IconData icon) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F8),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFF5D9E5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFB70D5C), size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(text, style: const TextStyle(color: Color(0xFF777286))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _primaryAction(String text, IconData icon, VoidCallback? action) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: action,
          icon: Icon(icon),
          label: Text(text),
        ),
      );
}

class _QuickCarePinDialog extends StatefulWidget {
  const _QuickCarePinDialog();

  @override
  State<_QuickCarePinDialog> createState() => _QuickCarePinDialogState();
}

class _QuickCarePinDialogState extends State<_QuickCarePinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify customer PIN'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: const InputDecoration(
        labelText: 'Last four digits of customer mobile',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Verify & start'),
      ),
    ],
  );
}

class _QuickCareQuoteDialog extends StatefulWidget {
  const _QuickCareQuoteDialog({required this.serviceQuote});

  final bool serviceQuote;

  @override
  State<_QuickCareQuoteDialog> createState() => _QuickCareQuoteDialogState();
}

class _QuickCareQuoteDialogState extends State<_QuickCareQuoteDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.serviceQuote ? 'Quote this service' : 'Quote additional work',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.serviceQuote
                ? 'Service quote (₹)'
                : 'Additional amount (₹)',
          ),
        ),
        TextField(
          controller: _reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Work and reason'),
        ),
        const SizedBox(height: 8),
        const Text(
          'The customer must approve this amount before you continue or close the job.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (_amount.text.trim(), _reason.text.trim())),
        child: const Text('Send quote'),
      ),
    ],
  );
}

class _QuickCareFinalAmountDialog extends StatefulWidget {
  const _QuickCareFinalAmountDialog({required this.initialAmount});

  final String initialAmount;

  @override
  State<_QuickCareFinalAmountDialog> createState() =>
      _QuickCareFinalAmountDialogState();
}

class _QuickCareFinalAmountDialogState
    extends State<_QuickCareFinalAmountDialog> {
  late final _amount = TextEditingController(text: widget.initialAmount);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Finish service work'),
    content: TextField(
      controller: _amount,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Final agreed amount (₹)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, int.tryParse(_amount.text.trim())),
        child: const Text('Request payment'),
      ),
    ],
  );
}

class _QuickCareReasonDialog extends StatefulWidget {
  const _QuickCareReasonDialog({
    required this.title,
    required this.hint,
    required this.action,
  });

  final String title;
  final String hint;
  final String action;

  @override
  State<_QuickCareReasonDialog> createState() => _QuickCareReasonDialogState();
}

class _QuickCareReasonDialogState extends State<_QuickCareReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: widget.hint,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(widget.action),
      ),
    ],
  );
}
