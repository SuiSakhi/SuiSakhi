import 'package:flutter/material.dart';

import '../../models/partner_application.dart';
import '../../models/security_template.dart';
import '../../services/partner_agreement_service.dart';
import '../../services/payout_config_service.dart';

/// Collects affirmative, document-by-document Partner agreement acceptance.
class PartnerAgreementAcceptanceDialog extends StatefulWidget {
  const PartnerAgreementAcceptanceDialog({
    required this.application,
    required this.documents,
    required this.joiningSecurityDeposit,
    super.key,
  });

  final PartnerApplication application;
  final List<SecurityTemplate> documents;
  final double joiningSecurityDeposit;

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final documents = await PartnerAgreementService.loadRequiredDocuments(
      application.partnerType,
    );
    final payoutConfig = await PayoutConfigService.fetch();
    if (!context.mounted) return null;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PartnerAgreementAcceptanceDialog(
        application: application,
        documents: documents,
        joiningSecurityDeposit: payoutConfig.partnerJoiningSecurityDeposit,
      ),
    );
  }

  @override
  State<PartnerAgreementAcceptanceDialog> createState() =>
      _PartnerAgreementAcceptanceDialogState();
}

class _PartnerAgreementAcceptanceDialogState
    extends State<PartnerAgreementAcceptanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _legalName;
  late final TextEditingController _signatoryName;
  final Set<String> _acceptedPackIds = {};
  String _capacity = 'Individual Partner';
  bool _confirmAuthority = false;
  bool _acceptedJoiningDeposit = false;

  @override
  void initState() {
    super.initState();
    final application = widget.application;
    _legalName = TextEditingController(
      text: _nonEmpty(application.businessName, application.contactName),
    );
    _signatoryName = TextEditingController(
      text: application.contactName?.trim() ?? '',
    );
    if (application.businessName?.trim().isNotEmpty == true) {
      _capacity = 'Owner / authorised signatory';
    }
  }

  @override
  void dispose() {
    _legalName.dispose();
    _signatoryName.dispose();
    super.dispose();
  }

  String _nonEmpty(String? first, String? second) {
    if (first?.trim().isNotEmpty == true) return first!.trim();
    return second?.trim() ?? '';
  }

  Future<void> _review(SecurityTemplate document) async {
    final packId = document.sourcePackId;
    if (packId == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _AgreementDocumentReviewDialog(document: document),
    );
    if (accepted == true && mounted) {
      setState(() => _acceptedPackIds.add(packId));
    }
  }

  void _acceptAndContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (_acceptedPackIds.length != widget.documents.length ||
        !_confirmAuthority ||
        (widget.joiningSecurityDeposit > 0 && !_acceptedJoiningDeposit)) {
      return;
    }
    final consentText =
        'I have reviewed and affirmatively accept each Partner agreement '
        'listed for my application. I confirm that I am the Partner or have '
        'authority to accept on behalf of the named legal entity.';
    final depositTerms = widget.joiningSecurityDeposit > 0
        ? 'One-time Partner joining security deposit: '
              '₹${widget.joiningSecurityDeposit.toStringAsFixed(2)}. '
              'This deposit is refundable after the Partner discontinues '
              'service with SuiSakhi.'
        : 'No Partner joining security deposit is currently charged.';
    Navigator.of(context).pop({
      'acceptedDocumentIds': widget.documents
          .map((document) => document.sourcePackId!)
          .toList(growable: false),
      'documents': widget.documents
          .map(PartnerAgreementService.snapshotForAcceptance)
          .toList(growable: false),
      'partnerLegalName': _legalName.text.trim(),
      'signatoryName': _signatoryName.text.trim(),
      'signatoryCapacity': _capacity,
      'consentText': consentText,
      'joiningSecurityDeposit': {
        'amount': widget.joiningSecurityDeposit,
        'currency': 'INR',
        'termsText': depositTerms,
        'accepted':
            widget.joiningSecurityDeposit <= 0 || _acceptedJoiningDeposit,
        // The current build records the terms. It does not collect money.
        'collectionStatus': widget.joiningSecurityDeposit <= 0
            ? 'notRequired'
            : 'notCollected',
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Review & accept Partner agreements'),
      content: SizedBox(
        width: size.width * 0.88,
        height: size.height * 0.68,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Partner Master Agreement is required for every Partner. '
                'Safety documents appear when they apply to this service category. '
                'Open and accept each document before submitting.',
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFFFF6E2),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.joiningSecurityDeposit > 0
                            ? 'One-time refundable joining deposit · '
                                  '₹${widget.joiningSecurityDeposit.toStringAsFixed(2)}'
                            : 'Joining deposit · ₹0.00',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.joiningSecurityDeposit > 0
                            ? 'This one-time security deposit is refundable after you discontinue service with SuiSakhi.'
                            : 'No joining security deposit is currently charged.',
                      ),
                      if (widget.joiningSecurityDeposit > 0) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'This application records your acceptance. Payment collection and refund processing are handled outside the app.',
                        ),
                      ],
                      if (widget.joiningSecurityDeposit > 0)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _acceptedJoiningDeposit,
                          onChanged: (value) => setState(
                            () => _acceptedJoiningDeposit = value ?? false,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I understand and accept the refundable joining deposit terms.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final document in widget.documents)
                      _documentTile(document),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _legalName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Partner / legal entity name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Enter the Partner or legal entity name.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _signatoryName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Signatory name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Enter the signatory name.',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _capacity,
                      decoration: const InputDecoration(
                        labelText: 'Signatory capacity',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Individual Partner',
                          child: Text('Individual Partner'),
                        ),
                        DropdownMenuItem(
                          value: 'Owner / authorised signatory',
                          child: Text('Owner / authorised signatory'),
                        ),
                        DropdownMenuItem(
                          value: 'Authorised representative',
                          child: Text('Authorised representative'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _capacity = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _confirmAuthority,
                      onChanged: (value) =>
                          setState(() => _confirmAuthority = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I confirm I have authority to accept these agreements.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _acceptedPackIds.length == widget.documents.length &&
                  _confirmAuthority &&
                  (widget.joiningSecurityDeposit <= 0 ||
                      _acceptedJoiningDeposit)
              ? _acceptAndContinue
              : null,
          child: const Text('Accept & submit'),
        ),
      ],
    );
  }

  Widget _documentTile(SecurityTemplate document) {
    final packId = document.sourcePackId!;
    final accepted = _acceptedPackIds.contains(packId);
    return Card(
      child: ListTile(
        leading: Icon(
          accepted ? Icons.verified_rounded : Icons.description_outlined,
          color: accepted ? Colors.green : null,
        ),
        title: Text(document.title),
        subtitle: Text(
          accepted ? 'Accepted' : document.summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () => _review(document),
          child: Text(accepted ? 'Review again' : 'View & accept'),
        ),
        onTap: () => _review(document),
      ),
    );
  }
}

class _AgreementDocumentReviewDialog extends StatefulWidget {
  const _AgreementDocumentReviewDialog({required this.document});

  final SecurityTemplate document;

  @override
  State<_AgreementDocumentReviewDialog> createState() =>
      _AgreementDocumentReviewDialogState();
}

class _AgreementDocumentReviewDialogState
    extends State<_AgreementDocumentReviewDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    return AlertDialog(
      title: Text(widget.document.title),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: SelectableText(widget.document.body),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I have read and accept this document.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Accept document'),
        ),
      ],
    );
  }
}
