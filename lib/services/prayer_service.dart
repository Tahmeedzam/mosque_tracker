import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTime {
  final String name;
  final String arabicName;
  final DateTime time;
  final IconData icon;

  PrayerTime({
    required this.name,
    required this.arabicName,
    required this.time,
    required this.icon,
  });
}

class PrayerService {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _audioPlayer = AudioPlayer();
  bool _initialized = false;

  List<PrayerTime> _prayerTimes = [];
  String _locationName = "";
  DateTime? _lastFetched;

  List<PrayerTime> get prayerTimes => _prayerTimes;
  String get locationName => _locationName;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      "adhan_channel",
      "Adhan",
      description: "Adhan notification at prayer times",
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Play adhan sound when notification is tapped
    _playAdhan();
  }

  Future<void> _playAdhan() async {
    try {
      await _audioPlayer.play(AssetSource('audio/adhan.mp3'));
    } catch (e) {
      debugPrint("Error playing adhan: $e");
    }
  }

  Future<List<PrayerTime>> fetchPrayerTimes() async {
    // Return cached if fetched today
    final now = DateTime.now();
    if (_lastFetched != null &&
        _lastFetched!.day == now.day &&
        _prayerTimes.isNotEmpty) {
      return _prayerTimes;
    }

    try {
      // Get location
      final position = await geo.Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      // Fetch from Aladhan API
      // Method 3 = Muslim World League (best for international)
      final url = Uri.parse(
        "https://api.aladhan.com/v1/timings/${now.day}-${now.month}-${now.year}"
        "?latitude=$lat&longitude=$lng&method=3",
      );

      final response = await http.get(url);
      if (response.statusCode != 200) throw "API error ${response.statusCode}";

      final data = jsonDecode(response.body);
      final timings = data["data"]["timings"];
      final meta = data["data"]["meta"];

      _locationName = "${meta["timezone"]}";

      // Save to prefs for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("prayer_times_cache", response.body);
      await prefs.setString(
        "prayer_times_date",
        "${now.day}-${now.month}-${now.year}",
      );

      _prayerTimes = _parseTimes(timings, now);
      _lastFetched = now;

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint("Notification permission: $granted");

      // Schedule adhans for today
      await _scheduleAdhans();

      return _prayerTimes;
    } catch (e) {
      debugPrint("Error fetching prayer times: $e");

      // Try loading from cache
      return await _loadFromCache();
    }
  }

  Future<List<PrayerTime>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString("prayer_times_cache");
      if (cached == null) return [];

      final data = jsonDecode(cached);
      final timings = data["data"]["timings"];
      final now = DateTime.now();
      _prayerTimes = _parseTimes(timings, now);
      return _prayerTimes;
    } catch (e) {
      return [];
    }
  }

  List<PrayerTime> _parseTimes(Map timings, DateTime now) {
    DateTime parseTime(String t) {
      final parts = t.split(":");
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return [
      PrayerTime(
        name: "Sehri / Fajr",
        arabicName: "الفجر",
        time: parseTime(timings["Fajr"]),
        icon: Icons.dark_mode_outlined,
      ),
      PrayerTime(
        name: "Sunrise",
        arabicName: "الشروق",
        time: parseTime(timings["Sunrise"]),
        icon: Icons.wb_twilight_outlined,
      ),
      PrayerTime(
        name: "Dhuhr",
        arabicName: "الظهر",
        time: parseTime(timings["Dhuhr"]),
        icon: Icons.wb_sunny_outlined,
      ),
      PrayerTime(
        name: "Asr",
        arabicName: "العصر",
        time: parseTime(timings["Asr"]),
        icon: Icons.light_mode_outlined,
      ),
      PrayerTime(
        name: "Iftaar / Maghrib",
        arabicName: "المغرب",
        time: parseTime(timings["Maghrib"]),
        icon: Icons.sunny_snowing,
      ),
      PrayerTime(
        name: "Isha",
        arabicName: "العشاء",
        time: parseTime(timings["Isha"]),
        icon: Icons.nightlight_outlined,
      ),
    ];
  }

  Future<void> _scheduleAdhans() async {
    // Cancel existing adhan notifications
    await _notifications.cancelAll();
    final now = DateTime.now();

    for (int i = 0; i < _prayerTimes.length; i++) {
      final prayer = _prayerTimes[i];
      debugPrint("Scheduling adhan for ${prayer.name} at ${prayer.time}");
      debugPrint("_scheduleAdhans called, ${_prayerTimes.length} prayers");
      debugPrint(
        "Now: $now, Prayer time: ${prayer.time}, Is future: ${prayer.time.isAfter(now)}",
      );

      // Skip sunrise — no adhan for sunrise
      if (prayer.name == "Sunrise") continue;

      // Skip past prayer times
      if (prayer.time.isBefore(now)) continue;

      final scheduledTime = tz.TZDateTime.from(prayer.time, tz.local);

      await _notifications.zonedSchedule(
        id: i,
        title: "وقت الصلاة — ${prayer.name}",
        body: "حان وقت ${prayer.arabicName}",
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            "adhan_channel",
            "Adhan",
            channelDescription: "Adhan at prayer times",
            importance: Importance.high,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('adhan'),
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'adhan.mp3',
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    debugPrint("Adhans scheduled for ${_prayerTimes.length} prayers");
  }

  // Get next prayer
  PrayerTime? getNextPrayer() {
    final now = DateTime.now();
    for (final prayer in _prayerTimes) {
      if (prayer.name == "Sunrise") continue;
      if (prayer.time.isAfter(now)) return prayer;
    }
    return null;
  }

  // Duration until next prayer
  Duration? getTimeUntilNextPrayer() {
    final next = getNextPrayer();
    if (next == null) return null;
    return next.time.difference(DateTime.now());
  }

  // Play adhan immediately (for testing or manual trigger)
  Future<void> playAdhanNow() async => _playAdhan();
}
