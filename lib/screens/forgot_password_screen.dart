import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:bluefarm/services/auth_service.dart';
import 'package:bluefarm/services/ui_feedback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bounce_button.dart';
import 'reset_password_success_screen.dart';
import 'reset_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
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

  Future<void> _resetPassword() async {
    final identifier = identifierController.text.trim();

    if (identifier.isEmpty) {
      UIFeedback.showInfo(context, "Please enter your email or mobile number");
      return;
    }

    setState(() => _loading = true);
    
    // Check if it's an email or a phone number
    if (identifier.contains('@')) {
      try {
        await AuthService().resetPassword(identifier);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResetPasswordSuccessScreen()),
          );
        }
      } on AuthException catch (e) {
        if (mounted) UIFeedback.showError(context, e.message);
      } catch (e) {
        if (mounted) UIFeedback.showError(context, "Failed to send reset link. Please try again.");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // It's a phone number - send OTP
      try {
        // Strip spaces and ensure it has country code for Supabase phone auth
        String phone = identifier.replaceAll(RegExp(r'\s+'), '');
        if (!phone.startsWith('+')) {
           // Default to India if no country code provided
           phone = '+91$phone'; 
        }
        
        await AuthService().verifyPhone(
          phone: phone,
          onCodeSent: (verificationId) {
            if (mounted) {
              UIFeedback.showSuccess(context, "OTP sent to your phone");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResetPasswordOtpScreen(phone: phone),
                ),
              );
            }
          },
          onError: (error) {
            if (mounted) {
              UIFeedback.showError(context, error);
              setState(() => _loading = false);
            }
          },
        );
      } catch (e) {
        if (mounted) {
          UIFeedback.showError(context, "Failed to send OTP.");
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.oceanGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                        "Reset Password",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _fadeAt(0.15, 0.55),
                      child: Text(
                        "Enter your registered email or mobile number to receive reset instructions.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
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
                              // Email / Mobile Field
                              TextField(
                                controller: identifierController,
                                style: const TextStyle(
                                  color: Color(0xFF0D1F3C),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Email or Mobile Number",
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF5A789E).withValues(alpha: 0.7),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
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
                              
                              // Send Link Button
                              BounceButton(
                                onPressed: _loading ? null : _resetPassword,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50), 
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
                                            "SEND RESET LINK",
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
                            ],
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
