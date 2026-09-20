import 'package:cloud_firestore/cloud_firestore.dart';

class PartnerWorkspaceProfile {
  const PartnerWorkspaceProfile({
    required this.accountId,
    required this.profileId,
    required this.partnerType,
    required this.displayName,
    required this.status,
    required this.operationalStatus,
    required this.activationStatus,
    required this.approvalStatus,
    required this.kycStatus,
    required this.partnerData,
    this.businessName,
    this.contactName,
    this.mobileE164,
    this.email,
    this.profilePhotoUrl,
    this.sourceApplicationId,
    this.approvedAt,
  });

  final String accountId;
  final String profileId;
  final String partnerType;
  final String displayName;
  final String? businessName;
  final String? contactName;
  final String? mobileE164;
  final String? email;
  final String? profilePhotoUrl;
  final String status;
  final String operationalStatus;
  final String activationStatus;
  final String approvalStatus;
  final String kycStatus;
  final String? sourceApplicationId;
  final DateTime? approvedAt;
  final Map<String, dynamic> partnerData;

  bool get isApproved => approvalStatus == 'approved';
  bool get isKycVerified => kycStatus == 'verified';
  bool get isActive => status == 'active';
  bool get isOperationallyActive =>
      operationalStatus == 'active' && activationStatus == 'active';
  bool get canUseOperations =>
      isApproved && isKycVerified && isActive && isOperationallyActive;

  String get businessDisplayName {
    for (final value in [businessName, displayName, contactName]) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'SuiSakhi Partner';
  }

  String get initial => businessDisplayName[0].toUpperCase();

  factory PartnerWorkspaceProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    String text(String key, [String fallback = '']) =>
        (data[key] ?? fallback).toString().trim();
    String? optional(String key) {
      final value = text(key);
      return value.isEmpty ? null : value;
    }

    final businessName = optional('businessName') ?? optional('shopName');
    final resolvedDisplayName =
        businessName ??
        optional('displayName') ??
        optional('name') ??
        optional('contactName') ??
        'SuiSakhi Partner';
    final rawPartnerData = data['partnerData'];
    return PartnerWorkspaceProfile(
      accountId: text('accountId'),
      profileId: text('profileId', document.id),
      partnerType: text('partnerType', 'other'),
      displayName: resolvedDisplayName,
      businessName: businessName,
      contactName: optional('contactName'),
      mobileE164: optional('mobileE164'),
      email: optional('email'),
      profilePhotoUrl: optional('profilePhotoUrl'),
      status: text('status', 'inactive'),
      operationalStatus: text('operationalStatus', 'inactive'),
      activationStatus: text('activationStatus', 'inactive'),
      approvalStatus: text('approvalStatus', 'pending'),
      kycStatus: text('kycStatus', 'notStarted'),
      sourceApplicationId: optional('sourceApplicationId'),
      approvedAt: _date(data['approvedAt']),
      partnerData: rawPartnerData is Map
          ? Map<String, dynamic>.from(rawPartnerData)
          : const <String, dynamic>{},
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
