import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ui_feedback_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'bluefarm1572@gmail.com',
      query: 'subject=BlueFarm%20Privacy%20Request',
    );
    try {
      if (!await launchUrl(emailUri)) {
        if (context.mounted) {
          UIFeedback.showError(context, 'Could not launch email client.');
        }
      }
    } catch (_) {
      if (context.mounted) {
        UIFeedback.showError(context, 'Could not launch email client.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const darkBlue = Color(0xFF0F2B5B);
    const textColor = Color(0xFF1E293B);
    const mutedColor = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: darkBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact Privacy Support',
            icon: const Icon(Icons.mail_outline_rounded,
                color: primaryBlue, size: 22),
            onPressed: () => _launchEmail(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "BlueFarm Privacy Policy",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: darkBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Effective Date: October 27, 2026",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                      Divider(height: 24, color: borderColor),
                      Text(
                        "BlueFarm helps aquaculture farmers manage farm profiles and access aquaculture-related information, including nearby fish markets, collection hubs and cold-storage facilities. This policy explains what information BlueFarm processes, why it is used, and the choices available to you.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Privacy Highlights Callout Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: primaryBlue, width: 4),
                      top: BorderSide(color: Color(0xFFBFDBFE)),
                      right: BorderSide(color: Color(0xFFBFDBFE)),
                      bottom: BorderSide(color: Color(0xFFBFDBFE)),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Privacy Highlights",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Aadhaar document images and Aadhaar numbers are processed locally on your device for verification and are not uploaded to BlueFarm servers. BlueFarm stores a readable farm-location address and related region/PIN-code text. Live GPS coordinates used to find nearby markets are held temporarily in memory and are not stored in the BlueFarm database.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 1
                _buildSectionCard(
                  title: "1. Information We Collect or Process",
                  children: const [
                    _BulletItem(
                      title: "Account Information",
                      body:
                          "Information you provide to register or sign in, such as your email address and authentication-related identifiers.",
                    ),
                    _BulletItem(
                      title: "Profile and Farm Information",
                      body:
                          "Details you enter during onboarding or profile editing, which may include your name, age, phone number, farm name, pond area, waterbody type, species, region, PIN code, and farm address.",
                    ),
                    _BulletItem(
                      title: "Farm Location Text",
                      body:
                          "When you choose automatic location detection, BlueFarm may reverse-geocode device coordinates into a readable address and save that address in your profile. Region and PIN code may also be saved. If reverse geocoding fails, a coordinate string may be saved in the address field. You may manually edit your location text.",
                    ),
                    _BulletItem(
                      title: "Water-Quality and Farm Readings",
                      body:
                          "Sensor readings or monitoring information that you submit or connect to BlueFarm, where those features are enabled.",
                    ),
                    _BulletItem(
                      title: "Aadhaar Verification Result",
                      body:
                          "The app may store a boolean verification status (for example, aadhaar_verified) in your profile.",
                    ),
                    _BulletItem(
                      title: "Technical Information",
                      body:
                          "The app platform and diagnostic information may be processed by the operating system, Google Play, or infrastructure providers as part of operating, securing, and troubleshooting the service.",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 2
                _buildSectionCard(
                  title: "2. Aadhaar Document Processing",
                  children: const [
                    Text(
                      "When you choose to scan or select an Aadhaar image for verification, BlueFarm uses on-device text recognition through Google ML Kit to check for government-issuer text, a 12-digit Aadhaar-number pattern, and a name match. In this described flow, text recognition occurs on your device. BlueFarm does not upload or store the Aadhaar image, full Aadhaar number, Aadhaar address, or date of birth on its servers. The image is held temporarily on the device for the session, and the app stores only the verification-status flag. Do not use the verification feature if you do not wish to provide the document for local processing.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 3
                _buildSectionCard(
                  title: "3. How We Use Information",
                  children: const [
                    Text(
                      "BlueFarm uses information to create and manage accounts, display and update farmer profiles, support farm-management features, show relevant aquaculture resources, find nearby markets when requested, perform the selected verification flow, maintain security, troubleshoot errors, and respond to support or privacy requests.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 4
                _buildSectionCard(
                  title: "4. Location and Third-Party Services",
                  children: const [
                    _BulletItem(
                      title: "Device Location",
                      body:
                          "BlueFarm requests location access when you initiate a feature that needs it. The app does not continuously track your movements or run background location tracking. Live coordinates used by the 'Market Near Me' feature are used temporarily in memory to find nearby facilities and calculate distances, and are not saved to the BlueFarm database.",
                    ),
                    _BulletItem(
                      title: "OpenStreetMap Nominatim",
                      body:
                          "When you request automatic address detection, coordinates may be sent to the Nominatim geocoding service to obtain a readable address. The resulting address text, region, and PIN code may then be saved to your BlueFarm profile. Nominatim is a third-party service governed by its own terms and privacy practices.",
                    ),
                    _BulletItem(
                      title: "Supabase",
                      body:
                          "BlueFarm uses Supabase for authentication and database storage of account/profile information and other data described above. Information stored there is subject to the app's configuration and the provider's infrastructure and privacy terms.",
                    ),
                    _BulletItem(
                      title: "Google ML Kit",
                      body:
                          "The described Aadhaar text recognition is performed on-device; the Aadhaar image is not sent by BlueFarm to a remote OCR server in this flow.",
                    ),
                    _BulletItem(
                      title: "Google Play and Device Providers",
                      body:
                          "They may process information under their own policies in connection with app distribution, device operation, security, and diagnostics.",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 5
                _buildSectionCard(
                  title: "5. When Information Is Shared",
                  children: const [
                    Text(
                      "BlueFarm does not sell your personal information. Information may be processed by service providers where needed to operate the app, as described in this policy, or disclosed where required by law, to protect users and the service, or to address security or abuse. We do not intend to share Aadhaar images or full Aadhaar numbers with BlueFarm servers or service providers.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 6
                _buildSectionCard(
                  title: "6. Storage, Security and Retention",
                  children: const [
                    Text(
                      "Profile information is stored in the BlueFarm backend while needed to provide the service. Live coordinates used for nearby-market calculations are temporary and are not written to the BlueFarm database. Aadhaar images and numbers are not retained by BlueFarm servers in the described verification flow. We use the security controls available through the app and its infrastructure, but no method of electronic storage or transmission can be guaranteed to be completely secure. Retention of information held by third-party providers may be governed by their own policies.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 7
                _buildSectionCard(
                  title: "7. Your Choices and Account Deletion",
                  children: [
                    const Text(
                      "You can edit profile and farm-location text in the app where those features are available, and you can choose whether to grant location permission. To request account deletion or ask us to access, correct, or delete information associated with your account, email us with 'BlueFarm privacy request' in the subject line.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _launchEmail(context),
                      icon: const Icon(Icons.email_outlined,
                          size: 16, color: primaryBlue),
                      label: const Text(
                        "Email bluefarm1572@gmail.com",
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 8
                _buildSectionCard(
                  title: "8. Children's Privacy",
                  children: const [
                    Text(
                      "BlueFarm is intended for individuals involved in aquaculture and farm management, not for children. If you believe a child has provided personal information to BlueFarm, contact us so we can review the request.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 9
                _buildSectionCard(
                  title: "9. Changes to This Policy",
                  children: const [
                    Text(
                      "We may update this policy as BlueFarm's features, data practices, or legal requirements change. The updated policy will be published at this address with a revised effective date. Please review it periodically.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 10
                _buildSectionCard(
                  title: "10. Contact Us",
                  children: [
                    const Text(
                      "For questions, concerns, or privacy and account-deletion requests, contact:",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business_rounded,
                              color: primaryBlue, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "BlueFarm Privacy Support",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: darkBlue,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "bluefarm1572@gmail.com",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _launchEmail(context),
                            child: const Text(
                              "Send Email",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Clean Footer Copyright
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "© 2026 BlueFarm. All rights reserved.",
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    const darkBlue = Color(0xFF0F2B5B);
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String title;
  final String body;

  const _BulletItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: textColor,
                ),
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F2B5B),
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
