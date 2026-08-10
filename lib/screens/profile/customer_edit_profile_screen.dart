import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CustomerEditProfileScreen extends StatefulWidget {
  const CustomerEditProfileScreen({super.key});

  @override
  State<CustomerEditProfileScreen> createState() =>
      _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState extends State<CustomerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;

  String _fitPreference = 'Not selected';
  String _preferredLanguage = 'English';

  bool _smsEnabled = true;
  bool _whatsappEnabled = true;
  bool _appNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;

  static const List<String> _fitOptions = [
    'Not selected',
    'Regular Fit',
    'Comfort Fit',
    'Slim Fit',
    'Loose Fit',
  ];

  static const List<String> _languageOptions = [
    'English',
    'Hindi',
    'Marathi',
  ];

  @override
  void initState() {
    super.initState();

    final profile = AppState.instance.profile;
    final user = FirebaseAuth.instance.currentUser;

    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : AppState.instance.displayName;

    _fullNameCtrl = TextEditingController(text: displayName);
    _mobileCtrl = TextEditingController(text: user?.phoneNumber ?? '');
    _emailCtrl = TextEditingController(
      text: profile?.email?.trim().isNotEmpty == true
          ? profile!.email!.trim()
          : user?.email ?? '',
    );

    _dobCtrl = TextEditingController(text: profile?.dateOfBirth ?? '');
    _heightCtrl = TextEditingController(
      text: profile?.heightCm != null ? profile!.heightCm!.toStringAsFixed(0) : '',
    );
    _weightCtrl = TextEditingController(
      text: profile?.weightKg != null ? profile!.weightKg!.toStringAsFixed(0) : '',
    );

    _fitPreference = profile?.fitPreference?.trim().isNotEmpty == true
        ? profile!.fitPreference!
        : 'Not selected';

    _preferredLanguage = profile?.preferredLanguage.trim().isNotEmpty == true
        ? profile!.preferredLanguage
        : 'English';

    _smsEnabled = profile?.notifySms ?? true;
    _whatsappEnabled = profile?.notifyWhatsApp ?? true;
    _appNotificationsEnabled = profile?.notifyApp ?? true;
    _emailNotificationsEnabled = profile?.notifyEmail ?? false;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }
  
  double? _optionalDouble(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await AppState.instance.updateCustomerBasicProfile(
      name: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim(),
      heightCm: _optionalDouble(_heightCtrl),
      weightKg: _optionalDouble(_weightCtrl),
      fitPreference: _fitPreference == 'Not selected' ? null : _fitPreference,
      preferredLanguage: _preferredLanguage,
      notifySms: _smsEnabled,
      notifyWhatsApp: _whatsappEnabled,
      notifyApp: _appNotificationsEnabled,
      notifyEmail: _emailNotificationsEnabled,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, true);
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );

    if (selectedDate == null) return;

    _dobCtrl.text =
        '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/'
        '${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ProfileEditInfoCard(),
            const SizedBox(height: 20),

            const _SectionTitle(title: 'Basic Information'),
            _ProfileTextField(
              controller: _fullNameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _ProfileTextField(
              controller: _mobileCtrl,
              label: 'Mobile Number',
              icon: Icons.phone_outlined,
              readOnly: true,
              helperText: 'Mobile number can be changed through Helpdesk only.',
            ),
            const SizedBox(height: 12),
            _ProfileTextField(
              controller: _emailCtrl,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              helperText: 'Optional',
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return null;
                }

                final emailRegex = RegExp(
                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                );

                if (!emailRegex.hasMatch(email)) {
                  return 'Enter a valid email address';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            _ProfileTextField(
              controller: _dobCtrl,
              label: 'Date of Birth',
              icon: Icons.cake_outlined,
              readOnly: true,
              helperText: 'Optional',
              onTap: _selectDateOfBirth,
            ),

            const SizedBox(height: 20),
            const _SectionTitle(title: 'Body & Fit Details'),
            Row(
              children: [
                Expanded(
                  child: _ProfileTextField(
                    controller: _heightCtrl,
                    label: 'Height',
                    icon: Icons.height_outlined,
                    keyboardType: TextInputType.number,
                    helperText: 'cm, optional',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final height = double.tryParse(value.trim());
                      if (height == null || height < 50 || height > 250) {
                        return 'Invalid height';
                      }

                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileTextField(
                    controller: _weightCtrl,
                    label: 'Weight',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: TextInputType.number,
                    helperText: 'kg, optional',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final weight = double.tryParse(value.trim());
                      if (weight == null || weight < 10 || weight > 250) {
                        return 'Invalid weight';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fitPreference,
              decoration: const InputDecoration(
                labelText: 'Fit Preference',
                prefixIcon: Icon(Icons.checkroom_outlined),
                border: OutlineInputBorder(),
              ),
              items: _fitOptions
                  .map(
                    (fit) => DropdownMenuItem<String>(
                      value: fit,
                      child: Text(fit),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _fitPreference = value);
              },
            ),

            const SizedBox(height: 20),
            const _SectionTitle(title: 'Preferences'),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              decoration: const InputDecoration(
                labelText: 'Preferred Language',
                prefixIcon: Icon(Icons.language_outlined),
                border: OutlineInputBorder(),
              ),
              items: _languageOptions
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _preferredLanguage = value);
              },
            ),
            const SizedBox(height: 14),

            const _SectionTitle(title: 'Notification Preferences'),
            _PreferenceSwitch(
              title: 'SMS Notifications',
              subtitle: 'Receive SMS for order and profile updates',
              value: _smsEnabled,
              onChanged: (value) {
                setState(() => _smsEnabled = value);
              },
            ),
            _PreferenceSwitch(
              title: 'WhatsApp Notifications',
              subtitle: 'Receive WhatsApp updates where available',
              value: _whatsappEnabled,
              onChanged: (value) {
                setState(() => _whatsappEnabled = value);
              },
            ),
            _PreferenceSwitch(
              title: 'App Notifications',
              subtitle: 'Receive in-app notifications',
              value: _appNotificationsEnabled,
              onChanged: (value) {
                setState(() => _appNotificationsEnabled = value);
              },
            ),
            _PreferenceSwitch(
              title: 'Email Notifications',
              subtitle: 'Receive email updates',
              value: _emailNotificationsEnabled,
              onChanged: (value) {
                setState(() => _emailNotificationsEnabled = value);
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Profile'),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditInfoCard extends StatelessWidget {
  const _ProfileEditInfoCard();

  @override
  Widget build(BuildContext context) {
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFF3EAFB),
            child: Icon(
              Icons.person_outline,
              color: Color(0xFF7B3FB2),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Update your profile details. Full name is required. Other details are optional and can be completed when needed.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.35,
              ),
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

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? helperText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.helperText,
    this.readOnly = false,
    this.keyboardType,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6DDF1),
        ),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}