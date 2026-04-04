enum Gender { male, female, other }

enum UserRole { customer, tailor, owner, delivery }

class UserProfile {
  final String name;
  final Gender gender;
  final int age;
  final UserRole role;
  final String? avatarPath;
  final String? email;
  final String? photoUrl;
  /// Order / status pings via WhatsApp Cloud API (requires backend + Meta template).
  final bool notifyWhatsApp;
  /// Optional UPI for tailor/delivery payout records (shop may mirror in Owner settings).
  final String? payoutUpiId;
  /// Doorstep / delivery address for customers (shown to delivery partners on orders).
  final String? deliveryAddress;

  const UserProfile({
    required this.name,
    this.gender = Gender.female,
    this.age = 0,
    this.role = UserRole.customer,
    this.avatarPath,
    this.email,
    this.photoUrl,
    this.notifyWhatsApp = true,
    this.payoutUpiId,
    this.deliveryAddress,
  });

  String get genderLabel {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}
