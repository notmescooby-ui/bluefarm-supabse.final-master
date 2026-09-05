import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bluefarm/screens/role_selection_screen.dart';
import 'package:bluefarm/services/ui_feedback_service.dart';

class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  Future<bool> checkProfileExists({String? email, String? phone}) async {
    try {
      final query = Supabase.instance.client.from('profiles').select('id');
      
      if (email != null && email.isNotEmpty) {
        final res = await query.eq('email', email.trim()).maybeSingle();
        return res != null;
      } else if (phone != null && phone.isNotEmpty) {
        final res = await query.eq('phone', phone.trim()).maybeSingle();
        return res != null;
      }
      return false;
    } catch (e) {
      debugPrint("Check Profile Error: $e");
      // If RLS prevents anonymous read, this might throw. Assuming public read for now.
      return false;
    }
  }

  // Use the Web Client ID for Google Auth
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '52765421109-bb752c0s1v5sah837jf999io3lbp1rgg.apps.googleusercontent.com' : null,
    serverClientId: '52765421109-bb752c0s1v5sah837jf999io3lbp1rgg.apps.googleusercontent.com',
    scopes: ['email'],
  );

  Future<void> signInWithGoogle({bool isLogin = false}) async {
    try {
      if (kIsWeb) {
        debugPrint("Google Auth: Using Supabase OAuth for Web...");
        await _auth.signInWithOAuth(OAuthProvider.google);
        return;
      }

      debugPrint("Google Auth: Attempting sign-out of previous session...");
      await _googleSignIn.signOut();

      debugPrint("Google Auth: Opening account picker...");
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("Google Auth: Flow cancelled by user.");
        return;
      }



      debugPrint("Google Auth: Getting authentication tokens...");
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception("Google Auth: Failed to retrieve ID Token.");
      }

      debugPrint("Google Auth: Exchanging tokens with Supabase...");

      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint("Google Auth: Success! User: ${_auth.currentUser?.email}");
    } catch (e) {
      debugPrint("Google Auth General Error: $e");
      rethrow;
    }
  }

  // --- SMS Logic (Supabase) ---
  Future<void> verifyPhone({
    required String phone,
    bool shouldCreateUser = true,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      // Formats expected by Supabase (e.g. +91...)
      await _auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: shouldCreateUser,
      );
      // Pass phone instead of verificationId for Supabase
      onCodeSent(phone);
    } on AuthException catch (e) {
      debugPrint("Phone AuthException: ${e.message}");
      if (e.message.toLowerCase().contains("signups not allowed") || e.message.toLowerCase().contains("user not found")) {
        onError("Account not found. Please create an account first.");
      } else {
        onError(e.message);
      }
    } catch (e) {
      debugPrint("Phone Auth Error: $e");
      onError(e.toString());
    }
  }

  Future<AuthResponse> verifyOTP(String phone, String smsCode) async {
    return await _auth.verifyOTP(
      type: OtpType.sms,
      token: smsCode,
      phone: phone,
    );
  }

  // --- Email OTP Logic ---
  Future<void> sendEmailOtp({
    required String email,
    bool shouldCreateUser = true,
    required Function() onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.signInWithOtp(email: email.trim(), shouldCreateUser: shouldCreateUser);
      onCodeSent();
    } on AuthException catch (e) {
      debugPrint("Email AuthException: ${e.message}");
      if (e.message.toLowerCase().contains("signups not allowed") || e.message.toLowerCase().contains("user not found")) {
        onError("Account not found. Please create an account first.");
      } else {
        onError(e.message);
      }
    } catch (e) {
      debugPrint("Email Auth Error: $e");
      onError(e.toString());
    }
  }

  Future<AuthResponse> verifyEmailOtp(String email, String token) async {
    return await _auth.verifyOTP(
      type: OtpType.email,
      token: token,
      email: email.trim(),
    );
  }

  String _normalizeIdentifier(String identifier) {
    identifier = identifier.trim();
    if (identifier.contains('@')) {
      return identifier;
    }
    // Process mobile number like a pseudo email (as per user request)
    String cleanNumber = identifier.replaceAll(RegExp(r'\s+'), '');
    return "$cleanNumber@gmail.com";
  }

  Future<AuthResponse> signInWithEmailAndPassword({
    required String identifier,
    required String password,
  }) async {
    final email = _normalizeIdentifier(identifier);
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailAndPassword({
    required String identifier,
    required String password,
  }) async {
    final email = _normalizeIdentifier(identifier);
    return await _auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword(String identifier) async {
    final email = _normalizeIdentifier(identifier);
    await _auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> handleLoginRedirect(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final doc = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (context.mounted) {
      if (doc != null && doc['full_name'] != null) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (r) => false);
      } else {
        // No profile -> Account not found
        await signOut();
        if (context.mounted) {
          UIFeedback.showError(context, "Account not found. Please create an account first.");
        }
      }
    }
  }

  Future<void> handleSignupRedirect(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final doc = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (context.mounted) {
      if (doc != null && doc['full_name'] != null) {
        // Already has an account, log them in
        UIFeedback.showSuccess(context, "Account already exists, logging you in.");
      }
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (r) => false);
    }
  }
}
