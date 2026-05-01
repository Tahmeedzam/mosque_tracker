import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// SUPABASE CLIENT
// ─────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────

// Streams auth state changes (login, logout, token refresh)
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

// Simple current user getter
final currentUserProvider = Provider((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser;
});

// ─────────────────────────────────────────────
// MOSQUES (all mosques from DB)
// ─────────────────────────────────────────────

final mosquesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('mosques')
      .select('id, name, lat, lng, city, verified')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

// ─────────────────────────────────────────────
// VISITED MOSQUES (realtime stream from Supabase)
// ─────────────────────────────────────────────

// ✅ This is the key — Supabase realtime stream means ANY change
// (insert or delete) automatically updates every widget watching this.
final visitedMosquesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return Stream.value([]);

  return supabase
      .from('visitedMosque')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('visited_at');
});

// ─────────────────────────────────────────────
// NEARBY MOSQUES (derived from mosquesProvider + user location)
// ─────────────────────────────────────────────

// Holds the user's current lat/lng — updated by the map screen
final userLocationProvider = StateProvider<({double lat, double lng})?>(
  (ref) => null,
);

final nearbyMosquesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final mosquesAsync = ref.watch(mosquesProvider);
  final location = ref.watch(userLocationProvider);

  // Return empty list if either isn't ready
  return mosquesAsync.whenOrNull(
        data: (mosques) {
          if (location == null) return [];
          const offset = 0.15;
          return mosques.where((m) {
            final mLat = (m['lat'] as num).toDouble();
            final mLng = (m['lng'] as num).toDouble();
            return mLat >= location.lat - offset &&
                mLat <= location.lat + offset &&
                mLng >= location.lng - offset &&
                mLng <= location.lng + offset;
          }).toList();
        },
      ) ??
      [];
});

// ─────────────────────────────────────────────
// VISITED IDS SET (fast O(1) lookup)
// ─────────────────────────────────────────────

// Derived from visitedMosquesProvider — just the IDs as a Set for quick checking
final visitedMosqueIdsProvider = Provider<Set<String>>((ref) {
  final visitedAsync = ref.watch(visitedMosquesProvider);
  return visitedAsync.whenOrNull(
        data: (list) => list.map((m) => m['mosque_id'].toString()).toSet(),
      ) ??
      {};
});

// ─────────────────────────────────────────────
// VISIT ACTIONS (insert / delete from Supabase)
// ─────────────────────────────────────────────

class VisitActions {
  final SupabaseClient _supabase;
  VisitActions(this._supabase);

  Future<void> markVisited(dynamic mosqueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw "User not logged in";

    await _supabase.from("visitedMosque").insert({
      'user_id': userId,
      'mosque_id': mosqueId,
    });
    // ✅ No manual reload needed — the stream above auto-updates
  }

  Future<void> unmarkVisited(dynamic mosqueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw "User not logged in";

    await _supabase
        .from("visitedMosque")
        .delete()
        .eq('user_id', userId)
        .eq('mosque_id', mosqueId);
    // ✅ No manual reload needed — the stream above auto-updates
  }
}

final visitActionsProvider = Provider<VisitActions>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return VisitActions(supabase);
});
