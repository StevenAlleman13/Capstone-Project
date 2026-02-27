import 'dart:async';
import 'dart:math' as math;

import 'package:android_intent_plus/android_intent.dart';
import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _permissionChannel = MethodChannel('lockin/permissions');
const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 18.0;

// ─────────────────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── profile ──────────────────────────────────────────────────────────────
  String _username = '';
  int _coins = 0;

  // ── ring data ─────────────────────────────────────────────────────────────
  double _taskRing = 0;
  double _macroRing = 0;
  double _weightRing = 0;

  // ── screen time ───────────────────────────────────────────────────────────
  Duration _usedToday = Duration.zero;
  bool _permissionDenied = false;
  bool _screenTimeLoading = true;
  Timer? _refreshTimer;
  Timer? _liveTimer;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _fetchScreenTime();
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _fetchScreenTime());
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_permissionDenied && !_screenTimeLoading) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadProfile(), _loadRings()]);
  }

  // ── profile ───────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _supabase
          .from('profiles')
          .select('username, coins')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _username = (row?['username'] ?? user.email ?? 'User').toString();
        _coins =
            (row?['coins'] is num) ? (row!['coins'] as num).toInt() : 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _username = _supabase.auth.currentUser?.email ?? 'User');
    }
  }

  // ── rings ─────────────────────────────────────────────────────────────────
  Future<void> _loadRings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final todayStr = _todayKey();

    await Future.wait([
      // Task ring
      () async {
        try {
          final rows = await _supabase
              .from('user_tasks')
              .select('days, completed_dates')
              .eq('user_id', user.id);
          final todayWeekday = _weekdayName(DateTime.now().weekday);
          int total = 0, done = 0;
          for (final r in rows) {
            final days = List<String>.from(r['days'] ?? []);
            if (days.isEmpty || days.contains(todayWeekday)) {
              total++;
              if (List<String>.from(r['completed_dates'] ?? [])
                  .contains(todayStr)) done++;
            }
          }
          if (!mounted) return;
          setState(() =>
              _taskRing = total == 0 ? 0 : (done / total).clamp(0.0, 1.0));
        } catch (_) {}
      }(),

      // Macro ring
      () async {
        try {
          final goalRow = await _supabase
              .from('macro_goals')
              .select('calorie_goal')
              .eq('user_id', user.id)
              .maybeSingle();
          final goal = (goalRow?['calorie_goal'] is num)
              ? (goalRow!['calorie_goal'] as num).toDouble()
              : 2000.0;
          final logs = await _supabase
              .from('daily_macro_logs')
              .select('calories')
              .eq('user_id', user.id)
              .eq('log_date', todayStr);
          double total = 0;
          for (final l in logs) {
            total += (l['calories'] is num)
                ? (l['calories'] as num).toDouble()
                : 0;
          }
          if (!mounted) return;
          setState(() => _macroRing = (total / goal).clamp(0.0, 1.0));
        } catch (_) {}
      }(),

      // Weight ring
      () async {
        try {
          final row = await _supabase
              .from('weight_entries')
              .select('entry_date')
              .eq('user_id', user.id)
              .eq('entry_date', todayStr)
              .maybeSingle();
          if (!mounted) return;
          setState(() => _weightRing = row != null ? 1.0 : 0.0);
        } catch (_) {}
      }(),
    ]);
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  // ── screen time ───────────────────────────────────────────────────────────
  Future<void> _fetchScreenTime() async {
    try {
      final has = await _permissionChannel
              .invokeMethod<bool>('hasUsageStatsPermission') ??
          false;
      if (!has) {
        if (mounted)
          setState(() {
            _permissionDenied = true;
            _screenTimeLoading = false;
          });
        return;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final list = await AppUsage().getAppUsage(start, now);
      Duration total = Duration.zero;
      for (final i in list) total += i.usage;
      if (mounted)
        setState(() {
          _usedToday = total;
          _permissionDenied = false;
          _screenTimeLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _permissionDenied = true;
          _screenTimeLoading = false;
        });
    }
  }

  Future<void> _openUsageSettings() async {
    const intent =
        AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
    await intent.launch();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final difficulty = Hive.box('selected_apps')
        .get('difficulty', defaultValue: 'normal') as String;
    const limitMinutes = {'easy': 240, 'normal': 120, 'hardcore': 60};
    const diffLabels = {
      'easy': 'Easy',
      'normal': 'Normal',
      'hardcore': 'Hardcore'
    };
    final limitMins = limitMinutes[difficulty] ?? 120;
    final limit = Duration(minutes: limitMins);
    final remaining =
        _usedToday >= limit ? Duration.zero : limit - _usedToday;
    final screenProgress =
        (1.0 - _usedToday.inSeconds / limit.inSeconds).clamp(0.0, 1.0);
    final screenBarColor = screenProgress < 0.2 ? Colors.red : neon;
    final diffLabel = diffLabels[difficulty] ?? 'Normal';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile ───────────────────────────────────────────────────
            _ProfileWidget(username: _username, coins: _coins),
            const SizedBox(height: 10),

            // ── Activity Rings ────────────────────────────────────────────
            _ActivityRingsWidget(
              taskRing: _taskRing,
              macroRing: _macroRing,
              weightRing: _weightRing,
            ),
            const SizedBox(height: 10),

            // ── Daily Tasks (expands to fill remaining space) ─────────────
            Expanded(
              child: _DailyTasksWidget(
                onTasksChanged: () => _loadRings(),
              ),
            ),
            const SizedBox(height: 10),

            // ── Screen Time ───────────────────────────────────────────────
            _ScreenTimeWidget(
              loading: _screenTimeLoading,
              permissionDenied: _permissionDenied,
              remaining: remaining,
              usedToday: _usedToday,
              limit: limit,
              progress: screenProgress,
              barColor: screenBarColor,
              diffLabel: diffLabel,
              fmtDuration: _fmtDuration,
              onEnablePermission: _openUsageSettings,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileWidget extends StatelessWidget {
  final String username;
  final int coins;

  const _ProfileWidget({required this.username, required this.coins});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: Colors.black,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username.isEmpty ? '—' : username,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$coins coins',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: [],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: neon, width: 2),
              color: Colors.black,
              boxShadow: [
                BoxShadow(color: neon.withOpacity(0.4), blurRadius: 10)
              ],
            ),
            child: Icon(Icons.person, color: neon, size: 30),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVITY RINGS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityRingsWidget extends StatelessWidget {
  final double taskRing;
  final double macroRing;
  final double weightRing;

  const _ActivityRingsWidget({
    required this.taskRing,
    required this.macroRing,
    required this.weightRing,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: Colors.black,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [          _RingItem(value: taskRing, label: 'Tasks', color: const Color(0xFF00FF66)),
          _RingItem(value: macroRing, label: 'Macros', color: const Color(0xFFFF9500)),
          _RingItem(value: weightRing, label: 'Weight', color: const Color(0xFF2196F3)),
        ],
      ),
    );
  }
}

class _RingItem extends StatelessWidget {
  final double value;
  final String label;
  final Color color;

  const _RingItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(value: value, color: color),
            child: Center(
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: []),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [])),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (value > 0) {
      final sweep = 2 * math.pi * value.clamp(0.0, 1.0);
      final rect = Rect.fromCircle(center: center, radius: radius);

      // Glow
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Fill
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  DAILY TASKS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _DailyTasksWidget extends StatefulWidget {
  final VoidCallback onTasksChanged;
  const _DailyTasksWidget({required this.onTasksChanged});

  @override
  State<_DailyTasksWidget> createState() => _DailyTasksWidgetState();
}

class _DailyTasksWidgetState extends State<_DailyTasksWidget> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  Future<void> _loadTasks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await _supabase
          .from('user_tasks')
          .select()
          .eq('user_id', user.id);

      final todayWeekday = _weekdayName(DateTime.now().weekday);
      final tasks = (rows as List).map((r) => {
            'id': r['id'],
            'name': r['name'].toString(),
            'days': List<String>.from(r['days'] ?? []),
            'end_date': r['end_date'],
            'completed_dates':
                List<String>.from(r['completed_dates'] ?? []),
            'user_id': r['user_id'],
          }).where((t) {
        final days = t['days'] as List<String>;
        return days.isEmpty || days.contains(todayWeekday);
      }).toList();

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isCompletedToday(Map<String, dynamic> task) =>
      (task['completed_dates'] as List<String>).contains(_todayKey());

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final today = _todayKey();
    final completed = List<String>.from(task['completed_dates'] as List);
    if (completed.contains(today)) {
      completed.remove(today);
    } else {
      completed.add(today);
    }
    setState(() => task['completed_dates'] = completed);
    try {
      await _supabase
          .from('user_tasks')
          .update({'completed_dates': completed})
          .eq('id', task['id']);
      widget.onTasksChanged();
    } catch (_) {}
  }

  Future<void> _addTask() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: const Text('Add Task',
            style: TextStyle(color: _neonGreen, shadows: [])),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Task name',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _neonGreen),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: _neonGreen, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter a task name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _neonGreen, shadows: [])),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _neonGreen),
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, nameCtrl.text.trim());
            },
            child: const Text('Add',
                style: TextStyle(color: Colors.black, shadows: [])),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final id = const Uuid().v4();
    final newTask = {
      'id': id,
      'name': result,
      'days': <String>[],
      'end_date': null,
      'completed_dates': <String>[],
      'user_id': user.id,
    };

    setState(() => _tasks.add(newTask));

    try {
      await _supabase.from('user_tasks').insert({
        'id': id,
        'name': result,
        'days': [],
        'end_date': null,
        'completed_dates': [],
        'user_id': user.id,
      });
      widget.onTasksChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save task.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: neon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DAILY TASKS',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: neon, size: 24),
                  tooltip: 'Add task',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _addTask,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Divider(height: 1, color: neon.withOpacity(0.2)),

          // Task list
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks for today.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: neon.withOpacity(0.5),
                            fontSize: 13,
                            shadows: [],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final task = _tasks[i];
                          final done = _isCompletedToday(task);
                          return InkWell(
                            onTap: () => _toggleTask(task),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: done
                                      ? neon
                                      : neon.withOpacity(0.35),
                                  width: done ? 1.5 : 1,
                                ),
                                color: done
                                    ? neon.withOpacity(0.08)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    done
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color:
                                        done ? neon : neon.withOpacity(0.4),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      task['name'] as String,
                                      style: TextStyle(
                                        color: done ? neon : Colors.white,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: neon,
                                        fontSize: 14,
                                        shadows: [],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN TIME WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenTimeWidget extends StatelessWidget {
  final bool loading;
  final bool permissionDenied;
  final Duration remaining;
  final Duration usedToday;
  final Duration limit;
  final double progress;
  final Color barColor;
  final String diffLabel;
  final String Function(Duration) fmtDuration;
  final VoidCallback onEnablePermission;

  const _ScreenTimeWidget({
    required this.loading,
    required this.permissionDenied,
    required this.remaining,
    required this.usedToday,
    required this.limit,
    required this.progress,
    required this.barColor,
    required this.diffLabel,
    required this.fmtDuration,
    required this.onEnablePermission,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'REMAINING SCREEN TIME',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: neon.withOpacity(0.5), width: 1),
                ),
                child: Text(
                  diffLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (permissionDenied) ...[
            const Text('Permission Required',
                style:
                    TextStyle(color: Colors.white, fontSize: 13, shadows: [])),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onEnablePermission,
              style: OutlinedButton.styleFrom(
                foregroundColor: neon,
                side: BorderSide(color: neon.withOpacity(0.7), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enable'),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtDuration(remaining),
                  style: TextStyle(
                    color: barColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    shadows: [],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${fmtDuration(usedToday)} / ${fmtDuration(limit)}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, shadows: []),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _NeonProgressBar(value: progress, neon: barColor),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEON PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

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
        boxShadow: [
          BoxShadow(color: neon.withValues(alpha: 0.18), blurRadius: 14)
        ],
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
                BoxShadow(
                    color: neon.withValues(alpha: 0.35), blurRadius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
