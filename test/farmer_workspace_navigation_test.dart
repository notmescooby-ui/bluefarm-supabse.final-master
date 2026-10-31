import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bluefarm/providers/app_provider.dart';
import 'package:bluefarm/screens/main_shell.dart';
import 'package:bluefarm/screens/home_screen.dart';
import 'package:bluefarm/screens/feeder_automate_screen.dart';
import 'package:bluefarm/screens/market_near_me_screen.dart';
import 'package:bluefarm/screens/harvest_screen.dart';
import 'package:bluefarm/screens/insights_screen.dart';
import 'package:bluefarm/screens/knowledge_screen.dart';
import 'package:bluefarm/screens/settings_screen.dart';
import 'package:bluefarm/services/demo_mode_service.dart';
import 'package:bluefarm/widgets/animated_banner.dart';

Widget _buildTestApp({
  required Widget child,
  required AppProvider provider,
  double textScale = 1.0,
}) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          padding: const EdgeInsets.only(top: 24, bottom: 34),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> pumpFrames(WidgetTester tester, [int durationMs = 300]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: durationMs));
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
    DemoModeService.isDemoMode = true;
    DemoModeService.demoRole = 'farmer';
    provider = AppProvider();
  });

  tearDown(() {
    provider.stopSensorWatch();
    provider.dispose();
    DemoModeService.isDemoMode = false;
  });

  group('Farmer Workspace QA - Navigation & Shell Tests', () {
    testWidgets('1. All seven bottom navigation tabs render with correct icons and labels',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const MainShell(), provider: provider));
      await pumpFrames(tester, 1200);

      // Verify all 7 tab labels exist in the bottom navigation bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Feeder'), findsOneWidget);
      expect(find.text('Near Me'), findsOneWidget);
      expect(find.text('Harvest'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);

      // Verify HomeScreen is active and onstage initially
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify offstage screens are mounted inside IndexedStack
      expect(find.byType(FeederAutomateScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(MarketNearMeScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(HarvestScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(InsightsScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(KnowledgeScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('2. Tab switching between tabs preserves IndexedStack state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const MainShell(), provider: provider));
      await pumpFrames(tester, 1200);

      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);
      IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      // Switch to Feeder (index 1)
      await tester.tap(find.text('Feeder'));
      await pumpFrames(tester);
      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 1);
      expect(find.byType(FeederAutomateScreen), findsOneWidget);

      // Switch to Account (index 6)
      await tester.tap(find.text('Account'));
      await pumpFrames(tester);
      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 6);
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Switch back to Home (index 0)
      await tester.tap(find.text('Home'));
      await pumpFrames(tester);
      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);
      expect(find.byType(HomeScreen), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('3. Feeder dashboard card navigates to FeederAutomateScreen and AppBar back returns to Home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const MainShell(), provider: provider));
      await pumpFrames(tester, 1200);

      final indexedStackFinder = find.byType(IndexedStack);
      IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      // Scroll until Feeder Automation card is visible in CustomScrollView
      await tester.scrollUntilVisible(
        find.text('Automated Pond Feeder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await pumpFrames(tester);

      // Tap Feeder Automation card
      final feederCardFinder = find.text('Automated Pond Feeder');
      expect(feederCardFinder, findsOneWidget);
      await tester.tap(feederCardFinder);
      await pumpFrames(tester);

      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 1);
      expect(find.byType(FeederAutomateScreen), findsOneWidget);

      // Verify Feeder back button with tooltip "Back to Home"
      final backButtonFinder = find.byTooltip('Back to Home');
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await pumpFrames(tester);

      // Verified returned to Home tab
      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      provider.stopSensorWatch();
    });

    testWidgets('4. Feeder Configure button navigates to FeederAutomateScreen and AppBar back returns to Home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const MainShell(), provider: provider));
      await pumpFrames(tester, 1200);

      final indexedStackFinder = find.byType(IndexedStack);
      IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      // Scroll until Configure button is visible in CustomScrollView
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Configure'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await pumpFrames(tester);

      // Tap "Configure" button on feeder card
      final configBtnFinder = find.widgetWithText(ElevatedButton, 'Configure');
      expect(configBtnFinder, findsOneWidget);
      await tester.tap(configBtnFinder);
      await pumpFrames(tester);

      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 1);

      // Back to Home
      final backButtonFinder = find.byTooltip('Back to Home');
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await pumpFrames(tester);

      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      provider.stopSensorWatch();
    });

    testWidgets('5. PopScope intercepts system back navigation on non-home tabs and returns to Home tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(child: const MainShell(), provider: provider));
      await pumpFrames(tester, 1200);

      final indexedStackFinder = find.byType(IndexedStack);

      // Switch to Feeder tab
      await tester.tap(find.text('Feeder'));
      await pumpFrames(tester);
      IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.index, 1);

      // Simulate system pop route
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await pumpFrames(tester);

      // Should be popped back to Home tab (index 0)
      stack = tester.widget(indexedStackFinder);
      expect(stack.index, 0);

      provider.stopSensorWatch();
    });
  });

  group('Feeder Automation - Hardware Connectivity & Safety Indication Tests', () {
    testWidgets('6. Feeder screen shows SIMULATOR badge & warning banner when hardware is disconnected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await provider.setDeviceConnected(false);

      await tester.pumpWidget(_buildTestApp(
        child: const FeederAutomateScreen(isTab: false),
        provider: provider,
      ));
      await pumpFrames(tester);

      // SIMULATOR badge
      expect(find.text('SIMULATOR'), findsOneWidget);
      expect(find.text('ONLINE'), findsNothing);

      // Warning banner
      expect(find.text('Hardware Disconnected · Simulator Mode'), findsOneWidget);
      expect(find.text('STANDBY (HARDWARE OFFLINE)'), findsOneWidget);

      // Test Turn ON Feeder button
      final turnOnBtn = find.widgetWithText(ElevatedButton, 'Turn ON Feeder');
      expect(turnOnBtn, findsOneWidget);
      await tester.tap(turnOnBtn);
      await pumpFrames(tester);

      // Feeder is now in simulator active mode
      expect(provider.isFeederOn, isTrue);
      expect(find.text('FEEDER ACTIVE (SIMULATOR)'), findsOneWidget);
      expect(find.textContaining('Simulator Mode · Hardware Offline'), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('7. Feeder screen shows ONLINE badge and no disconnect warning when connected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await provider.setDeviceConnected(true);

      await tester.pumpWidget(_buildTestApp(
        child: const FeederAutomateScreen(isTab: false),
        provider: provider,
      ));
      await pumpFrames(tester);

      // ONLINE badge
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('SIMULATOR'), findsNothing);

      // No warning banner
      expect(find.text('Hardware Disconnected · Simulator Mode'), findsNothing);
      expect(find.text('FEEDER STANDBY · GATE CLOSED'), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('8. Feeder Automate screen applies correct bottom safe-area padding for tab vs standalone',
        (WidgetTester tester) async {
      // Hosted as tab
      await tester.pumpWidget(_buildTestApp(
        child: const FeederAutomateScreen(isTab: true),
        provider: provider,
      ));
      await pumpFrames(tester);

      final tabScrollView = tester.widget<SingleChildScrollView>(
        find.descendant(of: find.byType(Scaffold), matching: find.byType(SingleChildScrollView)).first,
      );
      final tabPadding = tabScrollView.padding as EdgeInsets;
      // 85.0 + bottom padding 34 = 119.0
      expect(tabPadding.bottom, 119.0);

      // Standalone
      await tester.pumpWidget(_buildTestApp(
        child: const FeederAutomateScreen(isTab: false),
        provider: provider,
      ));
      await pumpFrames(tester);

      final standaloneScrollView = tester.widget<SingleChildScrollView>(
        find.descendant(of: find.byType(Scaffold), matching: find.byType(SingleChildScrollView)).first,
      );
      final standalonePadding = standaloneScrollView.padding as EdgeInsets;
      // 24.0 + bottom padding 34 = 58.0
      expect(standalonePadding.bottom, 58.0);

      provider.stopSensorWatch();
    });
  });

  group('Responsive Layout & Accessibility Tests', () {
    testWidgets('9. Narrow screen (320px) with 1.5x font scale renders HomeScreen without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        child: const HomeScreen(),
        provider: provider,
        textScale: 1.5,
      ));
      await pumpFrames(tester, 1200);

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('10. Narrow screen (320px) with 1.5x font scale renders FeederAutomateScreen without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        child: const FeederAutomateScreen(isTab: true),
        provider: provider,
      ));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Turn ON Feeder'), findsOneWidget);
      expect(find.text('Turn OFF Feeder'), findsOneWidget);

      provider.stopSensorWatch();
    });

    testWidgets('11. AnimatedBanner errorBuilder handles missing asset gracefully without crashing',
        (WidgetTester tester) async {
      bool ctaPressed = false;
      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: AnimatedBanner(
            title: 'Test Aquaculture Banner',
            subtitle: 'Testing graceful image error fallback',
            ctaText: 'Explore',
            onCtaPressed: () => ctaPressed = true,
            imagePath: 'assets/non_existent_image.png',
          ),
        ),
        provider: provider,
      ));
      await pumpFrames(tester, 1200);

      expect(tester.takeException(), isNull);
      expect(find.text('Test Aquaculture Banner'), findsOneWidget);
      expect(find.byIcon(Icons.waves_rounded), findsOneWidget);

      await tester.tap(find.text('Explore'));
      expect(ctaPressed, isTrue);

      provider.stopSensorWatch();
    });
  });
}
