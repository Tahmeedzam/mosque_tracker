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
  List<Map<String, dynamic>> _visitedMaqam = [];

  bool _visitedLoaded = false;
  bool _maqamLoaded = false;

  List<Map<String, dynamic>> get mosques => _mosques;
  List<Map<String, dynamic>> get visitedMosques => _visitedMosques;

  // ── Viewport-based fetch from Supabase using PostGIS ─────────────────────
  Future<List<Map<String, dynamic>>> fetchMosquesByBbox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    debugPrint("fetchMosquesByBbox called");
    try {
      final response = await _supabase.rpc(
        'mosques_in_bbox',
        params: {
          'min_lat': south,
          'min_lng': west,
          'max_lat': north,
          'max_lng': east,
        },
      );
      debugPrint("RPC response type: ${response.runtimeType}");
      final results = List<Map<String, dynamic>>.from(response);
      debugPrint("fetchMosquesByBbox returned: ${results.length}");
      return results;
    } catch (e) {
      debugPrint("fetchMosquesByBbox ERROR: $e");
      return [];
    }
  }

  // ── Overpass fallback for areas with no Supabase data ────────────────────
  Future<List<Map<String, dynamic>>> fetchMosquesFromOverpass({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    try {
      final query =
          '[out:json][timeout:30];('
          'node["amenity"="place_of_worship"]["religion"="muslim"]($south,$west,$north,$east);'
          'way["amenity"="place_of_worship"]["religion"="muslim"]($south,$west,$north,$east);'
          'node["amenity"="mosque"]($south,$west,$north,$east);'
          'way["amenity"="mosque"]($south,$west,$north,$east);'
          ');out center tags;';

      final response = await http.post(
        Uri.parse("https://overpass-api.de/api/interpreter"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
        },
        body: "data=${Uri.encodeQueryComponent(query)}",
      );

      if (response.statusCode != 200) {
        debugPrint("Overpass error: ${response.statusCode}");
        return [];
      }

      final data = jsonDecode(response.body);
      final elements = data["elements"] as List;
      final List<Map<String, dynamic>> mosques = [];

      for (final element in elements) {
        double? mosLat;
        double? mosLng;

        if (element["type"] == "node") {
          mosLat = element["lat"]?.toDouble();
          mosLng = element["lon"]?.toDouble();
        } else if (element["center"] != null) {
          mosLat = element["center"]["lat"]?.toDouble();
          mosLng = element["center"]["lon"]?.toDouble();
        }

        if (mosLat == null || mosLng == null) continue;

        final tags = element["tags"] ?? {};
        final name = tags["name"] ?? tags["name:en"] ?? "Unnamed Mosque";

        mosques.add({
          "id": "osm_${element["type"]}_${element["id"]}",
          "name": name,
          "lat": mosLat,
          "lng": mosLng,
          "city": "",
          "country": "",
          "verified": false,
          "status": "unknown",
          "women_allowed": "unknown",
          "has_wudu_area": null,
          "has_parking": null,
          "verified_count": 0,
          "source": "overpass", // mark as temporary
        });
      }

      debugPrint("Overpass returned ${mosques.length} mosques");
      return mosques;
    } catch (e) {
      debugPrint("Overpass fetch error: $e");
      return [];
    }
  }

  // ── Main method called by map on every camera change ─────────────────────
  Future<List<Map<String, dynamic>>> getMosquesForViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    debugPrint(
      "getMosquesForViewport called — S:$south W:$west N:$north E:$east",
    );

    final supabaseMosques = await fetchMosquesByBbox(
      south: south,
      west: west,
      north: north,
      east: east,
    );

    debugPrint("Supabase returned: ${supabaseMosques.length}");

    if (supabaseMosques.length >= 3) {
      _mosques = supabaseMosques;
      return supabaseMosques;
    }

    debugPrint("Falling back to Overpass...");
    final overpassMosques = await fetchMosquesFromOverpass(
      south: south,
      west: west,
      north: north,
      east: east,
    );

    debugPrint("Overpass returned: ${overpassMosques.length}");

    final Map<String, Map<String, dynamic>> merged = {};
    for (final m in supabaseMosques) merged[m["id"].toString()] = m;
    for (final m in overpassMosques) {
      if (!merged.containsKey(m["id"].toString()))
        merged[m["id"].toString()] = m;
    }

    final result = merged.values.toList();
    _mosques = result;
    debugPrint("Total merged: ${result.length}");
    return result;
  }

  // ── Visited mosques ───────────────────────────────────────────────────────
  Future<void> loadVisitedMosques({bool forceReload = false}) async {
    if (_visitedLoaded && !forceReload) return;
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
      debugPrint("Error loading visited mosques: $e");
      _visitedMosques = [];
    }
  }

  bool isMosqueVisited(String mosqueId) {
    return _visitedMosques.any(
      (m) => m['mosque_id'].toString() == mosqueId.toString(),
    );
  }

  Future<void> markMosqueVisited(String mosqueId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      if (isMosqueVisited(mosqueId)) return;

      await _supabase.from('visitedMosque').insert({
        "user_id": userId,
        "mosque_id": mosqueId,
      });

      await loadVisitedMosques(forceReload: true);
      debugPrint("Mosque $mosqueId marked as visited");
    } catch (e) {
      debugPrint("Error marking visited: $e");
    }
  }

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

  //Maqam Services:
  Future<int> loadPersonalMaqam() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('personal_places')
          .select('id, user_id, name')
          .eq('user_id', userId)
          .order('created_at');

      _visitedMaqam = List<Map<String, dynamic>>.from(response);
      _maqamLoaded = true;
      if (_visitedMaqam.isNotEmpty) {
        return _visitedMaqam.length;
      }
      return 0;
    } catch (e) {
      debugPrint("Error loading visited mosques: $e");
      _visitedMaqam = [];
      return 0;
    }
  }
}
