import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/demo_mode_service.dart';

import 'home_screen.dart';
import 'feeder_automate_screen.dart';
import 'knowledge_screen.dart';
import 'insights_screen.dart';
import 'harvest_screen.dart';
import 'market_near_me_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().loadAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Column(
          children: [
            if (DemoModeService.isDemoMode)
              Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFBFDBFE), width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 4,
                    bottom: 6,
                    left: 12,
                    right: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Demo Review Mode • Sample Data (Identity Not Certified)",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => DemoModeService.exitDemoMode(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Exit Demo",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: [
                      HomeScreen(
                        onNavigateToTab: (index) => setState(() => _currentIndex = index),
                      ),
                      FeederAutomateScreen(
                        isTab: true,
                        onBackToHome: () => setState(() => _currentIndex = 0),
                      ),
                      const MarketNearMeScreen(isFarmer: true),
                      const HarvestScreen(),
                      const InsightsScreen(),
                      const KnowledgeScreen(),
                      const SettingsScreen(),
                    ],
                  ),

                  // Bottom Navigation Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
              padding: EdgeInsets.only(
                top: 7,
                bottom: 7 + MediaQuery.of(context).padding.bottom,
                left: 4,
                right: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
                border: const Border(
                  top: BorderSide(
                    color: Color(0xFFE5E5E0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_filled,
                    inactiveIcon: Icons.home_outlined,
                    label: 'Home',
                    isActive: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _buildNavItem(
                    icon: Icons.set_meal_rounded,
                    inactiveIcon: Icons.set_meal_outlined,
                    label: 'Feeder',
                    isActive: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _buildNavItem(
                    icon: Icons.near_me_rounded,
                    inactiveIcon: Icons.near_me_outlined,
                    label: 'Near Me',
                    isActive: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _buildNavItem(
                    icon: Icons.inventory_2_rounded,
                    inactiveIcon: Icons.inventory_2_outlined,
                    label: 'Harvest',
                    isActive: _currentIndex == 3,
                    onTap: () => setState(() => _currentIndex = 3),
                  ),
                  _buildNavItem(
                    icon: Icons.show_chart_rounded,
                    inactiveIcon: Icons.show_chart_rounded,
                    label: 'Insights',
                    isActive: _currentIndex == 4,
                    onTap: () => setState(() => _currentIndex = 4),
                  ),
                  _buildNavItem(
                    icon: Icons.auto_awesome_rounded,
                    inactiveIcon: Icons.auto_awesome_outlined,
                    label: 'Learn',
                    isActive: _currentIndex == 5,
                    onTap: () => setState(() => _currentIndex = 5),
                  ),
                  _buildNavItem(
                    icon: Icons.account_circle_rounded,
                    inactiveIcon: Icons.account_circle_outlined,
                    label: 'Account',
                    isActive: _currentIndex == 6,
                    onTap: () => setState(() => _currentIndex = 6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
    ),
  );
}

  Widget _buildNavItem({
    required IconData icon,
    required IconData inactiveIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? const Color(0xFF1565C0) : const Color(0xFF6B7280);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? icon : inactiveIcon, size: 21, color: color),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
