import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.map_outlined, 'label': 'Map'},
      {'icon': Icons.menu_book_outlined, 'label': 'Journey'},
      {'icon': Icons.military_tech_outlined, 'label': 'Badges'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    double dragStartX = 0;

    return GestureDetector(
      onHorizontalDragStart: (d) => dragStartX = d.globalPosition.dx,
      onHorizontalDragEnd: (d) {
        final dx = d.globalPosition.dx - dragStartX;
        if (dx < -30 && currentIndex < 3) onTap(currentIndex + 1);
        if (dx > 30 && currentIndex > 0) onTap(currentIndex - 1);
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF080E0B),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final active = i == currentIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF2D6A4F).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i]['icon'] as IconData,
                      color: active
                          ? const Color(0xFF52B788)
                          : const Color(0xFF6B6B6B),
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        color: active
                            ? const Color(0xFF52B788)
                            : const Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
