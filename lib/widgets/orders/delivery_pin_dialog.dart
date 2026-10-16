import 'package:flutter/material.dart';

Future<String?> showDeliveryPinDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DeliveryPinDialog(),
  );
}

class _DeliveryPinDialog extends StatefulWidget {
  const _DeliveryPinDialog();

  @override
  State<_DeliveryPinDialog> createState() => _DeliveryPinDialogState();
}

class _DeliveryPinDialogState extends State<_DeliveryPinDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm customer handover'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Customer delivery PIN',
          hintText: 'Enter 4-digit PIN',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Verify PIN'),
        ),
      ],
    );
  }
}
