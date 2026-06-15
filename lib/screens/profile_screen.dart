import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mosque_tracker/services/auth_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final authService = AuthService();
  final _supabase = Supabase.instance.client;
  final mosqueService = MosqueService();
  String formattedDate = "Loading...";

  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _totalMaqam = 0;

  @override
  void initState() {
    super.initState();
    _getMosqueTimestamp();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      // Load maqam count
      final maqamCount = await mosqueService.loadPersonalMaqam();

      setState(() {
        userData = response;
        _totalMaqam = maqamCount;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error loading user: $e");
    }
  }

  void _logout() async {
    await authService.signOut();
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "?";
    final parts = name.trim().split(" ");
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name[0].toUpperCase();
  }

  void _getMosqueTimestamp() async {
    try {
      // 1. Fetch the row containing the timestamp (e.g., 'created_at')
      final response = await _supabase
          .from('mosques')
          .select('created_at')
          .limit(1)
          .single(); // Use .single() if you are fetching a specific single row

      final String? timestamp = response['created_at'];

      if (timestamp != null) {
        // 2. Parse the ISO 8601 string from Supabase into a Dart DateTime object
        DateTime parsedDate = DateTime.parse(timestamp).toLocal();

        // 3. Format it into a "normal" readable style
        // Example formats:
        // 'yyyy-MM-dd'         -> 2026-06-02
        // 'dd MMM yyyy, hh:mm a' -> 02 Jun 2026, 04:39 PM
        String normalDate = DateFormat('dd MMM yyyy').format(parsedDate);

        if (!mounted) return;

        // 4. Update your state to refresh the UI
        setState(() {
          formattedDate = normalDate;
        });
      }
    } catch (e) {
      print("Error fetching timestamp: $e");
      if (mounted) {
        setState(() {
          formattedDate = "Error loading date";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visited = mosqueService.visitedMosques;
    final totalVisited = visited.length;

    // Count unique cities from visited mosques
    final visitedIds = visited.map((v) => v['mosque_id'].toString()).toSet();
    final visitedMosqueData = mosqueService.mosques
        .where((m) => visitedIds.contains(m['id'].toString()))
        .toList();
    final uniqueCities = visitedMosqueData
        .map((m) => m['city']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF52B788)),
            )
          : CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    userData: userData,
                    totalVisited: totalVisited,
                    uniqueCities: uniqueCities,
                    initials: _getInitials(
                      userData?['display_name'] ?? userData?['full_name'],
                    ),
                    onLogout: _logout,
                    onEditProfile: () => _showEditProfileSheet(),
                    dateJoined: formattedDate,
                    maqamVisited: _totalMaqam,
                  ),
                ),

                // ── Journey section label ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      children: [
                        const Text(
                          "MY JOURNEY",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.14,
                            color: Color(0xFF9E9C97),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 0.5,
                            color: const Color(0xFFC9963A).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Visited list ─────────────────────────────────────
                visited.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              const Text("🕌", style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 16),
                              const Text(
                                "No mosques visited yet",
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 18,
                                  color: Color(0xFFF5F0E8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Visit a mosque and confirm your prayer\nto start your journey",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.35),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final visit = visited[index];
                          final mosqueId = visit['mosque_id'].toString();
                          final mosqueData = mosqueService.mosques.firstWhere(
                            (m) => m['id'].toString() == mosqueId,
                            orElse: () => {},
                          );
                          final name = mosqueData['name'] ?? 'Unknown Mosque';
                          final city = mosqueData['city'] ?? '';
                          final visitedAt = visit['visited_at'] != null
                              ? DateTime.parse(visit['visited_at'])
                              : null;

                          return _VisitItem(
                            name: name,
                            city: city,
                            visitedAt: visitedAt,
                            isLast: index == visited.length - 1,
                          );
                        }, childCount: visited.length),
                      ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(
      text: userData?['display_name'] ?? userData?['full_name'] ?? '',
    );
    final bioController = TextEditingController(text: userData?['bio'] ?? '');
    final homeCityController = TextEditingController(
      text: userData?['home_city'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF152419),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9963A).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Edit Profile",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  color: Color(0xFFF5F0E8),
                ),
              ),
              const SizedBox(height: 20),
              _EditField(label: "Display Name", controller: nameController),
              const SizedBox(height: 12),
              _EditField(label: "Bio", controller: bioController, maxLines: 2),
              const SizedBox(height: 12),
              _EditField(label: "Home City", controller: homeCityController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final userId = _supabase.auth.currentUser?.id;
                    if (userId == null) return;

                    await _supabase
                        .from('users')
                        .update({
                          'display_name': nameController.text.trim(),
                          'bio': bioController.text.trim(),
                          'home_city': homeCityController.text.trim(),
                        })
                        .eq('id', userId);

                    await _loadUserData();
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: Color(0xFFF5F0E8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final int totalVisited;
  final int uniqueCities;
  final String initials;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final String? dateJoined;
  final int maqamVisited;

  const _ProfileHeader({
    required this.userData,
    required this.totalVisited,
    required this.uniqueCities,
    required this.initials,
    required this.onLogout,
    required this.onEditProfile,
    required this.dateJoined,
    required this.maqamVisited,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = userData?['avatar_url'] as String?;
    final displayName = userData?['display_name'] as String?;
    final fullName = userData?['full_name'] as String?;
    final name =
        (displayName?.isNotEmpty == true ? displayName : fullName) ??
        'Anonymous';
    final email = userData?['email'] as String? ?? '';
    final bio = userData?['bio'] as String?;
    final homeCity = userData?['home_city'] as String?;

    Future<void> showLogoutDialogBox() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF152419),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFC9963A).withOpacity(0.2)),
          ),
          title: const Text(
            "Logout?",
            style: TextStyle(color: Color(0xFFF5F0E8), fontFamily: 'Georgia'),
          ),
          content: Text(
            "Are you sure you want to logout?",
            style: const TextStyle(color: Color(0xFF9E9C97), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFF52B788)),
              ),
            ),
            TextButton(
              onPressed: () => {Navigator.of(ctx).pop(), onLogout()},
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        // image: const DecorationImage(
        //   image: AssetImage('assets/pattern.png'),
        //   fit: BoxFit.cover,
        //   opacity: 0.06,
        // ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row — logout button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "PROFILE",
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.18,
                      color: Color(0xFFE8B96A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onEditProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: const Text(
                            "Edit",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF5F0E8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: showLogoutDialogBox,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar + name row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC9963A).withOpacity(0.5),
                        width: 2,
                      ),
                      color: const Color(0xFF2D6A4F).withOpacity(0.4),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFE8B96A),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFE8B96A),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name + email + location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF5F0E8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        if (homeCity != null && homeCity.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: const Color(0xFF52B788).withOpacity(0.7),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                homeCity,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF52B788),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Bio
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  bio,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'Date Joined: ${dateJoined.toString()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  _StatBox(number: totalVisited.toString(), label: "Mosques"),
                  const SizedBox(width: 10),
                  _StatBox(number: uniqueCities.toString(), label: "Cities"),
                  const SizedBox(width: 10),
                  _StatBox(number: maqamVisited.toString(), label: "Maqam"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simple streak — days in a row with at least one visit
  String mosqueStreak() {
    return "—"; // placeholder — implement later with visited_at dates
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String number;
  final String label;

  const _StatBox({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC9963A).withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8B96A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.1,
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visit item ────────────────────────────────────────────────────────────────
class _VisitItem extends StatelessWidget {
  final String name;
  final String city;
  final DateTime? visitedAt;
  final bool isLast;

  const _VisitItem({
    required this.name,
    required this.city,
    required this.visitedAt,
    required this.isLast,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2D6A4F),
                  border: Border.all(
                    color: const Color(0xFFC9963A).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 60,
                  color: const Color(0xFF2D6A4F).withOpacity(0.25),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF152419),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text("🕌", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF5F0E8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (city.isNotEmpty) ...[
                              Text(
                                city,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                              Text(
                                " · ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ],
                            Text(
                              visitedAt != null ? _formatDate(visitedAt!) : "—",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF52B788),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit field ────────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF52B788),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
