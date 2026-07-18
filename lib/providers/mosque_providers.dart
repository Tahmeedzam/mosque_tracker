import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mosque_tracker/services/mosque.service.dart';

// ── Visited Mosques Notifier ──────────────────────────────────────────────────
class VisitedMosquesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  VisitedMosquesNotifier() : super([]) {
    load();
  }

  final _supabase = Supabase.instance.client;

  Future<void> load() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('visitedMosque')
          .select(
            'id, mosque_id, mosque_name, mosque_city, mosque_country, mosque_lat, mosque_lng, visited_at',
          )
          .eq('user_id', userId)
          .order('visited_at');

      state = List<Map<String, dynamic>>.from(response);

      // Keep MosqueService in sync
      MosqueService().syncVisitedFromProvider(state);
    } catch (e) {
      debugPrint("VisitedMosquesNotifier load error: $e");
    }
  }

  Future<void> markVisited(String mosqueId) async {
    await MosqueService().markMosqueVisited(mosqueId);
    await load(); // reload and update state — triggers rebuild everywhere
  }

  Future<void> unmarkVisited(String mosqueId) async {
    await MosqueService().unmarkMosqueVisited(mosqueId);
    await load();
  }

  void clear() {
    state = [];
  }
}

// ── Maqam Count Notifier ──────────────────────────────────────────────────────
class MaqamCountNotifier extends StateNotifier<int> {
  MaqamCountNotifier() : super(0) {
    load();
  }

  final _supabase = Supabase.instance.client;

  Future<void> load() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('personal_places')
          .select('id')
          .eq('user_id', userId);

      state = (response as List).length;
    } catch (e) {
      debugPrint("MaqamCountNotifier load error: $e");
    }
  }

  void increment() => state = state + 1;
  void decrement() => state = state > 0 ? state - 1 : 0;
  void clear() => state = 0;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final visitedMosquesProvider =
    StateNotifierProvider<VisitedMosquesNotifier, List<Map<String, dynamic>>>(
      (ref) => VisitedMosquesNotifier(),
    );

// Derived — just the count, no extra logic needed
final visitedCountProvider = Provider<int>((ref) {
  return ref.watch(visitedMosquesProvider).length;
});

// Derived — unique cities count
final uniqueCitiesProvider = Provider<int>((ref) {
  final visited = ref.watch(visitedMosquesProvider);
  return visited
      .map((v) => v['mosque_city']?.toString() ?? '')
      .where((c) => c.isNotEmpty)
      .toSet()
      .length;
});

final maqamCountProvider = StateNotifierProvider<MaqamCountNotifier, int>(
  (ref) => MaqamCountNotifier(),
);
