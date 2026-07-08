import 'package:flutter/material.dart';
import 'package:mosque_tracker/screens/report_form_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mosque_tracker/services/mosque.service.dart';

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
  bool _isEditing = false;
  bool _isSaving = false;
  late Map<String, dynamic> _mosqueData;

  // Edit controllers
  late TextEditingController _nameController;

  // Edit state
  late String _selectedStatus;
  late String _selectedWomenAllowed;
  late String _selectedWuduArea;
  late String _selectedParking;

  final List<String> _statusOptions = [
    'unknown',
    'open',
    'closed_temporary',
    'closed_permanent',
    'under_construction',
  ];

  final List<String> _yesNoOptions = ['unknown', 'yes', 'no'];

  @override
  void initState() {
    super.initState();
    _mosqueData = Map<String, dynamic>.from(
      widget.mosque,
    ); // this stays widget.mosque — it's the initial load
    _nameController = TextEditingController(text: _mosqueData["name"] ?? "");
    _selectedStatus = _mosqueData["status"] ?? "unknown";
    _selectedWomenAllowed = _mosqueData["women_allowed"] ?? "unknown";
    _selectedWuduArea = _mosqueData["has_wudu_area"] == true
        ? "yes"
        : _mosqueData["has_wudu_area"] == false
        ? "no"
        : "unknown";
    _selectedParking = _mosqueData["has_parking"] == true
        ? "yes"
        : _mosqueData["has_parking"] == false
        ? "no"
        : "unknown";
    _loadDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    await Future.wait([_fetchPrayerCount(), _fetchVisitedDate()]);
  }

  Future<void> _fetchPrayerCount() async {
    try {
      final response = await _supabase
          .from('visitedMosque')
          .select('id')
          .eq('mosque_id', _mosqueData["id"]);
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
          .eq('mosque_id', _mosqueData["id"])
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

  Future<void> _saveEdits() async {
    setState(() => _isSaving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase
          .from('mosques')
          .update({
            'name': _nameController.text.trim(),
            'status': _selectedStatus,
            'women_allowed': _selectedWomenAllowed,
            'has_wudu_area': _selectedWuduArea == 'unknown'
                ? null
                : _selectedWuduArea == 'yes',
            'has_parking': _selectedParking == 'unknown'
                ? null
                : _selectedParking == 'yes',
            'last_edited_by': userId,
            'last_edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _mosqueData["id"]);

      // Reload fresh mosque data from Supabase
      final fresh = await _supabase
          .from('mosques')
          .select(
            'id, name, lat, lng, city, country, verified, status, women_allowed, has_wudu_area, has_parking, verified_count',
          )
          .eq('id', _mosqueData["id"])
          .single();

      // await MosqueService().loadMosques(forceReload: true);

      if (mounted) {
        // preserve fields that don't exist in mosques table
        final visited = widget.mosque["visited"];
        final distance = widget.mosque["distance"];

        setState(() {
          _mosqueData = Map<String, dynamic>.from(fresh);
          _mosqueData["visited"] = visited;
          _mosqueData["distance"] = distance;
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mosque details updated — JazakAllah Khair"),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _reportMosque() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(
          type: 'mosque_issue',
          title: 'Mosque Data Issue',
          subtitle: 'Tell us the mosque name and what\'s wrong',
          placeholder: 'e.g. Masjid Al-Noor shows the wrong location...',
          mosqueName: _mosqueData["name"].toString(),
          mosqueId: _mosqueData["id"].toString(),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return "$y ${y == 1 ? 'year' : 'years'} ago";
    } else if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return "$m ${m == 1 ? 'month' : 'months'} ago";
    } else if (diff.inDays >= 1) {
      return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
    } else if (diff.inHours >= 1) {
      return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
    }
    return "Just now";
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return "—";
    final meters = (distance as double).round();
    if (meters >= 1000) return "${(meters / 1000).toStringAsFixed(1)} km away";
    return "$meters m away";
  }

  String _formatLocation() {
    final city = (_mosqueData["city"] ?? "").toString().trim();
    final country = (_mosqueData["country"] ?? "").toString().trim();
    final countryCode = _toCountryCode(country);
    if (city.isNotEmpty && countryCode.isNotEmpty) return "$city, $countryCode";
    if (city.isNotEmpty) return city;
    if (countryCode.isNotEmpty) return countryCode;
    return "—";
  }

  String _toCountryCode(String country) {
    if (country.length == 2) return country.toUpperCase();
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
    };
    return map[country.toLowerCase()] ?? country;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'closed_temporary':
        return 'Temporarily Closed';
      case 'closed_permanent':
        return 'Permanently Closed';
      case 'under_construction':
        return 'Under Construction';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return const Color(0xFF52B788);
      case 'closed_temporary':
        return const Color(0xFFC9963A);
      case 'closed_permanent':
        return Colors.redAccent;
      case 'under_construction':
        return const Color(0xFFE8B96A);
      default:
        return const Color(0xFF9E9C97);
    }
  }

  String _yesNoLabel(String s) {
    switch (s) {
      case 'yes':
        return 'Yes';
      case 'no':
        return 'No';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVisited = _mosqueData["visited"] == true;
    final location = _formatLocation();
    final distance = _formatDistance(_mosqueData["distance"]);
    final status = _mosqueData["status"] ?? "unknown";
    final womenAllowed = _mosqueData["women_allowed"] ?? "unknown";
    final hasWudu = _mosqueData["has_wudu_area"];
    final hasParking = _mosqueData["has_parking"];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────
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
                          child: _isEditing
                              ? TextField(
                                  controller: _nameController,
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 16,
                                    color: Color(0xFFF5F0E8),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.06),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF52B788,
                                        ).withOpacity(0.4),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF52B788),
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _mosqueData["name"] ?? "Mosque",
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
                        const SizedBox(width: 8),
                        // Edit / Save button
                        GestureDetector(
                          onTap: _isEditing
                              ? (_isSaving ? null : _saveEdits)
                              : () => setState(() => _isEditing = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? const Color(0xFF2D6A4F).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isEditing
                                    ? const Color(0xFF52B788).withOpacity(0.4)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF52B788),
                                    ),
                                  )
                                : Text(
                                    _isEditing ? "Save" : "Edit",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isEditing
                                          ? const Color(0xFF52B788)
                                          : Colors.white.withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Cancel edit or close
                        GestureDetector(
                          onTap: _isEditing
                              ? () => setState(() => _isEditing = false)
                              : () => Navigator.of(context).pop(),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isEditing ? Icons.close : Icons.close,
                              size: 16,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Info rows ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        // Location
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

                        // Status
                        _isEditing
                            ? _EditDropdown(
                                label: "Status",
                                icon: Icons.info_outline,
                                value: _selectedStatus,
                                options: _statusOptions,
                                displayLabel: _statusLabel,
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v),
                              )
                            : _InfoRow(
                                icon: Icons.info_outline,
                                label: "Status",
                                value: _statusLabel(status),
                                valueColor: _statusColor(status),
                              ),
                        const SizedBox(height: 12),

                        // Women allowed
                        _isEditing
                            ? _EditDropdown(
                                label: "Women",
                                icon: Icons.people_outline,
                                value: _selectedWomenAllowed,
                                options: _yesNoOptions,
                                displayLabel: _yesNoLabel,
                                onChanged: (v) =>
                                    setState(() => _selectedWomenAllowed = v),
                              )
                            : _InfoRow(
                                icon: Icons.people_outline,
                                label: "Women",
                                value: _yesNoLabel(womenAllowed),
                                valueColor: womenAllowed == 'yes'
                                    ? const Color(0xFF52B788)
                                    : womenAllowed == 'no'
                                    ? Colors.redAccent
                                    : const Color(0xFF9E9C97),
                              ),
                        const SizedBox(height: 12),

                        // Wudu area
                        _isEditing
                            ? _EditDropdown(
                                label: "Wudu area",
                                icon: Icons.water_drop_outlined,
                                value: _selectedWuduArea,
                                options: _yesNoOptions,
                                displayLabel: _yesNoLabel,
                                onChanged: (v) =>
                                    setState(() => _selectedWuduArea = v),
                              )
                            : _InfoRow(
                                icon: Icons.water_drop_outlined,
                                label: "Wudu area",
                                value: hasWudu == null
                                    ? "Unknown"
                                    : hasWudu == true
                                    ? "Available"
                                    : "Not available",
                                valueColor: hasWudu == true
                                    ? const Color(0xFF52B788)
                                    : const Color(0xFF9E9C97),
                              ),
                        const SizedBox(height: 12),

                        // Parking
                        _isEditing
                            ? _EditDropdown(
                                label: "Parking",
                                icon: Icons.local_parking_outlined,
                                value: _selectedParking,
                                options: _yesNoOptions,
                                displayLabel: _yesNoLabel,
                                onChanged: (v) =>
                                    setState(() => _selectedParking = v),
                              )
                            : _InfoRow(
                                icon: Icons.local_parking_outlined,
                                label: "Parking",
                                value: hasParking == null
                                    ? "Unknown"
                                    : hasParking == true
                                    ? "Available"
                                    : "Not available",
                                valueColor: hasParking == true
                                    ? const Color(0xFF52B788)
                                    : const Color(0xFF9E9C97),
                              ),
                        const SizedBox(height: 12),

                        // Verified

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

                        // Your visit
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

                  const SizedBox(height: 16),

                  // ── Verify button ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _reportMosque,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF7A2E2E,
                          ).withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF7A2E2E).withOpacity(0.35),
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_outlined,
                              size: 15,
                              color: Color.fromARGB(255, 194, 74, 74),
                            ),
                            SizedBox(width: 7),
                            Text(
                              "Report This Mosque",
                              style: TextStyle(
                                color: Color.fromARGB(255, 194, 74, 74),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Footer quote ───────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
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
          width: 80,
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

// ── Edit dropdown ─────────────────────────────────────────────────────────────
class _EditDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final String Function(String) displayLabel;
  final Function(String) onChanged;

  const _EditDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.displayLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF52B788)),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9C97)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                dropdownColor: const Color(0xFF1C2E22),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFF5F0E8),
                  fontWeight: FontWeight.w500,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFF52B788),
                ),
                items: options.map((o) {
                  return DropdownMenuItem(
                    value: o,
                    child: Text(displayLabel(o)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
