import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/screens/mosque_bottom_sheet.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mosque_tracker/services/mosque.service.dart';

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

  Map<String, dynamic>? selectedMosque;
  bool showBottomSheet = false;

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
    await Future.wait([
      mosqueService.loadMosques(),
      mosqueService.loadVisitedMosques(),
    ]);

    final nearby = mosqueService.getMosquesNearby(lat, long);

    if (mounted) {
      setState(() => mosques = nearby);
      debugPrint("Mosques near user: ${mosques.length}");
      await _addMosqueMarkers();
    }
  }

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

    if (visited) {
      final glowPaint = Paint()
        ..color = const Color(0xFF2D6A4F).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(const Offset(size / 2, size / 2), 28, glowPaint);
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = visited ? 2.5 : 1.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, borderPaint);

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

    final geoJson = _buildGeoJson();

    await mapboxMapController!.style.addSource(
      GeoJsonSource(id: "mosques-source", data: geoJson),
    );

    await mapboxMapController!.style.addLayer(
      SymbolLayer(
        id: "mosques-layer",
        sourceId: "mosques-source",
        iconImageExpression: ["get", "icon"],
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

    _hidePOILayers();
    mapboxMapController!.setOnMapTapListener(_onMapTap);
    debugPrint("Markers added: ${mosques.length}");
  }

  // ✅ NEW: builds a fresh GeoJSON string reflecting current visited state
  String _buildGeoJson() {
    final features = mosques.map((mosque) {
      final mosqueId = mosque["id"].toString();
      final isVisited = mosqueService.isMosqueVisited(mosqueId);
      return {
        "type": "Feature",
        "properties": {
          "id": mosqueId,
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

    return jsonEncode({"type": "FeatureCollection", "features": features});
  }

  // ✅ NEW: called by the bottom sheet after a visit change.
  // Updates the GeoJSON source in-place — no layer rebuild needed.
  Future<void> _refreshMarkers() async {
    if (mapboxMapController == null) return;

    final geoJson = _buildGeoJson();

    try {
      await mapboxMapController!.style.setStyleSourceProperty(
        "mosques-source",
        "data",
        geoJson,
      );
      debugPrint("Markers refreshed after visit change");
    } catch (e) {
      debugPrint("Error refreshing markers: $e");
    }
  }

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

  // ✅ Updated _onMapTap — zooms into the tapped mosque
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
      final feature = features.first?.queriedFeature.feature;
      if (feature == null) return;

      final rawProps = feature["properties"];
      final props = Map<String, dynamic>.from(rawProps as Map);

      final mosqueId = props["id"]?.toString() ?? "";
      final fullMosque = mosqueService.mosques.firstWhere(
        (m) => m["id"].toString() == mosqueId,
        orElse: () => {
          "id": mosqueId,
          "name": props["name"]?.toString() ?? "Unnamed Mosque",
          "lat": 0.0,
          "lng": 0.0,
          "city": "",
          "verified": false,
        },
      );

      final mosqueLat = (fullMosque["lat"] as num).toDouble();
      final mosqueLng = (fullMosque["lng"] as num).toDouble();

      // ✅ Zoom in to the tapped mosque
      mapboxMapController?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(mosqueLng, mosqueLat)),
          zoom: 16.5,
        ),
        MapAnimationOptions(duration: 500),
      );

      final distanceMeters = _calculateDistance(
        lat,
        long,
        mosqueLat,
        mosqueLng,
      );

      setState(() {
        selectedMosque = {
          ...fullMosque,
          "visited": mosqueService.isMosqueVisited(mosqueId),
          "distance": distanceMeters,
        };
        showBottomSheet = true;
      });
    } else {
      setState(() => showBottomSheet = false);
    }
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    const roadFactor =
        1.4; // ✅ real-world roads are ~40% longer than straight line
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c * roadFactor; // ✅ multiply here
  }

  double _toRad(double deg) => deg * (3.141592653589793 / 180);

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap controller) {
    setState(() => mapboxMapController = controller);
    mapboxMapController?.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    mapboxMapController?.scaleBar.updateSettings(
      ScaleBarSettings(enabled: false),
    );
    mapboxMapController?.logo.updateSettings(LogoSettings(enabled: false));
    mapboxMapController?.attribution.updateSettings(
      AttributionSettings(enabled: false),
    );
    mapboxMapController?.compass.updateSettings(
      CompassSettings(enabled: false),
    );
    _getCurrentLocation();
  }

  void _zoomToUserLocation() {
    if (lat == 0.0 && long == 0.0) return;
    mapboxMapController?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(long, lat)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: Stack(
        children: [
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    14,
                    26,
                    20,
                  ).withOpacity(0.95),
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
          // ✅ My location FAB
          Positioned(
            right: 16,
            bottom: 20,
            child: GestureDetector(
              onTap: _zoomToUserLocation,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF152419).withOpacity(0.97),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF52B788).withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF52B788),
                  size: 20,
                ),
              ),
            ),
          ),

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
                      onVisitChanged:
                          _refreshMarkers, // ✅ pass the refresh callback
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
