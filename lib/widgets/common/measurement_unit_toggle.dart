import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/measurement_unit.dart';

/// cm / in — updates [AppState.measurementUnit] and persists for the signed-in user.
class MeasurementUnitToggle extends StatelessWidget {
  const MeasurementUnitToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final u = AppState.instance.measurementUnit;
        return SegmentedButton<MeasurementUnit>(
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: AppColors.primary,
            selectedForegroundColor: Colors.white,
            foregroundColor: AppColors.textSecondary,
          ),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: MeasurementUnit.cm,
              label: Text('cm'),
            ),
            ButtonSegment(
              value: MeasurementUnit.inch,
              label: Text('in'),
            ),
          ],
          selected: {u},
          onSelectionChanged: (s) {
            final next = s.first;
            if (next != u) {
              AppState.instance.setMeasurementUnit(next);
            }
          },
        );
      },
    );
  }
}
