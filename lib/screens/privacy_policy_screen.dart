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
    const accentGreen = Color(0xFF176B52);
    const inkColor = Color(0xFF17332B);
    const mutedColor = Color(0xFF53645D);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: inkColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Contact Privacy Support',
            icon: const Icon(Icons.mail_outline_rounded,
                color: accentGreen, size: 22),
            onPressed: () => _launchEmail(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCE6E0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.security_rounded,
                                color: accentGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "BlueFarm Privacy Policy",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: inkColor,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Effective date: 27 October 2026",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "BlueFarm helps aquaculture farmers manage farm profiles and access aquaculture-related information, including nearby fish markets, collection hubs and cold-storage facilities. This policy explains what information BlueFarm processes, why it is used, and the choices available to you.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF293F36),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Privacy Highlights Callout Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF7F1),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                      left: BorderSide(color: accentGreen, width: 4),
                      top: BorderSide(color: Color(0xFFDCE6E0)),
                      right: BorderSide(color: Color(0xFFDCE6E0)),
                      bottom: BorderSide(color: Color(0xFFDCE6E0)),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          color: accentGreen, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Privacy Highlights",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: accentGreen,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Aadhaar document images and Aadhaar numbers are processed locally on your device for verification and are NOT uploaded to BlueFarm servers. BlueFarm stores a readable farm-location address and related region/PIN-code text. Live GPS coordinates used to find nearby markets are held temporarily in memory and are NOT stored in the BlueFarm database.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.55,
                                color: Color(0xFF17332B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section 1
                _buildSectionCard(
                  number: "1",
                  title: "Information we collect or process",
                  icon: Icons.list_alt_rounded,
                  children: const [
                    _BulletItem(
                      title: "Account information",
                      body:
                          "Information you provide to register or sign in, such as your email address and authentication-related identifiers.",
                    ),
                    _BulletItem(
                      title: "Profile and farm information",
                      body:
                          "Details you enter during onboarding or profile editing, which may include your name, age, phone number, farm name, pond area, waterbody type, species, region, PIN code and farm address.",
                    ),
                    _BulletItem(
                      title: "Farm location text",
                      body:
                          "When you choose automatic location detection, BlueFarm may reverse-geocode device coordinates into a readable address and save that address in your profile. Region and PIN code may also be saved. If reverse geocoding fails, a coordinate string may be saved in the address field. You may manually edit your location text.",
                    ),
                    _BulletItem(
                      title: "Water-quality and farm readings",
                      body:
                          "Sensor readings or monitoring information that you submit or connect to BlueFarm, where those features are enabled.",
                    ),
                    _BulletItem(
                      title: "Aadhaar verification result",
                      body:
                          "The app may store a boolean verification status (for example, aadhaar_verified) in your profile.",
                    ),
                    _BulletItem(
                      title: "Technical information",
                      body:
                          "The app platform and diagnostic information may be processed by the operating system, Google Play, or infrastructure providers as part of operating, securing and troubleshooting the service.",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 2
                _buildSectionCard(
                  number: "2",
                  title: "Aadhaar document processing",
                  icon: Icons.badge_outlined,
                  children: const [
                    Text(
                      "When you choose to scan or select an Aadhaar image for verification, BlueFarm uses on-device text recognition through Google ML Kit to check for government-issuer text, a 12-digit Aadhaar-number pattern and a name match. In this described flow, text recognition occurs on your device. BlueFarm does not upload or store the Aadhaar image, full Aadhaar number, Aadhaar address or date of birth on its servers. The image is held temporarily on the device for the session, and the app stores only the verification-status flag. Do not use the verification feature if you do not wish to provide the document for local processing.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 3
                _buildSectionCard(
                  number: "3",
                  title: "How we use information",
                  icon: Icons.lightbulb_outline_rounded,
                  children: const [
                    Text(
                      "BlueFarm uses information to create and manage accounts, display and update farmer profiles, support farm-management features, show relevant aquaculture resources, find nearby markets when requested, perform the selected verification flow, maintain security, troubleshoot errors and respond to support or privacy requests.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 4
                _buildSectionCard(
                  number: "4",
                  title: "Location and third-party services",
                  icon: Icons.location_on_outlined,
                  children: const [
                    _BulletItem(
                      title: "Device location",
                      body:
                          "BlueFarm requests location access when you initiate a feature that needs it. The app does not continuously track your movements or run background location tracking. Live coordinates used by the 'Market Near Me' feature are used temporarily in memory to find nearby facilities and calculate distances, and are not saved to the BlueFarm database.",
                    ),
                    _BulletItem(
                      title: "OpenStreetMap Nominatim",
                      body:
                          "When you request automatic address detection, coordinates may be sent to the Nominatim geocoding service to obtain a readable address. The resulting address text, region and PIN code may then be saved to your BlueFarm profile. Nominatim is a third-party service governed by its own terms and privacy practices.",
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
                      title: "Google Play and device providers",
                      body:
                          "They may process information under their own policies in connection with app distribution, device operation, security and diagnostics.",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 5
                _buildSectionCard(
                  number: "5",
                  title: "When information is shared",
                  icon: Icons.share_outlined,
                  children: const [
                    Text(
                      "BlueFarm does not sell your personal information. Information may be processed by service providers where needed to operate the app, as described in this policy, or disclosed where required by law, to protect users and the service, or to address security or abuse. We do not intend to share Aadhaar images or full Aadhaar numbers with BlueFarm servers or service providers.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 6
                _buildSectionCard(
                  number: "6",
                  title: "Storage, security and retention",
                  icon: Icons.lock_outline_rounded,
                  children: const [
                    Text(
                      "Profile information is stored in the BlueFarm backend while needed to provide the service. Live coordinates used for nearby-market calculations are temporary and are not written to the BlueFarm database. Aadhaar images and numbers are not retained by BlueFarm servers in the described verification flow. We use the security controls available through the app and its infrastructure, but no method of electronic storage or transmission can be guaranteed to be completely secure. Retention of information held by third-party providers may be governed by their own policies.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 7
                _buildSectionCard(
                  number: "7",
                  title: "Your choices and account deletion",
                  icon: Icons.settings_accessibility_rounded,
                  children: [
                    const Text(
                      "You can edit profile and farm-location text in the app where those features are available, and you can choose whether to grant location permission. To request account deletion or ask us to access, correct or delete information associated with your account, email us with 'BlueFarm privacy request' in the subject.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _launchEmail(context),
                      icon: const Icon(Icons.email_outlined,
                          size: 16, color: accentGreen),
                      label: const Text(
                        "Email bluefarm1572@gmail.com",
                        style: TextStyle(
                          color: accentGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accentGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                  number: "8",
                  title: "Children's privacy",
                  icon: Icons.family_restroom_rounded,
                  children: const [
                    Text(
                      "BlueFarm is intended for people involved in aquaculture and farm management, not for children. If you believe a child has provided personal information to BlueFarm, contact us so we can review the request.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 9
                _buildSectionCard(
                  number: "9",
                  title: "Changes to this policy",
                  icon: Icons.update_rounded,
                  children: const [
                    Text(
                      "We may update this policy as BlueFarm's features, data practices or legal requirements change. The updated policy will be published at this address with a revised effective date. Please review it periodically.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section 10
                _buildSectionCard(
                  number: "10",
                  title: "Contact us",
                  icon: Icons.support_agent_rounded,
                  children: [
                    const Text(
                      "For questions, concerns, or privacy and account-deletion requests, contact:",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF293F36),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business_rounded,
                              color: accentGreen, size: 22),
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
                                    color: inkColor,
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
                                color: accentGreen,
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

                const SizedBox(height: 24),

                // Footer Copyright
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

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String number,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    const accentGreen = Color(0xFF176B52);
    const inkColor = Color(0xFF17332B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: inkColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
    const accentGreen = Color(0xFF176B52);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF293F36),
                ),
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17332B),
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
