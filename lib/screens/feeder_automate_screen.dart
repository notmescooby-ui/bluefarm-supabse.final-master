import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ui_feedback_service.dart';

class FeederAutomateScreen extends StatefulWidget {
  final bool isTab;
  const FeederAutomateScreen({super.key, this.isTab = false});

  @override
  State<FeederAutomateScreen> createState() => _FeederAutomateScreenState();
}

class _FeederAutomateScreenState extends State<FeederAutomateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _burstTimer;
  int _burstSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _burstTimer?.cancel();
    super.dispose();
  }

  void _startBurstFeed(int seconds, AppProvider provider) {
    _burstTimer?.cancel();
    provider.turnOnFeeder();
    UIFeedback.showSuccess(
        context, "Feeder started for $seconds seconds burst feed");

    setState(() {
      _burstSecondsRemaining = seconds;
    });

    _burstTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_burstSecondsRemaining > 1) {
          _burstSecondsRemaining--;
        } else {
          _burstSecondsRemaining = 0;
          timer.cancel();
          provider.turnOffFeeder();
          UIFeedback.showInfo(context, "Burst feed completed. Gate closed.");
        }
      });
    });
  }

  void _showAddScheduleDialog(BuildContext context, AppProvider provider) {
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    final labelCtrl = TextEditingController(text: 'Morning Snack');
    double amount = 1.5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add Feeding Schedule",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1F3C),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Schedule Label",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g. Early Feeding",
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Feed Time",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E5E0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded,
                              size: 20, color: Color(0xFF1565C0)),
                          const SizedBox(width: 10),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1F3C),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            "Change",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Feed Amount (kg)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        "${amount.toStringAsFixed(1)} kg",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: amount,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: const Color(0xFF1565C0),
                    onChanged: (val) {
                      setSheetState(() => amount = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final formattedTime = selectedTime.format(context);
                        provider.addFeedingSchedule(
                          labelCtrl.text.trim().isEmpty
                              ? "Feed"
                              : labelCtrl.text.trim(),
                          formattedTime,
                          amount,
                        );
                        Navigator.pop(context);
                        UIFeedback.showSuccess(
                            context, "Scheduled feed saved for $formattedTime");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Save Schedule",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isOn = provider.isFeederOn;
        final angle = provider.servoAngle;
        final hopperPct = provider.hopperLevel;

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F5), // BlueFarm signature cream
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F1A2A), size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Feeder Automation",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1A2A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "POND #1 · SMART DISPENSER",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(0xFF059669),
                    ),
                    SizedBox(width: 6),
                    Text(
                      "ONLINE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: widget.isTab ? 110 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────────────────────────────────────────
                // HERO FEEDER SECTION WITH ICON & ON / OFF BUTTONS
                // ─────────────────────────────────────────────────────────────
                _buildHeroFeederCard(context, provider, isOn, angle),
                const SizedBox(height: 24),

                // ─────────────────────────────────────────────────────────────
                // AUTOMATION & SCHEDULE SECTION
                // ─────────────────────────────────────────────────────────────
                _buildAutomationSection(context, provider),
                const SizedBox(height: 24),

                // ─────────────────────────────────────────────────────────────
                // GATE SERVO CALIBRATION CARD
                // ─────────────────────────────────────────────────────────────
                _buildGateCalibrationCard(context, provider, angle),
                const SizedBox(height: 24),

                // ─────────────────────────────────────────────────────────────
                // HOPPER STORAGE CARD
                // ─────────────────────────────────────────────────────────────
                _buildHopperCard(context, provider, hopperPct),
                const SizedBox(height: 24),

                // ─────────────────────────────────────────────────────────────
                // FEEDING LOGS SECTION
                // ─────────────────────────────────────────────────────────────
                _buildFeedingLogs(context, provider),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HERO FEEDER CARD (Feeder Icon + Dedicated ON and OFF buttons)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroFeederCard(
      BuildContext context, AppProvider provider, bool isOn, int angle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn
              ? const Color(0xFF059669).withValues(alpha: 0.35)
              : const Color(0xFFE5E5E0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn
                ? const Color(0xFF059669).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Feeder Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isOn
                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOn
                        ? const Color(0xFF059669)
                        : const Color(0xFF9CA3AF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOn ? "FEEDER ACTIVE · DISPENSING" : "FEEDER STANDBY · GATE CLOSED",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isOn
                        ? const Color(0xFF059669)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── PROMINENT FEEDER ICON ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = isOn ? _pulseController.value : 0.0;
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn
                      ? const Color(0xFF059669).withValues(alpha: 0.08)
                      : const Color(0xFF1565C0).withValues(alpha: 0.05),
                  boxShadow: isOn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF059669)
                                .withValues(alpha: 0.2 + (0.2 * pulse)),
                            blurRadius: 28 + (12 * pulse),
                            spreadRadius: 4 + (4 * pulse),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isOn
                          ? [
                              const Color(0xFF059669),
                              const Color(0xFF10B981),
                            ]
                          : [
                              const Color(0xFF0F2B5B),
                              const Color(0xFF1565C0),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isOn
                            ? const Color(0xFF059669).withValues(alpha: 0.4)
                            : const Color(0xFF1565C0).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Feeder illustration icon
                      const Icon(
                        Icons.set_meal_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                      Positioned(
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "$angle°",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            isOn ? "Dispensing Feed into Pond" : "Automated Feeder Ready",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F1A2A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOn
                ? "Gate open at $angle° · Motor running"
                : "Tap 'Turn ON Feeder' to start manual dispense",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),

          if (_burstSecondsRemaining > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Burst Feed: $_burstSecondsRemaining s remaining",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── BENEATH THE FEEDER ICON: DEDICATED ON AND OFF BUTTONS ──────────
          Row(
            children: [
              // BUTTON: TURN ON FEEDER
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isOn
                        ? null
                        : () {
                            provider.turnOnFeeder();
                            UIFeedback.showSuccess(
                              context,
                              "Feeder turned ON! Dispenser gate opened to 90°",
                            );
                          },
                    icon: const Icon(Icons.power_settings_new_rounded,
                        size: 20, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Turn ON Feeder",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: const Color(0xFF059669), // Green
                      disabledBackgroundColor:
                          const Color(0xFF059669).withValues(alpha: 0.4),
                      elevation: isOn ? 0 : 3,
                      shadowColor:
                          const Color(0xFF059669).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // BUTTON: TURN OFF FEEDER
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: !isOn
                        ? null
                        : () {
                            provider.turnOffFeeder();
                            UIFeedback.showInfo(
                              context,
                              "Feeder turned OFF. Gate closed.",
                            );
                          },
                    icon: const Icon(Icons.power_off_rounded,
                        size: 20, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Turn OFF Feeder",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: const Color(0xFFDC2626), // Danger red
                      disabledBackgroundColor:
                          const Color(0xFFDC2626).withValues(alpha: 0.3),
                      elevation: !isOn ? 0 : 3,
                      shadowColor:
                          const Color(0xFFDC2626).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Burst shortcuts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Timed Burst:",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                _buildBurstChip("10 sec", () => _startBurstFeed(10, provider)),
                const SizedBox(width: 8),
                _buildBurstChip("30 sec", () => _startBurstFeed(30, provider)),
                const SizedBox(width: 8),
                _buildBurstChip("60 sec", () => _startBurstFeed(60, provider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurstChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1565C0).withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AUTOMATION & SCHEDULE SECTION
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAutomationSection(BuildContext context, AppProvider provider) {
    final isAuto = provider.isFeederAutoMode;
    final schedules = provider.feedingSchedules;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Smart Auto-Schedule",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1A2A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Feed fish according to scheduled timetable",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              Switch.adaptive(
                value: isAuto,
                activeColor: const Color(0xFF1565C0),
                onChanged: (val) {
                  provider.toggleFeederAutoMode(val);
                  UIFeedback.showInfo(
                    context,
                    val
                        ? "Auto-Feeding schedule enabled"
                        : "Auto-Feeding schedule paused",
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE5E5E0)),

          // Schedules list
          if (schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "No automated schedules configured.",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else
            ...List.generate(schedules.length, (idx) {
              final item = schedules[idx];
              final enabled = item['enabled'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEF0F2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: Color(0xFF1565C0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'] ?? "Feed Schedule",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F1A2A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${item['time']} · ${item['amount']} kg feed",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: enabled,
                      activeColor: const Color(0xFF059669),
                      onChanged: (val) {
                        provider.toggleSchedule(idx, val);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        provider.removeSchedule(idx);
                        UIFeedback.showInfo(context, "Schedule removed");
                      },
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showAddScheduleDialog(context, provider),
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1565C0)),
              label: const Text(
                "Add New Feeding Schedule",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GATE SERVO CALIBRATION CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGateCalibrationCard(
      BuildContext context, AppProvider provider, int angle) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dispenser Gate Angle",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1A2A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Servo Position (GPIO19 PWM)",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: angle > 0
                      ? const Color(0xFF059669).withValues(alpha: 0.12)
                      : const Color(0xFF6B7280).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  angle > 0 ? "GATE OPEN ($angle°)" : "GATE CLOSED (0°)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: angle > 0
                        ? const Color(0xFF059669)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF1565C0),
              inactiveTrackColor:
                  const Color(0xFF1565C0).withValues(alpha: 0.15),
              thumbColor: const Color(0xFF1565C0),
              overlayColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
              trackHeight: 6,
            ),
            child: Slider(
              min: 0,
              max: 90,
              divisions: 90,
              value: angle.toDouble(),
              onChanged: (v) => provider.updateServo(v.toInt()),
            ),
          ),

          Row(
            children: [
              _buildPresetButton(
                label: "0° (Close)",
                isActive: angle == 0,
                onTap: () => provider.updateServo(0),
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                label: "45° (Half)",
                isActive: angle == 45,
                onTap: () => provider.updateServo(45),
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                label: "90° (Full)",
                isActive: angle == 90,
                onTap: () => provider.updateServo(90),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFF1565C0).withValues(alpha: 0.1)
              : Colors.transparent,
          side: BorderSide(
            color: isActive ? const Color(0xFF1565C0) : const Color(0xFFE5E5E0),
            width: isActive ? 1.5 : 1.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? const Color(0xFF1565C0) : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HOPPER FEED STORAGE CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHopperCard(
      BuildContext context, AppProvider provider, double hopperPct) {
    final remainingKg = (hopperPct / 100 * 20.0).toStringAsFixed(1);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hopper Capacity & Feed Level",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1A2A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Pellet Feed 3.0mm · 20 kg max capacity",
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              Text(
                "${hopperPct.toInt()}%",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: hopperPct < 20
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hopperPct / 100,
              minHeight: 12,
              backgroundColor: const Color(0xFFE5E5E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                hopperPct < 20
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Estimated remaining: $remainingKg kg (~4 days)",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  provider.refillHopper();
                  UIFeedback.showSuccess(
                    context,
                    "Hopper level reset to 100% (20 kg refilled)",
                  );
                },
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: Color(0xFF1565C0)),
                label: const Text(
                  "Refill Hopper",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FEEDING LOGS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFeedingLogs(BuildContext context, AppProvider provider) {
    final logs = provider.feedingLogs;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Feeding Activity",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F1A2A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Real-time history of automated and manual feed dispenses",
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),

          ...logs.map((log) {
            final isSuccess = log['status'] == 'Success';
            final isActive = log['status'] == 'Active';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEF0F2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.motion_photos_paused_rounded
                        : isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.info_rounded,
                    size: 18,
                    color: isActive
                        ? const Color(0xFFD97706)
                        : isSuccess
                            ? const Color(0xFF059669)
                            : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${log['mode']} · ${log['amount']}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F1A2A),
                          ),
                        ),
                        Text(
                          log['time'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isActive
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log['status'] ?? 'Done',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFE5E5E0),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
