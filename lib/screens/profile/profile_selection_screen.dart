import 'package:flutter/material.dart';

class ProfileSelectionScreen extends StatelessWidget {
  final List<Map<String, dynamic>> profiles;

  const ProfileSelectionScreen({
    super.key,
    required this.profiles,
  });

  IconData _iconForRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.store;
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

    switch (role) {
      case 'owner':
      case 'tailor':
      case 'supplier':
        final shopName =
            (profile['shopName'] ?? '').toString().trim();
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

  String _roleTitle(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';

      case 'tailor':
        return 'Tailor';

      case 'delivery':
      case 'delivery_partner':
        return 'Delivery Partner';

      case 'supplier':
        return 'Supplier';

      case 'customer':
      default:
        return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Profile'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: profiles.length,
        separatorBuilder: (_, index) =>
              const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = profiles[index];

          final role =
              (profile['role'] ?? 'customer').toString();

          final isDefault =
              profile['isDefaultProfile'] == true;

          return Card(
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_iconForRole(role)),
              ),
              title: Text(
                _displayName(profile),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_roleTitle(role)),
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
                      'Selected ${_roleTitle(role)}: ${_displayName(profile)}',
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
