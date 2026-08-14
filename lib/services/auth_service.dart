import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  // Use the Web Client ID for Google Auth
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '52765421109-bb752c0s1v5sah837jf999io3lbp1rgg.apps.googleusercontent.com' : null,
    serverClientId: '52765421109-bb752c0s1v5sah837jf999io3lbp1rgg.apps.googleusercontent.com',
    scopes: ['email'],
  );

  Future<void> signInWithGoogle() async {
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
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      // Formats expected by Supabase (e.g. +91...)
      await _auth.signInWithOtp(
        phone: phone,
      );
      // Pass phone instead of verificationId for Supabase
      onCodeSent(phone);
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
}
