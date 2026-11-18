import 'package:flutter_test/flutter_test.dart';
import 'package:bluefarm/services/email_notification_service.dart';
import 'package:bluefarm/services/demo_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmailNotificationService Tests', () {
    test('Service instance is a singleton', () {
      final instance1 = EmailNotificationService();
      final instance2 = EmailNotificationService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Demo Mode cleanly suppresses outgoing network emails', () async {
      DemoModeService.isDemoMode = true;
      final service = EmailNotificationService();

      // Should complete cleanly without error in demo mode
      await expectLater(
        service.notifyUserRegistration(
          userId: 'demo-user-123',
          fullName: 'Google Play Reviewer',
          role: 'farmer',
          email: 'bluefarm1572@gmail.com',
        ),
        completes,
      );

      await expectLater(
        service.notifyNewOrder(
          orderId: 'demo-order-123',
          buyerId: 'demo-buyer-123',
          species: 'Rohu',
          quantityKg: 25.0,
          pricePerKg: 180.0,
          totalPrice: 4500.0,
          paymentMethod: 'cod',
        ),
        completes,
      );

      await expectLater(
        service.notifyOrderCancellation(
          orderId: 'demo-order-123',
          reason: 'Test cancellation',
        ),
        completes,
      );

      await expectLater(
        service.notifyNewHarvest(
          listingId: 'demo-listing-123',
          species: 'Catla',
          quantityKg: 50.0,
          pricePerKg: 210.0,
        ),
        completes,
      );

      DemoModeService.isDemoMode = false;
    });
  });
}
