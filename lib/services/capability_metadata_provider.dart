import '../models/capability_definition.dart';

abstract interface class CapabilityMetadataProvider {
  List<CapabilityGroupDefinition> groupsForPartnerCategory(
    String partnerCategoryCode,
  );

  List<CapabilityDefinition> capabilitiesForPartnerCategory(
    String partnerCategoryCode,
  );

  List<CapabilityDefinition> capabilitiesForGroup({
    required String partnerCategoryCode,
    required String groupCode,
  });

  CapabilityDefinition? capabilityForCode(String? capabilityCode);

  CapabilityGroupDefinition? groupForCode({
    required String partnerCategoryCode,
    required String groupCode,
  });
}
