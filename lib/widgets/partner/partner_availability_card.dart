import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

typedef AvailabilitySlot = Map<String, dynamic>;

List<AvailabilitySlot> readPartnerAvailabilitySlots(
  Map<String, dynamic> profile, {
  required String extensionKey,
}) {
  Map<String, dynamic> asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  final partnerData = asMap(profile['partnerData']);
  final extensions = asMap(partnerData['extensions']);
  final extension = asMap(extensions[extensionKey]);
  final operational = asMap(extension['operational']);
  final rawSlots = operational['availabilitySlots'];
  if (rawSlots is List) {
    final slots = rawSlots
        .whereType<Map>()
        .map((slot) => Map<String, dynamic>.from(slot))
        .where(_validSlot)
        .toList(growable: false);
    if (slots.isNotEmpty) return slots;
  }

  final schedule = asMap(extension['operatingSchedule']);
  final workshop = asMap(extension['workshopDetails']);
  final days = (schedule['operatingDays'] ?? workshop['operatingDays']);
  final opening = (schedule['openingTime'] ?? workshop['openingTime'])
      ?.toString();
  final closing = (schedule['closingTime'] ?? workshop['closingTime'])
      ?.toString();
  if (days is! List || opening == null || closing == null) {
    return const <AvailabilitySlot>[];
  }
  return days
      .map(
        (day) => <String, dynamic>{
          'day': day.toString().toLowerCase(),
          'start': opening,
          'end': closing,
        },
      )
      .where(_validSlot)
      .toList(growable: false);
}

bool _validSlot(Map<String, dynamic> slot) {
  const days = <String>{
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };
  final day = slot['day']?.toString().toLowerCase() ?? '';
  final start = slot['start']?.toString() ?? '';
  final end = slot['end']?.toString() ?? '';
  return days.contains(day) &&
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(start) &&
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(end) &&
      start.compareTo(end) < 0;
}

Future<List<AvailabilitySlot>?> showPartnerAvailabilityHoursDialog(
  BuildContext context, {
  required String title,
  required List<AvailabilitySlot> initialSlots,
}) => showDialog<List<AvailabilitySlot>>(
  context: context,
  builder: (context) =>
      _AvailabilityHoursDialog(title: title, initialSlots: initialSlots),
);

String partnerAvailabilityHoursLabel(
  BuildContext context,
  List<AvailabilitySlot> slots,
) {
  if (slots.isEmpty) return 'Hours not set';
  const dayLabels = <String, String>{
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };
  final days = slots
      .map((slot) => dayLabels[slot['day']?.toString()] ?? '')
      .where((day) => day.isNotEmpty)
      .join(', ');
  final first = slots.first;
  String displayTime(Object? value) {
    final parts = value.toString().split(':');
    if (parts.length != 2) return value.toString();
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value.toString();
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  return '$days · ${displayTime(first['start'])}–${displayTime(first['end'])}';
}

class PartnerAvailabilityCard extends StatelessWidget {
  const PartnerAvailabilityCard({
    super.key,
    required this.title,
    required this.available,
    required this.loaded,
    required this.saving,
    required this.enabled,
    required this.slots,
    required this.onAvailabilityChanged,
    required this.onEditHours,
    this.error,
    this.onRetry,
  });

  final String title;
  final bool available;
  final bool loaded;
  final bool saving;
  final bool enabled;
  final List<AvailabilitySlot> slots;
  final ValueChanged<bool>? onAvailabilityChanged;
  final VoidCallback? onEditHours;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.textHint;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                available
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        error != null
                            ? '$title unavailable'
                            : !loaded
                            ? 'Checking $title'
                            : available
                            ? '$title · Online'
                            : '$title · Offline',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      error ??
                          (available
                              ? 'Eligible work can be assigned to you.'
                              : 'Turn on when you are ready to receive work.'),
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null && onRetry != null)
                IconButton(
                  tooltip: 'Retry',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                )
              else if (!loaded || saving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: available,
                  onChanged: enabled ? onAvailabilityChanged : null,
                ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  partnerAvailabilityHoursLabel(context, slots),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: enabled && loaded && !saving ? onEditHours : null,
                icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                label: const Text('Hours'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityHoursDialog extends StatefulWidget {
  const _AvailabilityHoursDialog({
    required this.title,
    required this.initialSlots,
  });

  final String title;
  final List<AvailabilitySlot> initialSlots;

  @override
  State<_AvailabilityHoursDialog> createState() =>
      _AvailabilityHoursDialogState();
}

class _AvailabilityHoursDialogState extends State<_AvailabilityHoursDialog> {
  static const _days = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const _labels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  late final Set<String> _selectedDays;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.initialSlots.isEmpty
        ? _days.take(6).toSet()
        : widget.initialSlots
              .map((slot) => slot['day']?.toString() ?? '')
              .where(_days.contains)
              .toSet();
    final first = widget.initialSlots.isEmpty
        ? null
        : widget.initialSlots.first;
    _start = _readTime(first?['start'], const TimeOfDay(hour: 9, minute: 0));
    _end = _readTime(first?['end'], const TimeOfDay(hour: 17, minute: 0));
  }

  TimeOfDay _readTime(Object? value, TimeOfDay fallback) {
    final parts = value?.toString().split(':') ?? const <String>[];
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _stored(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  Future<void> _pickTime({required bool opening}) async {
    final current = opening ? _start : _end;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null || !mounted) return;
    setState(() {
      if (opening) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose your regular working days and hours.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (var index = 0; index < _days.length; index++)
                FilterChip(
                  label: Text(_labels[index]),
                  selected: _selectedDays.contains(_days[index]),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedDays.add(_days[index]);
                    } else {
                      _selectedDays.remove(_days[index]);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(opening: true),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text('From ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(opening: false),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text('Until ${_end.format(context)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _selectedDays.isEmpty || _minutes(_end) <= _minutes(_start)
            ? null
            : () => Navigator.pop(
                context,
                _days
                    .where(_selectedDays.contains)
                    .map(
                      (day) => <String, dynamic>{
                        'day': day,
                        'start': _stored(_start),
                        'end': _stored(_end),
                      },
                    )
                    .toList(growable: false),
              ),
        child: const Text('Save hours'),
      ),
    ],
  );
}
