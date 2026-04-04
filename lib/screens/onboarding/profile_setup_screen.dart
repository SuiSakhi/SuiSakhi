import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../models/user_profile.dart';
import '../../services/profile_photo_service.dart';
import '../../widgets/common/custom_button.dart';

String _profilePhotoStorageMessage(FirebaseException e) {
  final c = e.code.toLowerCase();
  if (c == 'permission-denied' ||
      c == 'unauthorized' ||
      c.contains('unauthorized')) {
    return 'Storage rules blocked access. In Firebase Console → Storage → Rules, '
        'allow signed-in users to read and write under users/{userId}/...';
  }
  if (c.contains('object-not-found')) {
    return 'Storage is blocking read after upload. In Firebase Console → Storage → Rules, '
        'publish rules that allow read and write for users/{userId}/** when request.auth.uid == userId. '
        'See firebase/storage.rules in this project, then tap Open rules below.';
  }
  return 'Photo upload failed: ${e.message ?? e.code}';
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _nameController = TextEditingController(
    text: () {
      final name = AppState.instance.profile?.name ?? '';
      return (name.isNotEmpty && name != 'Guest' && name != 'User')
          ? name
          : '';
    }(),
  );
  late final TextEditingController _emailController;
  final _ageController = TextEditingController(text: '25');
  final Gender _selectedGender = Gender.female;
  int _selectedAge = 25;
  final _formKey = GlobalKey<FormState>();
  String? _photoUrl;
  bool _photoBusy = false;
  bool _notifyWhatsApp = true;
  late final TextEditingController _payoutUpiController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _photoUrl = AppState.instance.profile?.photoUrl;
    _emailController = TextEditingController(
      text: AppState.instance.profile?.email?.trim() ?? '',
    );
    _notifyWhatsApp = AppState.instance.profile?.notifyWhatsApp ?? true;
    _payoutUpiController = TextEditingController(
      text: AppState.instance.profile?.payoutUpiId?.trim() ?? '',
    );
    _addressController = TextEditingController(
      text: AppState.instance.profile?.deliveryAddress?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _payoutUpiController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  static String? _optionalEmailValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Enter a valid email or leave blank';
    }
    return null;
  }

  void _showStorageHelpSnackBar(String message) {
    if (!mounted) return;
    final pid = Firebase.app().options.projectId.trim();
    final rulesUri = pid.isEmpty
        ? null
        : Uri.parse(
            'https://console.firebase.google.com/project/$pid/storage/rules',
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 14),
        content: Text(message),
        action: rulesUri != null
            ? SnackBarAction(
                label: 'Open rules',
                onPressed: () async {
                  if (await canLaunchUrl(rulesUri)) {
                    await launchUrl(rulesUri, mode: LaunchMode.externalApplication);
                  }
                },
              )
            : null,
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _photoBusy = true);
    String? url;
    var showedError = false;
    try {
      url = await ProfilePhotoService.uploadProfilePhoto(file);
    } on FirebaseException catch (e) {
      showedError = true;
      if (mounted) {
        _showStorageHelpSnackBar(_profilePhotoStorageMessage(e));
      }
    } catch (e) {
      showedError = true;
      if (mounted) {
        _showStorageHelpSnackBar('Photo upload failed: $e');
      }
    }
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (url == null && !showedError && mounted) {
      _showStorageHelpSnackBar(
        'Could not upload photo — try again. If it keeps failing, check Storage rules '
        '(users/{userId}/ must allow read & write for that user).',
      );
      return;
    }
    if (url == null) return;
    await AppState.instance.updatePhotoUrl(url);
    if (mounted) setState(() => _photoUrl = url);
  }

  void _adjustAge(int delta) {
    final current = int.tryParse(_ageController.text) ?? _selectedAge;
    final newAge = (current + delta).clamp(10, 80);
    setState(() => _selectedAge = newAge);
    _ageController.text = '$newAge';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _photoBusy ? null : _pickProfilePhoto,
                          borderRadius: BorderRadius.circular(28),
                          child: Ink(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: _photoUrl == null
                                  ? AppColors.primaryGradient
                                  : null,
                              color: _photoUrl != null
                                  ? AppColors.surfaceVariant
                                  : null,
                              image: _photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photoBusy
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : _photoUrl == null
                                    ? const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: Colors.white,
                                        size: 40,
                                      )
                                    : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _photoBusy ? null : _pickProfilePhoto,
                        icon: const Icon(Icons.face_retouching_natural_rounded, size: 18),
                        label: Text(_photoUrl == null ? 'Add profile photo' : 'Change photo'),
                      ),
                      Text(
                        'Optional — used for your look preview in Dress designer',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Set Up Your\nProfile', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'We\'ll use this to personalise your experience',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 36),

                // Name
                Text('Your Name', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 24),

                Text('Email (optional)', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _optionalEmailValidator,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add anytime under Edit profile. Used for receipts and shop contact only.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 24),
                Text('Delivery address', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'House / flat, street, area, landmark, city, PIN — used so delivery can reach you.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Full address for doorstep delivery',
                    prefixIcon: Icon(Icons.home_work_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (t.length < 12) {
                      return 'Add a bit more detail (street, area, city, PIN)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Order updates on WhatsApp',
                      style: AppTextStyles.titleMedium),
                  subtitle: Text(
                    'Sends a template message to this login number when your order is placed (requires backend setup).',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                  value: _notifyWhatsApp,
                  onChanged: (v) => setState(() => _notifyWhatsApp = v),
                ),
                const SizedBox(height: 20),
                Text('Payout UPI (optional)', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'If you are a tailor or delivery partner, add your UPI id so payout '
                  'records match your account. Customers: you can leave this blank.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _payoutUpiController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'name@upi',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // Age
                Text('Age', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Decrement button
                    _AgeStepBtn(
                      icon: Icons.remove,
                      onTap: () => _adjustAge(-1),
                    ),
                    const SizedBox(width: 12),
                    // Editable age field
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          suffixText: 'yrs',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          if (parsed != null && parsed >= 10 && parsed <= 80) {
                            setState(() => _selectedAge = parsed);
                          }
                        },
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 10 || n > 80) {
                            return 'Enter age between 10–80';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Increment button
                    _AgeStepBtn(
                      icon: Icons.add,
                      onTap: () => _adjustAge(1),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () async {
                    if (_formKey.currentState!.validate()) {
                      final age = int.tryParse(_ageController.text) ?? _selectedAge;
                      final existing = AppState.instance.profile;
                      final em = _emailController.text.trim();
                      final upi = _payoutUpiController.text.trim();
                      final addr = _addressController.text.trim();
                      AppState.instance.setProfile(UserProfile(
                        name: _nameController.text.trim(),
                        gender: _selectedGender,
                        age: age,
                        email: em.isEmpty ? null : em,
                        photoUrl: _photoUrl ?? existing?.photoUrl,
                        role: existing?.role ?? UserRole.customer,
                        notifyWhatsApp: _notifyWhatsApp,
                        payoutUpiId: upi.isEmpty ? null : upi,
                        deliveryAddress: addr.isEmpty ? null : addr,
                      ));
                      AppState.instance.markSetupComplete();
                      await AppState.instance.saveUserProfile();
                      if (context.mounted) context.go('/home');
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AgeStepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
