import 'package:flutter/material.dart';
import 'package:mosque_tracker/screens/login_screen.dart';
import 'package:mosque_tracker/screens/main_screen.dart';
import 'package:mosque_tracker/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingComplete(),
      builder: (context, onboardingSnapshot) {
        if (!onboardingSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1A14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF52B788)),
            ),
          );
        }

        // Show onboarding if not complete
        if (onboardingSnapshot.data == false) {
          return const OnboardingScreen();
        }

        // Onboarding done — check auth
        return StreamBuilder(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F1A14),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF52B788)),
                ),
              );
            }

            final session = snapshot.data!.session;
            if (session != null) {
              return const MainScreen();
            }
            return const LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
