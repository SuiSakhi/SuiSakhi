import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class CustomerOrdersHubScreen extends StatelessWidget {
  const CustomerOrdersHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F5FC),
    appBar: AppBar(
      title: const Text('My Orders'),
      centerTitle: true,
      backgroundColor: const Color(0xFFF8F5FC),
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Choose a service to track its orders and view order history.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _OrderCategoryCard(
          icon: Icons.checkroom_outlined,
          title: 'Tailoring Orders',
          subtitle: 'Stitching, alterations and tailoring requests',
          onTap: () => context.push('/orders?module=coreTailoring'),
        ),
        _OrderCategoryCard(
          icon: Icons.local_laundry_service_outlined,
          title: 'Garment Care Orders',
          subtitle: 'Laundry, dry cleaning and garment treatments',
          onTap: () => context.push('/garment-care/orders'),
        ),
        _OrderCategoryCard(
          icon: Icons.storefront_outlined,
          title: 'Fashion Store',
          subtitle: 'Product enquiries and store order updates',
          onTap: () => context.push('/orders?module=marketplace'),
        ),
        _OrderCategoryCard(
          icon: Icons.home_repair_service_outlined,
          title: 'Quick Care & Home Services',
          subtitle: 'Home service requests and their status',
          onTap: () => context.push('/orders?module=quickFix'),
        ),
        _OrderCategoryCard(
          icon: Icons.event_outlined,
          title: 'Weddings & Event Orders',
          subtitle: 'Wedding packages and event requests',
          onTap: () => context.push('/orders?module=bulkOrder'),
        ),
      ],
    ),
  );
}

class _OrderCategoryCard extends StatelessWidget {
  const _OrderCategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF3EAFB),
        foregroundColor: AppColors.primary,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
