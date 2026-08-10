import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement.dart';
import '../models/stitching_rate.dart';
import '../models/phone_registry_entry.dart';
import '../models/user_profile.dart';
import 'measurement_unit.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Auth ─────────────────────────────────────────────────────────────────
  bool get isLoggedIn => _auth.currentUser != null;
  bool _hasCompletedSetup = false;
  bool get hasCompletedSetup => _hasCompletedSetup;

  void markSetupComplete() {
    _hasCompletedSetup = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _profile = null;
    _rates = [];
    _hasCompletedSetup = false;
    _measurementUnit = MeasurementUnit.cm;
    _measurements = null;
    _savedDressMeasurementsCm = {};
    notifyListeners();
  }

  // ── Profile & Role ────────────────────────────────────────────────────────
  UserProfile? _profile;
  UserProfile? get profile => _profile;
  UserRole get role => _profile?.role ?? UserRole.customer;

  void setProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  String get displayName => _profile?.name ?? _auth.currentUser?.displayName ?? 'Guest';

  // ── Measurement display (stored values are always cm) ─────────────────────
  MeasurementUnit _measurementUnit = MeasurementUnit.cm;
  MeasurementUnit get measurementUnit => _measurementUnit;

  /// Updates display unit and persists on `users/{uid}` when signed in.
  Future<void> setMeasurementUnit(MeasurementUnit unit) async {
    if (_measurementUnit == unit) return;
    _measurementUnit = unit;
    notifyListeners();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set(
        {'measurementUnit': unit.storageName},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  String get initials {
    final name = displayName;
    if (name.isEmpty || name == 'Guest') return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Looks up a display name by [e164] phone before Firebase signs the user in.
  /// Requires a `phoneNumber` field on `users` docs (see [saveUserProfile]) and
  /// Firestore rules that allow this query for unauthenticated clients (or it returns null).
  Future<String?> lookupDisplayNameByPhoneForSignIn(String e164) async {
    try {
      final snap = await _db
          .collection('users')
          .where('phoneNumber', isEqualTo: e164)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final name = snap.docs.first.data()['name'] as String?;
      final t = name?.trim() ?? '';
      if (t.length < 2 || t == 'User' || t == 'Guest') return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  /// Load user profile from Firestore after login
  Future<void> loadUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _profile = UserProfile(
          name: data['name'] ?? '',
          email: data['email'],
          photoUrl: data['photoUrl'],
          dateOfBirth: data['dateOfBirth'] as String?,
          heightCm: data['heightCm'] is num
              ? (data['heightCm'] as num).toDouble()
              : null,
          weightKg: data['weightKg'] is num
              ? (data['weightKg'] as num).toDouble()
              : null,
          fitPreference: data['fitPreference'] as String?,
          preferredLanguage:
              (data['preferredLanguage'] as String?)?.trim().isNotEmpty == true
                  ? data['preferredLanguage'] as String
                  : 'English',
          notifySms: data['notifySms'] is bool ? data['notifySms'] as bool : true,
          notifyApp: data['notifyApp'] is bool ? data['notifyApp'] as bool : true,
          notifyEmail:
              data['notifyEmail'] is bool ? data['notifyEmail'] as bool : false,
          age: data['age'],
          role: UserRole.values.firstWhere(
            (r) => r.name == (data['role'] ?? 'customer'),
            orElse: () => UserRole.customer,
          ),
          notifyWhatsApp: data['notifyWhatsApp'] is bool
              ? data['notifyWhatsApp'] as bool
              : true,
          payoutUpiId: data['payoutUpiId'] as String?,
          deliveryAddress: _parseUserDeliveryAddress(data['deliveryAddress']),
        );
        _hasCompletedSetup = data['setupComplete'] ?? false;
        _measurementUnit =
            measurementUnitFromStorage(data['measurementUnit']) ??
                MeasurementUnit.cm;
        _savedDressMeasurementsCm = _parseDressDesignerMeasurementsMap(
            data['dressDesignerMeasurements']);
        notifyListeners();
      }
    } catch (_) {}
  }

  static String? _parseUserDeliveryAddress(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final t = raw.trim();
      return t.isEmpty ? null : t;
    }
    if (raw is List) {
      final t = raw.map((e) => e.toString()).join('\n').trim();
      return t.isEmpty ? null : t;
    }
    final t = raw.toString().trim();
    return t.isEmpty ? null : t;
  }

  /// Updates profile delivery address and persists to `users/{uid}`.
  Future<void> setProfileDeliveryAddress(String? raw) async {
    final p = _profile;
    if (p == null) return;
    final t = raw?.trim() ?? '';
    setProfile(UserProfile(
      name: p.name,
      gender: p.gender,
      age: p.age,
      role: p.role,
      avatarPath: p.avatarPath,
      email: p.email,
      photoUrl: p.photoUrl,
      notifyWhatsApp: p.notifyWhatsApp,
      payoutUpiId: p.payoutUpiId,
      deliveryAddress: t.isEmpty ? null : t,
    ));
    await saveUserProfile();
  }

  /// Keys used by [DressDesignerScreen] — values are cm as strings (e.g. `"86.0"`).
  static const List<String> dressDesignerMeasurementKeys = [
    'Chest',
    'Waist',
    'Hip',
    'Shoulder',
    'Length',
    'Sleeve Length',
  ];

  Map<String, String> _parseDressDesignerMeasurementsMap(Object? raw) {
    final out = <String, String>{};
    if (raw is! Map) return out;
    for (final e in raw.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v == null) continue;
      out[k] = v is num ? v.toString() : v.toString();
    }
    return out;
  }

  Map<String, String> _savedDressMeasurementsCm = {};

  /// Last saved dress-designer measurements (cm), from Firestore `dressDesignerMeasurements`.
  Map<String, String> get savedDressMeasurementsCm =>
      Map.unmodifiable(_savedDressMeasurementsCm);

  String? get currentUserId => _auth.currentUser?.uid;

  /// Persists the six designer fields (cm) on `users/{uid}` for next login.
  Future<void> saveDressDesignerMeasurements(
    Map<String, String> cmMap, {
    bool notify = true,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _savedDressMeasurementsCm = Map<String, String>.from(cmMap);

    if (notify) {
      notifyListeners();
    }

    try {
      await _db.collection('users').doc(uid).set(
        {'dressDesignerMeasurements': cmMap},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Map<String, String> _bodyScanToDressDesignerCm(BodyMeasurements bm) {
    String f(double? x) => (x ?? 0).toStringAsFixed(1);
    return {
      if (bm.chest != null) 'Chest': f(bm.chest),
      if (bm.waist != null) 'Waist': f(bm.waist),
      if (bm.hips != null) 'Hip': f(bm.hips),
      if (bm.shoulder != null) 'Shoulder': f(bm.shoulder),
      if (bm.armLength != null) 'Sleeve Length': f(bm.armLength),
    };
  }

  Future<void> _mergeBodyScanIntoSavedDressMeasurements(
      BodyMeasurements bm) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final merged = Map<String, String>.from(_savedDressMeasurementsCm);
    for (final e in _bodyScanToDressDesignerCm(bm).entries) {
      merged[e.key] = e.value;
    }
    for (final k in dressDesignerMeasurementKeys) {
      merged.putIfAbsent(k, () => '0.0');
    }
    await saveDressDesignerMeasurements(merged);
  }

  /// Persists [photoUrl] on the signed-in user and refreshes in-memory [profile].
  Future<void> updatePhotoUrl(String photoUrl) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'photoUrl': photoUrl},
      SetOptions(merge: true),
    );
    if (_profile != null) {
      setProfile(UserProfile(
        name: _profile!.name,
        gender: _profile!.gender,
        age: _profile!.age,
        role: _profile!.role,
        email: _profile!.email ?? _auth.currentUser?.email,
        photoUrl: photoUrl,
        avatarPath: _profile!.avatarPath,
        notifyWhatsApp: _profile!.notifyWhatsApp,
        payoutUpiId: _profile!.payoutUpiId,
        deliveryAddress: _profile!.deliveryAddress,
      ));
    } else {
      notifyListeners();
    }
  }

  /// Save user profile to Firestore
  Future<void> saveUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _profile == null) return;
    await _db.collection('users').doc(uid).set({
      'name': _profile!.name,
      'email': _profile!.email ?? _auth.currentUser?.email,
      'photoUrl': _profile!.photoUrl ?? _auth.currentUser?.photoURL,
      'phoneNumber': _auth.currentUser?.phoneNumber,
      'age': _profile!.age,
      'role': _profile!.role.name,
      'setupComplete': _hasCompletedSetup,
      'measurementUnit': _measurementUnit.storageName,
      'dateOfBirth': (_profile!.dateOfBirth?.trim().isNotEmpty == true)
          ? _profile!.dateOfBirth!.trim()
          : FieldValue.delete(),
      'heightCm': _profile!.heightCm ?? FieldValue.delete(),
      'weightKg': _profile!.weightKg ?? FieldValue.delete(),
      'fitPreference': (_profile!.fitPreference?.trim().isNotEmpty == true)
          ? _profile!.fitPreference!.trim()
          : FieldValue.delete(),
      'preferredLanguage': _profile!.preferredLanguage,
      'notifySms': _profile!.notifySms,
      'notifyApp': _profile!.notifyApp,
      'notifyEmail': _profile!.notifyEmail,
      'notifyWhatsApp': _profile!.notifyWhatsApp,
      'payoutUpiId': (_profile!.payoutUpiId?.trim().isNotEmpty == true)
          ? _profile!.payoutUpiId!.trim()
          : FieldValue.delete(),
      'deliveryAddress': (_profile!.deliveryAddress?.trim().isNotEmpty == true)
          ? _profile!.deliveryAddress!.trim()
          : FieldValue.delete(),
    }, SetOptions(merge: true));
    await syncPhoneRegistryForCurrentUser();
  }
  Future<void> updateCustomerBasicProfile({
    required String name,
    String? email,
    String? dateOfBirth,
    double? heightCm,
    double? weightKg,
    String? fitPreference,
    String? preferredLanguage,
    bool? notifySms,
    bool? notifyWhatsApp,
    bool? notifyApp,
    bool? notifyEmail,
  }) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;

  final current = _profile;

  final updatedProfile = UserProfile(
    name: name.trim(),
    gender: current?.gender ?? Gender.female,
    age: current?.age ?? 0,
    role: current?.role ?? UserRole.customer,
    avatarPath: current?.avatarPath,
    email: email?.trim().isNotEmpty == true ? email!.trim() : null,
    photoUrl: current?.photoUrl,
    dateOfBirth:
        dateOfBirth?.trim().isNotEmpty == true ? dateOfBirth!.trim() : null,
    heightCm: heightCm,
    weightKg: weightKg,
    fitPreference:
        fitPreference?.trim().isNotEmpty == true ? fitPreference!.trim() : null,
    preferredLanguage:
        preferredLanguage?.trim().isNotEmpty == true
            ? preferredLanguage!.trim()
            : current?.preferredLanguage ?? 'English',
    notifySms: notifySms ?? current?.notifySms ?? true,
    notifyWhatsApp: notifyWhatsApp ?? current?.notifyWhatsApp ?? true,
    notifyApp: notifyApp ?? current?.notifyApp ?? true,
    notifyEmail: notifyEmail ?? current?.notifyEmail ?? false,
    payoutUpiId: current?.payoutUpiId,
    deliveryAddress: current?.deliveryAddress,
  );

  setProfile(updatedProfile);

  await _db.collection('users').doc(uid).set({
    'name': updatedProfile.name,
    'email': updatedProfile.email ?? FieldValue.delete(),
    'dateOfBirth': updatedProfile.dateOfBirth ?? FieldValue.delete(),
    'heightCm': updatedProfile.heightCm ?? FieldValue.delete(),
    'weightKg': updatedProfile.weightKg ?? FieldValue.delete(),
    'fitPreference': updatedProfile.fitPreference ?? FieldValue.delete(),
    'preferredLanguage': updatedProfile.preferredLanguage,
    'notifySms': updatedProfile.notifySms,
    'notifyWhatsApp': updatedProfile.notifyWhatsApp,
    'notifyApp': updatedProfile.notifyApp,
    'notifyEmail': updatedProfile.notifyEmail,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  final phone = _auth.currentUser?.phoneNumber;
  if (phone != null && phone.trim().isNotEmpty) {
    final accountId = await fetchAccountIdForMobile(phone.trim());

    if (accountId != null && accountId.isNotEmpty) {
      final profiles = await fetchActiveProfilesForAccount(accountId);

      Map<String, dynamic>? customerProfile;
      for (final profile in profiles) {
        final role = (profile['role'] ?? '').toString();
        if (role == 'customer') {
          customerProfile = profile;
          break;
        }
      }

      final customerProfileId =
          customerProfile?['profileId']?.toString() ??
              customerProfile?['docId']?.toString();

      if (customerProfileId != null && customerProfileId.trim().isNotEmpty) {
        await _db
            .collection('accounts')
            .doc(accountId)
            .collection('profiles')
            .doc(customerProfileId)
            .set({
          'displayName': updatedProfile.name,
          'name': updatedProfile.name,
          'email': updatedProfile.email ?? FieldValue.delete(),
          'dateOfBirth': updatedProfile.dateOfBirth ?? FieldValue.delete(),
          'heightCm': updatedProfile.heightCm ?? FieldValue.delete(),
          'weightKg': updatedProfile.weightKg ?? FieldValue.delete(),
          'fitPreference': updatedProfile.fitPreference ?? FieldValue.delete(),
          'preferredLanguage': updatedProfile.preferredLanguage,
          'notifySms': updatedProfile.notifySms,
          'notifyWhatsApp': updatedProfile.notifyWhatsApp,
          'notifyApp': updatedProfile.notifyApp,
          'notifyEmail': updatedProfile.notifyEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
}
  /// Firestore-safe mobile lookup id.
  /// Example: +919876543210 -> m_919876543210
  static String mobileAccountDocId(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    return 'm_$digits';
  }

  /// Ensures one generated accountId exists for the given mobile number.
  ///
  /// Structure:
  /// mobile_accounts/{safeMobileKey}
  ///   -> accountId
  ///
  /// accounts/{accountId}
  ///   -> mobileE164 and account-level fields
  Future<String> ensureAccountForMobile(String mobileE164) async {
    final safeMobileKey = mobileAccountDocId(mobileE164);
    final lookupRef = _db.collection('mobile_accounts').doc(safeMobileKey);

    final existingLookup = await lookupRef.get();
    if (existingLookup.exists) {
      final data = existingLookup.data();
      final accountId = data?['accountId']?.toString();
      if (accountId != null && accountId.trim().isNotEmpty) {
        await _db.collection('accounts').doc(accountId).set({
          'mobileE164': mobileE164,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return accountId;
      }
    }

    final accountRef = _db.collection('accounts').doc();
    final accountId = accountRef.id;

    await accountRef.set({
      'accountId': accountId,
      'mobileE164': mobileE164,
      'status': 'active',
      'totalProfiles': 0,
      'defaultProfileId': null,
      'activeProfileId': null,
      'lastSelectedProfileId': null,
      'notifyWhatsApp': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await lookupRef.set({
      'mobileE164': mobileE164,
      'accountId': accountId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return accountId;
  }

  /// Ensures the default Customer profile exists under:
  /// accounts/{accountId}/profiles/{profileId}
  ///
  /// Customer profile is always the default profile in SuiSakhi.
  Future<String> ensureDefaultCustomerProfile({
    required String accountId,
    required String mobileE164,
    String? displayName,
  }) async {
    final profilesRef =
        _db.collection('accounts').doc(accountId).collection('profiles');

    final existingCustomer = await profilesRef
        .where('role', isEqualTo: 'customer')
        .where('isDefaultProfile', isEqualTo: true)
        .limit(1)
        .get();

    if (existingCustomer.docs.isNotEmpty) {
      final profileId = existingCustomer.docs.first.id;

      await _db.collection('accounts').doc(accountId).set({
        'defaultProfileId': profileId,
        'activeProfileId': profileId,
        'lastSelectedProfileId': profileId,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await profilesRef.doc(profileId).set({
        'lastSelectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return profileId;
    }

    final profileRef = profilesRef.doc();
    final profileId = profileRef.id;

    final cleanedName = displayName?.trim();
    final customerName =
        cleanedName != null && cleanedName.isNotEmpty ? cleanedName : 'Customer';

    await profileRef.set({
      'profileId': profileId,
      'accountId': accountId,
      'mobileE164': mobileE164,
      'profileType': 'customer',
      'role': 'customer',
      'partnerType': null,
      'displayName': customerName,
      'profilePhotoUrl': null,
      'status': 'active',
      'isDefaultProfile': true,
      'lastSelectedAt': FieldValue.serverTimestamp(),
      'relationship': 'self',
      'gender': 'female',
      'dateOfBirth': null,
      'height': null,
      'weight': null,
      'favoriteStyles': <String>[],
      'fabricPreferences': <String>[],
      'colorPreferences': <String>[],
      'partnerProfileId': null,
      'shopName': null,
      'serviceArea': <String>[],
      'isAvailable': null,
      'payoutUpiId': null,
      'approvalStatus': null,
      'approvedAt': null,
      'approvedBy': null,
      'rejectionReason': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('accounts').doc(accountId).set({
      'defaultProfileId': profileId,
      'activeProfileId': profileId,
      'lastSelectedProfileId': profileId,
      'totalProfiles': FieldValue.increment(1),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return profileId;
  }

  /// Ensures an active Customer profile exists for the account.
  ///
  /// This is a self-healing method for older accounts that may have been
  /// created as partner-only before the Customer-first architecture was finalized.
  Future<String> ensureCustomerProfileExistsForAccount({
    required String accountId,
    required String mobileE164,
    String? displayName,
  }) async {
    final profilesRef = _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles');

    final existingCustomerSnap = await profilesRef
        .where('role', isEqualTo: 'customer')
        .limit(1)
        .get();

    if (existingCustomerSnap.docs.isNotEmpty) {
      final doc = existingCustomerSnap.docs.first;
      final data = doc.data();

      await doc.reference.set({
        'status': 'active',
        'isDefaultProfile': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final existingProfileId =
          (data['profileId'] ?? doc.id).toString().trim();

      return existingProfileId.isNotEmpty ? existingProfileId : doc.id;
    }

    final customerProfileId = profilesRef.doc().id;
    final safeDisplayName =
        displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'Customer';

    await profilesRef.doc(customerProfileId).set({
      'profileId': customerProfileId,
      'accountId': accountId,
      'role': 'customer',
      'profileType': 'customer',
      'displayName': safeDisplayName,
      'name': safeDisplayName,
      'mobileE164': mobileE164,
      'status': 'active',
      'isDefaultProfile': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return customerProfileId;
  }
  /// Ensures generated accountId and default Customer profile exist
  /// after successful Firebase login.
  ///
  /// This is foundation logic only. It does not change navigation yet.
  Future<void> ensureAccountAndDefaultProfileAfterLogin({
    required String uid,
    required String mobileE164,
    String? displayName,
  }) async {
    final accountId = await ensureAccountForMobile(mobileE164);

    final customerProfileId = await ensureCustomerProfileExistsForAccount(
      accountId: accountId,
      mobileE164: mobileE164,
      displayName: displayName,
    );

    final activeProfiles = await fetchActiveProfilesForAccount(accountId);

    await _db.collection('accounts').doc(accountId).set({
      'defaultProfileId': customerProfileId,
      'totalProfiles': activeProfiles.length,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(uid).set({
      'accountId': accountId,
      'defaultProfileId': customerProfileId,
      'mobileE164': mobileE164,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Looks up generated accountId from mobile_accounts/{safeMobileKey}.
  Future<String?> fetchAccountIdForMobile(String mobileE164) async {
    try {
      final safeMobileKey = mobileAccountDocId(mobileE164);
      final doc = await _db.collection('mobile_accounts').doc(safeMobileKey).get();

      if (!doc.exists) return null;

      final data = doc.data();
      final accountId = data?['accountId']?.toString().trim();

      if (accountId == null || accountId.isEmpty) return null;
      return accountId;
    } catch (_) {
      return null;
    }
  }

  /// Fetches active profiles for ProfileSelectionScreen.
  ///
  /// Customer profile is always sorted first.
  Future<List<Map<String, dynamic>>> fetchActiveProfilesForAccount(
    String accountId,
  ) async {
    try {
      final snap = await _db
          .collection('accounts')
          .doc(accountId)
          .collection('profiles')
          .where('status', isEqualTo: 'active')
          .get();

      final profiles = snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          ...data,
          'profileId': data['profileId'] ?? doc.id,
          'docId': doc.id,
        };
      }).toList();

      profiles.sort((a, b) {
        final aRole = (a['role'] ?? '').toString();
        final bRole = (b['role'] ?? '').toString();

        if (aRole == 'customer' && bRole != 'customer') return -1;
        if (aRole != 'customer' && bRole == 'customer') return 1;

        final aName = (a['displayName'] ?? a['shopName'] ?? '').toString();
        final bName = (b['displayName'] ?? b['shopName'] ?? '').toString();

        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

      return profiles;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Saves the selected profile as active profile for the account.
  Future<void> setActiveProfileForAccount({
    required String accountId,
    required String profileId,
  }) async {
    await _db.collection('accounts').doc(accountId).set({
      'activeProfileId': profileId,
      'lastSelectedProfileId': profileId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles')
        .doc(profileId)
        .set({
      'lastSelectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).set({
        'accountId': accountId,
        'activeProfileId': profileId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Converts a profile document role into existing UserRole enum.
  UserRole roleFromProfileData(Map<String, dynamic> profileData) {
    final role = (profileData['role'] ?? 'customer').toString();

    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'tailor':
        return UserRole.tailor;
      case 'delivery':
      case 'delivery_partner':
        return UserRole.delivery;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }
  /// Firestore doc id: E.164 digits only (e.g. 917066187793).
  static String phoneRegistryDocId(String e164) =>
      e164.replaceAll(RegExp(r'\D'), '');

  /// Best-effort read before OTP (unauthenticated get allowed by rules).
  Future<PhoneRegistryEntry?> fetchPhoneRegistry(String e164) async {
    try {
      final id = phoneRegistryDocId(e164);
      if (id.length < 10) return null;
      final doc = await _db.collection('phoneRegistry').doc(id).get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      return PhoneRegistryEntry(
        uid: d['uid'] as String? ?? '',
        roleName: (d['role'] as String?)?.trim().isNotEmpty == true
            ? (d['role'] as String).trim()
            : 'customer',
        displayName: d['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Keeps `phoneRegistry` aligned with the signed-in user's phone + role (last write wins).
  Future<void> syncPhoneRegistryForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _profile == null) return;
    final phone = _auth.currentUser?.phoneNumber;
    if (phone == null || phone.trim().isEmpty) return;
    final id = phoneRegistryDocId(phone);
    if (id.length < 10) return;
    try {
      final displayName = _profile!.name.trim().isEmpty
          ? (_auth.currentUser?.displayName?.trim().isNotEmpty == true
              ? _auth.currentUser!.displayName!.trim()
              : 'Customer')
          : _profile!.name.trim();
      await _db.collection('phoneRegistry').doc(id).set({
        'uid': uid,
        'role': _profile!.role.name,
        'name': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Role Management (owner enrolls tailors) ───────────────────────────────

  /// Normalizes a phone string to E.164-style (digits + leading +). Matches login OTP (+91 default for 10-digit IN).
  static String? normalizePhoneE164(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return null;
    if (t.startsWith('+')) return t;
    if (RegExp(r'^\d{10}$').hasMatch(t)) return '+91$t';
    return '+$t';
  }

  /// Checks Firestore config for owner/tailor/delivery by email and tailor by phone (OTP).
  /// Returns [UserRole.owner], [UserRole.tailor], [UserRole.delivery], or null (= default customer).
  Future<UserRole?> getRoleFromConfig(String? email, {String? phoneE164}) async {
    try {
      final doc = await _db.collection('config').doc('admin').get();
      final data = doc.data() ?? {};
      final ownerEmails = List<String>.from(data['ownerEmails'] ?? []);
      final tailorEmails = List<String>.from(data['tailorEmails'] ?? []);
      final deliveryEmails = List<String>.from(data['deliveryEmails'] ?? []);
      final tailorPhones = <String>{};
      for (final x in List<dynamic>.from(data['tailorPhones'] ?? [])) {
        final n = normalizePhoneE164(x.toString());
        if (n != null) tailorPhones.add(n);
      }

      final em = email?.trim().toLowerCase();
      if (em != null && em.isNotEmpty) {
        if (ownerEmails.contains(em)) return UserRole.owner;
        if (tailorEmails.contains(em)) return UserRole.tailor;
        if (deliveryEmails.contains(em)) return UserRole.delivery;
      }

      final p = normalizePhoneE164(phoneE164);
      if (p != null && tailorPhones.contains(p)) return UserRole.tailor;
    } catch (_) {}
    return null;
  }
/// Code Change 02-Jul-2026

/// Lookup Fashion Partner by phone number.
Future<Map<String, dynamic>?> lookupPartnerByPhone(String phoneE164) async {
  try {
    final phone = normalizePhoneE164(phoneE164);
    if (phone == null) return null;

    final snap = await _db
        .collection('partner_users')
        .where('phone', isEqualTo: phone)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return null;
    }

    return snap.docs.first.data();
  } catch (e) {
    debugPrint('Partner lookup failed: $e');
    return null;
  }
}

  /// Bootstrap: register an email as the shop owner (first-time setup).
  Future<void> enrollOwner(String email) async {
    await _db.collection('config').doc('admin').set({
      'ownerEmails': FieldValue.arrayUnion([email.toLowerCase()]),
    }, SetOptions(merge: true));
  }

  List<Map<String, dynamic>> _parseTailorProfilesMap(Map<String, dynamic> data) {
    final out = <Map<String, dynamic>>[];
    for (final e in List<dynamic>.from(data['tailorProfiles'] ?? [])) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  /// Owner: enroll tailor with display name + mobile (required). Optional [loginEmail]
  /// for Google sign-in; it is not shown in the owner list UI.
  Future<void> enrollTailorWithProfile({
    required String firstName,
    required String lastName,
    required String phoneRaw,
    String? loginEmail,
  }) async {
    final mobile = normalizePhoneE164(phoneRaw);
    if (mobile == null) return;
    final ref = _db.collection('config').doc('admin');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final profiles = _parseTailorProfilesMap(data);
      profiles.removeWhere((p) => p['mobile'] == mobile);
      profiles.add({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'mobile': mobile,
        if (loginEmail != null && loginEmail.trim().isNotEmpty)
          'loginEmail': loginEmail.trim().toLowerCase(),
      });
      final emails = List<String>.from(data['tailorEmails'] ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      final le = loginEmail?.trim().toLowerCase();
      if (le != null && le.isNotEmpty && !emails.contains(le)) {
        emails.add(le);
      }
      final phones = List<String>.from(data['tailorPhones'] ?? []);
      if (!phones.contains(mobile)) {
        phones.add(mobile);
      }
      tx.set(
        ref,
        {
          'tailorProfiles': profiles,
          'tailorEmails': emails,
          'tailorPhones': phones,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Owner: enroll a new tailor by their Google email only (legacy).
  Future<void> enrollTailor(String email) async {
    await _db.collection('config').doc('admin').set({
      'tailorEmails': FieldValue.arrayUnion([email.toLowerCase()]),
    }, SetOptions(merge: true));
  }

  /// Owner: enroll a tailor who signs in with Phone / OTP only (legacy).
  Future<void> enrollTailorPhone(String phoneRaw) async {
    final n = normalizePhoneE164(phoneRaw);
    if (n == null) return;
    await _db.collection('config').doc('admin').set({
      'tailorPhones': FieldValue.arrayUnion([n]),
    }, SetOptions(merge: true));
  }

  /// Owner: remove tailor by email (syncs [tailorProfiles] + phones).
  Future<void> removeTailor(String email) async {
    final em = email.toLowerCase();
    final ref = _db.collection('config').doc('admin');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final profiles = _parseTailorProfilesMap(data);
      String? mobileToDrop;
      profiles.removeWhere((p) {
        if ((p['loginEmail'] as String?)?.toLowerCase() == em) {
          mobileToDrop = p['mobile'] as String?;
          return true;
        }
        return false;
      });
      var emails = List<String>.from(data['tailorEmails'] ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      emails.remove(em);
      var phones = List<String>.from(data['tailorPhones'] ?? []);
      final drop = mobileToDrop != null ? normalizePhoneE164(mobileToDrop) : null;
      if (drop != null) {
        phones = phones
            .where((p) => normalizePhoneE164(p) != drop)
            .toList();
      }
      tx.set(
        ref,
        {
          'tailorProfiles': profiles,
          'tailorEmails': emails,
          'tailorPhones': phones,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Owner: remove tailor by phone (syncs [tailorProfiles] + emails).
  Future<void> removeTailorPhone(String phoneRaw) async {
    final n = normalizePhoneE164(phoneRaw);
    if (n == null) return;
    final ref = _db.collection('config').doc('admin');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final profiles = _parseTailorProfilesMap(data);
      String? emailToDrop;
      profiles.removeWhere((p) {
        if (p['mobile'] == n) {
          emailToDrop = p['loginEmail'] as String?;
          return true;
        }
        return false;
      });
      var emails = List<String>.from(data['tailorEmails'] ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      if (emailToDrop != null) {
        emails.remove(emailToDrop!.toLowerCase());
      }
      var phones = List<String>.from(data['tailorPhones'] ?? []);
      phones = phones.where((p) => normalizePhoneE164(p) != n).toList();
      tx.set(
        ref,
        {
          'tailorProfiles': profiles,
          'tailorEmails': emails,
          'tailorPhones': phones,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Owner: enroll a delivery partner by their Google email.
  Future<void> enrollDeliveryPartner(String email) async {
    await _db.collection('config').doc('admin').set({
      'deliveryEmails': FieldValue.arrayUnion([email.toLowerCase()]),
    }, SetOptions(merge: true));
    await _db.collection('subscriptions').doc(email.toLowerCase()).set({
      'email': email.toLowerCase(),
      'active': true,
      'subscribedAt': FieldValue.serverTimestamp(),
      'subscribedUntil': DateTime.now().add(const Duration(days: 30)),
      'totalDeliveries': 0,
    }, SetOptions(merge: true));
  }

  /// Owner: remove a delivery partner.
  Future<void> removeDeliveryPartner(String email) async {
    await _db.collection('config').doc('admin').set({
      'deliveryEmails': FieldValue.arrayRemove([email.toLowerCase()]),
    }, SetOptions(merge: true));
    await _db.collection('subscriptions').doc(email.toLowerCase())
        .update({'active': false});
  }

  /// Owner: save delivery settings (fee per order, subscription fee).
  Future<void> saveDeliverySettings({
    required double feePerOrder,
    required double subscriptionFee,
  }) async {
    await _db.collection('config').doc('delivery').set({
      'feePerOrder': feePerOrder,
      'subscriptionFee': subscriptionFee,
    }, SetOptions(merge: true));
  }

  /// Fetch delivery settings.
  Future<Map<String, double>> getDeliverySettings() async {
    try {
      final doc = await _db.collection('config').doc('delivery').get();
      final data = doc.data() ?? {};
      return {
        'feePerOrder': (data['feePerOrder'] as num?)?.toDouble() ?? 50.0,
        'subscriptionFee': (data['subscriptionFee'] as num?)?.toDouble() ?? 500.0,
      };
    } catch (_) {
      return {'feePerOrder': 50.0, 'subscriptionFee': 500.0};
    }
  }

  /// Update order status in Firestore.
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({'status': status});
  }

  // ── Body Measurements (from AI scan) ─────────────────────────────────────
  BodyMeasurements? _measurements;
  BodyMeasurements? get measurements => _measurements;

  void setMeasurements(BodyMeasurements measurements) {
    _measurements = measurements;
    notifyListeners();
    unawaited(_mergeBodyScanIntoSavedDressMeasurements(measurements));
  }

  // ── Stitching Rates (set by Owner, stored in Firestore) ───────────────────
  List<StitchingRate> _rates = [];
  List<StitchingRate> get rates => List.unmodifiable(_rates);

  /// Load rates from Firestore (call once on app start or login)
  /// Sanitises a dress type string for use as a Firestore document ID.
  /// Firestore does not allow '/' in document IDs (treated as path separator).
  static String _rateDocId(String dressType) =>
      dressType.replaceAll('/', '_');

  Future<void> loadRates() async {
    try {
      final snap = await _db.collection('rates').get();
      if (snap.docs.isEmpty) {
        await _seedDefaultRates();
      } else {
        _rates = snap.docs.map((d) => StitchingRate(
          dressType: d['dressType'] as String,
          basePrice: (d['basePrice'] as num).toDouble(),
          notes: d['notes'] as String?,
        )).toList();
        notifyListeners();
      }
    } catch (_) {
      // Fallback to defaults if Firestore unavailable
      _loadDefaultRates();
    }
  }

  void _loadDefaultRates() {
    _rates = [
      StitchingRate(dressType: 'Kurti', basePrice: 350),
      StitchingRate(dressType: 'Blouse', basePrice: 200),
      StitchingRate(dressType: 'Salwar Suit', basePrice: 600),
      StitchingRate(dressType: 'Lehenga', basePrice: 1200),
      StitchingRate(dressType: 'Gown', basePrice: 1500),
      StitchingRate(dressType: 'Kurta', basePrice: 400),
      StitchingRate(dressType: 'Shirt', basePrice: 300),
      StitchingRate(dressType: 'Sherwani', basePrice: 2000),
      StitchingRate(dressType: 'Saree Blouse', basePrice: 250),
      StitchingRate(dressType: 'Trouser/Pant', basePrice: 350),
    ];
    notifyListeners();
  }

  Future<void> _seedDefaultRates() async {
    _loadDefaultRates();
    final batch = _db.batch();
    for (final r in _rates) {
      final ref = _db.collection('rates').doc(_rateDocId(r.dressType));
      batch.set(ref, {
        'dressType': r.dressType,
        'basePrice': r.basePrice,
        'notes': r.notes,
      });
    }
    await batch.commit();
  }

  Future<void> updateRate(String dressType, double price, {String? notes}) async {
    final idx = _rates.indexWhere((r) => r.dressType == dressType);
    if (idx != -1) {
      _rates[idx].basePrice = price;
      _rates[idx].notes = notes;
    } else {
      _rates.add(StitchingRate(dressType: dressType, basePrice: price, notes: notes));
    }
    notifyListeners();
    await _db.collection('rates').doc(_rateDocId(dressType)).set({
      'dressType': dressType,
      'basePrice': price,
      'notes': notes,
    }, SetOptions(merge: true));
  }

  Future<void> deleteRate(String dressType) async {
    _rates.removeWhere((r) => r.dressType == dressType);
    notifyListeners();
    await _db.collection('rates').doc(_rateDocId(dressType)).delete();
  }
}
