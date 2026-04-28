import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';
import 'package:mosque_tracker/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final authService = AuthService();
  final supabase = Supabase.instance.client;

  void login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      await authService.signUpWithEmailPassword(email, password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error $e")));
      }
    }
  }

  continueWithGoogle() async {
    try {
      GoogleSignIn singIn = GoogleSignIn.instance;
      await singIn.initialize(
        serverClientId: dotenv.env["WEB_OAUTH"],
        clientId: Platform.isAndroid
            ? dotenv.env["ANDROID_OAUTH"]
            : dotenv.env["IOS_OAUTH"],
      );
      GoogleSignInAccount account = await singIn.authenticate();
      String idToken = account.authentication.idToken ?? "";
      final authorization =
          await account.authorizationClient.authorizationForScopes([
            'email',
            'profile',
          ]) ??
          await account.authorizationClient.authorizeScopes([
            'email',
            'profile',
          ]);

      final result = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      if (result.user != null && result.session != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
          (context) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          TextField(controller: _emailController),
          SizedBox(height: 20),
          TextField(controller: _passwordController),
          SizedBox(height: 20),

          GestureDetector(
            onTap: continueWithGoogle,
            child: Text("Login with Google"),
          ),

          ElevatedButton(onPressed: login, child: const Text("login")),
        ],
      ),
    );
  }
}
