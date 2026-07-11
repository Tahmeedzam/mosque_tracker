import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mosque_tracker/services/badge_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

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
    } catch (e) {}
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      final jsonString = await rootBundle.loadString('assets/json/badges.json');

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

          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(155, 27, 67, 50),
                          border: Border.all(
                            color: isUnlocked
                                ? const Color(0xFFE8B96A).withOpacity(0.5)
                                : const Color(0xFF1A3326),
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  badge['image_url'] ?? '',
                                  height: 64,
                                  width: 64,
                                  fit: BoxFit.contain,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Title
                              Text(
                                badge['name'] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF5F0E8),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Description
                              Text(
                                badge['description'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color.fromARGB(255, 150, 150, 150),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Close Button
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B4332),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      'Close',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
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
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      badge['image_url'] ?? '',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.workspace_premium,
                        size: 56,
                        color: Colors.white24,
                      ),
                    ),
                  ),
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
            ),
          );
        }, childCount: _badges.length),
      ),
    );
  }
}
