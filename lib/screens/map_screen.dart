import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/screens/mosque_bottom_sheet.dart';
import 'package:mosque_tracker/services/overpass_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  // For bottom sheet
  Map<String, dynamic>? selectedMosque;
  bool showBottomSheet = false;

  // Visited mosque ids — will come from Supabase later
  final Set<String> visitedIds = {"123456", "789012"}; // hardcoded for now

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

  // Generate a circular mosque icon programmatically
  Future<Uint8List> _createMosqueIcon(bool visited) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 80.0;

    final bgColor = visited ? const Color(0xFF2D6A4F) : const Color(0xFF1C2E22);
    final borderColor = visited
        ? const Color(0xFFC9963A)
        : const Color(0xFF3A5A40);
    final iconColor = visited
        ? const Color(0xFFE8B96A)
        : const Color(0xFF52B788);

    // Outer glow for visited
    if (visited) {
      final glowPaint = Paint()
        ..color = const Color(0xFF2D6A4F).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(const Offset(size / 2, size / 2), 28, glowPaint);
    }

    // Background circle
    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = visited ? 2.5 : 1.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, borderPaint);

    // Mosque emoji text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '🕌',
        style: TextStyle(fontSize: visited ? 20 : 16, color: iconColor),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _addMosqueMarkers() async {
    if (mapboxMapController == null || mosques.isEmpty) return;

    // Create and register both icon images
    final visitedIcon = await _createMosqueIcon(true);
    final unvisitedIcon = await _createMosqueIcon(false);

    await mapboxMapController!.style.addStyleImage(
      "mosque-visited",
      1.0,
      MbxImage(width: 80, height: 80, data: visitedIcon),
      false,
      [],
      [],
      null,
    );

    await mapboxMapController!.style.addStyleImage(
      "mosque-unvisited",
      1.0,
      MbxImage(width: 80, height: 80, data: unvisitedIcon),
      false,
      [],
      [],
      null,
    );

    // Build GeoJSON with visited property
    final features = mosques.map((mosque) {
      final isVisited = visitedIds.contains(mosque["id"]);
      return {
        "type": "Feature",
        "properties": {
          "id": mosque["id"],
          "name": mosque["name"],
          "visited": isVisited,
          "icon": isVisited ? "mosque-visited" : "mosque-unvisited",
        },
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

    await mapboxMapController!.style.addSource(
      GeoJsonSource(id: "mosques-source", data: geoJson),
    );

    // Symbol layer using custom icons
    await mapboxMapController!.style.addLayer(
      SymbolLayer(
        id: "mosques-layer",
        sourceId: "mosques-source",
        iconImage: "mosque-unvisited", // default, expression overrides below
        iconSize: 0.6,
        iconAllowOverlap: true,
        textField: "{name}",
        textSize: 10.0,
        textOffset: [0.0, 2.2],
        textAnchor: TextAnchor.TOP,
        textColor: 0xFFE8B96A,
        textHaloColor: 0xFF0F1A14,
        textHaloWidth: 1.5,
        textAllowOverlap: false,
        textOptional: true,
      ),
    );

    // Hide all other POI labels on the map
    _hidePOILayers();

    // Set up tap listener
    mapboxMapController!.setOnMapTapListener(_onMapTap);

    debugPrint("Markers added: ${mosques.length}");
  }

  // Hide non-mosque POI icons and labels
  void _hidePOILayers() async {
    final style = mapboxMapController!.style;
    final layersToHide = [
      "poi-label",
      "airport-label",
      "transit-label",
      "natural-point-label",
      "place-neighborhood-suburb-label",
      "road-label",
    ];
    for (final layerId in layersToHide) {
      try {
        await style.setStyleLayerProperty(layerId, "visibility", "none");
      } catch (_) {}
    }
  }

  void _onMapTap(MapContentGestureContext context) async {
    if (mapboxMapController == null) return;

    final screenCoord = context.touchPosition;
    final features = await mapboxMapController!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(
        ScreenCoordinate(x: screenCoord.x, y: screenCoord.y),
      ),
      RenderedQueryOptions(layerIds: ["mosques-layer"]),
    );

    if (features.isNotEmpty) {
      setState(() {
        selectedMosque = {
          "id": "demo_001",
          "name": "Masjid Al-Noor",
          "visited": true,
        };
        showBottomSheet = true;
      });
    } else {
      setState(() => showBottomSheet = false);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap controller) {
    setState(() => mapboxMapController = controller);
    mapboxMapController?.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: Stack(
        children: [
          // Map
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(19.14273214558291, 72.84395646537473),
              ),
              zoom: 14,
            ),
            styleUri: "mapbox://styles/mapbox/dark-v11",
            onMapCreated: _onMapCreated,
          ),

          // Search bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2E22).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFC9963A).withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.35),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Find a mosque...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating bottom sheet
          // Floating bottom sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            bottom: showBottomSheet ? 100 : -300,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: showBottomSheet ? 1.0 : 0.0,
              child: selectedMosque != null
                  ? MosqueBottomSheet(
                      mosque: selectedMosque!,
                      onClose: () => setState(() => showBottomSheet = false),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating bottom sheet widget ──────────────────────────────────────────────
