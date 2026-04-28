import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/services/overpass_service.dart';
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double lat = 0.0;
  double long = 0.0;
  MapboxMap? mapboxMapController;
  List<Map<String, dynamic>> mosques = [];
  final mosqueService = MosqueService();

  Future<geo.Position> _getCurrentLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled');

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location are denied');
      }
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error("Location permissions are permanently disabled");
    }

    geo.Position value = await geo.Geolocator.getCurrentPosition();
    setState(() {
      lat = value.latitude;
      long = value.longitude;
    });

    mapboxMapController?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(long, lat)),
        zoom: 14.0,
      ),
    );

    await setMosquesData();
    return value;
  }

  Future<void> setMosquesData() async {
    mosques = await mosqueService.getMosquesNearby(lat, long);
    debugPrint("Total mosques: ${mosques.length}");
    await _addMosqueMarkers();
  }

  Future<void> _addMosqueMarkers() async {
    if (mapboxMapController == null) return;
    if (mosques.isEmpty) return;

    // Build GeoJSON FeatureCollection from mosque list
    final features = mosques.map((mosque) {
      return {
        "type": "Feature",
        "properties": {"id": mosque["id"], "name": mosque["name"]},
        "geometry": {
          "type": "Point",
          "coordinates": [mosque["lng"], mosque["lat"]],
        },
      };
    }).toList();

    final geoJson = jsonEncode({
      "type": "FeatureCollection",
      "features": features,
    });

    // Add source
    await mapboxMapController!.style.addSource(
      GeoJsonSource(id: "mosques-source", data: geoJson),
    );

    // Add circle layer
    await mapboxMapController!.style.addLayer(
      CircleLayer(
        id: "mosques-layer",
        sourceId: "mosques-source",
        circleRadius: 8.0,
        circleColor: 0xFF2D6A4F, // green for all mosques for now
        circleStrokeWidth: 2.0,
        circleStrokeColor: 0xFFFFFFFF,
      ),
    );

    debugPrint("Markers added: ${mosques.length}");
  }

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap controller) {
    setState(() {
      mapboxMapController = controller;
    });
    mapboxMapController?.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    CameraOptions cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(19.14273214558291, 72.84395646537473),
      ),
      zoom: 14,
    );

    return Scaffold(
      body: MapWidget(
        cameraOptions: cameraOptions,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
