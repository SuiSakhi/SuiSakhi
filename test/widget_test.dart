// Basic smoke test — verifies key model classes are importable and usable.
// Full UI tests are in integration_test/app_test.dart (require a device/simulator).
import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/models/dress.dart';
import 'package:stitchsmart/models/user_profile.dart';

void main() {
  test('OrderStatus values exist', () {
    expect(OrderStatus.values.length, 10);
  });

  test('UserRole values exist', () {
    expect(UserRole.values.length, 4);
  });

  test('DressOrder can be constructed', () {
    final order = DressOrder(
      id: 'test',
      dressType: 'Kurti',
      tailorName: '',
      status: OrderStatus.pending,
      orderDate: DateTime(2024, 1, 1),
      price: 350,
    );
    expect(order.id, 'test');
    expect(order.status.label, 'Order placed');
  });
}
