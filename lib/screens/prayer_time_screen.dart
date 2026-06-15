import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mosque_tracker/services/prayer_service.dart';

class PrayerTimeScreen extends StatefulWidget {
  const PrayerTimeScreen({super.key});

  @override
  State<PrayerTimeScreen> createState() => _PrayerTimeScreenState();
}

class _PrayerTimeScreenState extends State<PrayerTimeScreen> {
  final _prayerService = PrayerService();
  List<PrayerTime> _prayers = [];
  bool _loading = true;
  String _error = "";
  Timer? _countdownTimer;
  Duration? _timeUntilNext;
  PrayerTime? _nextPrayer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _prayerService.initialize();
    if (!mounted) return;
    await _loadPrayers();
    if (!mounted) return;
    _startCountdown();
  }

  Future<void> _loadPrayers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = "";
    });
    try {
      final prayers = await _prayerService.fetchPrayerTimes();
      if (!mounted) return;
      setState(() {
        _prayers = prayers;
        _loading = false;
        _nextPrayer = _prayerService.getNextPrayer();
        _timeUntilNext = _prayerService.getTimeUntilNextPrayer();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Could not load prayer times";
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _nextPrayer = _prayerService.getNextPrayer();
        _timeUntilNext = _prayerService.getTimeUntilNextPrayer();
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$min $period";
  }

  bool _isNextPrayer(PrayerTime prayer) {
    return _nextPrayer?.name == prayer.name;
  }

  bool _isPast(PrayerTime prayer) {
    return prayer.time.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF52B788)),
            )
          : _error.isNotEmpty
          ? _buildError()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildNextPrayerCard()),
                SliverToBoxAdapter(
                  child: _buildSectionLabel("TODAY'S PRAYERS"),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPrayerRow(_prayers[index]),
                    childCount: _prayers.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildNote()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1B4332),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "PRAYER TIMES",
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.18,
                      color: Color(0xFFE8B96A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadPrayers,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Color(0xFFE8B96A),
                      ),
                    ),
                  ),
                  // TextButton(
                  //   onPressed: () => PrayerService().playAdhanNow(),
                  //   child: const Text("Test Adhan Sound"),
                  // ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "أَقِمِ الصَّلَاةَ",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  color: Color(0xFFF5F0E8),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "Establish the prayer",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_prayerService.locationName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: const Color(0xFF52B788).withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _prayerService.locationName,
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF52B788).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    if (_nextPrayer == null || _timeUntilNext == null) {
      return const SizedBox(height: 20);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9963A).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D6A4F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC9963A).withOpacity(0.3),
              ),
            ),
            child: Icon(
              _nextPrayer!.icon,
              color: const Color(0xFFE8B96A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "NEXT PRAYER",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.14,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _nextPrayer!.name,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    color: Color(0xFFF5F0E8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _nextPrayer!.arabicName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCountdown(_timeUntilNext!),
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  color: Color(0xFFE8B96A),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _formatTime(_nextPrayer!.time),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
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
    );
  }

  Widget _buildPrayerRow(PrayerTime prayer) {
    final isNext = _isNextPrayer(prayer);
    final isPast = _isPast(prayer);
    final isSunrise = prayer.name == "Sunrise";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext
            ? const Color(0xFF1B4332).withOpacity(0.6)
            : const Color(0xFF152419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? const Color(0xFFC9963A).withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          width: isNext ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPast
                  ? Colors.white.withOpacity(0.03)
                  : isNext
                  ? const Color(0xFF2D6A4F).withOpacity(0.4)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              prayer.icon,
              size: 18,
              color: isPast
                  ? Colors.white.withOpacity(0.2)
                  : isNext
                  ? const Color(0xFFE8B96A)
                  : const Color(0xFF52B788),
            ),
          ),
          const SizedBox(width: 14),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isPast
                        ? Colors.white.withOpacity(0.25)
                        : const Color(0xFFF5F0E8),
                  ),
                ),
                Text(
                  prayer.arabicName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPast
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),

          // Time + badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(prayer.time),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isPast
                      ? Colors.white.withOpacity(0.2)
                      : isNext
                      ? const Color(0xFFE8B96A)
                      : const Color(0xFFF5F0E8),
                  letterSpacing: 0.5,
                ),
              ),
              if (isPast)
                Text(
                  "Done",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              if (isNext)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9963A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFFE8B96A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isSunrise && !isPast && !isNext)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "No adhan",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: const Color(0xFF52B788).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              const Text(
                "ABOUT THESE TIMINGS",
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9E9C97),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Prayer times are calculated using the Muslim World League method, "
            "which is widely accepted for international use. Times are based on "
            "your current GPS location and may vary slightly from your local mosque. "
            "Sehri time corresponds to Fajr, and Iftaar corresponds to Maghrib. ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 40,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _loadPrayers,
              child: const Text(
                "Try again",
                style: TextStyle(color: Color(0xFF52B788)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
