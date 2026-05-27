import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MosqueDetailModal extends StatefulWidget {
  final Map<String, dynamic> mosque;
  const MosqueDetailModal({super.key, required this.mosque});

  @override
  State<MosqueDetailModal> createState() => _MosqueDetailModalState();
}

class _MosqueDetailModalState extends State<MosqueDetailModal> {
  final _supabase = Supabase.instance.client;
  int? _prayerCount;
  String? _visitedAgo;
  bool _loadingCount = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    await Future.wait([_fetchPrayerCount(), _fetchVisitedDate()]);
  }

  Future<void> _fetchPrayerCount() async {
    try {
      final response = await _supabase
          .from('visitedMosque')
          .select('id')
          .eq('mosque_id', widget.mosque["id"]);

      if (mounted) {
        setState(() {
          _prayerCount = (response as List).length;
          _loadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCount = false);
    }
  }

  Future<void> _fetchVisitedDate() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('visitedMosque')
          .select('visited_at')
          .eq('mosque_id', widget.mosque["id"])
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        final visitedAt = DateTime.parse(response['visited_at']);
        setState(() => _visitedAgo = _timeAgo(visitedAt));
      }
    } catch (e) {
      debugPrint("Error fetching visited date: $e");
    }
  }

  // Converts DateTime to "3 months ago" style string
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return "$years ${years == 1 ? 'year' : 'years'} ago";
    } else if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return "$months ${months == 1 ? 'month' : 'months'} ago";
    } else if (diff.inDays >= 1) {
      return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
    } else if (diff.inHours >= 1) {
      return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return "Just now";
    }
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return "—";
    final meters = (distance as double).round();
    if (meters >= 1000) return "${(meters / 1000).toStringAsFixed(1)} km away";
    return "$meters m away";
  }

  // "Mumbai, IN" style from city + country
  String _formatLocation() {
    final city = (widget.mosque["city"] ?? "").toString().trim();
    final country = (widget.mosque["country"] ?? "").toString().trim();

    // Try to shorten country to 2-letter code if it's a full name
    final countryCode = _toCountryCode(country);

    if (city.isNotEmpty && countryCode.isNotEmpty) return "$city, $countryCode";
    if (city.isNotEmpty) return city;
    if (countryCode.isNotEmpty) return countryCode;
    return "—";
  }

  // Basic country name → ISO code mapping for common countries
  String _toCountryCode(String country) {
    if (country.length == 2) return country.toUpperCase(); // already a code
    const map = {
      "india": "IN",
      "united states": "US",
      "united kingdom": "GB",
      "pakistan": "PK",
      "bangladesh": "BD",
      "saudi arabia": "SA",
      "united arab emirates": "AE",
      "malaysia": "MY",
      "indonesia": "ID",
      "turkey": "TR",
      "egypt": "EG",
      "nigeria": "NG",
      "canada": "CA",
      "australia": "AU",
      "france": "FR",
      "germany": "DE",
    };
    return map[country.toLowerCase()] ?? country;
  }

  @override
  Widget build(BuildContext context) {
    final isVisited = widget.mosque["visited"] == true;
    final location = _formatLocation();
    final address = (widget.mosque["address"] ?? "").toString().trim();
    final distance = _formatDistance(widget.mosque["distance"]);
    final isVerified = widget.mosque["verified"] == true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF152419),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFC9963A).withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFC9963A).withOpacity(0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF52B788).withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Text("🕌", style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.mosque["name"] ?? "Mosque",
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF5F0E8),
                              ),
                            ),
                            if (location != "—")
                              Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9C97),
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info rows ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      // Address — only show if we have it in DB
                      if (address.isNotEmpty) ...[
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: "Address",
                          value: address,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // City, Country
                      _InfoRow(
                        icon: Icons.map_outlined,
                        label: "Location",
                        value: location,
                      ),
                      const SizedBox(height: 12),

                      // Distance
                      _InfoRow(
                        icon: Icons.straighten_outlined,
                        label: "Distance",
                        value: distance,
                      ),
                      const SizedBox(height: 12),

                      // Verified status
                      _InfoRow(
                        icon: isVerified
                            ? Icons.verified_outlined
                            : Icons.help_outline,
                        label: "Status",
                        value: isVerified ? "Verified mosque" : "Not verified",
                        valueColor: isVerified
                            ? const Color(0xFF52B788)
                            : const Color(0xFF9E9C97),
                      ),
                      const SizedBox(height: 12),

                      // People prayed here
                      _InfoRow(
                        icon: Icons.people_outline,
                        label: "Prayed here",
                        value: _loadingCount
                            ? "loading..."
                            : _prayerCount == 1
                            ? "1 person"
                            : "${_prayerCount ?? 0} people",
                        valueColor: const Color(0xFFC9963A),
                      ),
                      const SizedBox(height: 12),

                      // Visited + date together in one row
                      _InfoRow(
                        icon: isVisited
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        label: "Your visit",
                        value: isVisited
                            ? (_visitedAgo != null
                                  ? "Prayed here · $_visitedAgo"
                                  : "Prayed here")
                            : "Not yet visited",
                        valueColor: isVisited
                            ? const Color(0xFFC9963A)
                            : const Color(0xFF9E9C97),
                      ),
                    ],
                  ),
                ),

                // ── Footer ──────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.format_quote_outlined,
                        size: 13,
                        color: const Color(0xFF52B788).withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          "The earth will bear witness to your prayers",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF52B788),
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.format_quote_outlined,
                        size: 13,
                        color: const Color(0xFF52B788).withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF52B788)),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9C97)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? const Color(0xFFF5F0E8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
