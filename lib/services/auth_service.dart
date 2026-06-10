import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  //Sign-in with email and password
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  //Sign-up with email and password
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  Future<bool> continueWithGoogle() async {
    try {
      GoogleSignIn signIn = GoogleSignIn.instance;
      await signIn.initialize(
        serverClientId: dotenv.env["WEB_OAUTH"],
        clientId: Platform.isAndroid
            ? dotenv.env["ANDROID_OAUTH"]
            : dotenv.env["IOS_OAUTH"],
      );

      GoogleSignInAccount account = await signIn.authenticate();
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

      final result = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      if (result.user != null && result.session != null) {
        final user = result.user!;
        await _supabase.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? '',
          'display_name': user.userMetadata?['full_name'] ?? '',
          'avatar_url': user.userMetadata?['avatar_url'] ?? '',
          'last_active': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
        return true;
      }
      return false;
    } catch (e) {
      print("Google sign in error: $e");
      return false;
    }
  }

  //Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  //Get user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;

    final user = session?.user;
    return user?.email;
  }
}
