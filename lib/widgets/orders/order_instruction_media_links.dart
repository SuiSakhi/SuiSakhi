import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'order_instruction_media_preview_dialog.dart';

/// Opens customer-recorded tailoring instructions for the customer or assigned
/// Tailor. Storage rules validate access before issuing each download URL.
class OrderInstructionMediaLinks extends StatefulWidget {
  const OrderInstructionMediaLinks({super.key, required this.media});

  final List<Map<String, dynamic>> media;

  @override
  State<OrderInstructionMediaLinks> createState() =>
      _OrderInstructionMediaLinksState();
}

class _OrderInstructionMediaLinksState
    extends State<OrderInstructionMediaLinks> {
  final Set<String> _opening = {};

  Future<void> _open(Map<String, dynamic> item) async {
    final storagePath = item['storagePath']?.toString().trim() ?? '';
    if (storagePath.isEmpty || _opening.contains(storagePath)) return;
    setState(() => _opening.add(storagePath));
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => OrderInstructionMediaPreviewDialog(
          kind: item['kind']?.toString() ?? '',
          storagePath: storagePath,
        ),
      );
    } catch (_) {
      if (mounted) _message('Could not open this instruction recording.');
    } finally {
      if (mounted) setState(() => _opening.remove(storagePath));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.media
            .map((item) {
              final kind = item['kind']?.toString() ?? '';
              final path = item['storagePath']?.toString() ?? '';
              if (!['audio', 'video'].contains(kind) || path.isEmpty) {
                return const SizedBox.shrink();
              }
              final opening = _opening.contains(path);
              return OutlinedButton.icon(
                onPressed: opening ? null : () => _open(item),
                icon: opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        kind == 'audio'
                            ? Icons.play_circle_outline_rounded
                            : Icons.videocam_outlined,
                      ),
                label: Text(
                  kind == 'audio' ? 'Open voice note' : 'Open video note',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
