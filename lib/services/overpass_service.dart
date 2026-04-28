import 'dart:convert';
import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

class MosqueService {
  Future<List<Map<String, dynamic>>> getMosquesNearby(
    double lat,
    double lng,
  ) async {
    // ── LIVE API (commented out until Overpass stabilises) ──────────────
    // double offset = 0.05;
    // double south = lat - offset;
    // double north = lat + offset;
    // double west = lng - offset;
    // double east = lng + offset;
    // String query =
    //     '[out:json][timeout:30];('
    //     'node["amenity"="place_of_worship"]["religion"="muslim"]($south,$west,$north,$east);'
    //     'way["amenity"="place_of_worship"]["religion"="muslim"]($south,$west,$north,$east);'
    //     'node["amenity"="mosque"]($south,$west,$north,$east);'
    //     'way["amenity"="mosque"]($south,$west,$north,$east);'
    //     'node["building"="mosque"]($south,$west,$north,$east);'
    //     'way["building"="mosque"]($south,$west,$north,$east);'
    //     'relation["amenity"="place_of_worship"]["religion"="muslim"]($south,$west,$north,$east);'
    //     ');out center tags;';
    // final response = await http.post(
    //   Uri.parse("https://maps.mail.ru/osm/tools/overpass/api/interpreter"),
    //   headers: {
    //     "Content-Type": "application/x-www-form-urlencoded",
    //     "Accept": "application/json",
    //   },
    //   body: "data=${Uri.encodeQueryComponent(query)}",
    // );
    // if (response.statusCode != 200) {
    //   print("Overpass error: ${response.statusCode} — ${response.body}");
    //   return [];
    // }
    // final data = jsonDecode(response.body);
    // final elements = data["elements"] as List;
    // ────────────────────────────────────────────────────────────────────

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

    print("Total mosques loaded: ${mosques.length}");
    return mosques;
  }
}
