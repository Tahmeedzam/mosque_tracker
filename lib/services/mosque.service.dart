import 'package:supabase_flutter/supabase_flutter.dart';

class MosqueService {
  static final MosqueService _instance = MosqueService._internal();
  factory MosqueService() => _instance;
  MosqueService._internal();

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _mosques = [];
  List<Map<String, dynamic>> _visitedMosques = [];

  // Separate flags so loading all mosques doesn't block loading visited ones
  bool _mosquesLoaded = false;
  bool _visitedLoaded = false;

  // Getters - This solves the "Value isn't used" warning
  List<Map<String, dynamic>> get mosques => _mosques;
  List<Map<String, dynamic>> get visitedMosques => _visitedMosques;
  bool get isLoaded => _mosquesLoaded;

  Future<void> loadMosques() async {
    if (_mosquesLoaded) return;
    try {
      final response = await _supabase
          .from('mosques')
          .select('id, name, lat, lng, city, verified')
          .order('name');

      _mosques = List<Map<String, dynamic>>.from(response);
      _mosquesLoaded = true;
    } catch (e) {
      print("Error loading mosques: $e");
    }
  }

  Future<void> loadVisitedMosques({bool forceReload = false}) async {
    if (_visitedLoaded && !forceReload) return; // ✅ allow forced refresh

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('visitedMosque')
          .select('id, mosque_id, visited_at')
          .eq('user_id', userId)
          .order('visited_at');

      _visitedMosques = List<Map<String, dynamic>>.from(response);
      _visitedLoaded = true;
    } catch (e) {
      print("Error loading visited mosques: $e");
      _visitedMosques = [];
    }
  }

  // Check if a specific mosque ID is in the visited list
  bool isMosqueVisited(String mosqueId) {
    return _visitedMosques.any(
      (m) => m['mosque_id'].toString() == mosqueId.toString(),
    );
  }

  List<Map<String, dynamic>> getMosquesNearby(
    double lat,
    double lng, {
    double offset = 0.15,
  }) {
    final south = lat - offset;
    final north = lat + offset;
    final west = lng - offset;
    final east = lng + offset;

    return _mosques.where((m) {
      final mLat = (m['lat'] as num).toDouble();
      final mLng = (m['lng'] as num).toDouble();
      return mLat >= south && mLat <= north && mLng >= west && mLng <= east;
    }).toList();
  }
}
