import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/models/user_profile.dart';

void main() {
  group('UserProfile construction', () {
    test('uses defaults when only name is given', () {
      const profile = UserProfile(name: 'Priya Sharma');
      expect(profile.name, 'Priya Sharma');
      expect(profile.gender, Gender.female);
      expect(profile.age, 0);
      expect(profile.role, UserRole.customer);
      expect(profile.email, isNull);
      expect(profile.photoUrl, isNull);
      expect(profile.avatarPath, isNull);
    });

    test('stores all fields correctly', () {
      const profile = UserProfile(
        name: 'Rahul Kumar',
        gender: Gender.male,
        age: 28,
        role: UserRole.owner,
        email: 'rahul@gmail.com',
        photoUrl: 'https://example.com/photo.jpg',
        avatarPath: '/local/avatar.png',
      );
      expect(profile.name, 'Rahul Kumar');
      expect(profile.gender, Gender.male);
      expect(profile.age, 28);
      expect(profile.role, UserRole.owner);
      expect(profile.email, 'rahul@gmail.com');
      expect(profile.photoUrl, 'https://example.com/photo.jpg');
      expect(profile.avatarPath, '/local/avatar.png');
    });

    test('tailor role is stored correctly', () {
      const profile = UserProfile(name: 'Master Tailor', role: UserRole.tailor);
      expect(profile.role, UserRole.tailor);
    });
  });

  group('UserProfile.genderLabel', () {
    test('male returns Male', () {
      const profile = UserProfile(name: 'Test', gender: Gender.male);
      expect(profile.genderLabel, 'Male');
    });

    test('female returns Female', () {
      const profile = UserProfile(name: 'Test', gender: Gender.female);
      expect(profile.genderLabel, 'Female');
    });

    test('other returns Other', () {
      const profile = UserProfile(name: 'Test', gender: Gender.other);
      expect(profile.genderLabel, 'Other');
    });
  });

  group('UserRole', () {
    test('has customer, tailor, owner, delivery roles', () {
      expect(UserRole.values.length, 4);
    });

    test('can be looked up by name — customer', () {
      expect(
        UserRole.values.firstWhere((r) => r.name == 'customer'),
        UserRole.customer,
      );
    });

    test('can be looked up by name — tailor', () {
      expect(
        UserRole.values.firstWhere((r) => r.name == 'tailor'),
        UserRole.tailor,
      );
    });

    test('can be looked up by name — owner', () {
      expect(
        UserRole.values.firstWhere((r) => r.name == 'owner'),
        UserRole.owner,
      );
    });

    test('defaults to customer when role name is unknown', () {
      final role = UserRole.values.firstWhere(
        (r) => r.name == 'admin',
        orElse: () => UserRole.customer,
      );
      expect(role, UserRole.customer);
    });
  });

  group('Gender', () {
    test('has exactly three values', () {
      expect(Gender.values.length, 3);
    });
  });
}
