import 'partner_workspace_module.dart';

class PartnerWorkspaceDefinition {
  const PartnerWorkspaceDefinition({
    required this.partnerType,
    required this.categoryLabel,
    required this.modules,
  });

  final String partnerType;
  final String categoryLabel;
  final List<PartnerWorkspaceModule> modules;

  List<PartnerWorkspaceModule> modulesFor(String section) {
    final result = modules
        .where((module) => module.section == section)
        .toList();
    result.sort((left, right) => left.order.compareTo(right.order));
    return result;
  }
}
