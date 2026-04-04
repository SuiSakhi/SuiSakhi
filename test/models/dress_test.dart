import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/models/dress.dart';

void main() {
  group('DressOrder', () {
    test('creates with required fields', () {
      final order = DressOrder(
        id: 'order-1',
        dressType: 'Kurti',
        tailorName: 'Priya',
        status: OrderStatus.pending,
        orderDate: DateTime(2024, 1, 1),
        price: 350.0,
      );
      expect(order.id, 'order-1');
      expect(order.dressType, 'Kurti');
      expect(order.tailorName, 'Priya');
      expect(order.status, OrderStatus.pending);
      expect(order.price, 350.0);
      expect(order.deliveryDate, isNull);
      expect(order.customerId, isNull);
      expect(order.fabricDescription, isNull);
      expect(order.advancePercent, 40);
    });

    test('creates with all optional fields', () {
      final delivery = DateTime(2024, 2, 1);
      final order = DressOrder(
        id: 'order-2',
        dressType: 'Lehenga',
        tailorName: 'Meena',
        status: OrderStatus.delivered,
        orderDate: DateTime(2024, 1, 15),
        deliveryDate: delivery,
        price: 1200.0,
        fabricDescription: 'Silk fabric, red color',
        customerId: 'user-123',
        advancePercent: 50,
        advanceAmount: 600,
        balanceAmount: 600,
      );
      expect(order.deliveryDate, delivery);
      expect(order.fabricDescription, 'Silk fabric, red color');
      expect(order.customerId, 'user-123');
      expect(order.advanceAmount, 600);
    });

    test('price can be zero', () {
      final order = DressOrder(
        id: 'order-3',
        dressType: 'Blouse',
        tailorName: '',
        status: OrderStatus.pending,
        orderDate: DateTime.now(),
        price: 0.0,
      );
      expect(order.price, 0.0);
    });

    test('fromFirestore migrates legacy inProgress to inStitching', () {
      final order = DressOrder.fromFirestore('x', {
        'dressType': 'Kurti',
        'tailorName': '',
        'status': 'inProgress',
        'orderDate': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'price': 100.0,
        'paymentStatus': 'unpaid',
      });
      expect(order.status, OrderStatus.inStitching);
    });
  });

  group('OrderStatus labels', () {
    test('non-empty for all', () {
      for (final s in OrderStatus.values) {
        expect(s.label.isNotEmpty, true);
      }
    });
    test('pending', () => expect(OrderStatus.pending.label, 'Order placed'));
    test('inStitching', () => expect(OrderStatus.inStitching.label, 'In stitching'));
    test('readyForPickup', () => expect(OrderStatus.readyForPickup.label, 'Ready for delivery'));
    test('delivered', () => expect(OrderStatus.delivered.label, 'Delivered'));
    test('cancelled', () => expect(OrderStatus.cancelled.label, 'Cancelled'));
  });

  group('OrderStatus colors', () {
    test('pending is orange', () {
      expect(OrderStatus.pending.color, const Color(0xFFFF9800));
    });
    test('inStitching is blue', () {
      expect(OrderStatus.inStitching.color, const Color(0xFF2196F3));
    });
    test('readyForPickup is purple', () {
      expect(OrderStatus.readyForPickup.color, const Color(0xFF9C27B0));
    });
    test('delivered is green', () {
      expect(OrderStatus.delivered.color, const Color(0xFF2E7D32));
    });
    test('cancelled is red', () {
      expect(OrderStatus.cancelled.color, const Color(0xFFE53935));
    });
    test('all statuses have distinct colors', () {
      final colors = OrderStatus.values.map((s) => s.color).toSet();
      expect(colors.length, OrderStatus.values.length);
    });
  });

  group('OrderStatus pipeline', () {
    test('pending then pickedUp', () {
      expect(OrderStatus.pending.nextForTailor, OrderStatus.pickedUp);
    });
    test('qcPassed then readyForPickup', () {
      expect(OrderStatus.qcPassed.nextForTailor, OrderStatus.readyForPickup);
    });
    test('readyForPickup then outForDelivery for delivery', () {
      expect(OrderStatus.readyForPickup.nextForDelivery, OrderStatus.outForDelivery);
    });
    test('delivered has no tailor next', () {
      expect(OrderStatus.delivered.nextForTailor, isNull);
    });
  });

  group('DressCategory', () {
    test('has ladies and gents', () {
      expect(DressCategory.values, contains(DressCategory.ladies));
      expect(DressCategory.values, contains(DressCategory.gents));
    });
  });

  group('OrderStatus enum lookup', () {
    test('can look up status by name', () {
      for (final status in OrderStatus.values) {
        final found = OrderStatus.values.firstWhere((s) => s.name == status.name);
        expect(found, status);
      }
    });

    test('defaults to pending when name is unknown', () {
      final status = OrderStatus.values.firstWhere(
        (s) => s.name == 'unknown_status',
        orElse: () => OrderStatus.pending,
      );
      expect(status, OrderStatus.pending);
    });
  });
}
