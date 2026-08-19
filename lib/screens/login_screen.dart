import 'package:flutter/material.dart';
import 'package:bluefarm/services/auth_service.dart';
import 'package:bluefarm/services/ui_feedback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bounce_button.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final identifierController = TextEditingController();
  
  bool _loading = false;
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    identifierController.dispose();
    super.dispose();
  }

  Animation<double> _fadeAt(double start, double end) {
    return Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<Offset> _slideAt(double start, double end) {
    return Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await AuthService().signInWithGoogle(isLogin: true);
      if (mounted) {
        await AuthService().handleLoginRedirect(context);
      }
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, "Google Sign-In failed: ${e.toString()}");
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendOtp() async {
    final identifier = identifierController.text.trim();
    if (identifier.isEmpty) {
      UIFeedback.showInfo(context, "Please enter an email or phone number");
      return;
    }

    final isEmail = identifier.contains('@');
    if (!isEmail && identifier.length < 10) {
      UIFeedback.showInfo(context, "Please enter a valid phone number");
      return;
    }

    setState(() => _loading = true);

    if (isEmail) {
      await AuthService().sendEmailOtp(
        email: identifier,
        shouldCreateUser: false,
        onCodeSent: () {
          if (mounted) {
            UIFeedback.showSuccess(context, "OTP sent successfully to email");
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => OtpScreen(identifier: identifier, isLogin: true, isEmail: true),
                transitionDuration: const Duration(milliseconds: 600),
                transitionsBuilder: (_, anim, __, child) {
                  return FadeTransition(opacity: anim, child: child);
                }
              )
            );
          }
        },
        onError: (e) {
          if (mounted) {
            UIFeedback.showError(context, e);
            setState(() => _loading = false);
          }
        }
      );
    } else {
      await AuthService().verifyPhone(
        phone: identifier,
        shouldCreateUser: false,
        onCodeSent: (vid) {
          if (mounted) {
            UIFeedback.showSuccess(context, "OTP sent successfully to phone");
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => OtpScreen(identifier: identifier, verificationId: vid, isLogin: true, isEmail: false),
                transitionDuration: const Duration(milliseconds: 600),
                transitionsBuilder: (_, anim, __, child) {
                  return FadeTransition(opacity: anim, child: child);
                }
              )
            );
          }
        },
        onError: (e) {
          if (mounted) {
            UIFeedback.showError(context, e);
            setState(() => _loading = false);
          }
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.oceanGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fadeAt(0.0, 0.4),
                      child: SlideTransition(
                        position: _slideAt(0.0, 0.4),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              "lib/assets/logo.png",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAt(0.1, 0.5),
                      child: const Text(
                        "BlueFarm Login",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _fadeAt(0.2, 0.6),
                      child: SlideTransition(
                        position: _slideAt(0.2, 0.6),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field
                              TextField(
                                controller: identifierController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: Color(0xFF0D1F3C),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Email or Phone Number",
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF5A789E).withValues(alpha: 0.7),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.account_circle_outlined,
                                    color: Color(0xFF5A789E),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Login Button
                              BounceButton(
                                onPressed: _loading ? null : _sendOtp,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50), // Standard green from AgriYukt reference
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            "GET OTP",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Fixed pixel overflow using Wrap
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      color: Color(0xFF5A789E),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context, 
                                        MaterialPageRoute(builder: (_) => const SignupScreen())
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      "Create your account",
                                      style: TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Google Sign In Button
                    FadeTransition(
                      opacity: _fadeAt(0.4, 0.8),
                      child: SlideTransition(
                        position: _slideAt(0.4, 0.8),
                        child: BounceButton(
                          onPressed: _loading ? null : signInWithGoogle,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  "https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png",
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Text(
                                    "G",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D1F3C),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
  }
}
