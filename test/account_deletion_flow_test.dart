import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bluefarm/providers/app_provider.dart';
import 'package:bluefarm/screens/settings_screen.dart';
import 'package:bluefarm/screens/buyer_shell.dart';
import 'package:bluefarm/services/account_deletion_service.dart';

Widget _buildTestApp({
  required Widget child,
  AppProvider? provider,
}) {
  final p = provider ?? AppProvider();
  return ChangeNotifierProvider<AppProvider>.value(
    value: p,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
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

  group('Account Deletion Configuration Tests', () {
    test('Deletion URL constant points to official web route, not GitHub', () {
      const url = AccountDeletionConfig.deletionUrl;
      expect(url.startsWith('https://'), isTrue);
      expect(url.contains('/account-deletion'), isTrue);
      expect(url.contains('github.com'), isFalse,
          reason: 'Mobile app must never redirect users to a development GitHub repository');
    });
  });

  group('Farmer Account Deletion Flow Tests', () {
    testWidgets('Farmer SettingsScreen displays Delete Account and shows confirmation dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find Delete Account option (rendered with InkWell and Text)
      final deleteTileFinder = find.text('Delete Account');
      expect(deleteTileFinder, findsOneWidget);

      // Tap Delete Account
      await tester.tap(deleteTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify confirmation dialog contents
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Account'), findsNWidgets(2)); // tile and dialog title
      expect(
        find.textContaining("redirected to BlueFarm's official account deletion website"),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cancel_delete_account_button')), findsOneWidget);
      expect(find.byKey(const Key('continue_delete_account_button')), findsOneWidget);

      // Tapping Cancel dismisses dialog
      await tester.tap(find.byKey(const Key('cancel_delete_account_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Buyer Account Deletion Flow Tests', () {
    testWidgets('Buyer Profile Tab displays Delete Account and opens confirmation dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp(child: const BuyerShell()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Profile tab (tab index 3 in navigation bar: Icon(Icons.person_outline))
      final profileNavIcon = find.byIcon(Icons.person_outline);
      expect(profileNavIcon, findsOneWidget);
      await tester.tap(profileNavIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find Delete Account in profile
      final deleteTile = find.text('Delete Account');
      expect(deleteTile, findsOneWidget);

      // Tap Delete Account
      await tester.tap(deleteTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining("redirected to BlueFarm's official account deletion website"),
        findsOneWidget,
      );

      // Cancel button works
      await tester.tap(find.byKey(const Key('cancel_delete_account_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
