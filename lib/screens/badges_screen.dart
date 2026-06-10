import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mosque_tracker/services/badge_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  List<dynamic> _badges = [];
  List<String> _unlockedIds = [];
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await BadgeService().grantNewBadge();
    } catch (e) {
      debugPrint("Badge grant error: $e");
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      final jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/badges.json');

      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final List<dynamic> localData = jsonMap['badges'];

      final userId = _supabase.auth.currentUser?.id ?? '';
      final dbData = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final earned = dbData.map((row) => row['badge_id'].toString()).toList();

      if (!mounted) return;
      setState(() {
        _badges = localData;
        _unlockedIds = earned;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Badge load error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF52B788)),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                _buildGrid(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1B4332),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "COLLECTION",
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: Color(0xFFE8B96A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Your Badges",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  color: Color(0xFFF5F0E8),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final badge = _badges[index];
          final String badgeId = badge["id"] ?? "";
          final bool isUnlocked = _unlockedIds.contains(badgeId);

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF112219),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnlocked
                    ? const Color(0xFFE8B96A).withOpacity(0.3)
                    : const Color(0xFF1A3326),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ColorFiltered(
                //   colorFilter: ColorFilter.mode(
                //     isUnlocked ? Colors.transparent : Colors.grey,
                //     BlendMode.saturation,
                //   ),
                //   child: Image.network(
                //     badge['image_url'] ?? '',
                //     height: 64,
                //     errorBuilder: (_, __, ___) => const Icon(
                //       Icons.workspace_premium,
                //       size: 64,
                //       color: Colors.white24,
                //     ),
                //   ),
                // ),
                const SizedBox(height: 12),
                Text(
                  badge['name'] ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isUnlocked
                        ? const Color(0xFFE8B96A)
                        : Colors.white30,
                    fontWeight: isUnlocked
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUnlocked ? "Unlocked" : "Locked",
                  style: TextStyle(
                    fontSize: 10,
                    color: isUnlocked
                        ? const Color(0xFF52B788)
                        : Colors.white24,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          );
        }, childCount: _badges.length),
      ),
    );
  }
}
