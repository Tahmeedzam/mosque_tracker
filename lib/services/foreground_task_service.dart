import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mosque_tracker/services/local_database_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:mosque_tracker/services/prayer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MosqueTaskHandler());
}

class MosqueTaskHandler extends TaskHandler {
  final _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 3000, // 10s for testing, change to 300000 for prod
    statusChangeDelayMs: 1000,
    allowMockLocations: true,
    printDevLog: true,
  );

  final _notifications = FlutterLocalNotificationsPlugin();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print("Foreground task started");

    // Initialize dotenv
    await dotenv.load(fileName: ".env");

    // Initialize Supabase in this isolate
    try {
      await Supabase.initialize(
        anonKey: dotenv.env["SUPABASE_ANON_KEY"]!,
        url: dotenv.env["SUPABASE_URL"]!,
      );
    } catch (e) {
      print("Supabase already initialized or error: $e");
    }

    // Initialize notifications in this isolate
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      "prayer_prompt",
      "Prayer Prompts",
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Load mosques
    await MosqueService().loadMosques();
    await MosqueService().loadVisitedMosques();

    // Get location
    final position = await geo.Geolocator.getCurrentPosition();
    final nearby = MosqueService().getMosquesNearby(
      position.latitude,
      position.longitude,
    );

    print("Background geofencing for ${nearby.length} mosques");

    // Build geofences
    final geofences = nearby.map((mosque) {
      return Geofence(
        id: mosque["id"].toString(),
        latitude: (mosque["lat"] as num).toDouble(),
        longitude: (mosque["lng"] as num).toDouble(),
        radius: [GeofenceRadius(id: "radius_${mosque["id"]}", length: 150)],
      );
    }).toList();

    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatus);
    await _geofenceService.start(geofences);
    await PrayerService().initialize();
    await PrayerService().fetchPrayerTimes();
  }

  Future<void> _onGeofenceStatus(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    print("Background geofence: ${geofence.id} — $status");

    if (status == GeofenceStatus.DWELL) {
      if (MosqueService().isMosqueVisited(geofence.id)) return;

      // Get mosque name
      final mosque = MosqueService().mosques.firstWhere(
        (m) => m["id"].toString() == geofence.id,
        orElse: () => {"name": "a mosque"},
      );
      final mosqueName = mosque["name"].toString();

      // Save to local DB
      await LocalDatabaseService.instance.savePendingMosque(
        geofence.id,
        mosqueName,
      );

      // Send notification
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: "You've been at $mosqueName",
        body: "Tap to log your prayer",
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            "prayer_prompt",
            "Prayer Prompts",
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

      print("Notification sent for $mosqueName");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print("Foreground task alive: $timestamp");
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _geofenceService.removeGeofenceStatusChangeListener(_onGeofenceStatus);
    await _geofenceService.stop();
    print("Foreground task destroyed");
  }
}
