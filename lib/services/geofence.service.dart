import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:mosque_tracker/services/local_database_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';

// Both must be top-level functions outside the clas

class MosqueGeofenceService {
  static final MosqueGeofenceService _instance =
      MosqueGeofenceService._internal();
  factory MosqueGeofenceService() => _instance;
  MosqueGeofenceService._internal();
  Function(String mosqueId, String mosqueName, String triggeredAt)?
  onDwellDetected;

  final _geofenceService = GeofenceService.instance.setup(
    interval: 5000, // check every 5 seconds
    accuracy: 100, // 100 meters accuracy
    // loiteringDelayMs: 300000, // 5 minutes dwell time
    loiteringDelayMs: 10000, // 10 seconds dwell time
    statusChangeDelayMs: 1000,
    allowMockLocations: false,
    printDevLog: true,
  );

  bool _initialized = false;

  // Called from outside when visit is confirmed
  Function(String mosqueId, String mosqueName)? onPrayerConfirmed;

  Future<void> startGeofencing(List<Map<String, dynamic>> nearbyMosques) async {
    // Stop any existing geofencing first
    await _geofenceService.stop();

    if (nearbyMosques.isEmpty) return;

    // Only create geofences for mosques within 2km
    final geofences = nearbyMosques.map((mosque) {
      return Geofence(
        id: mosque["id"].toString(),
        latitude: (mosque["lat"] as num).toDouble(),
        longitude: (mosque["lng"] as num).toDouble(),
        radius: [
          GeofenceRadius(
            id: "radius_150m_${mosque["id"]}",
            length: 150, // 150 meter radius
          ),
        ],
      );
    }).toList();

    // Listen to geofence events
    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);

    await _geofenceService.start(geofences);
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status == GeofenceStatus.DWELL) {
      if (MosqueService().isMosqueVisited(geofence.id)) return;

      final mosqueName = _getMosqueName(geofence.id);
      final triggeredAt = DateTime.now().toIso8601String();

      // Save to local DB always
      await LocalDatabaseService.instance.savePendingMosque(
        geofence.id,
        mosqueName,
      );

      // If app is open, fire callback directly — skip notification
    }
  }

  String _getMosqueName(String mosqueId) {
    final mosque = MosqueService().mosques.firstWhere(
      (m) => m["id"].toString() == mosqueId,
      orElse: () => {"name": "this mosque"},
    );
    return mosque["name"].toString();
  }

  Future<void> stop() async {
    await _geofenceService.stop();
    _geofenceService.removeGeofenceStatusChangeListener(
      _onGeofenceStatusChanged,
    );
  }
}
