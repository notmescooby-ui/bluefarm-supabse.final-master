import 'package:flutter/material.dart';
import '../widgets/bounce_button.dart';
import '../localization/app_translations.dart';
import 'login_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with TickerProviderStateMixin {
  String selectedLanguage = "en";
  late AnimationController _staggerCtrl;
  late AnimationController _buttonCtrl;

  static const _languages = [
    ('en', 'English', 'ENGLISH', '🇬🇧'),
    ('hi', 'हिंदी', 'HINDI', '🇮🇳'),
    ('mr', 'मराठी', 'MARATHI', '🇮🇳'),
    ('te', 'తెలుగు', 'TELUGU', '🇮🇳'),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _buttonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _buttonCtrl.forward();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _buttonCtrl.dispose();
    super.dispose();
  }

  Animation<double> _staggeredFade(int index) {
    final start = index * 0.12;
    final end = (start + 0.35).clamp(0.0, 1.0);
    return Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _staggeredSlide(int index) {
    final start = index * 0.12;
    final end = (start + 0.35).clamp(0.0, 1.0);
    return Tween(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'lib/assets/bg-screens.png',
            fit: BoxFit.cover,
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Translation Icon
                  FadeTransition(
                    opacity: _staggeredFade(0),
                    child: SlideTransition(
                      position: _staggeredSlide(0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Header Title
                  FadeTransition(
                    opacity: _staggeredFade(0),
                    child: const Text(
                      "Choose your language",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Subtitle
                  FadeTransition(
                    opacity: _staggeredFade(0),
                    child: Text(
                      "You can change this anytime in settings",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Language cards
                  Column(
                    children: List.generate(_languages.length, (i) {
                      final (code, title, sub, flag) = _languages[i];
                      final selected = selectedLanguage == code;

                      return FadeTransition(
                        opacity: _staggeredFade(i + 1),
                        child: SlideTransition(
                          position: _staggeredSlide(i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: BounceButton(
                              onPressed: () {
                                setState(() {
                                  selectedLanguage = code;
                                  AppTranslations.currentLanguage = code;
                                });
                              },
                              child: AnimatedScale(
                                scale: selected ? 1.03 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    // Highlight selected box with white/light-green background
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      // Thicker green/accent border for selected box
                                      color: selected
                                          ? const Color(0xFF059669)
                                          : Colors.transparent,
                                      width: selected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selected
                                            ? Colors.black.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.04),
                                        blurRadius: selected ? 24 : 10,
                                        offset: selected ? const Offset(0, 8) : const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Text(flag, style: const TextStyle(fontSize: 28)),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: selected
                                                    ? const Color(0xFF0D1F3C)
                                                    : const Color(0xFF5A789E),
                                              ),
                                            ),
                                            Text(
                                              sub,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: selected
                                                    ? const Color(0xFF059669).withValues(alpha: 0.7)
                                                    : const Color(0xFF5A789E).withValues(alpha: 0.6),
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedScale(
                                        scale: selected ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.elasticOut,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF059669),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Continue button
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _buttonCtrl,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _buttonCtrl,
                        curve: Curves.easeOutCubic,
                      )),
                      child: BounceButton(
                        onPressed: () {
                          AppTranslations.setLanguage(selectedLanguage);
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 600),
                              pageBuilder: (_, __, ___) => const LoginScreen(),
                              transitionsBuilder: (_, anim, __, child) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: anim,
                                      curve: Curves.easeOutCubic,
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Continue",
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
