import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';

class CustomerAccountCenterScreen extends StatelessWidget {
  const CustomerAccountCenterScreen({super.key});
  static const Color _primaryColor = Color(0xFF7B3FB2);

  @override
  Widget build(BuildContext context) {
    final profile = AppState.instance.profile;
    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : AppState.instance.displayName;

    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        title: const Text('My Account'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F5FC),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            displayName: displayName,
            phone: phone,
          ),
          const SizedBox(height: 20),

          _SectionTitle(title: 'My Profile'),
          _MenuItem(
            icon: Icons.person_outline,
            title: 'View Profile',
            subtitle: 'See your customer profile details',
            onTap: () => _comingSoon(context, 'View Profile'),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update name, photo and preferences',
            onTap: () => _comingSoon(context, 'Edit Profile'),
          ),
          _MenuItem(
            icon: Icons.family_restroom,
            title: 'Family Members',
            subtitle: 'Manage family profiles and measurements',
            onTap: () => _comingSoon(context, 'Family Members'),
          ),

          const SizedBox(height: 16),
          _SectionTitle(title: 'Tailoring'),
          _MenuItem(
            icon: Icons.straighten,
            title: 'Measurements',
            subtitle: 'Manage saved measurements',
            onTap: () => context.push('/measurements'),
          ),
          _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Manage Addresses',
            subtitle: 'Pickup, delivery and default addresses',
            onTap: () => context.push('/customer-addresses'),
          ),

          const SizedBox(height: 16),
          _SectionTitle(title: 'Orders'),
          _MenuItem(
            icon: Icons.local_shipping_outlined,
            title: 'Order Tracking',
            subtitle: 'Track active orders',
            onTap: () => _comingSoon(context, 'Order Tracking'),
          ),
          _MenuItem(
            icon: Icons.history,
            title: 'Order History',
            subtitle: 'View previous and archived orders',
            onTap: () => context.push('/orders'),
          ),

          const SizedBox(height: 16),
          _SectionTitle(title: 'Saved & Benefits'),
          _MenuItem(
            icon: Icons.favorite_border,
            title: 'Wishlist',
            subtitle: 'Saved designs and favorites',
            onTap: () => _comingSoon(context, 'Wishlist'),
          ),
          _MenuItem(
            icon: Icons.style_outlined,
            title: 'Purchased Designs',
            subtitle: 'Your profile-owned paid designs',
            onTap: () => _comingSoon(context, 'Purchased Designs'),
          ),
          _MenuItem(
            icon: Icons.workspace_premium_outlined,
            title: 'Membership',
            subtitle: 'Subscription and plan benefits',
            onTap: () => _comingSoon(context, 'Membership'),
          ),
          _MenuItem(
            icon: Icons.card_giftcard,
            title: 'Rewards & Referrals',
            subtitle: 'Referral benefits and rewards',
            onTap: () => _comingSoon(context, 'Rewards & Referrals'),
          ),

          const SizedBox(height: 16),
          _SectionTitle(title: 'Partner Opportunities'),
          _MenuItem(
            icon: Icons.handshake_outlined,
            title: 'Become a Partner',
            subtitle: 'Register as Owner, Tailor, Supplier or Delivery Partner',
            onTap: () => _comingSoon(context, 'Become a Partner'),
          ),
          
          const SizedBox(height: 16),
          _SectionTitle(title: 'Settings & Support'),
          _MenuItem(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'WhatsApp and order alerts',
            onTap: () => _comingSoon(context, 'Notifications'),
          ),
          _MenuItem(
            icon: Icons.support_agent,
            title: 'Help & Support',
            subtitle: 'Contact support or raise an issue',
            onTap: () => _comingSoon(context, 'Help & Support'),
          ),
          _MenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Security',
            subtitle: 'Privacy, terms and account security',
            onTap: () => _comingSoon(context, 'Privacy & Security'),
          ),

          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from SuiSakhi',
            isDestructive: true,
            onTap: () async {
              await AppState.instance.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _comingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String phone;

  const _ProfileHeader({
    required this.displayName,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'C';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: 
              CustomerAccountCenterScreen._primaryColor.withOpacity(0.12),
            child: Text(
              initial,
              style: TextStyle(
                color: CustomerAccountCenterScreen._primaryColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isNotEmpty ? phone : 'Customer Profile',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Default Customer',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive
        ? Colors.red
        : CustomerAccountCenterScreen._primaryColor;
    final titleColor = isDestructive ? Colors.red : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.10),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
