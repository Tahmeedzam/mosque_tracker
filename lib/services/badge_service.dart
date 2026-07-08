import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BadgeService {
  final _supabase = Supabase.instance.client;

  Future<void> grantNewBadge() async {
    final String userId = _supabase.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    final visitedData = await _supabase
        .from("visitedMosque")
        .select("mosque_id, mosque_city")
        .eq("user_id", userId);

    final int totalVisited = visitedData.length;

    // Unique cities directly from denormalized field
    final uniqueCities = visitedData
        .map((m) => m['mosque_city']?.toString().toLowerCase() ?? '')
        .where((city) => city.isNotEmpty)
        .toSet();

    final serverBadges = await _supabase
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);

    final List<String> alreadyUnlocked = serverBadges
        .map((b) => b['badge_id'].toString())
        .toList();

    final List<String> toUnlock = [];

    if (totalVisited >= 1 && !alreadyUnlocked.contains("badge_first_step")) {
      toUnlock.add("badge_first_step");
    }
    if (totalVisited >= 10 && !alreadyUnlocked.contains("badge_ten")) {
      toUnlock.add("badge_ten");
    }
    if (uniqueCities.length >= 3 &&
        !alreadyUnlocked.contains("badge_traveller")) {
      toUnlock.add("badge_traveller");
    }

    for (final badgeId in toUnlock) {
      await _supabase.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
      });
      print("Badge unlocked: $badgeId");
    }
  }
}
