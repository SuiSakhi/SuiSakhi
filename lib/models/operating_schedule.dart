import 'package:flutter/material.dart';

class OperatingSchedule {
  const OperatingSchedule({
    this.operatingDays = const <String>[],
    this.openingTime,
    this.closingTime,
  });

  static const List<String> orderedDayCodes = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const Map<String, String> shortDayLabels = {
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };

  static const Map<String, String> fullDayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  final List<String> operatingDays;

  /// Normalized 24-hour value such as `09:00`.
  final String? openingTime;

  /// Normalized 24-hour value such as `21:00`.
  final String? closingTime;

  bool get hasOperatingDays {
    return normalizedOperatingDays.isNotEmpty;
  }

  bool get hasOpeningTime {
    return timeOfDayFromStorage(openingTime) != null;
  }

  bool get hasClosingTime {
    return timeOfDayFromStorage(closingTime) != null;
  }

  bool get hasCompleteSchedule {
    return hasOperatingDays && hasOpeningTime && hasClosingTime;
  }

  List<String> get normalizedOperatingDays {
    final selectedDays = operatingDays
        .map((day) => day.trim().toLowerCase())
        .where(orderedDayCodes.contains)
        .toSet();

    return orderedDayCodes.where(selectedDays.contains).toList(growable: false);
  }

  bool get closesAfterOpening {
    final opening = timeOfDayFromStorage(openingTime);
    final closing = timeOfDayFromStorage(closingTime);

    if (opening == null || closing == null) {
      return false;
    }

    return _minutesSinceMidnight(closing) > _minutesSinceMidnight(opening);
  }

  String get operatingDaysDisplay {
    final labels = normalizedOperatingDays
        .map((day) => fullDayLabels[day] ?? day)
        .toList(growable: false);

    if (labels.isEmpty) {
      return 'Not provided';
    }

    return labels.join(', ');
  }

  OperatingSchedule copyWith({
    List<String>? operatingDays,
    String? openingTime,
    String? closingTime,
  }) {
    return OperatingSchedule(
      operatingDays: operatingDays ?? this.operatingDays,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operatingDays': normalizedOperatingDays,
      'openingTime': normalizedTimeOrNull(openingTime),
      'closingTime': normalizedTimeOrNull(closingTime),
    };
  }

  factory OperatingSchedule.fromMap(Map<String, dynamic> data) {
    final rawDays = data['operatingDays'];

    return OperatingSchedule(
      operatingDays: rawDays is Iterable
          ? rawDays.map((day) => day.toString()).toList(growable: false)
          : const <String>[],
      openingTime: normalizedTimeOrNull(data['openingTime']?.toString()),
      closingTime: normalizedTimeOrNull(data['closingTime']?.toString()),
    );
  }

  static TimeOfDay? timeOfDayFromStorage(String? value) {
    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return null;
    }

    final parts = normalizedValue.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String storageValueFromTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  static String? normalizedTimeOrNull(String? value) {
    final time = timeOfDayFromStorage(value);

    if (time == null) {
      return null;
    }

    return storageValueFromTimeOfDay(time);
  }

  static int _minutesSinceMidnight(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }
}
