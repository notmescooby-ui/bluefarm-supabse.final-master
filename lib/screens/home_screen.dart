import 'package:flutter/material.dart';
import 'package:bluefarm/widgets/animated_banner.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/sensor_data.dart';
import 'recommendation_questionnaire_screen.dart';
import 'market_near_me_screen.dart';
import 'feeder_automate_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return "morning";
    if (h < 17) return "afternoon";
    return "evening";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, store, _) {
        final r = store.latestReading ?? SensorData.demo;
        final isConnected = store.isDeviceConnected;

        // Determine worst status
        String worst = "good";
        if (r.phStatus == "CRITICAL" || r.tempStatus == "CRITICAL" || r.turbStatus == "CRITICAL") {
          worst = "critical";
        } else if (r.phStatus == "WARNING" || r.tempStatus == "WARNING" || r.turbStatus == "WARNING") {
          worst = "warning";
        }

        String headline = worst == "good" ? "Water is calm,\nwith no alerts." : worst == "warning" ? "Water is calm,\nwith one note." : "Action needed\nimmediately.";
        String headlineDesc = worst == "good"
            ? "Your pond is inside every safe range."
            : worst == "warning"
                ? "One reading is drifting — check the details below."
                : "One reading is out of range. Open it for what to do next.";

        Color headlineColor = worst == "good" ? const Color(0xFF059669) : worst == "warning" ? const Color(0xFFD97706) : const Color(0xFFDC2626);

        final farmerName = ((store.userProfile ?? {})['full_name'] ?? (store.userProfile ?? {})['name'] ?? 'Farmer').split(' ')[0];
        final farmName = (store.userProfile ?? {})['farm_name'] ?? "Your farm";
        final initial = farmerName.isNotEmpty ? farmerName[0].toUpperCase() : 'F';

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F5), // Cream
          body: CustomScrollView(
            slivers: [
              // AppHeader
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20, right: 20, bottom: 20,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "BlueFarm",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F1A2A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "FARMER WORKSPACE",
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1A2A).withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF0F1A2A),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // AnimatedBanner (Image based)
                    _buildAnimatedBanner(context, farmerName),
                    const SizedBox(height: 20),

                    // Headline (Redesigned matching React)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "RIGHT NOW · YOUR POND",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280), // Ink-muted
                          ),
                        ),
                        const SizedBox(height: 24),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            headline,
                            style: const TextStyle(
                              fontSize: 36,
                              height: 1.05,
                              letterSpacing: -0.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F1A2A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          headlineDesc,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280), // Ink-muted
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Readings
                    _StatCard(
                      icon: Icons.thermostat,
                      label: "Temperature",
                      value: r.temperature.toStringAsFixed(1),
                      unit: "°C",
                      isNormal: r.tempIsNormal,
                      safeRange: "24-30 °C",
                    ),
                    const SizedBox(height: 12),
                    _StatCard(
                      icon: Icons.water_drop,
                      label: "pH",
                      value: r.ph.toStringAsFixed(1),
                      unit: "",
                      isNormal: r.phIsNormal,
                      safeRange: "6.5-8.5",
                    ),
                    const SizedBox(height: 12),
                    _StatCard(
                      icon: Icons.cloud,
                      label: "Turbidity",
                      value: r.turbidity.toStringAsFixed(1),
                      unit: "NTU",
                      isNormal: r.turbIsNormal,
                      safeRange: "1-100 NTU",
                    ),
                    const SizedBox(height: 20),

                    // Smart recommendations
                    if (worst != "good") ...[
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text(
                            "Action Required",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "One or more pond parameters are out of safe range. Analyze the issue now to get an AI-driven smart recommendation plan.",
                              style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  String param = "pH";
                                  if (r.tempStatus == "CRITICAL" || r.tempStatus == "WARNING") {
                                    param = "Temperature";
                                  } else if (r.turbStatus == "CRITICAL" || r.turbStatus == "WARNING") param = "Turbidity";
                                  
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => RecommendationQuestionnaireScreen(
                                    parameter: param,
                                    sensorData: r,
                                  )));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text("Analyze Issue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text(
                            "Smart recommendations",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: const Text(
                          "Pond conditions are healthy. No immediate action required.",
                          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Feeder Automation Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.set_meal_rounded, size: 20, color: Color(0xFF1565C0)),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Feeder Automation",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: store.isFeederOn
                                ? const Color(0xFF059669).withValues(alpha: 0.12)
                                : const Color(0xFF1565C0).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: store.isFeederOn
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                store.isFeederOn ? "FEEDING ACTIVE" : "SMART IOT",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: store.isFeederOn
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (widget.onNavigateToTab != null) {
                          widget.onNavigateToTab!(1);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FeederAutomateScreen(),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: store.isFeederOn
                                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                                          : [const Color(0xFF0F2B5B), const Color(0xFF1565C0)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (store.isFeederOn
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF1565C0))
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.set_meal_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Flexible(
                                            child: Text(
                                              "Automated Pond Feeder",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0D1F3C),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (store.isFeederOn
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFF6B7280))
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              store.isFeederOn ? "ON" : "OFF",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: store.isFeederOn
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        store.isFeederOn
                                            ? "Dispensing feed into pond · Gate ${store.servoAngle}°"
                                            : "Schedule active · Hopper ${store.hopperLevel.toInt()}% full",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: Color(0xFFF1F1F1)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      if (store.isFeederOn) {
                                        store.turnOffFeeder();
                                      } else {
                                        store.turnOnFeeder();
                                      }
                                    },
                                    icon: Icon(
                                      store.isFeederOn
                                          ? Icons.power_settings_new_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 16,
                                      color: store.isFeederOn
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF059669),
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        store.isFeederOn ? "Turn OFF" : "Quick Feed ON",
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: store.isFeederOn
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: store.isFeederOn
                                            ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                                            : const Color(0xFF059669).withValues(alpha: 0.4),
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (widget.onNavigateToTab != null) {
                                        widget.onNavigateToTab!(1);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const FeederAutomateScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.tune_rounded,
                                        size: 16, color: Colors.white),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "Configure",
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Market Near Me Feature Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF1565C0)),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Market Near Me",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "MAPS & BUYERS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (widget.onNavigateToTab != null) {
                          widget.onNavigateToTab!(2);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MarketNearMeScreen(isFarmer: true),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.pin_drop_rounded,
                                color: Color(0xFF1565C0),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Find Local Markets & Buyers",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D1F3C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Locate nearby fish collection centres, cold storage & registered buyers with GPS navigation",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Padding for bottom nav
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8), // Flat modern radius
      border: Border.all(
        color: const Color(0xFFE5E5E0), // Hairline
        width: 1,
      ),
    );
  }

  Widget _buildAnimatedBanner(BuildContext context, String farmerName) {
    return AnimatedBanner(
      title: 'Namaste, $farmerName!',
      subtitle: 'Your ponds are being watched over.',
      ctaText: 'View Pond',
      onCtaPressed: () {
        // Implement view pond action or navigate to insights
      },
      imagePath: 'lib/assets/aquaculture-bg.png',
    );
  }

  Widget _buildRec(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0D1F3C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _StatusDot extends StatefulWidget {
  final bool isGood;
  const _StatusDot({required this.isGood});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: widget.isGood ? const Color(0xFF059669).withValues(alpha: 0.5 + 0.5 * _ctrl.value) : const Color(0xFFD97706).withValues(alpha: 0.5 + 0.5 * _ctrl.value),
            shape: BoxShape.circle,
          ),
        );
      }
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool isNormal;
  final String safeRange;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.isNormal,
    required this.safeRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE5E5E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1F3C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Safe: $safeRange",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D1F3C),
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isNormal ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isNormal ? "GOOD" : "WARNING",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
