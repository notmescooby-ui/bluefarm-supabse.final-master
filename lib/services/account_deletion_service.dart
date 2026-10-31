import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui_feedback_service.dart';

/// Central configuration for BlueFarm account deletion redirection.
class AccountDeletionConfig {
  /// Publicly deployed account deletion URL.
  /// This route handles secure identity verification (via Supabase OTP)
  /// and account deletion request processing for both Farmer and Buyer accounts.
  static const String deletionUrl =
      'https://bluefarm-market.lovable.app/account-deletion';

  /// Fallback official production domain URL
  static const String fallbackDeletionUrl =
      'https://bluefarm.market/account-deletion';
}

/// Service providing reusable account deletion confirmation dialog
/// and redirection logic for both Farmer and Buyer profile screens.
class AccountDeletionService {
  /// Displays an explanation confirmation dialog to the user before redirecting
  /// them to the official BlueFarm account deletion portal.
  ///
  /// Returns `true` if the user confirmed and the browser was successfully launched,
  /// `false` if the user cancelled or if launch failed.
  static Future<bool> confirmAndRedirectToDeleteAccount(
    BuildContext context, {
    String role = 'account',
  }) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To permanently delete your BlueFarm account and associated personal data, you will be redirected to BlueFarm\'s official account deletion website.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before you continue:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Account ownership will be verified securely via a one-time code (OTP) sent to your registered email or phone.\n'
                      '• Active orders and legally mandated transaction records will be reviewed prior to deletion.\n'
                      '• Account deletion is permanent and irreversible.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF7F1D1D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancel_delete_account_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('continue_delete_account_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (proceed == true) {
      if (!context.mounted) return false;
      return await launchAccountDeletionPortal(context);
    }
    return false;
  }

  /// Opens the official BlueFarm account deletion web route in an external browser.
  static Future<bool> launchAccountDeletionPortal(
    BuildContext context, {
    String? overrideUrl,
  }) async {
    final targetUrl = overrideUrl ?? AccountDeletionConfig.deletionUrl;
    final Uri uri = Uri.parse(targetUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        UIFeedback.showError(
          context,
          'Could not launch account deletion portal. Please open: $targetUrl',
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        UIFeedback.showError(
          context,
          'Could not open account deletion link. Please visit: $targetUrl',
        );
      }
      return false;
    }
  }
}
