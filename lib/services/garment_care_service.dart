import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address_details.dart';
import '../models/garment_care_domain.dart';
import '../models/payment_models.dart';

class GarmentCareService {
  GarmentCareService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<({String accountId, String profileId})>
  customerContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to request Garment Care.');
    final user = await _db.collection('users').doc(uid).get();
    final userData = user.data() ?? const <String, dynamic>{};
    final accountId = (userData['accountId'] ?? '').toString().trim();
    final profileId =
        (userData['activeProfileId'] ?? userData['defaultProfileId'] ?? '')
            .toString()
            .trim();
    if (accountId.isEmpty || profileId.isEmpty) {
      throw StateError('Your active Customer profile could not be found.');
    }
    final profile = await _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles')
        .doc(profileId)
        .get();
    if (!profile.exists ||
        profile.data()?['role'] != 'customer' ||
        profile.data()?['status'] != 'active') {
      throw StateError('Switch to an active Customer profile to continue.');
    }
    return (accountId: accountId, profileId: profileId);
  }

  static Future<List<Map<String, dynamic>>> customerAddresses() async {
    final owner = await customerContext();
    final snapshot = await _db
        .collection('accounts')
        .doc(owner.accountId)
        .collection('addresses')
        .where('status', isEqualTo: 'active')
        .get();
    final addresses = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final details = AddressDetails.fromMap(data);
          return <String, dynamic>{
            ...data,
            'addressId': doc.id,
            'formattedAddress': details.formattedAddress,
          };
        })
        .toList(growable: false);
    addresses.sort(
      (a, b) => (a['isDefault'] == true ? 0 : 1).compareTo(
        b['isDefault'] == true ? 0 : 1,
      ),
    );
    return addresses;
  }

  static Future<Map<String, dynamic>?> customerCartDraft() async {
    final owner = await customerContext();
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to restore your care cart.');
    final snapshot = await _db
        .collection('accounts')
        .doc(owner.accountId)
        .collection('profiles')
        .doc(owner.profileId)
        .collection('garment_care_cart_drafts')
        .doc('current')
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data['customerUid'] != uid) {
      return null;
    }
    return data;
  }

  static Future<bool> clearCustomerCartDraftIfAlreadySubmitted(
    Map<String, dynamic> draft,
  ) async {
    try {
      final owner = await customerContext();
      final uid = _auth.currentUser?.uid;
      final updatedAt = draft['updatedAt'];
      final draftItems = (draft['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (uid == null || updatedAt is! Timestamp || draftItems.isEmpty) {
        return false;
      }

      final expectedItems = <String, int>{};
      var expectedCount = 0;
      for (final item in draftItems) {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        if (quantity < 1) return false;
        final signature = _cartDraftItemSignature(item);
        expectedItems.update(
          signature,
          (existingQuantity) => existingQuantity + quantity,
          ifAbsent: () => quantity,
        );
        expectedCount += quantity;
      }

      final orders = await _db
          .collection('garment_care_orders')
          .where('customerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      final ordersByCheckout =
          <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final order in orders.docs) {
        final checkoutId =
            order.data()['cartCheckoutId']?.toString().trim() ?? '';
        final createdAt = order.data()['createdAt'];
        if (checkoutId.isEmpty ||
            createdAt is! Timestamp ||
            createdAt.compareTo(updatedAt) <= 0) {
          continue;
        }
        ordersByCheckout.putIfAbsent(checkoutId, () => []).add(order);
      }

      for (final checkoutOrders in ordersByCheckout.values) {
        final checkoutId =
            checkoutOrders.first.data()['cartCheckoutId']?.toString() ?? '';
        final checkout = await _db
            .collection('garment_care_checkouts')
            .doc(checkoutId)
            .get();
        final checkoutOrderIds =
            (checkout.data()?['orderIds'] as List<dynamic>? ?? const [])
                .map((id) => id.toString())
                .toSet();
        if (!checkout.exists ||
            checkoutOrderIds.length != checkoutOrders.length ||
            !checkoutOrders.every(
              (order) => checkoutOrderIds.contains(order.id),
            )) {
          continue;
        }
        // The checkout stores physical garments once even when one garment
        // has service steps in several parent orders.
        final checkoutItemCount =
            (checkout.data()?['itemCount'] as num?)?.toInt() ?? 0;
        if (checkoutItemCount != expectedCount) continue;

        final submittedGarments = <String, Map<String, dynamic>>{};
        for (final order in checkoutOrders) {
          final items = await order.reference.collection('items').get();
          for (final item in items.docs) {
            final data = item.data();
            final garmentId = data['garmentId']?.toString().trim() ?? '';
            final garmentKey = garmentId.isEmpty
                ? '${order.id}/${item.id}'
                : garmentId;
            final garment = submittedGarments.putIfAbsent(garmentKey, () {
              return {
                ...data,
                'serviceIds': <dynamic>[],
                'serviceSteps': <dynamic>[],
              };
            });
            (garment['serviceIds'] as List<dynamic>).addAll(
              data['serviceIds'] as List<dynamic>? ?? const [],
            );
            (garment['serviceSteps'] as List<dynamic>).addAll(
              data['serviceSteps'] as List<dynamic>? ?? const [],
            );
          }
        }
        final submittedItems = <String, int>{};
        for (final garment in submittedGarments.values) {
          final signature = _cartDraftItemSignature(garment);
          submittedItems.update(
            signature,
            (existingQuantity) => existingQuantity + 1,
            ifAbsent: () => 1,
          );
        }
        final submittedItemCount = submittedGarments.length;
        final sameItems =
            submittedItems.length == expectedItems.length &&
            expectedItems.entries.every(
              (entry) => submittedItems[entry.key] == entry.value,
            );
        if (submittedItemCount != expectedCount || !sameItems) {
          continue;
        }

        final draftRef = _db
            .collection('accounts')
            .doc(owner.accountId)
            .collection('profiles')
            .doc(owner.profileId)
            .collection('garment_care_cart_drafts')
            .doc('current');
        var deleted = false;
        await _db.runTransaction((transaction) async {
          final current = await transaction.get(draftRef);
          final currentData = current.data();
          final currentUpdatedAt = currentData?['updatedAt'];
          if (currentData?['customerUid'] == uid &&
              currentUpdatedAt is Timestamp &&
              currentUpdatedAt.compareTo(updatedAt) == 0) {
            transaction.delete(draftRef);
            deleted = true;
          }
        });
        if (deleted) return true;
      }
    } catch (_) {
      // A reconciliation lookup must never prevent the saved cart from opening.
    }
    return false;
  }

  static String _cartDraftItemSignature(Map<String, dynamic> item) {
    final rawSteps = item['serviceSteps'] as List<dynamic>? ?? const [];
    final serviceSteps =
        rawSteps.whereType<Map>().map((step) {
          final data = Map<String, dynamic>.from(step);
          return {
            'groupCode': (data['groupCode'] ?? '').toString(),
            'serviceId': (data['serviceId'] ?? '').toString(),
          };
        }).toList()..sort((first, second) {
          final groupOrder = first['groupCode']!.compareTo(
            second['groupCode']!,
          );
          return groupOrder != 0
              ? groupOrder
              : first['serviceId']!.compareTo(second['serviceId']!);
        });
    final rawServiceIds = item['serviceIds'] as List<dynamic>? ?? const [];
    final serviceIds = rawServiceIds.map((id) => id.toString()).toList()
      ..sort();
    final rawPhotos = item['conditionPhotoPaths'] as List<dynamic>? ?? const [];
    final photos = rawPhotos.map((path) => path.toString()).toList()..sort();
    return jsonEncode({
      'displayName': (item['displayName'] ?? '').toString().trim(),
      'itemTypeCode': (item['itemTypeCode'] ?? '').toString(),
      'material': (item['material'] ?? '').toString().trim(),
      'groupCode': (item['groupCode'] ?? item['serviceGroupCode'] ?? '')
          .toString(),
      'serviceIds': serviceIds,
      'serviceSteps': serviceSteps,
      'conditionNotes': (item['conditionNotes'] ?? '').toString().trim(),
      'careNotes': (item['careNotes'] ?? '').toString().trim(),
      'conditionPhotoPaths': photos,
      'sourceOrderId': (item['sourceOrderId'] ?? '').toString(),
    });
  }

  static Future<void> saveCustomerCartDraft({
    required List<Map<String, dynamic>> items,
    required String? pickupAddressId,
    required Map<String, String> pickupSlotsByGroup,
    required Map<String, int> pickupDatesByGroup,
  }) async {
    final owner = await customerContext();
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to save your care cart.');
    await _db
        .collection('accounts')
        .doc(owner.accountId)
        .collection('profiles')
        .doc(owner.profileId)
        .collection('garment_care_cart_drafts')
        .doc('current')
        .set({
          'customerUid': uid,
          'accountId': owner.accountId,
          'profileId': owner.profileId,
          'schemaVersion': 1,
          'items': items,
          'pickupAddressId': pickupAddressId,
          'pickupSlotsByGroup': pickupSlotsByGroup,
          'pickupDatesByGroup': pickupDatesByGroup,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> clearCustomerCartDraft() async {
    final owner = await customerContext();
    await _db
        .collection('accounts')
        .doc(owner.accountId)
        .collection('profiles')
        .doc(owner.profileId)
        .collection('garment_care_cart_drafts')
        .doc('current')
        .delete();
  }

  static Future<List<GarmentCareIdentity>> savedGarments() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const <GarmentCareIdentity>[];
    final snapshot = await _db
        .collection('garment_identities')
        .where('customerUid', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((doc) => GarmentCareIdentity.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> legacyGarmentReferences() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const <Map<String, dynamic>>[];
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .get();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          return data['garmentRecordPublishedAt'] != null &&
              data['garmentRecord'] is Map;
        })
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static Future<({String checkoutId, List<String> orderIds})> createOrder({
    required String accountId,
    required String profileId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> pickupAddress,
    required Map<String, Map<String, dynamic>> pickupByServiceGroup,
  }) async {
    final result = await _functions
        .httpsCallable('createGarmentCareOrder')
        .call({
          'customerAccountId': accountId,
          'customerProfileId': profileId,
          'pickupAddressId': pickupAddress['addressId'],
          'pickupByServiceGroup': pickupByServiceGroup,
          'items': items,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      checkoutId: (data['checkoutId'] ?? data['cartCheckoutId'] ?? '')
          .toString(),
      orderIds: (data['orderIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
    );
  }

  static Future<Map<String, dynamic>> customerPricing() async {
    final result = await _functions
        .httpsCallable('getCustomerGarmentCarePricing')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> adminPricing() async {
    final result = await _functions
        .httpsCallable('getAdminGarmentCarePricing')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerGarmentHistory(
    String garmentId,
  ) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('garment_care_history_events')
        .where('customerUid', isEqualTo: uid)
        .where('garmentId', isEqualTo: garmentId)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('garment_care_orders')
        .where('customerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> adminOrders() => _db
      .collection('garment_care_orders')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> adminOrderJobs(
    String orderId,
  ) => _db
      .collection('garment_care_service_jobs')
      .where('orderId', isEqualTo: orderId)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> adminOrderShipments(
    String orderId,
  ) => _db
      .collection('garment_care_shipments')
      .where('orderId', isEqualTo: orderId)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerJobs(
    String orderId,
  ) {
    return _db
        .collection('garment_care_service_jobs')
        .where('orderId', isEqualTo: orderId)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerInvoices(
    String orderId,
  ) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('garment_care_invoices')
        .where('orderId', isEqualTo: orderId)
        .where('customerUid', isEqualTo: uid)
        .snapshots();
  }

  static Future<void> ensureSubOrderNumbers(String orderId) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) return;
    await _functions
        .httpsCallable('ensureGarmentCareSubOrderNumbers')
        .call({'orderId': normalizedOrderId})
        .timeout(const Duration(seconds: 20));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerPartnerNotes(
    String orderId,
  ) => _db
      .collection('garment_care_orders')
      .doc(orderId)
      .collection('events')
      .where('type', isEqualTo: 'partner_customer_note')
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerShipments(
    String orderId,
  ) => _db
      .collection('garment_care_shipments')
      .where('orderId', isEqualTo: orderId)
      .snapshots();

  static Future<void> payFinalInvoice({
    required String invoiceId,
    required OnlinePaymentMethod method,
  }) async {
    await _functions.httpsCallable('completeSandboxGarmentCarePayment').call({
      'invoiceId': invoiceId,
      'paymentMethod': method.name,
    });
  }

  static Future<void> payFinalInvoices({
    required List<String> invoiceIds,
    required OnlinePaymentMethod method,
  }) async {
    final normalizedIds = invoiceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.length == 1) {
      await payFinalInvoice(invoiceId: normalizedIds.single, method: method);
      return;
    }
    if (normalizedIds.length < 2) {
      throw ArgumentError('At least one final invoice is required.');
    }
    await _functions
        .httpsCallable('completeSandboxGarmentCarePaymentBatch')
        .call({'invoiceIds': normalizedIds, 'paymentMethod': method.name});
  }

  static Future<void> confirmCustomerDelivery({
    required String shipmentId,
    required String pin,
    required String accountId,
    required String profileId,
  }) async {
    await _functions.httpsCallable('confirmGarmentCareCustomerDelivery').call({
      'shipmentId': shipmentId,
      'pin': pin,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
    });
  }

  static Future<Map<String, dynamic>> deliveryPaymentDetails({
    required String shipmentId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCareDeliveryPaymentDetails')
        .call({
          'shipmentId': shipmentId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> recordPaymentAtDelivery({
    required String shipmentId,
    required String accountId,
    required String profileId,
    required double amount,
  }) async {
    await _functions.httpsCallable('recordGarmentCarePaymentAtDelivery').call({
      'shipmentId': shipmentId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'amount': amount,
    });
  }

  static Future<Map<String, dynamic>> pickupPartnerDetails(
    String shipmentId,
  ) async {
    final result = await _functions
        .httpsCallable('getGarmentCarePickupPartnerDetails')
        .call({'shipmentId': shipmentId})
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> partnerPickupWorkDetails({
    required String shipmentId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCarePickupWorkDetails')
        .call({
          'shipmentId': shipmentId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
        })
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> partnerServiceJobDetails({
    required String jobId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCarePartnerServiceJobDetails')
        .call({
          'jobId': jobId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
        })
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> sendPartnerCustomerNote({
    required String jobId,
    required String accountId,
    required String profileId,
    required String message,
  }) async {
    await _functions.httpsCallable('sendGarmentCarePartnerOrderNote').call({
      'jobId': jobId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'message': message,
    });
  }

  static Future<void> acceptPickup({
    required String shipmentId,
    required String accountId,
    required String profileId,
  }) async {
    await _functions.httpsCallable('acceptGarmentCarePickup').call({
      'shipmentId': shipmentId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
    });
  }

  static Future<Map<String, dynamic>> adminPartnerProfileDetails({
    required String accountId,
    required String profileId,
  }) async {
    final snapshot = await _db
        .collection('accounts')
        .doc(accountId)
        .collection('profiles')
        .doc(profileId)
        .get();
    final profile = snapshot.data() ?? const <String, dynamic>{};
    if (!snapshot.exists) {
      throw StateError('Assigned Partner profile not found.');
    }
    final partnerData = profile['partnerData'] is Map
        ? Map<String, dynamic>.from(profile['partnerData'] as Map)
        : const <String, dynamic>{};
    final rawAdditionalPhones =
        profile['additionalContactNumbers'] ??
        profile['alternateContactNumbers'] ??
        const <String>[];
    return {
      'name':
          profile['businessName'] ??
          profile['shopName'] ??
          profile['displayName'] ??
          profile['name'] ??
          partnerData['businessName'] ??
          'Garment Care Partner',
      'contactPhone':
          profile['contactPhone'] ??
          profile['mobileE164'] ??
          profile['mobileNumber'] ??
          profile['phone'] ??
          '',
      'additionalContactPhones': rawAdditionalPhones is List
          ? rawAdditionalPhones
          : rawAdditionalPhones is String && rawAdditionalPhones.isNotEmpty
          ? [rawAdditionalPhones]
          : const <String>[],
    };
  }

  static Future<Map<String, dynamic>> adminPickupPartnerDetails({
    required String shipmentId,
    required String accountId,
    required String profileId,
  }) async {
    Map<String, dynamic> profileDetails = const <String, dynamic>{};
    Object? profileError;
    try {
      profileDetails = await adminPartnerProfileDetails(
        accountId: accountId,
        profileId: profileId,
      );
    } catch (error) {
      profileError = error;
    }

    if ((profileDetails['contactPhone']?.toString().trim().isNotEmpty ??
            false) &&
        (profileDetails['name']?.toString().trim().isNotEmpty ?? false)) {
      return profileDetails;
    }

    try {
      final serverDetails = await pickupPartnerDetails(shipmentId);
      return {
        ...serverDetails,
        ...profileDetails,
        'name': (profileDetails['name']?.toString().trim().isNotEmpty ?? false)
            ? profileDetails['name']
            : serverDetails['name'],
        'contactPhone':
            (profileDetails['contactPhone']?.toString().trim().isNotEmpty ??
                false)
            ? profileDetails['contactPhone']
            : serverDetails['contactPhone'],
        'additionalContactPhones':
            (profileDetails['additionalContactPhones'] as List<dynamic>? ??
                    const <dynamic>[])
                .isNotEmpty
            ? profileDetails['additionalContactPhones']
            : serverDetails['additionalContactPhones'],
      };
    } catch (error) {
      if (profileError != null) {
        throw StateError(
          'Assigned Partner details could not be loaded. '
          'Profile: $profileError. Server lookup: $error',
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> adminCustomerDetails(
    String orderId,
  ) async {
    final result = await _functions
        .httpsCallable('getGarmentCareOrderCustomerDetails')
        .call({'orderId': orderId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> customerServicePartnerDetails(
    String jobId,
  ) async {
    final result = await _functions
        .httpsCallable('getGarmentCareServicePartnerDetails')
        .call({'jobId': jobId})
        .timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> customerDeliveryGroups(
    String orderId,
  ) => _db
      .collection('garment_care_orders')
      .doc(orderId)
      .collection('delivery_groups')
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> partnerJobs({
    required String accountId,
    required String profileId,
  }) {
    return _db
        .collection('garment_care_service_jobs')
        .where('assignedPartnerAccountId', isEqualTo: accountId)
        .where('assignedPartnerProfileId', isEqualTo: profileId)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> dispatchQueue() {
    return _db
        .collection('garment_care_service_jobs')
        .where('status', whereIn: const ['queued', 'rejected'])
        .where('dispatchEligible', isEqualTo: true)
        .snapshots();
  }

  static Future<void> updatePartnerPreferences({
    required String accountId,
    required String profileId,
    required bool availableForOrders,
    required String openAt,
    required String closeAt,
  }) async {
    await _functions.httpsCallable('updateGarmentCarePartnerPreferences').call({
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'availableForOrders': availableForOrders,
      'openAt': openAt,
      'closeAt': closeAt,
    });
  }

  static Future<void> updatePartnerPriority({
    required String accountId,
    required String profileId,
    required int priority,
  }) async {
    await _functions.httpsCallable('updateGarmentCarePartnerPriority').call({
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'priority': priority,
    });
  }

  static Future<void> requestPartnerReassignment({
    required String jobId,
    required String accountId,
    required String profileId,
    required String reason,
  }) async {
    await _functions.httpsCallable('requestGarmentCareJobReassignment').call({
      'jobId': jobId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'reason': reason,
    });
  }

  static Future<void> respondToItemRevision({
    required String revisionId,
    required String decision,
    String? replacementServiceId,
  }) async {
    await _functions.httpsCallable('respondToGarmentCareItemRevision').call({
      'revisionId': revisionId,
      'decision': decision,
      'replacementServiceId': replacementServiceId,
    });
  }

  static Future<void> submitFeedback({
    required String orderId,
    required int rating,
    required String feedback,
  }) async {
    await _functions.httpsCallable('submitGarmentCareFeedback').call({
      'orderId': orderId,
      'rating': rating,
      'feedback': feedback,
    });
  }

  static Future<void> reportWarrantyIssue({
    required String orderId,
    required String description,
  }) async {
    await _functions.httpsCallable('reportGarmentCareWarrantyIssue').call({
      'orderId': orderId,
      'description': description,
    });
  }

  static Future<void> assignJob({
    required String jobId,
    required String partnerAccountId,
    required String partnerProfileId,
  }) async {
    await _functions.httpsCallable('assignGarmentCareServiceJob').call({
      'jobId': jobId,
      'partnerAccountId': partnerAccountId,
      'partnerProfileId': partnerProfileId,
    });
  }

  static Future<List<Map<String, dynamic>>> partnerCandidates() async {
    final result = await _functions
        .httpsCallable('getGarmentCarePartnerCandidates')
        .call();
    final payload = Map<String, dynamic>.from(result.data as Map);
    return (payload['partners'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> deliveryPartnerCandidates({
    required String accountId,
    required String profileId,
    required String shipmentId,
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCareDeliveryCandidates')
        .call({
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'shipmentId': shipmentId,
        });
    final payload = Map<String, dynamic>.from(result.data as Map);
    return (payload['partners'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<void> updateGarmentCareDeliveryAvailability({
    required String accountId,
    required String profileId,
    required bool available,
  }) async {
    await _functions
        .httpsCallable('updateGarmentCareDeliveryPartnerAvailability')
        .call({
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'available': available,
        });
  }

  static Future<void> assignReturnDeliveryPartner({
    required String shipmentId,
    required String accountId,
    required String profileId,
    required String deliveryPartnerAccountId,
    required String deliveryPartnerProfileId,
  }) async {
    await _functions.httpsCallable('assignGarmentCareReturnPartner').call({
      'shipmentId': shipmentId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'deliveryPartnerAccountId': deliveryPartnerAccountId,
      'deliveryPartnerProfileId': deliveryPartnerProfileId,
    });
  }

  static Future<void> respondToGarmentCareDeliveryAssignment({
    required String shipmentId,
    required String accountId,
    required String profileId,
    required String decision,
    String reasonCode = '',
  }) async {
    await _functions
        .httpsCallable('respondToGarmentCareDeliveryAssignment')
        .call({
          'shipmentId': shipmentId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'decision': decision,
          if (reasonCode.isNotEmpty) 'reasonCode': reasonCode,
        });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> pickupQueue() => _db
      .collection('garment_care_shipments')
      .where('shipmentType', isEqualTo: 'customer_pickup')
      .where('status', isEqualTo: 'queued')
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> partnerIncomingShipments({
    required String accountId,
    required String profileId,
  }) => _db
      .collection('garment_care_shipments')
      .where('toPartnerAccountId', isEqualTo: accountId)
      .where('toPartnerProfileId', isEqualTo: profileId)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> partnerOutgoingShipments({
    required String accountId,
    required String profileId,
  }) => _db
      .collection('garment_care_shipments')
      .where('fromPartnerAccountId', isEqualTo: accountId)
      .where('fromPartnerProfileId', isEqualTo: profileId)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> deliveryPartnerShipments({
    required String accountId,
    required String profileId,
  }) => _db
      .collection('garment_care_shipments')
      .where('deliveryPartnerAccountId', isEqualTo: accountId)
      .where('deliveryPartnerProfileId', isEqualTo: profileId)
      .snapshots();

  static Stream<DocumentSnapshot<Map<String, dynamic>>> partnerShipmentStatus(
    String shipmentId,
  ) => _db.collection('garment_care_shipments').doc(shipmentId).snapshots();

  static Future<void> assignPickup({
    required String shipmentId,
    required String partnerAccountId,
    required String partnerProfileId,
  }) async {
    await _functions.httpsCallable('assignGarmentCarePickup').call({
      'shipmentId': shipmentId,
      'partnerAccountId': partnerAccountId,
      'partnerProfileId': partnerProfileId,
    });
  }

  static Future<void> recordHandover({
    required String shipmentId,
    required String accountId,
    required String profileId,
    required String action,
    required List<String> confirmedGarmentIds,
    List<String> rejectedGarmentIds = const [],
    Map<String, String> pickupRejectionReasons = const {},
    Map<String, String> evidencePhotosByGarmentId = const {},
  }) async {
    await _functions.httpsCallable('recordGarmentCareHandover').call({
      'shipmentId': shipmentId,
      'partnerAccountId': accountId,
      'partnerProfileId': profileId,
      'action': action,
      'confirmedGarmentIds': confirmedGarmentIds,
      'rejectedGarmentIds': rejectedGarmentIds,
      'pickupRejectionReasons': pickupRejectionReasons,
      'evidencePhotosByGarmentId': evidencePhotosByGarmentId,
    });
  }

  static Future<void> advanceJob({
    required String jobId,
    required String accountId,
    required String profileId,
    required String targetStatus,
    String note = '',
    Map<String, String> treatmentRecord = const {},
  }) async {
    await _functions
        .httpsCallable(
          'advanceGarmentCareServiceJob',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 130)),
        )
        .call({
          'jobId': jobId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'targetStatus': targetStatus,
          'note': note,
          if (treatmentRecord.isNotEmpty) 'treatmentRecord': treatmentRecord,
        });
  }

  static Future<Map<String, dynamic>> submitInspectionQuote({
    required String jobId,
    required String accountId,
    required String profileId,
    required String inspectionNotes,
    String conditionFindings = '',
    double additionalServiceFee = 0,
    String additionalServiceReason = '',
    String inspectionMode = '',
    String conditionCode = '',
    List<String> observationCodes = const [],
    String recommendedActionCode = '',
    String priceImpactCode = '',
    String customerMessage = '',
    String optionalNote = '',
    String inspectionTemplateId = '',
    String inspectionTemplateVersionId = '',
    int? inspectionTemplateVersion,
    List<String> inspectionEvidencePaths = const [],
  }) async {
    final result = await _functions
        .httpsCallable(
          'submitGarmentCareInspectionQuote',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 130)),
        )
        .call({
          'jobId': jobId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'inspectionNotes': inspectionNotes,
          'conditionFindings': conditionFindings,
          'additionalServiceFee': additionalServiceFee,
          'additionalServiceReason': additionalServiceReason,
          'inspectionMode': inspectionMode,
          'conditionCode': conditionCode,
          'observationCodes': observationCodes,
          'recommendedActionCode': recommendedActionCode,
          'priceImpactCode': priceImpactCode,
          'customerMessage': customerMessage,
          'optionalNote': optionalNote,
          'inspectionTemplateId': inspectionTemplateId,
          'inspectionTemplateVersionId': inspectionTemplateVersionId,
          'inspectionTemplateVersion': inspectionTemplateVersion,
          'inspectionEvidencePaths': inspectionEvidencePaths,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> partnerInspectionContext({
    required String jobId,
    required String accountId,
    required String profileId,
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCareInspectionContext')
        .call({
          'jobId': jobId,
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> inspectionTemplates() async {
    final result = await _functions
        .httpsCallable('getGarmentCareInspectionTemplates')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> publishInspectionTemplates({
    required Map<String, dynamic> templates,
  }) async {
    final result = await _functions
        .httpsCallable('publishGarmentCareInspectionTemplates')
        .call({'templates': templates});
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> completionTemplates({
    required bool isAdmin,
    String accountId = '',
    String profileId = '',
  }) async {
    final result = await _functions
        .httpsCallable('getGarmentCareCompletionTemplates')
        .call({
          'isAdmin': isAdmin,
          if (!isAdmin) 'partnerAccountId': accountId,
          if (!isAdmin) 'partnerProfileId': profileId,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> publishCompletionTemplates({
    required List<Map<String, dynamic>> templates,
  }) async {
    final result = await _functions
        .httpsCallable('publishGarmentCareCompletionTemplates')
        .call({'templates': templates});
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> savePartnerCompletionTemplate({
    required String accountId,
    required String profileId,
    required Map<String, dynamic> template,
  }) async {
    await _functions
        .httpsCallable('savePartnerGarmentCareCompletionTemplate')
        .call({
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'template': template,
        });
  }

  static Future<void> deletePartnerCompletionTemplate({
    required String accountId,
    required String profileId,
    required String templateId,
  }) async {
    await _functions
        .httpsCallable('deletePartnerGarmentCareCompletionTemplate')
        .call({
          'partnerAccountId': accountId,
          'partnerProfileId': profileId,
          'templateId': templateId,
        });
  }

  static Future<String> publishPricing({
    required Map<String, dynamic> serviceRates,
    Map<String, dynamic> itemTypeRates = const {},
    required double platformCommissionPercent,
    required double taxPercent,
    required double deliveryPercent,
    required double logisticsAmount,
  }) async {
    final result = await _functions
        .httpsCallable('publishGarmentCarePricingVersion')
        .call({
          'serviceRates': serviceRates,
          'itemTypeRates': itemTypeRates,
          'platformCommissionPercent': platformCommissionPercent,
          'taxPercent': taxPercent,
          'deliveryPercent': deliveryPercent,
          'logisticsAmount': logisticsAmount,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['versionId'] ?? '').toString();
  }

  static Future<void> respondToConsent({
    required String consentId,
    required String decision,
  }) async {
    await _functions.httpsCallable('respondToGarmentCareConsent').call({
      'consentId': consentId,
      'decision': decision,
    });
  }
}
