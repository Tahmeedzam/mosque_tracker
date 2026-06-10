import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

  Future<void> loadMosques({bool forceReload = false}) async {
    if (_mosquesLoaded && !forceReload) return;
    try {
      final response = await _supabase
          .from('mosques')
          .select(
            'id, name, lat, lng, city, country, verified, status, women_allowed, has_wudu_area, has_parking, verified_count',
          )
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

  // In mosque.service.dart, add this method
  Future<Map<String, String>> getAddressFromLatLng(
    double lat,
    double lng,
  ) async {
    final token = dotenv.env["MAPBOX_GLOBAL_TOKEN"]!;
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json"
      "?access_token=$token&types=address,place,country&limit=1",
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      final features = data["features"] as List;
      if (features.isEmpty) return {"address": "", "city": "", "country": ""};

      final feature = features.first;
      final address = feature["place_name"] as String? ?? "";

      // Context array has city, region, country broken out
      final context = feature["context"] as List? ?? [];
      String city = "";
      String country = "";

      for (final item in context) {
        final id = item["id"].toString();
        if (id.startsWith("place")) city = item["text"] ?? "";
        if (id.startsWith("country")) country = item["text"] ?? "";
      }

      return {"address": address, "city": city, "country": country};
    } catch (e) {
      debugPrint("Geocoding error: $e");
      return {"address": "", "city": "", "country": ""};
    }
  }

  Future<void> markMosqueVisited(String mosqueId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Don't insert if already visited
      if (isMosqueVisited(mosqueId)) return;

      await _supabase.from('visitedMosque').insert({
        "user_id": userId,
        "mosque_id": mosqueId,
      });

      // Reload visited list
      await loadVisitedMosques(forceReload: true);
      debugPrint("Mosque $mosqueId marked as visited");
    } catch (e) {
      debugPrint("Error marking visited: $e");
    }
  }
}
