import 'package:flutter/material.dart';

import '../../models/operating_schedule.dart';

class OperatingScheduleField extends StatefulWidget {
  const OperatingScheduleField({
    required this.onChanged,
    this.initialValue = const OperatingSchedule(),
    this.enabled = true,
    this.operatingDaysRequired = true,
    this.openingTimeRequired = true,
    this.closingTimeRequired = true,
    this.requireClosingAfterOpening = true,
    this.sectionTitle = 'Operating Schedule',
    this.operatingDaysLabel = 'Operating days',
    this.openingTimeLabel = 'Opening time',
    this.closingTimeLabel = 'Closing time',
    this.spacing = 12,
    super.key,
  });

  final OperatingSchedule initialValue;

  final bool enabled;
  final bool operatingDaysRequired;
  final bool openingTimeRequired;
  final bool closingTimeRequired;
  final bool requireClosingAfterOpening;

  final String sectionTitle;
  final String operatingDaysLabel;
  final String openingTimeLabel;
  final String closingTimeLabel;

  final double spacing;

  final ValueChanged<OperatingSchedule> onChanged;

  @override
  State<OperatingScheduleField> createState() {
    return _OperatingScheduleFieldState();
  }
}

class _OperatingScheduleFieldState extends State<OperatingScheduleField> {
  final Set<String> _selectedDays = {};

  String? _openingTime;
  String? _closingTime;

  @override
  void initState() {
    super.initState();
    _loadInitialValue(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant OperatingScheduleField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameSchedule(oldWidget.initialValue, widget.initialValue)) {
      _loadInitialValue(widget.initialValue);
    }
  }

  void _loadInitialValue(OperatingSchedule schedule) {
    _selectedDays
      ..clear()
      ..addAll(schedule.normalizedOperatingDays);

    _openingTime = OperatingSchedule.normalizedTimeOrNull(schedule.openingTime);

    _closingTime = OperatingSchedule.normalizedTimeOrNull(schedule.closingTime);
  }

  OperatingSchedule get _currentSchedule {
    return OperatingSchedule(
      operatingDays: OperatingSchedule.orderedDayCodes
          .where(_selectedDays.contains)
          .toList(growable: false),
      openingTime: _openingTime,
      closingTime: _closingTime,
    );
  }

  void _emitSchedule() {
    widget.onChanged(_currentSchedule);
  }

  Future<void> _selectOpeningTime() async {
    if (!widget.enabled) {
      return;
    }

    final initialTime =
        OperatingSchedule.timeOfDayFromStorage(_openingTime) ??
        const TimeOfDay(hour: 9, minute: 0);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select opening time',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _openingTime = OperatingSchedule.storageValueFromTimeOfDay(selectedTime);
    });

    _emitSchedule();
  }

  Future<void> _selectClosingTime() async {
    if (!widget.enabled) {
      return;
    }

    final initialTime =
        OperatingSchedule.timeOfDayFromStorage(_closingTime) ??
        const TimeOfDay(hour: 20, minute: 0);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select closing time',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _closingTime = OperatingSchedule.storageValueFromTimeOfDay(selectedTime);
    });

    _emitSchedule();
  }

  void _toggleDay(String dayCode, bool selected) {
    if (!widget.enabled) {
      return;
    }

    setState(() {
      if (selected) {
        _selectedDays.add(dayCode);
      } else {
        _selectedDays.remove(dayCode);
      }
    });

    _emitSchedule();
  }

  String _displayTime(BuildContext context, String? storedValue) {
    final time = OperatingSchedule.timeOfDayFromStorage(storedValue);

    if (time == null) {
      return 'Not selected';
    }

    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  String? _daysValidator(Set<String>? value) {
    if (!widget.operatingDaysRequired) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Select at least one operating day';
    }

    return null;
  }

  String? _openingTimeValidator(String? value) {
    if (!widget.openingTimeRequired) {
      return null;
    }

    if (OperatingSchedule.timeOfDayFromStorage(value) == null) {
      return '${widget.openingTimeLabel} is required';
    }

    return null;
  }

  String? _closingTimeValidator(String? value) {
    if (widget.closingTimeRequired &&
        OperatingSchedule.timeOfDayFromStorage(value) == null) {
      return '${widget.closingTimeLabel} is required';
    }

    if (!widget.requireClosingAfterOpening) {
      return null;
    }

    final schedule = _currentSchedule;

    if (schedule.hasOpeningTime &&
        schedule.hasClosingTime &&
        !schedule.closesAfterOpening) {
      return 'Closing time must be after opening time';
    }

    return null;
  }

  bool _sameSchedule(OperatingSchedule first, OperatingSchedule second) {
    final firstDays = first.normalizedOperatingDays.join('|');

    final secondDays = second.normalizedOperatingDays.join('|');

    return firstDays == secondDays &&
        OperatingSchedule.normalizedTimeOrNull(first.openingTime) ==
            OperatingSchedule.normalizedTimeOrNull(second.openingTime) &&
        OperatingSchedule.normalizedTimeOrNull(first.closingTime) ==
            OperatingSchedule.normalizedTimeOrNull(second.closingTime);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sectionTitle.trim().isNotEmpty) ...[
          Text(
            widget.sectionTitle.trim(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: widget.spacing),
        ],
        FormField<Set<String>>(
          initialValue: Set<String>.from(_selectedDays),
          validator: _daysValidator,
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.operatingDaysLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OperatingSchedule.orderedDayCodes
                      .map((dayCode) {
                        return FilterChip(
                          label: Text(
                            OperatingSchedule.shortDayLabels[dayCode] ??
                                dayCode,
                          ),
                          selected: _selectedDays.contains(dayCode),
                          onSelected: widget.enabled
                              ? (selected) {
                                  _toggleDay(dayCode, selected);

                                  field.didChange(
                                    Set<String>.from(_selectedDays),
                                  );
                                }
                              : null,
                        );
                      })
                      .toList(growable: false),
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        SizedBox(height: widget.spacing),
        FormField<String>(
          initialValue: _openingTime,
          validator: _openingTimeValidator,
          builder: (field) {
            return InkWell(
              onTap: widget.enabled
                  ? () async {
                      await _selectOpeningTime();

                      field.didChange(_openingTime);
                    }
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.openingTimeLabel,
                  prefixIcon: const Icon(Icons.schedule_outlined),
                  suffixIcon: widget.enabled
                      ? const Icon(Icons.arrow_drop_down)
                      : null,
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                  enabled: widget.enabled,
                ),
                child: Text(_displayTime(context, _openingTime)),
              ),
            );
          },
        ),
        SizedBox(height: widget.spacing),
        FormField<String>(
          initialValue: _closingTime,
          validator: _closingTimeValidator,
          builder: (field) {
            return InkWell(
              onTap: widget.enabled
                  ? () async {
                      await _selectClosingTime();

                      field.didChange(_closingTime);
                    }
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.closingTimeLabel,
                  prefixIcon: const Icon(Icons.schedule_outlined),
                  suffixIcon: widget.enabled
                      ? const Icon(Icons.arrow_drop_down)
                      : null,
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                  enabled: widget.enabled,
                ),
                child: Text(_displayTime(context, _closingTime)),
              ),
            );
          },
        ),
      ],
    );
  }
}
