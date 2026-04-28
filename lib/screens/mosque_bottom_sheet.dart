import 'package:flutter/material.dart';

class MosqueBottomSheet extends StatelessWidget {
  final Map<String, dynamic> mosque;
  final VoidCallback onClose;

  const MosqueBottomSheet({required this.mosque, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isVisited = mosque["visited"] == true;

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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mosque["name"],
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
                      "250 M AWAY", // replace with real distance later
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF52B788),
                        letterSpacing: 0.06,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVisited)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D6A4F).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF52B788).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    "✓ Visited",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF52B788),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Meta chips
          Row(
            children: [
              _MetaChip(icon: Icons.location_on_outlined, label: "Mumbai"),
              const SizedBox(width: 8),
              if (isVisited)
                _MetaChip(
                  icon: Icons.access_time_outlined,
                  label: "Visited Mar 15",
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Action button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
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
