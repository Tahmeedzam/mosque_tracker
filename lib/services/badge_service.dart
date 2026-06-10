import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BadgeService {
  final _supabase = Supabase.instance.client;

  Future<void> grantNewBadge() async {
    final String userId = _supabase.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    final visitedMosqueData = await _supabase
        .from("visitedMosque")
        .select("*")
        .eq("user_id", userId);

    int totalVisitedCount = visitedMosqueData.length;

    // Set<String> uniqueCities = visitedMosqueData
    //     .map((m) => m['city']?.toString().toLowerCase() ?? '')
    //     .where((city) => city.isNotEmpty)
    //     .toSet();

    final List<dynamic> serverBadges = await _supabase
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);

    List<String> alreadyUnlockedIds = serverBadges
        .map((b) => b['badge_id'].toString())
        .toList();

    List<String> badgesToUnlockNow = [];

    //Badge: First step - Unlock first mosque
    if (totalVisitedCount > 0 &&
        !alreadyUnlockedIds.contains("badge_first_step")) {
      badgesToUnlockNow.add("badge_first_step");
    }
    //Badge: Ten - Unlock 10 mosque
    if (totalVisitedCount >= 10 && !alreadyUnlockedIds.contains("badge_ten")) {
      badgesToUnlockNow.add("badge_ten");
    }
    //Badge: Traveller - Visit 3 unique cities
    // if (uniqueCities.length >= 3 &&
    //     alreadyUnlockedIds.contains("badge_traveller")) {
    //   badgesToUnlockNow.add("badge_traveller");
    // }

    if (badgesToUnlockNow.isNotEmpty) {
      for (String badgeId in badgesToUnlockNow) {
        await _supabase.from('user_badges').insert({
          'user_id': userId,
          'badge_id': badgeId,
        });

        // 💥 Put your trigger for your unlock overlay animation here!

        print("🎉 UNLOCKED NEW BADGE: $badgeId");
      }
    }
  }
}
