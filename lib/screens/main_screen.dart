import 'package:flutter/material.dart';
import 'package:mosque_tracker/components/prayerConfirmModal.dart';
import 'package:mosque_tracker/screens/badges_screen.dart';
import 'package:mosque_tracker/screens/bottom_nav.dart';
import 'package:mosque_tracker/screens/map_screen.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';
import 'package:mosque_tracker/services/local_database_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

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
    _checkPendingMosque(); // check on first load too
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingMosque();
    }
  }

  Future<void> _checkPendingMosque() async {
    final pending = await LocalDatabaseService.instance.getPendingMosque();
    if (pending == null) return;
    if (!mounted) return;

    // Small delay so the screen is fully built
    await Future.delayed(const Duration(milliseconds: 500));

    _showPrayerModal(pending);
  }

  void _showPrayerModal(Map<String, dynamic> pending) {
    showModalBottomSheet(
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
          Navigator.pop(context);
        },
        onDismiss: () async {
          await LocalDatabaseService.instance.clearPendingMosque();
          Navigator.pop(context);
        },
      ),
    );
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
          BadgesScreen(),
          BadgesScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _currentIndex, onTap: _goTo),
    );
  }
}
