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
  Future<void> saveDressDesignerMeasurements(Map<String, String> cmMap) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _savedDressMeasurementsCm = Map<String, String>.from(cmMap);
    notifyListeners();
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
