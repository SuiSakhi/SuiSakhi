import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class OrderStageProgress extends StatelessWidget {
  const OrderStageProgress({
    super.key,
    required this.stages,
    required this.currentStep,
    this.compact = true,
  }) : assert(stages.length > 1);

  final List<String> stages;
  final int currentStep;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = currentStep.clamp(0, stages.length - 1).toInt();
    final primary = AppColors.primary;
    final muted = AppColors.textHint.withValues(alpha: 0.35);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                _StageDot(
                  index: index,
                  active: active,
                  primary: primary,
                  muted: muted,
                ),
                if (index < stages.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < active ? primary : muted,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < stages.length; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 2,
                      right: index == stages.length - 1 ? 0 : 2,
                    ),
                    child: Text(
                      stages[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: index == 0
                          ? TextAlign.left
                          : index == stages.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        height: 1.1,
                        color: index <= active
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        fontWeight: index == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.index,
    required this.active,
    required this.primary,
    required this.muted,
  });

  final int index;
  final int active;
  final Color primary;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final completed = index < active;
    final selected = index == active;
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed || selected ? primary : Colors.white,
        border: Border.all(
          color: completed || selected ? primary : muted,
          width: 2,
        ),
      ),
      child: completed
          ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
          : selected
          ? Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
