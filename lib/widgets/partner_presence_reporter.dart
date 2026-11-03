import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Records partner app presence while a partner workspace is in the foreground.
/// This is an audit timestamp only; it does not change approval or availability.
class PartnerPresenceReporter extends StatefulWidget {
  const PartnerPresenceReporter({
    super.key,
    required this.accountId,
    required this.profileId,
    required this.child,
  });

  final String accountId;
  final String profileId;
  final Widget child;

  @override
  State<PartnerPresenceReporter> createState() =>
      _PartnerPresenceReporterState();
}

class _PartnerPresenceReporterState extends State<PartnerPresenceReporter>
    with WidgetsBindingObserver {
  Timer? _heartbeat;
  bool _writeInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartbeat = Timer.periodic(const Duration(minutes: 10), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_recordPresence());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recordPresence());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_recordPresence());
  }

  Future<void> _recordPresence() async {
    final accountId = widget.accountId.trim();
    final profileId = widget.profileId.trim();
    if (_writeInProgress || accountId.isEmpty || profileId.isEmpty) return;
    _writeInProgress = true;
    try {
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(accountId)
          .collection('profiles')
          .doc(profileId)
          .update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Presence is best effort and must not interrupt partner work.
    } finally {
      _writeInProgress = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
