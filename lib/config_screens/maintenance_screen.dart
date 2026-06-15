import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

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
              const Text("🔧", style: TextStyle(fontSize: 64)),
              const SizedBox(height: 32),
              const Text(
                "Under Maintenance",
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
                message.isNotEmpty
                    ? message
                    : "We are making improvements. Please check back soon.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9963A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC9963A).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_outlined,
                      size: 16,
                      color: Color(0xFFE8B96A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "We'll be back shortly",
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFE8B96A).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
