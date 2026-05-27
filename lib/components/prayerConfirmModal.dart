import 'package:flutter/material.dart';

class PrayerConfirmModal extends StatelessWidget {
  final String mosqueId;
  final String mosqueName;
  final String triggeredAt;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const PrayerConfirmModal({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
    required this.triggeredAt,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.parse(triggeredAt);
    final formattedTime =
        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF152419),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC9963A).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFC9963A).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Mosque icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC9963A).withOpacity(0.4),
              ),
            ),
            child: const Center(
              child: Text("🕌", style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 16),

          // Mosque name
          Text(
            mosqueName,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFFF5F0E8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Time
          Text(
            "Detected at $formattedTime",
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF52B788).withOpacity(0.8),
              letterSpacing: 0.04,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            "Did you pray here?",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 28),

          // Yes button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: const Color(0xFF52B788).withOpacity(0.3),
                  ),
                ),
              ),
              child: const Text(
                "✓  Yes, I prayed here",
                style: TextStyle(
                  color: Color(0xFFF5F0E8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.06,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // No button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Text(
                "Not this time",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
