import 'package:flutter/material.dart';
import '../../services/partner_workspace_registry.dart';

class ProfileSelectionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;

  const ProfileSelectionScreen({super.key, required this.profiles});

  IconData _iconForProfile(Map<String, dynamic> profile) {
    final role = (profile['role'] ?? 'customer')
        .toString()
        .trim()
        .toLowerCase();

    final partnerType = (profile['partnerType'] ?? '').toString().trim();

    // ================================================================
    // GENERIC PARTNER PROFILE
    // ================================================================
    //
    // Every new Partner Business Profile uses:
    //
    // role = partner
    // partnerType = tailor | measurementPartner | deliveryPartner | ...
    // ================================================================
    if (role == 'partner') {
      return PartnerWorkspaceRegistry.categoryIcon(partnerType);
    }

    // ================================================================
    // LEGACY PROFILE COMPATIBILITY
    // ================================================================
    //
    // These cases support older profile records until migration.
    // ================================================================
    switch (role) {
      case 'owner':
        return Icons.admin_panel_settings;

      case 'tailor':
        return Icons.content_cut;

      case 'delivery':
      case 'delivery_partner':
        return Icons.local_shipping;

      case 'supplier':
        return Icons.inventory_2;

      case 'customer':
      default:
        return Icons.person;
    }
  }

  String _displayName(Map<String, dynamic> profile) {
    final role = (profile['role'] ?? '').toString().toLowerCase();
    if (role == 'partner') {
      for (final key in ['businessName', 'shopName', 'displayName', 'name']) {
        final value = (profile[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return 'SuiSakhi Partner';
    }
    switch (role) {
      case 'owner':
      case 'tailor':
      case 'supplier':
        final shopName = (profile['shopName'] ?? '').toString().trim();
        if (shopName.isNotEmpty) {
          return shopName;
        }
        return (profile['displayName'] ?? 'Profile').toString();

      case 'delivery':
      case 'delivery_partner':
      case 'customer':
      default:
        return (profile['displayName'] ?? 'Profile').toString();
    }
  }

  String _roleTitle(Map<String, dynamic> profile) {
    final role = (profile['role'] ?? 'customer')
        .toString()
        .trim()
        .toLowerCase();

    final partnerType = (profile['partnerType'] ?? '').toString().trim();

    if (role == 'partner') {
      return PartnerWorkspaceRegistry.categoryLabel(partnerType);
    }

    switch (role) {
      case 'owner':
        return 'Owner';

      case 'customer':
      default:
        return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Profile'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: profiles.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = profiles[index];

          final isDefault = profile['isDefaultProfile'] == true;

          return Card(
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(child: Icon(_iconForProfile(profile))),
              title: Text(
                _displayName(profile),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_roleTitle(profile)),
                  if (isDefault)
                    const Text(
                      'Default Profile',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context, profile);
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected ${_roleTitle(profile)}: ${_displayName(profile)}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
