import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mosque_tracker/screens/splash_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/wifi.png', scale: 7),
              const SizedBox(height: 32),
              const Text(
                "No Internet Connection",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  color: Color(0xFFF5F0E8),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Please check your internet connection and try again",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    try {
                      final result = await InternetAddress.lookup('google.com');
                      if (result.isNotEmpty &&
                          result[0].rawAddress.isNotEmpty) {
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SplashScreen(),
                            ),
                          );
                        }
                      }
                    } on SocketException {
                      // still no internet — show snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Still no internet. Try again."),
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Retry",
                    style: TextStyle(
                      color: Color(0xFFF5F0E8),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
