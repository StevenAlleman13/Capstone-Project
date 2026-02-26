import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _permissionChannel = MethodChannel('lockin/permissions');

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _progress = 0;

  void _completeTask() {
    setState(() {
      if (_progress < 10) _progress++;
    });
  }

  void _resetProgress() {
    setState(() {
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _ProgressSectionFrame(title: 'PROGRESS BAR', progress: _progress),
          const SizedBox(height: 14),
          _DailyTasksSectionFrame(
            title: 'DAILY TASKS',
            progress: _progress,
            onComplete: _completeTask,
            onReset: _resetProgress,
          ),
          const SizedBox(height: 14),
          const _ScreenTimeSectionFrame(),
        ],
      ),
    );
  }
}

/* ------------------------- SCREEN TIME SECTION FRAME ---------------------- */

class _ScreenTimeSectionFrame extends StatefulWidget {
  const _ScreenTimeSectionFrame();

  @override
  State<_ScreenTimeSectionFrame> createState() => _ScreenTimeSectionFrameState();
}

class _ScreenTimeSectionFrameState extends State<_ScreenTimeSectionFrame>
    with WidgetsBindingObserver {
  static const _limitMinutes = {'easy': 240, 'normal': 120, 'hardcore': 60};
  static const _labels = {'easy': 'Easy', 'normal': 'Normal', 'hardcore': 'Hardcore'};

  Duration _usedToday = Duration.zero;
  DateTime? _lastFetchTime;
  bool _permissionDenied = false;
  bool _loading = true;
  Timer? _refreshTimer;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUsage();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchUsage());
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_permissionDenied && !_loading) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUsage();
    }
  }

  Future<void> _fetchUsage() async {
    try {
      final hasPermission = await _permissionChannel
          .invokeMethod<bool>('hasUsageStatsPermission') ?? false;

      if (!hasPermission) {
        if (mounted) setState(() { _permissionDenied = true; _loading = false; });
        return;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final usageList = await AppUsage().getAppUsage(startOfDay, now);

      Duration total = Duration.zero;
      for (final info in usageList) {
        total += info.usage;
      }

      if (mounted) setState(() { _usedToday = total; _permissionDenied = false; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _permissionDenied = true; _loading = false; });
    }
  }

  Future<void> _openUsageSettings() async {
    const intent = AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
    await intent.launch();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final difficulty =
        Hive.box('selected_apps').get('difficulty', defaultValue: 'normal') as String;
    final limitMins = _limitMinutes[difficulty] ?? 120;
    final label = _labels[difficulty] ?? 'Normal';
    final limit = Duration(minutes: limitMins);

    final remaining =
        _usedToday >= limit ? Duration.zero : limit - _usedToday;
    final progress =
        (1.0 - _usedToday.inSeconds / limit.inSeconds).clamp(0.0, 1.0);
    final barColor = progress < 0.2 ? Colors.red : neon;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.12), blurRadius: 16)],
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'REMAINING SCREEN TIME',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: neon,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: neon.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) ...[
            const SizedBox(
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ] else if (_permissionDenied) ...[
            Text(
              'Permission Required',
              style: TextStyle(color: Colors.white, fontSize: 13, shadows: []),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Grant Permission'),
              onPressed: _openUsageSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: neon,
                side: BorderSide(color: neon.withValues(alpha: 0.7), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            Text(
              _fmt(remaining),
              style: TextStyle(
                color: barColor,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                shadows: [],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_fmt(_usedToday)} / ${_fmt(limit)}',
              style: TextStyle(color: Colors.white, fontSize: 11, shadows: []),
            ),
            const SizedBox(height: 10),
            _NeonProgressBar(value: progress, neon: barColor),
          ],
        ],
      ),
    );
  }
}

class _ProgressSectionFrame extends StatelessWidget {
  final String title;
  final int progress;

  const _ProgressSectionFrame({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final fillFraction = progress.clamp(0, 10) / 10.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.12), blurRadius: 16)],
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: neon,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NeonProgressBar(value: fillFraction, neon: neon),
              ),
              const SizedBox(width: 12),
              Text(
                '$progress/10',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: neon,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeonProgressBar extends StatelessWidget {
  final double value;
  final Color neon;

  const _NeonProgressBar({required this.value, required this.neon});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: neon.withValues(alpha: 0.95), width: 1.4),
        boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.18), blurRadius: 14)],
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: neon,
              boxShadow: [
                BoxShadow(color: neon.withValues(alpha: 0.35), blurRadius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyTasksSectionFrame extends StatelessWidget {
  final String title;
  final int progress;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  const _DailyTasksSectionFrame({
    required this.title,
    required this.progress,
    required this.onComplete,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final isMaxed = progress >= 10;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.12), blurRadius: 16)],
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: neon,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isMaxed ? null : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: neon,
                    side: BorderSide(color: neon.withValues(alpha: 0.9), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isMaxed ? 'All Done' : 'Complete Task'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: neon,
                    side: BorderSide(color: neon.withValues(alpha: 0.9), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
