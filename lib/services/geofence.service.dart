import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mosque_tracker/services/local_database_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';

// Both must be top-level functions outside the class
@pragma('vm:entry-point')
void notificationTapForeground(NotificationResponse response) async {
  print(
    "Foreground notification tapped — action: ${response.actionId}, payload: ${response.payload}",
  );

  if (response.actionId == "yes_prayed") {
    final mosqueId = response.payload ?? "";
    if (mosqueId.isEmpty) return;
    await MosqueService().markMosqueVisited(mosqueId);
    print("Mosque $mosqueId marked visited from foreground notification");
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  print(
    "Background notification tapped — action: ${response.actionId}, payload: ${response.payload}",
  );

  if (response.actionId == "yes_prayed") {
    final mosqueId = response.payload ?? "";
    if (mosqueId.isEmpty) return;
    await MosqueService().markMosqueVisited(mosqueId);
    print("Mosque $mosqueId marked visited from background notification");
  }
}

class MosqueGeofenceService {
  static final MosqueGeofenceService _instance =
      MosqueGeofenceService._internal();
  factory MosqueGeofenceService() => _instance;
  MosqueGeofenceService._internal();

  final _geofenceService = GeofenceService.instance.setup(
    interval: 5000, // check every 5 seconds
    accuracy: 100, // 100 meters accuracy
    // loiteringDelayMs: 300000, // 5 minutes dwell time
    loiteringDelayMs: 10000, // 10 seconds dwell time
    statusChangeDelayMs: 1000,
    allowMockLocations: false,
    printDevLog: true,
  );

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Called from outside when visit is confirmed
  Function(String mosqueId, String mosqueName)? onPrayerConfirmed;

  Future<void> initialize() async {
    if (_initialized) return;

    // Setup notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: notificationTapForeground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
  }

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
    print("Geofencing started for ${geofences.length} mosques");
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

      // Save to local DB
      await LocalDatabaseService.instance.savePendingMosque(
        geofence.id,
        mosqueName,
      );

      // Send simple notification — no action buttons
      await _showSimpleNotification(mosqueName);
    }
  }

  Future<void> _showSimpleNotification(String mosqueName) async {
    const androidDetails = AndroidNotificationDetails(
      "prayer_prompt",
      "Prayer Prompts",
      channelDescription: "Prompts when you arrive at a mosque",
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: "You've been at $mosqueName",
      body: "Tap to log your prayer",
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  String _getMosqueName(String mosqueId) {
    final mosque = MosqueService().mosques.firstWhere(
      (m) => m["id"].toString() == mosqueId,
      orElse: () => {"name": "this mosque"},
    );
    return mosque["name"].toString();
  }

  Future<void> _showPrayerPrompt(String mosqueId, String mosqueName) async {
    const androidDetails = AndroidNotificationDetails(
      "prayer_prompt",
      "Prayer Prompts",
      channelDescription: "Prompts when you arrive at a mosque",
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction("yes_prayed", "✓ Yes, I prayed"),
        AndroidNotificationAction("not_now", "Not this time"),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: "prayer_prompt",
    );

    await _notifications.show(
      id: mosqueId.hashCode,
      title: "You've been at $mosqueName",
      body: "Did you pray here today?",
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: mosqueId,
    );
  }

  Future<void> stop() async {
    await _geofenceService.stop();
    _geofenceService.removeGeofenceStatusChangeListener(
      _onGeofenceStatusChanged,
    );
  }
}
