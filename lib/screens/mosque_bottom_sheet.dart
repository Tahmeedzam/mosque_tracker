import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mosque_tracker/providers/mosque_providers.dart';
import 'package:mosque_tracker/screens/mosque_detail_modal.dart';
import 'package:mosque_tracker/services/badge_service.dart';
import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MosqueBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> mosque;
  final VoidCallback onClose;
  final VoidCallback onVisitChanged; // ✅ NEW: tells the map to refresh markers

  const MosqueBottomSheet({
    super.key,
    required this.mosque,
    required this.onClose,
    required this.onVisitChanged,
  });

  @override
  ConsumerState<MosqueBottomSheet> createState() => _MosqueBottomSheetState();
}

class _MosqueBottomSheetState extends ConsumerState<MosqueBottomSheet> {
  final supabase = Supabase.instance.client;
  late bool isVisited;

  @override
  void initState() {
    super.initState();
    isVisited = widget.mosque["visited"] == true;
  }

  // ✅ FIX: when a NEW mosque is tapped, reset isVisited from the new prop
  @override
  void didUpdateWidget(covariant MosqueBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mosque["id"] != widget.mosque["id"]) {
      setState(() {
        isVisited = widget.mosque["visited"] == true;
      });
    }
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return "";
    final meters = (distance as double).round();
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} KM AWAY";
    }
    return "$meters M AWAY";
  }

  Future<void> _markAsVisited() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF52B788)),
      ),
    );

    try {
      await ref
          .read(visitedMosquesProvider.notifier)
          .markVisited(widget.mosque["id"].toString());
      await BadgeService().grantNewBadge();
      if (mounted) {
        setState(() => isVisited = true);
        widget.onVisitChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _unmarkAsVisited() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152419),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFC9963A).withOpacity(0.2)),
        ),
        title: const Text(
          "Remove visit?",
          style: TextStyle(color: Color(0xFFF5F0E8), fontFamily: 'Georgia'),
        ),
        content: Text(
          "Are you sure you want to mark \"${widget.mosque["name"]}\" as not visited?",
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
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF52B788)),
      ),
    );

    try {
      await ref
          .read(visitedMosquesProvider.notifier)
          .unmarkVisited(widget.mosque["id"].toString());
      if (mounted) {
        setState(() => isVisited = false);
        widget.onVisitChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showDetailModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => MosqueDetailModal(mosque: widget.mosque),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF152419).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9963A).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
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
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mosque["name"],
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF5F0E8),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDistance(widget.mosque["distance"]),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF52B788),
                        letterSpacing: 0.06,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isVisited ? _unmarkAsVisited : _markAsVisited,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isVisited
                        ? const Color(0xFF374B42).withOpacity(0.25)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVisited
                          ? const Color(0xFF52B788).withOpacity(0.3)
                          : const Color(0xFFC9963A).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isVisited ? "✓ Visited" : "Mark as Visited",
                    style: TextStyle(
                      fontSize: 11,
                      color: isVisited
                          ? const Color(0xFF52B788)
                          : const Color(0xFF9E9C97),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if ((widget.mosque["city"] ?? "").toString().isNotEmpty)
                _MetaChip(
                  icon: Icons.location_on_outlined,
                  label: widget.mosque["city"].toString(),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Directions button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                final lat = (widget.mosque["lat"] as num).toDouble();
                final lng = (widget.mosque["lng"] as num).toDouble();
                final name = Uri.encodeComponent(
                  widget.mosque["name"] ?? "Mosque",
                );

                final googleMapsUrl = Uri.parse(
                  "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
                );

                try {
                  await launchUrl(
                    googleMapsUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  // Fallback to geo URI
                  final geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($name)");
                  try {
                    await launchUrl(
                      geoUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e2) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not open maps")),
                      );
                    }
                  }
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_outlined,
                    size: 16,
                    color: Color(0xFF52B788),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Get directions",
                    style: TextStyle(
                      color: Color(0xFFF5F0E8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: "Dismiss",
                  barrierColor: Colors.black.withOpacity(0.6),
                  transitionDuration: const Duration(milliseconds: 280),
                  transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutCubic,
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  pageBuilder: (ctx, _, __) =>
                      MosqueDetailModal(mosque: widget.mosque),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: const Color(0xFF52B788).withOpacity(0.3),
                  ),
                ),
              ),
              child: const Text(
                "View details",
                style: TextStyle(
                  color: Color(0xFFF5F0E8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.06,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF9E9C97)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9C97)),
          ),
        ],
      ),
    );
  }
}
