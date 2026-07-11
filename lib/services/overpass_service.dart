import 'dart:convert';
import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

class MosqueService {
  Future<List<Map<String, dynamic>>> getMosquesNearby(
    double lat,
    double lng,
  ) async {
    // ── LOCAL JSON (active) ──────────────────────────────────────────────
    final raw = await rootBundle.loadString('assets/mosques.json');
    final data = jsonDecode(raw);
    final elements = data["elements"] as List;
    // ────────────────────────────────────────────────────────────────────

    List<Map<String, dynamic>> mosques = [];

    for (var element in elements) {
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
        "id": element["id"].toString(),
        "name": name,
        "lat": mosLat,
        "lng": mosLng,
      });
    }

    return mosques;
  }
}
