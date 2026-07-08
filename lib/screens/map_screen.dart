import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/components/blinkingDot.dart';
import 'package:mosque_tracker/screens/mosque_bottom_sheet.dart';
import 'package:mosque_tracker/services/foreground_service_manager.dart';
import 'package:mosque_tracker/services/geofence.service.dart';
import 'package:mosque_tracker/services/local_database_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoadingOverpass = false;

  final _geofenceService = MosqueGeofenceService();
  double lat = 0.0;
  double long = 0.0;
  MapboxMap? mapboxMapController;
  List<Map<String, dynamic>> mosques = [];
  final mosqueService = MosqueService();

  Map<String, dynamic>? selectedMosque;
  bool showBottomSheet = false;
  final _localDatabaseService = LocalDatabaseService.instance;
  int? mosqueStatus;
  int totalMosque = 0;
  int visitedMosque = 0;
  int visitedMaqam = 0;
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _mosques = [];
  List<Map<String, dynamic>> _visitedMosques = [];
  List<Map<String, dynamic>> _visitedMaqam = [];
  Timer? _cameraDebounce;

  bool _pinDropMode = false;
  double _pinnedLat = 0.0;
  double _pinnedLng = 0.0;
  String _pendingAddType = '';

  double _lastFetchLat = 0.0;
  double _lastFetchLng = 0.0;
  bool _isFetching = false;
  // List<Map<String, dynamic>> get visitedMosques => _visitedMosques;

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

    print("lat:$lat");
    print("long:$long");

    mapboxMapController?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(long, lat)),
        zoom: 14.0,
      ),
    );

    // Pass coordinates directly instead of relying on class variables
    await setMosquesData(
      overrideLat: value.latitude,
      overrideLng: value.longitude,
    );
    return value;
  }

  Future<void> setMosquesData({
    double? overrideLat,
    double? overrideLng,
  }) async {
    debugPrint(
      "setMosquesData entry — isFetching: $_isFetching, lat: $lat, lng: $long",
    );
    if (_isFetching) return;
    if (!mounted) return; // add this
    _isFetching = true;
    setState(() => _isLoadingOverpass = true);

    final fetchLat = overrideLat ?? lat;
    final fetchLng = overrideLng ?? long;

    debugPrint("setMosquesData called — lat: $fetchLat, lng: $fetchLng");
    final cameraState = await mapboxMapController!.getCameraState();
    final zoom = cameraState.zoom;

    // Larger bbox when zoomed out, smaller when zoomed in
    double offset;
    if (zoom < 10) {
      offset = 0.5; // very zoomed out — load large area
    } else if (zoom < 13) {
      offset = 0.3; // medium zoom
    } else {
      offset = 0.15; // zoomed in — load small area
    }
    // const offset = 0.15;

    final south = fetchLat - offset;
    final north = fetchLat + offset;
    final west = fetchLng - offset;
    final east = fetchLng + offset;

    debugPrint("BBox — S:$south W:$west N:$north E:$east");

    await mosqueService.loadVisitedMosques();

    final fetched = await mosqueService.getMosquesForViewport(
      south: south,
      west: west,
      north: north,
      east: east,
    );

    debugPrint("Fetched mosque count: ${fetched.length}");

    _lastFetchLat = fetchLat;
    _lastFetchLng = fetchLng;
    _isFetching = false;
    if (!mounted) return;

    if (mounted) {
      setState(() {
        mosques = fetched;
        _isLoadingOverpass = false; // add this
      });
      await _updateMarkers();
      await _updateMaqamMarkers();
    }
  }

  // New method — handles both first load and refresh
  Future<void> _updateMarkers() async {
    if (mapboxMapController == null || mosques.isEmpty) return;
    debugPrint("_updateMarkers called with ${mosques.length} mosques");

    try {
      await mapboxMapController!.style.setStyleSourceProperty(
        "mosques-source",
        "data",
        _buildMosqueGeoJson(),
      );
      // Also update maqam source if it exists
      try {
        await mapboxMapController!.style.setStyleSourceProperty(
          "maqam-source",
          "data",
          _buildMaqamGeoJson(),
        );
      } catch (_) {}
      debugPrint("Sources updated successfully");
      return;
    } catch (e) {
      debugPrint("Source update failed (first load): $e");
    }

    // First time setup
    debugPrint("Doing first time marker setup");
    try {
      final visitedIcon = await _createMosqueIcon(true);
      final unvisitedIcon = await _createMosqueIcon(false);
      final maqamIcon = await _createMaqamIcon();

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
      await mapboxMapController!.style.addStyleImage(
        "maqam-icon",
        1.0,
        MbxImage(width: 80, height: 80, data: maqamIcon),
        false,
        [],
        [],
        null,
      );
      debugPrint("Icons added");

      // Mosque source + layer
      await mapboxMapController!.style.addSource(
        GeoJsonSource(id: "mosques-source", data: _buildMosqueGeoJson()),
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
          textOptional: true,
        ),
      );

      // Maqam source + layer — separate from mosques
      await mapboxMapController!.style.addSource(
        GeoJsonSource(id: "maqam-source", data: _buildMaqamGeoJson()),
      );
      await mapboxMapController!.style.addLayer(
        SymbolLayer(
          id: "maqam-layer",
          sourceId: "maqam-source",
          iconImage: "maqam-icon",
          iconSize: 0.6,
          iconAllowOverlap: true,
          textField: "{name}",
          textSize: 10.0,
          textOffset: [0.0, 2.2],
          textAnchor: TextAnchor.TOP,
          textColor: 0xFFE8B96A,
          textHaloColor: 0xFF0F1A14,
          textHaloWidth: 1.5,
          textOptional: true,
        ),
      );

      _hidePOILayers();
      mapboxMapController!.setOnMapTapListener(_onMapTap);
      debugPrint("Setup complete");
    } catch (e) {
      debugPrint("First time setup ERROR: $e");
    }
  }

  Future<void> _updateMaqamMarkers() async {
    if (mapboxMapController == null || mosques.isEmpty) return;
    debugPrint("_updateMarkers called with ${mosques.length} mosques");

    try {
      await mapboxMapController!.style.setStyleSourceProperty(
        "mosques-source",
        "data",
        _buildMosqueGeoJson(),
      );
      debugPrint("Source updated successfully");
      return;
    } catch (e) {
      debugPrint("Source update failed (expected on first load): $e");
    }

    // First time setup
    debugPrint("Doing first time marker setup");
    try {
      final visitedIcon = await _createMaqamIcon();

      await mapboxMapController!.style.addStyleImage(
        "mosque-visited",
        1.0,
        MbxImage(width: 80, height: 80, data: visitedIcon),
        false,
        [],
        [],
        null,
      );
      debugPrint("Icons added");

      await mapboxMapController!.style.addSource(
        GeoJsonSource(id: "mosques-source", data: _buildMaqamGeoJson()),
      );
      debugPrint("Source added");

      await mapboxMapController!.style.addLayer(
        SymbolLayer(
          id: "mosques-layer",
          sourceId: "mosques-source",
          iconImageExpression: ["get", "icon"],
          iconSize: 0.6,
          iconAllowOverlap: true,
          // iconIgnorePlacement: true, // add this
          textField: "{name}",
          textSize: 10.0,
          textOffset: [0.0, 2.2],
          textAnchor: TextAnchor.TOP,
          textColor: 0xFFE8B96A,
          textHaloColor: 0xFF0F1A14,
          textHaloWidth: 1.5,
          textOptional: true,
        ),
      );
      debugPrint("Layer added");

      _hidePOILayers();
      mapboxMapController!.setOnMapTapListener(_onMapTap);
      debugPrint("Setup complete");
    } catch (e) {
      debugPrint("First time setup ERROR: $e");
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

  Future<Uint8List> _createMaqamIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 80.0;

    final bgColor = const Color(0xFF9E5241); // Warm Terracotta / Brick Red
    final borderColor = const Color(
      0xFFC9963A,
    ); // Kept the same for UI consistency!
    final iconColor = const Color(0xFFF5E6CC); // Soft Warm Sand / Cream

    final glowPaint = Paint()
      ..color = const Color(0xFF9E5241).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(const Offset(size / 2, size / 2), 28, glowPaint);

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '🏠',
        style: TextStyle(fontSize: 20, color: iconColor),
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

    final geoJson = _buildMosqueGeoJson();

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
        // textAllowOverlap: false,
        textOptional: true,
      ),
    );

    _hidePOILayers();
    mapboxMapController!.setOnMapTapListener(_onMapTap);
    debugPrint("Markers added: ${mosques.length}");
  }

  Future<void> _addMaqamMarkers() async {
    if (mapboxMapController == null || mosques.isEmpty) return;

    final visitedIcon = await _createMaqamIcon();

    await mapboxMapController!.style.addStyleImage(
      "mosque-visited",
      1.0,
      MbxImage(width: 80, height: 80, data: visitedIcon),
      false,
      [],
      [],
      null,
    );

    final geoJson = _buildMaqamGeoJson();

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

  void _getMaqamVisited() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('personal_places')
          .select('id, user_id, name, lat, lng')
          .eq('user_id', userId)
          .order('created_at');

      _visitedMaqam = List<Map<String, dynamic>>.from(response);
      setState(() => visitedMaqam = _visitedMaqam.length);

      // Update maqam layer if map is ready
      if (mapboxMapController != null) {
        try {
          await mapboxMapController!.style.setStyleSourceProperty(
            "maqam-source",
            "data",
            _buildMaqamGeoJson(),
          );
        } catch (_) {
          // Layer not ready yet — will be added when _updateMarkers runs
        }
      }
    } catch (e) {
      debugPrint("Error loading maqam: $e");
      _visitedMaqam = [];
    }
  }

  // ✅ NEW: builds a fresh GeoJSON string reflecting current visited state
  String _buildMosqueGeoJson() {
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

  String _buildMaqamGeoJson() {
    final features = _visitedMaqam.map((maqam) {
      return {
        "type": "Feature",
        "properties": {
          "id": maqam["id"].toString(),
          "name": maqam["name"] ?? "Maqam",
          "icon": "maqam-icon",
        },
        "geometry": {
          "type": "Point",
          "coordinates": [maqam["lng"], maqam["lat"]],
        },
      };
    }).toList();

    return jsonEncode({"type": "FeatureCollection", "features": features});
  }

  // ✅ NEW: called by the bottom sheet after a visit change.
  // Updates the GeoJSON source in-place — no layer rebuild needed.
  Future<void> _refreshMarkers() async {
    if (mapboxMapController == null) return;

    final geoJson = _buildMosqueGeoJson();

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
    RenderedQueryOptions(layerIds: ["mosques-layer", "maqam-layer"]);

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
    _getMosqueVisited();
    _getTotalMosque();
    _getMaqamVisited();
    _getCurrentMosqueStatus();
    super.initState();
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    _geofenceService.stop();
    super.dispose();
  }

  void _getCurrentMosqueStatus() async {
    int status = await _localDatabaseService.getCurrentStatus();
    setState(() {
      mosqueStatus = status; // Trigger a rebuild once data arrives
    });
  }

  void _onMapCreated(MapboxMap controller) async {
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

  void _getMosqueVisited() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('visitedMosque')
          .select('id, mosque_id, visited_at')
          .eq('user_id', userId)
          .order('visited_at');

      _visitedMosques = List<Map<String, dynamic>>.from(response);
      setState(() {
        visitedMosque = _visitedMosques.length;
      });
    } catch (e) {
      print("Error loading visited mosques: $e");
      _visitedMosques = [];
    }
  }

  void _getTotalMaqamVisited() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('personal_places')
          .select('id, user_id, name')
          .eq('user_id', userId)
          .order('created_at');

      _visitedMaqam = List<Map<String, dynamic>>.from(response);
      setState(() {
        visitedMaqam = _visitedMaqam.length;
      });
    } catch (e) {
      print("Error loading visited mosques: $e");
      _visitedMaqam = [];
    }
  }

  void _getTotalMosque() async {
    try {
      // 1. Request only the count from Supabase without downloading row data
      final response = await _supabase
          .from('mosques')
          .select('id') // Selecting just 'id' is enough when counting
          .count(CountOption.exact);

      // 2. Safely check if the widget is still active before updating UI
      if (!mounted) return;

      // 3. Update the state with the count returned from the server
      setState(() {
        totalMosque = response.count;
      });
    } catch (e) {
      print("Error loading mosque count: $e");
    }
  }

  // ── Show add options sheet ─────────────────────────────────────────────────
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF152419),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9963A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Add to map",
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                color: Color(0xFFF5F0E8),
              ),
            ),
            const SizedBox(height: 20),

            // Add mosque option
            _AddOptionTile(
              icon: "🕌",
              title: "Add a Mosque",
              subtitle: "Visible to all users on the map",
              onTap: () {
                Navigator.pop(context);
                _showAddMosqueForm();
              },
            ),
            const SizedBox(height: 10),

            // Add personal place option
            _AddOptionTile(
              icon: "📍",
              title: "Add a Maqam",
              subtitle: "Your personal prayer spot, visible only to you",
              onTap: () {
                Navigator.pop(context);
                _showAddPersonalPlaceForm();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Add mosque form ────────────────────────────────────────────────────────
  void _showAddMosqueForm({double? useLat, double? useLng}) {
    final nameController = TextEditingController();
    bool isSubmitting = false;
    bool useCurrentLocation = useLat == null;
    double formLat = useLat ?? lat;
    double formLng = useLng ?? long;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF152419),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9963A).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Add a Mosque",
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      color: Color(0xFFF5F0E8),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  Text(
                    "MOSQUE NAME",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: useLat == null,
                    style: const TextStyle(
                      color: Color(0xFFF5F0E8),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. Masjid Al-Noor",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF52B788)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location selection
                  Text(
                    "LOCATION",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Current location option
                  GestureDetector(
                    onTap: () => setSheetState(() {
                      useCurrentLocation = true;
                      formLat = lat;
                      formLng = long;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: useCurrentLocation
                            ? const Color(0xFF2D6A4F).withOpacity(0.2)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: useCurrentLocation
                              ? const Color(0xFF52B788).withOpacity(0.4)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: useCurrentLocation
                                ? const Color(0xFF52B788)
                                : Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Use my current location",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: useCurrentLocation
                                        ? const Color(0xFFF5F0E8)
                                        : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (useCurrentLocation)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Color(0xFF52B788),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pin on map option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _pinDropMode = true;
                        _pendingAddType = 'mosque';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !useCurrentLocation
                            ? const Color(0xFF2D6A4F).withOpacity(0.2)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !useCurrentLocation
                              ? const Color(0xFF52B788).withOpacity(0.4)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_pin,
                            size: 16,
                            color: !useCurrentLocation
                                ? const Color(0xFF52B788)
                                : Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Pin on map",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: !useCurrentLocation
                                        ? const Color(0xFFF5F0E8)
                                        : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  useLat != null
                                      ? "${useLat.toStringAsFixed(5)}, ${useLng!.toStringAsFixed(5)}"
                                      : "Tap to place pin on map",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            useLat != null
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            size: 16,
                            color: useLat != null
                                ? const Color(0xFF52B788)
                                : Colors.white.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              await _submitMosque(
                                nameController.text.trim(),
                                submitLat: formLat,
                                submitLng: formLng,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF5F0E8),
                              ),
                            )
                          : const Text(
                              "Add Mosque",
                              style: TextStyle(
                                color: Color(0xFFF5F0E8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit mosque to Supabase ──────────────────────────────────────────────
  Future<void> _submitMosque(
    String name, {
    required double submitLat,
    required double submitLng,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final address = await mosqueService.getAddressFromLatLng(
        submitLat,
        submitLng,
      );

      final newId = 'user_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.from('mosques').insert({
        'id': newId,
        'name': name,
        'lat': submitLat,
        'lng': submitLng,
        'city': address['city'] ?? '',
        'country': address['country'] ?? '',
        'added_by': userId,
        'verified': false,
        'status': 'open',
      });

      await _supabase.rpc(
        'update_mosque_location',
        params: {'mosque_id': newId},
      );

      await setMosquesData(overrideLat: submitLat, overrideLng: submitLng);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mosque added — JazakAllah Khair"),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding mosque: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Add personal place form ────────────────────────────────────────────────
  void _showAddPersonalPlaceForm({double? useLat, double? useLng}) {
    final nameController = TextEditingController();
    bool isSubmitting = false;
    bool useCurrentLocation = useLat == null;
    double formLat = useLat ?? lat;
    double formLng = useLng ?? long;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF152419),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9963A).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Add a Maqam",
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    color: Color(0xFFF5F0E8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Your personal prayer spot — only visible to you",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  "PLACE NAME",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Color(0xFFF5F0E8),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: "e.g. Home, Office, Dargah",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF52B788)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setSheetState(() {
                    useCurrentLocation = true;
                    formLat = lat;
                    formLng = long;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: useCurrentLocation
                          ? const Color(0xFF2D6A4F).withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: useCurrentLocation
                            ? const Color(0xFF52B788).withOpacity(0.4)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: useCurrentLocation
                              ? const Color(0xFF52B788)
                              : Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Use my current location",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: useCurrentLocation
                                      ? const Color(0xFFF5F0E8)
                                      : Colors.white.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (useCurrentLocation)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF52B788),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Pin on map option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _pinDropMode = true;
                      _pendingAddType = 'personal';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !useCurrentLocation
                          ? const Color(0xFF2D6A4F).withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !useCurrentLocation
                            ? const Color(0xFF52B788).withOpacity(0.4)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_pin,
                          size: 16,
                          color: !useCurrentLocation
                              ? const Color(0xFF52B788)
                              : Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pin on map",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: !useCurrentLocation
                                      ? const Color(0xFFF5F0E8)
                                      : Colors.white.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                useLat != null
                                    ? "${useLat.toStringAsFixed(5)}, ${useLng!.toStringAsFixed(5)}"
                                    : "Tap to place pin on map",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          useLat != null
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          size: 16,
                          color: useLat != null
                              ? const Color(0xFF52B788)
                              : Colors.white.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) return;
                            setSheetState(() => isSubmitting = true);
                            await _submitPersonalPlace(
                              nameController.text.trim(),
                              submitLat: formLat,
                              submitLng: formLng,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFFC9963A).withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE8B96A),
                            ),
                          )
                        : const Text(
                            "Add Maqam",
                            style: TextStyle(
                              color: Color(0xFFE8B96A),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit personal place to Supabase ─────────────────────────────────────
  Future<void> _submitPersonalPlace(
    String name, {
    required double submitLat,
    required double submitLng,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('personal_places').insert({
        'user_id': userId,
        'name': name,
        'lat': submitLat,
        'lng': submitLng,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Maqam added"),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding personal place: $e");
    }
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
            onCameraChangeListener: (CameraChangedEventData data) {
              _cameraDebounce?.cancel();
              _cameraDebounce = Timer(
                const Duration(milliseconds: 800),
                () async {
                  debugPrint("Camera settled");
                  if (mapboxMapController == null) return;

                  final centerLat = data.cameraState.center.coordinates.lat
                      .toDouble();
                  final centerLng = data.cameraState.center.coordinates.lng
                      .toDouble();

                  final distance = _calculateDistance(
                    _lastFetchLat,
                    _lastFetchLng,
                    centerLat,
                    centerLng,
                  );

                  debugPrint("Distance from last fetch: ${distance.round()}m");

                  if (distance > 2000) {
                    debugPrint("Fetching mosques for new area");
                    await setMosquesData(
                      overrideLat: centerLat,
                      overrideLng: centerLng,
                    );
                  }
                },
              );
            },
          ),

          SafeArea(
            child: Center(
              heightFactor: 1.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
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
                      ).withOpacity(0.4),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("🕌", style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Text(
                          "${visitedMosque}",
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF5F0E8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
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
                      ).withOpacity(0.4),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("🏠", style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Text(
                          "${visitedMaqam}",
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF5F0E8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoadingOverpass)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152419).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC9963A).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF52B788),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Finding mosques nearby...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Pin drop mode overlay
          if (_pinDropMode)
            Stack(
              children: [
                // Overlay hint + pin — ignore pointer so map stays interactive
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF152419).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFC9963A).withOpacity(0.4),
                              ),
                            ),
                            child: const Text(
                              "Move map to position the pin",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE8B96A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Icon(
                            Icons.location_pin,
                            color: Color(0xFFC9963A),
                            size: 48,
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom buttons — these DO receive touches
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _pinDropMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9E9C97),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final cameraState = await mapboxMapController!
                                .getCameraState();
                            setState(() {
                              _pinnedLat = cameraState.center.coordinates.lat
                                  .toDouble();
                              _pinnedLng = cameraState.center.coordinates.lng
                                  .toDouble();
                              _pinDropMode = false;
                            });
                            if (_pendingAddType == 'mosque') {
                              _showAddMosqueForm(
                                useLat: _pinnedLat,
                                useLng: _pinnedLng,
                              );
                            } else {
                              _showAddPersonalPlaceForm(
                                useLat: _pinnedLat,
                                useLng: _pinnedLng,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF52B788).withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              "Confirm Pin",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFF5F0E8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // ✅ Add button
          Positioned(
            right: 16,
            bottom: 72, // sits above location FAB
            child: GestureDetector(
              onTap: _showAddOptions,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF152419).withOpacity(0.97),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC9963A).withOpacity(0.3),
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
                  Icons.add_rounded,
                  color: Color(0xFFC9963A),
                  size: 22,
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

class _AddOptionTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF5F0E8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
