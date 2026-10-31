import 'package:flutter/material.dart';
import 'package:bluefarm/services/auth_service.dart';
import 'package:bluefarm/services/ui_feedback_service.dart';
import 'package:bluefarm/services/demo_mode_service.dart';
import '../widgets/bounce_button.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'privacy_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool _loading = false;
  bool _usePasswordMode = false;
  bool _obscurePassword = true;
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    identifierController.addListener(_onIdentifierChanged);
  }

  void _onIdentifierChanged() {
    final text = identifierController.text.trim().toLowerCase();
    if (DemoModeService.isReviewerIdentifier(text) && !_usePasswordMode) {
      setState(() {
        _usePasswordMode = true;
        if (passwordController.text.isEmpty) {
          passwordController.text = DemoModeService.reviewerPassword;
        }
      });
    }
  }

  @override
  void dispose() {
    identifierController.removeListener(_onIdentifierChanged);
    _entryCtrl.dispose();
    identifierController.dispose();
    passwordController.dispose();
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

  Future<void> _signInWithPassword() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();

    if (identifier.isEmpty) {
      UIFeedback.showInfo(context, "Please enter your email or username");
      return;
    }
    if (password.isEmpty) {
      UIFeedback.showInfo(context, "Please enter your password");
      return;
    }

    setState(() => _loading = true);

    // 1. Reviewer / Demo bypass
    if (DemoModeService.isReviewerCredential(identifier, password) ||
        (DemoModeService.isReviewerIdentifier(identifier) &&
            password == DemoModeService.reviewerPassword)) {
      UIFeedback.showSuccess(context, "Reviewer demo session activated!");
      await DemoModeService.startDemoSession(context, role: 'farmer');
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 2. Standard authentication
    try {
      final res = await AuthService().signInWithEmailAndPassword(
        identifier: identifier,
        password: password,
      );
      if (res.user != null && mounted) {
        await AuthService().handleLoginRedirect(context);
      }
    } catch (e) {
      // If reviewer account isn't yet created in Supabase auth, fall back safely
      if (DemoModeService.isReviewerIdentifier(identifier)) {
        if (mounted) {
          UIFeedback.showSuccess(context, "Reviewer demo session activated!");
          await DemoModeService.startDemoSession(context, role: 'farmer');
        }
      } else if (mounted) {
        UIFeedback.showError(context, "Login failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showReviewerDemoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF1565C0),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Google Play Reviewer / Demo",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F2B5B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Sample data • Non-sensitive evaluation mode",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                "This mode allows Google reviewers to test farm profiles, IoT telemetry, feeding logs, and market tools with sample data. Demo mode does NOT grant real government Aadhaar verification or certify identity.",
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 18),
            BounceButton(
              onPressed: () {
                Navigator.pop(ctx);
                DemoModeService.startDemoSession(context, role: 'farmer');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Explore as Aquaculture Farmer (Demo)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            BounceButton(
              onPressed: () {
                Navigator.pop(ctx);
                DemoModeService.startDemoSession(context, role: 'buyer');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_rounded, color: Color(0xFF0F2B5B), size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Explore as Fish Buyer / Exporter (Demo)",
                      style: TextStyle(
                        color: Color(0xFF0F2B5B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/assets/bg-screens.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
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
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0F2B5B),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.water_drop_rounded,
                                  size: 48,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
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
                              if (_usePasswordMode || DemoModeService.isReviewerIdentifier(identifierController.text)) ...[
                                const SizedBox(height: 14),
                                TextField(
                                  controller: passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    color: Color(0xFF0D1F3C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF5A789E).withValues(alpha: 0.7),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF5A789E),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: const Color(0xFF5A789E),
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                              ],
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _usePasswordMode = !_usePasswordMode;
                                    });
                                  },
                                  child: Text(
                                    _usePasswordMode ? "Sign in using OTP instead" : "Sign in with Password (Reviewer)",
                                    style: const TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Login Button
                              BounceButton(
                                onPressed: _loading ? null : (_usePasswordMode ? _signInWithPassword : _sendOtp),
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
                                        : Text(
                                            _usePasswordMode ? "SIGN IN" : "GET OTP",
                                            style: const TextStyle(
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
                    
                    const SizedBox(height: 20),

                    // Google Play Reviewer / Demo Access Card Button
                    FadeTransition(
                      opacity: _fadeAt(0.35, 0.75),
                      child: SlideTransition(
                        position: _slideAt(0.35, 0.75),
                        child: BounceButton(
                          onPressed: () => _showReviewerDemoSheet(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  color: Color(0xFF1565C0),
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Explore Demo / Reviewer Mode",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F2B5B),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Google Play Review • Sample Data & Mock Identity",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
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
                              mainAxisSize: MainAxisSize.min,
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
                                const Flexible(
                                  child: Text(
                                    "Continue with Google",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D1F3C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAt(0.5, 0.9),
                      child: SlideTransition(
                        position: _slideAt(0.5, 0.9),
                        child: BounceButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: Color(0xFF1565C0),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Privacy Policy",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
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
      ],
    ),
  );
  }
}
