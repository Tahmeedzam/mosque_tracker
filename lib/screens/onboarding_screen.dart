import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mosque_tracker/screens/login_screen.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      emoji: "🕌",
      title: "Your spiritual\njourney begins",
      subtitle:
          "Discover mosques around you, log your prayers, and build a personal record of your devotion — all private, all yours.",
      actionLabel: null,
    ),
    _OnboardingPage(
      emoji: "📍",
      title: "Find mosques\nnear you",
      subtitle:
          "We use your location to show nearby mosques and gently remind you when you arrive at one. Your location is never shared.",
      actionLabel: "Allow Location",
    ),
    _OnboardingPage(
      emoji: "🔔",
      title: "Never miss\na prayer",
      subtitle:
          "Get adhan notifications at prayer times and gentle prompts when you're at a mosque. You can change this anytime.",
      actionLabel: "Allow Notifications",
    ),
  ];

  void _next() async {
    if (_currentPage == 1) {
      await Permission.location.request();
      await Permission.locationAlways.request();
    }
    if (_currentPage == 2) {
      await Permission.notification.request();
      await _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: Stack(
        children: [
          // Geometric background pattern
          Positioned.fill(child: CustomPaint(painter: _GeometricPainter())),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                    child: GestureDetector(
                      onTap: _finish,
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),

                // Dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? const Color(0xFFC9963A)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _next,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF52B788).withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2D6A4F,
                                  ).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? "Get Started"
                                  : _pages[_currentPage].actionLabel ??
                                        "Continue",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFF5F0E8),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.06,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in hexagon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332).withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC9963A).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D6A4F).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(page.emoji, style: const TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 48),

          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: Color(0xFFF5F0E8),
              height: 1.25,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.5),
              height: 1.65,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;

  _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });
}

// Subtle geometric background

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9963A).withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 120.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        _drawHexagon(canvas, paint, Offset(x, y), 50);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * (math.pi / 180);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
