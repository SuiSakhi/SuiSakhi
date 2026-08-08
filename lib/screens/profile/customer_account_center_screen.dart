import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';

class CustomerAccountCenterScreen extends StatelessWidget {
  const CustomerAccountCenterScreen({super.key});

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
            onTap: () => context.push('/customer-profile'),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update name, photo and preferences',
            onTap: () => context.push('/customer-edit-profile'),
          ),
          _MenuItem(
            icon: Icons.family_restroom,
            title: 'Family Members',
            subtitle: 'Manage family profiles and measurements',
            onTap: () => context.push('/family-members'),
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
        borderRadius: BorderRadius.circular(22),
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
            radius: 36,
            backgroundColor: const Color(0xFFF3EAFB),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF7B3FB2),
                fontSize: 28,
                fontWeight: FontWeight.w800,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isEmpty ? 'Mobile not available' : phone,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EAFB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Customer Profile',
                    style: TextStyle(
                      color: Color(0xFF7B3FB2),
                      fontWeight: FontWeight.w700,
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
    final itemColor = isDestructive
        ? Colors.red
        : const Color(0xFF7B3FB2);

    final iconBackgroundColor = isDestructive
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFF3EAFB);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: CircleAvatar(
            backgroundColor: iconBackgroundColor,
            child: Icon(
              icon,
              color: itemColor,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDestructive ? Colors.red : Colors.black87,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(
            Icons.chevron_right,
            color: isDestructive ? Colors.red : Colors.black45,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
