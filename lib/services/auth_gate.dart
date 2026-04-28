// This will listen to auth state changes

import 'package:flutter/material.dart';
import 'package:mosque_tracker/screens/login_screen.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return ProfileScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
