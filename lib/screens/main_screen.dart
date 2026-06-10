import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mosque_tracker/components/prayerConfirmModal.dart';
import 'package:mosque_tracker/screens/badges_screen.dart';
import 'package:mosque_tracker/screens/bottom_nav.dart';
import 'package:mosque_tracker/screens/map_screen.dart';
import 'package:mosque_tracker/screens/prayer_time_screen.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';
import 'package:mosque_tracker/services/local_database_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:vibration/vibration.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _modalShowing = false;
  bool _proximityChecked = false;

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPendingMosque();
      if (!_modalShowing && !_proximityChecked) {
        await Future.delayed(const Duration(seconds: 5));
        _proximityChecked = true;
        if (!_modalShowing) _checkProximity();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_modalShowing) {
      _checkPendingMosque();
      // Reset proximity check so it runs again on next resume
      Future.delayed(const Duration(seconds: 3), () {
        if (!_modalShowing && !_proximityChecked) {
          _proximityChecked = true;
          _checkProximity();
        }
      });
    }
    if (state == AppLifecycleState.paused) {
      _proximityChecked = false;
    }
  }

  // ── Proximity check ───────────────────────────────────────────────────────
  Future<void> _checkProximity() async {
    if (_modalShowing) return;
    if (!mounted) return;

    try {
      // Get current location
      final position = await geo.Geolocator.getCurrentPosition();
      final userLat = position.latitude;
      final userLng = position.longitude;

      // Get all mosques from memory
      final mosques = MosqueService().mosques;
      if (mosques.isEmpty) return;

      // Find closest mosque within 150m
      Map<String, dynamic>? closestMosque;
      double closestDistance = double.infinity;

      for (final mosque in mosques) {
        final mLat = (mosque['lat'] as num).toDouble();
        final mLng = (mosque['lng'] as num).toDouble();
        final distance = _calculateDistance(userLat, userLng, mLat, mLng);

        if (distance <= 150 && distance < closestDistance) {
          // Skip if already visited
          if (MosqueService().isMosqueVisited(mosque['id'].toString()))
            continue;
          closestDistance = distance;
          closestMosque = mosque;
        }
      }

      if (closestMosque == null) return;
      if (!mounted) return;

      debugPrint(
        "Nearby mosque found: ${closestMosque['name']} — ${closestDistance.round()}m",
      );

      // Save to local DB and show modal
      await LocalDatabaseService.instance.savePendingMosque(
        closestMosque['id'].toString(),
        closestMosque['name'].toString(),
      );

      _showPrayerModal({
        "mosque_id": closestMosque['id'].toString(),
        "mosque_name": closestMosque['name'].toString(),
        "triggered_at": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Proximity check error: $e");
    }
  }

  // ── Haversine distance in meters ──────────────────────────────────────────
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * (pi / 180);

  // ── Pending mosque check ──────────────────────────────────────────────────
  Future<void> _checkPendingMosque() async {
    if (_modalShowing) return;
    final pending = await LocalDatabaseService.instance.getPendingMosque();
    if (pending == null) return;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (_modalShowing) return;
    _showPrayerModal(pending);
  }

  // ── Show modal ────────────────────────────────────────────────────────────
  void _showPrayerModal(Map<String, dynamic> pending) async {
    if (_modalShowing) return;
    if (!mounted) return;

    Vibration.vibrate(
      pattern: [0, 400, 200, 400],
      intensities: [0, 200, 0, 200],
    );

    setState(() => _modalShowing = true);

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => PrayerConfirmModal(
        mosqueId: pending["mosque_id"],
        mosqueName: pending["mosque_name"],
        triggeredAt: pending["triggered_at"],
        onConfirm: () async {
          await MosqueService().markMosqueVisited(pending["mosque_id"]);
          await LocalDatabaseService.instance.clearPendingMosque();
          if (context.mounted) Navigator.pop(context);
        },
        onDismiss: () async {
          await LocalDatabaseService.instance.clearPendingMosque();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );

    if (mounted) setState(() => _modalShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: const [
          MapScreen(),
          PrayerTimeScreen(),
          BadgesScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _currentIndex, onTap: _goTo),
    );
  }
}
