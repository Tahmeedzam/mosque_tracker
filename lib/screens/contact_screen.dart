import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mosque_tracker/screens/report_form_screen.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@athar-app.com', // replace with your actual email
      query: 'subject=Athar Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: const Color(0xFF1B4332),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: Color(0xFFE8B96A),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "SUPPORT",
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.18,
                      color: Color(0xFFE8B96A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We're here to help",
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      color: Color(0xFFF5F0E8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Let us know if something isn't working,\nor share your thoughts with us",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  _ContactOption(
                    icon: Icons.bug_report_outlined,
                    iconColor: const Color(0xFFE8957A),
                    title: "Report a Bug",
                    subtitle: "Something not working as expected?",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportFormScreen(
                          type: 'bug',
                          title: 'Report a Bug',
                          subtitle:
                              'Describe what went wrong, and we\'ll look into it',
                          placeholder:
                              'e.g. The map crashed when I tapped on a mosque...',
                          mosqueName: '',
                          mosqueId: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _ContactOption(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: const Color(0xFFE8B96A),
                    title: "Send Feedback",
                    subtitle: "Ideas, suggestions, or anything on your mind",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportFormScreen(
                          type: 'feedback',
                          title: 'Send Feedback',
                          subtitle:
                              'We read every message — share what you think',
                          placeholder:
                              'e.g. It would be great if the app could...',
                          mosqueName: '',
                          mosqueId: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _ContactOption(
                    icon: Icons.mail_outline_rounded,
                    iconColor: const Color(0xFF9E9C97),
                    title: "Email Us Directly",
                    subtitle: "support@athar-app.com",
                    onTap: _openEmail,
                  ),

                  const SizedBox(height: 32),

                  // Footer note
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Your feedback helps us build a better experience for the whole community",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.25),
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF152419),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF5F0E8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }
}
