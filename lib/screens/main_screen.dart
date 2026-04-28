import 'package:flutter/material.dart';
import 'package:mosque_tracker/screens/badges_screen.dart';
import 'package:mosque_tracker/screens/bottom_nav.dart';
import 'package:mosque_tracker/screens/map_screen.dart';
import 'package:mosque_tracker/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
