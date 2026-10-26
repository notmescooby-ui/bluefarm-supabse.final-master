import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../screens/main_shell.dart';
import '../screens/buyer_shell.dart';
import '../screens/login_screen.dart';

class DemoModeService {
  static bool isDemoMode = false;
  static String demoRole = 'farmer';

  static const String reviewerEmail = 'bluefarm1572@gmail.com';
  static const String reviewerPassword = 'bfarm1572';
  static const String reviewerTestOtp = '123456';
  static const String reviewerAltOtp = '157200';

  static final Map<String, dynamic> sampleFarmerProfile = {
    'id': 'demo-reviewer-farmer-01',
    'full_name': 'Google Play Reviewer',
    'email': reviewerEmail,
    'phone': '+91 98765 43210',
    'role': 'farmer',
    'farm_name': 'BlueFarm Demo Aqua Farm',
    'age': 38,
    'farm_size': '4.5 Acres',
    'waterbody_type': 'Pond (Brackish)',
    'fish_species': 'Vannamei Shrimp',
    'secondary_species': 'Tilapia',
    'stocking_density': '40 pcs/sq.m',
    'pincode': '534202',
    'region': 'Bhimavaram, Andhra Pradesh, India',
    'gps_address': 'Bhimavaram Rural Aquaculture Zone',
    'aadhaar_verified': false,
    'is_demo': true,
    'demo_verified': true,
    'verification_note':
        'Demo account for Google Play App Review. Sample data only. No real identity certified.',
    'account_status': 'demo_review',
  };

  static final Map<String, dynamic> sampleBuyerProfile = {
    'id': 'demo-reviewer-buyer-01',
    'full_name': 'Google Play Reviewer',
    'email': reviewerEmail,
    'phone': '+91 98765 43210',
    'role': 'buyer',
    'company_name': 'Aqua Exports Ltd (Demo)',
    'buyer_type': 'Exporters / Processors',
    'pincode': '530001',
    'region': 'Visakhapatnam, Andhra Pradesh, India',
    'gps_address': 'Port Road, Visakhapatnam, India',
    'aadhaar_verified': false,
    'is_demo': true,
    'demo_verified': true,
    'verification_note':
        'Demo account for Google Play App Review. Sample data only. No real identity certified.',
    'account_status': 'demo_review',
  };

  static bool isReviewerIdentifier(String? identifier) {
    if (identifier == null) return false;
    final clean = identifier.trim().toLowerCase();
    return clean == reviewerEmail.toLowerCase() ||
        clean == 'bfarmreview' ||
        clean == 'demo' ||
        clean == 'reviewer';
  }

  static bool isReviewerCredential(String? identifier, String? password) {
    if (!isReviewerIdentifier(identifier)) return false;
    return password != null &&
        (password.trim() == reviewerPassword || password.trim() == '123456');
  }

  static bool isReviewerOtp(String? otp) {
    if (otp == null) return false;
    final clean = otp.trim();
    return clean == reviewerTestOtp ||
        clean == reviewerAltOtp ||
        clean == reviewerPassword;
  }

  static Future<void> startDemoSession(
    BuildContext context, {
    String role = 'farmer',
  }) async {
    isDemoMode = true;
    demoRole = role;

    final profile =
        role == 'buyer' ? sampleBuyerProfile : sampleFarmerProfile;

    try {
      final appProvider = context.read<AppProvider>();
      appProvider.setDemoProfile(profile);
    } catch (_) {}

    if (!context.mounted) return;

    if (role == 'buyer') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BuyerShell()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  static void exitDemoMode(BuildContext context) {
    isDemoMode = false;
    demoRole = 'farmer';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
