import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppState.instance.profile;
    final user = FirebaseAuth.instance.currentUser;

    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : AppState.instance.displayName;

    final mobileNumber = user?.phoneNumber ?? 'Not available';
    final email = profile?.email?.trim().isNotEmpty == true
        ? profile!.email!.trim()
        : user?.email ?? 'Not added';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Profile'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              _comingSoon(context, 'Edit Profile');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            displayName: displayName,
            mobileNumber: mobileNumber,
          ),
          const SizedBox(height: 20),

          const _SectionTitle(title: 'Personal Information'),
          _InfoTile(
            icon: Icons.person_outline,
            title: 'Full Name',
            value: displayName,
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            title: 'Mobile Number',
            value: mobileNumber,
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: email,
          ),
          const _InfoTile(
            icon: Icons.cake_outlined,
            title: 'Date of Birth',
            value: 'Optional - Not added',
          ),
          const _InfoTile(
            icon: Icons.badge_outlined,
            title: 'Customer Type',
            value: 'Customer',
          ),

          const SizedBox(height: 18),
          const _SectionTitle(title: 'Body & Fit Details'),
          const _InfoTile(
            icon: Icons.height_outlined,
            title: 'Height',
            value: 'Optional - Not added',
          ),
          const _InfoTile(
            icon: Icons.monitor_weight_outlined,
            title: 'Weight',
            value: 'Optional - Not added',
          ),
          const _InfoTile(
            icon: Icons.checkroom_outlined,
            title: 'Fit Preference',
            value: 'Optional - Not added',
          ),

          const SizedBox(height: 18),
          const _SectionTitle(title: 'Preferences'),
          const _InfoTile(
            icon: Icons.language_outlined,
            title: 'Preferred Language',
            value: 'English',
          ),
          const _InfoTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            value: 'SMS, WhatsApp and App notifications',
          ),

          const SizedBox(height: 18),
          const _SectionTitle(title: 'Account Information'),
          const _InfoTile(
            icon: Icons.account_circle_outlined,
            title: 'Account ID',
            value: 'Available after Firebase sync',
          ),

          const _InfoTile(
            icon: Icons.perm_identity_outlined,
            title: 'Profile ID',
            value: 'Available after Firebase sync',
          ),

          const _InfoTile(
            icon: Icons.verified_user_outlined,
            title: 'Profile Status',
            value: 'Active',
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _comingSoon(context, 'Edit Profile');
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
  final String mobileNumber;

  const _ProfileHeader({
    required this.displayName,
    required this.mobileNumber,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'C';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            radius: 38,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 30,
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
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  mobileNumber,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Customer Profile',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
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
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6DDF1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
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
