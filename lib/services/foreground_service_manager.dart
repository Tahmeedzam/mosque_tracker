import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_task_service.dart';

class ForegroundServiceManager {
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: "mosque_tracker_service",
        channelName: "Mosque Tracker",
        channelDescription: "Detecting nearby mosques in background",
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    try {
      await FlutterForegroundTask.startService(
        serviceId: 1,
        notificationTitle: "Masjid Tracker",
        notificationText: "Detecting nearby mosques...",
        callback: startCallback,
      );
    } catch (e) {}
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
