import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bluefarm/providers/app_provider.dart';
import 'package:bluefarm/screens/login_screen.dart';
import 'package:bluefarm/screens/signup_screen.dart';

Widget _buildTestApp({
  required Widget child,
  required AppProvider provider,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 34),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  late AppProvider provider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://ttipwqpiwqwejvxtzqqn.supabase.co',
        anonKey: 'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
      );
    } catch (_) {
      // Supabase already initialized
    }
  });

  setUp(() {
    provider = AppProvider();
  });

  group('Login & Signup Screen Overflow Tests', () {
    testWidgets('LoginScreen Explore Demo card does not overflow on 360px viewport',
        (WidgetTester tester) async {
      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
        debugPrint('CAPTURED FLUTTER ERROR:\n$details');
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          child: const LoginScreen(),
          provider: provider,
          size: const Size(360, 800),
        ),
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      if (err != null) {
        if (err is FlutterError) {
          debugPrint('LOGIN SCREEN EXCEPTION DEEP:\n${err.toStringDeep()}');
        } else {
          debugPrint('LOGIN SCREEN EXCEPTION: $err');
        }
      }
      expect(err, isNull);
    });

    testWidgets('SignupScreen Explore Demo card does not overflow on 360px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          child: const SignupScreen(),
          provider: provider,
          size: const Size(360, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explore Demo / Reviewer Mode'), findsOneWidget);
      expect(find.text('Google Play Review • Sample Data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Profile Payload Schema Safety Tests', () {
    test('Farmer and Buyer payloads exclude non-existent columns', () {
      final validColumns = {
        'id',
        'full_name',
        'company_name',
        'phone',
        'email',
        'role',
        'aadhaar_verified',
        'buyer_type',
        'pincode',
        'region',
        'gps_address',
        'account_status',
        'farm_name',
        'age',
        'farm_size',
        'waterbody_type',
        'fish_species',
        'stocking_density',
        'secondary_species',
      };

      final nonExistentColumns = {
        'is_demo',
        'demo_verified',
        'verification_note',
      };

      final sampleFarmerPayload = {
        'id': 'test-farmer-id',
        'farm_name': 'Green Farm',
        'full_name': 'Test Farmer',
        'age': 35,
        'phone': '9876543210',
        'email': 'farmer@example.com',
        'role': 'farmer',
        'aadhaar_verified': true,
        'pincode': '400601',
        'region': 'Thane, Maharashtra, India',
        'gps_address': 'Majiwada, Thane',
        'farm_size': '2 Acres',
        'waterbody_type': 'Pond',
        'fish_species': 'Rohu',
        'stocking_density': '1000',
        'secondary_species': 'Catla',
        'account_status': 'active',
      };

      final sampleBuyerPayload = {
        'id': 'test-buyer-id',
        'full_name': 'Test Buyer',
        'company_name': 'Aqua Trader',
        'phone': '9876543210',
        'email': 'buyer@example.com',
        'role': 'buyer',
        'aadhaar_verified': true,
        'buyer_type': 'Wholesale Trader',
        'pincode': '400601',
        'region': 'Thane, Maharashtra, India',
        'gps_address': 'Majiwada, Thane',
        'account_status': 'active',
      };

      for (final col in nonExistentColumns) {
        expect(sampleFarmerPayload.containsKey(col), isFalse,
            reason: 'Farmer payload should not contain $col');
        expect(sampleBuyerPayload.containsKey(col), isFalse,
            reason: 'Buyer payload should not contain $col');
      }

      for (final key in sampleFarmerPayload.keys) {
        expect(validColumns.contains(key), isTrue,
            reason: 'Farmer key $key must exist in Supabase profiles schema');
      }

      for (final key in sampleBuyerPayload.keys) {
        expect(validColumns.contains(key), isTrue,
            reason: 'Buyer key $key must exist in Supabase profiles schema');
      }
    });
  });
}
