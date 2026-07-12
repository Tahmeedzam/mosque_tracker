import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  const BottomNav({required this.currentIndex, required this.onTap});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  String? currentVersion; // Holds the data once loaded

  @override
  void initState() {
    super.initState();
    _loadPackageInfo(); // Call the async function on startup
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      currentVersion =
          packageInfo.version; // Trigger a rebuild with the new data
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.map_outlined, 'label': 'Map'},
      {'icon': Icons.access_time_rounded, 'label': 'Prayer'},
      {'icon': Icons.military_tech_outlined, 'label': 'Badges'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    double dragStartX = 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        onHorizontalDragStart: (d) => dragStartX = d.globalPosition.dx,
        onHorizontalDragEnd: (d) {
          final dx = d.globalPosition.dx - dragStartX;
          if (dx < -30 && widget.currentIndex < 3)
            widget.onTap(widget.currentIndex + 1);
          if (dx > 30 && widget.currentIndex > 0)
            widget.onTap(widget.currentIndex - 1);
        },
        child: Container(
          height: 94,
          decoration: BoxDecoration(
            color: const Color(0xFF080E0B),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.07)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final active = i == widget.currentIndex;
                  return GestureDetector(
                    onTap: () => widget.onTap(i),
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
              SizedBox(height: 5),
              Center(
                child: Text(
                  "Version: $currentVersion",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    color: const Color(0xFF6B6B6B),
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
