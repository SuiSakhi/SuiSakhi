class CatalogueContributorSummary {
  const CatalogueContributorSummary({
    required this.sourceCode,
    required this.sourceLabel,
    required this.displayName,
    this.accountId,
    this.profileId,
    this.partnerType,
    this.approvalStatus,
    this.kycStatus,
  });

  final String sourceCode;
  final String sourceLabel;
  final String displayName;
  final String? accountId;
  final String? profileId;
  final String? partnerType;
  final String? approvalStatus;
  final String? kycStatus;

  bool get isPartner => profileId?.trim().isNotEmpty == true;
}
