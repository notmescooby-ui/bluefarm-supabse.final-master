import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/role_selection_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ttipwqpiwqwejvxtzqqn.supabase.co',
    anonKey: 'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()
        ..loadAllData()
        ..initializeData(),
      child: const BlueFarmApp(),
    ),
  );
}

class BlueFarmApp extends StatelessWidget {
  const BlueFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'BlueFarm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        // Smart Routing: If logged in, go to Role Selection, otherwise Splash
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            // Check initial session to avoid flashing loading screen
            final currentSession = Supabase.instance.client.auth.currentSession;
            if (snapshot.connectionState == ConnectionState.waiting && currentSession == null) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final session = snapshot.hasData ? snapshot.data!.session : currentSession;
            if (session != null) {
              return const RoleSelectionScreen();
            }
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}
