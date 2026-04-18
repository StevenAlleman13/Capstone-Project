import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:namer_app/main.dart' as m;

const _permissionChannel = MethodChannel('lockin/permissions');
const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 18.0;

Color primaryColor = m.primaryColor;
Color secondaryColor = m.secondaryColor;
Color textColor = m.textColor;

// ─────────────────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  // ── profile ──────────────────────────────────────────────────────────────
  String _username = '';
  int _coins = 0;

  // ── ring data ─────────────────────────────────────────────────────────────
  double _eventRing = 0;
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
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _fetchScreenTime();
      });
    }
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
      // Event ring
      () async {
        try {
          final rows = await _supabase
              .from('user_events')
              .select('date, days, end_time, all_day')
              .eq('user_id', user.id);
          final now = DateTime.now();
          const fullWeekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
          final todayWeekday = fullWeekdays[now.weekday % 7];
          int total = 0, done = 0;
          for (final r in rows) {
            final List<String> days = List<String>.from(r['days'] ?? []);
            final isRepeating = days.isNotEmpty;
            if (isRepeating) {
              if (!days.contains(todayWeekday)) continue;
              total++;
              final endTime = (r['end_time'] ?? '').toString();
              if (endTime.isNotEmpty) {
                try {
                  final parts = endTime.split(':');
                  final endH = int.parse(parts[0]);
                  final endM = int.parse(parts[1]);
                  if (now.hour > endH || (now.hour == endH && now.minute >= endM)) done++;
                } catch (_) {}
              }
            } else {
              final eventDate = (r['date'] ?? '').toString();
              if (!eventDate.startsWith(todayStr)) continue;
              total++;
              // Time-based completion — same logic as _isEventCompleted in events_page
              final allDay = r['all_day'] == true;
              if (allDay) {
                // All-day events complete at end of day (23:59:59)
                if (now.hour == 23 && now.minute == 59 && now.second >= 59) done++;
              } else {
                final endTime = (r['end_time'] ?? '').toString();
                if (endTime.isNotEmpty) {
                  try {
                    final parts = endTime.split(':');
                    int endH = int.parse(parts[0].trim());
                    int endM = int.parse(parts[1].trim().split(' ')[0]);
                    if (endTime.toUpperCase().contains('PM') && endH < 12) endH += 12;
                    if (endTime.toUpperCase().contains('AM') && endH == 12) endH = 0;
                    final eventEnd = DateTime(now.year, now.month, now.day, endH, endM);
                    if (eventEnd.isBefore(now)) done++;
                  } catch (_) {}
                }
              }
            }
          }
          if (!mounted) return;
          setState(() => _eventRing = total == 0 ? 0 : (done / total).clamp(0.0, 1.0));
        } catch (_) {}
      }(),

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
                  .contains(todayStr)) {
                done++;
              }
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
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _screenTimeLoading = false;
          });
        }
        return;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final list = await AppUsage().getAppUsage(start, now);
      final selected = List<String>.from(
        Hive.box('selected_apps').get('packages', defaultValue: <String>[]),
      );
      Duration total = Duration.zero;
      for (final i in list) {
        if (selected.isEmpty || selected.contains(i.packageName)) total += i.usage;
      }
      if (mounted) {
        setState(() {
          _usedToday = total;
          _permissionDenied = false;
          _screenTimeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _screenTimeLoading = false;
        });
      }
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
    const limitMinutes = {'easy': 240, 'normal': 120, 'hardcore': 60, 'test': 0};
    const diffLabels = {
      'easy': 'Easy',
      'normal': 'Normal',
      'hardcore': 'Hardcore',
      'test': 'Test',
    };
    final limitMins = limitMinutes[difficulty] ?? 120;
    final limit = Duration(minutes: limitMins);
    final remaining =
        _usedToday >= limit ? Duration.zero : limit - _usedToday;
    final screenProgress = limit.inSeconds == 0
        ? 0.0
        : (1.0 - _usedToday.inSeconds / limit.inSeconds).clamp(0.0, 1.0);
    final screenBarColor = screenProgress < 0.2 ? Colors.red : neon;
    final diffLabel = diffLabels[difficulty] ?? 'Normal';    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile ───────────────────────────────────────────────────
            _ProfileWidget(username: _username, coins: _coins, onSettingsReturn: _loadProfile),
            const SizedBox(height: 10),

            // ── Activity Rings ────────────────────────────────────────────
            _ActivityRingsWidget(
              eventRing: _eventRing,
              taskRing: _taskRing,
              macroRing: _macroRing,
              weightRing: _weightRing,
            ),
            const SizedBox(height: 10),              // ── Daily Tasks (expands to fill remaining space) ─────────────
            Expanded(
              flex: 1,              child: _DailyTasksWidget(
                onTasksChanged: () => _loadRings(),
              ),
            ),
            const SizedBox(height: 10),

            // ── Screen Time ───────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: _ScreenTimeWidget(
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
  final VoidCallback? onSettingsReturn;

  const _ProfileWidget({required this.username, required this.coins, this.onSettingsReturn});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: primaryColor,
      ),      child: Row(
        children: [
          // Left: Profile avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: neon.withOpacity(0.15),
            child: Icon(Icons.person, color: neon, size: 26),
          ),
          const SizedBox(width: 12),
          // Middle: Profile info
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
          // Right: Settings gear icon
          IconButton(
            icon: Icon(Icons.settings, color: neon, size: 26),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).pushNamed('/settings');
              onSettingsReturn?.call();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
  final double eventRing;
  final double taskRing;
  final double macroRing;
  final double weightRing;

  const _ActivityRingsWidget({
    required this.eventRing,
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
        color: primaryColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressBarItem(value: eventRing, label: 'Events', color: secondaryColor),
          const SizedBox(height: 12),
          _ProgressBarItem(value: taskRing, label: 'Tasks', color: const Color(0xFF00FF66)), // keeping this the same despite sharing the neon green color since its one of the progress bars
          const SizedBox(height: 12),
          _ProgressBarItem(value: macroRing, label: 'Macros', color: const Color(0xFFFF9500)),
          const SizedBox(height: 12),
          _ProgressBarItem(value: weightRing, label: 'Weight', color: const Color(0xFF2196F3)),
        ],
      ),
    );
  }
}

class _ProgressBarItem extends StatelessWidget {
  final double value;
  final String label;
  final Color color;

  const _ProgressBarItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [],
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withOpacity(0.5), width: 1),
              color: primaryColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
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
  final _supabase = Supabase.instance.client;  final _pageController = PageController();
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  int _currentPage = 0;

  // Pool of daily challenges
  static const List<String> _challengePool = [
    'Drink 8 glasses of water',
    'Workout for 1 hour',
    'Workout outside for 30 minutes',
    'Take a 20-minute walk',
    'Meditate for 10 minutes',
    'Eat a healthy breakfast',
    'Stretch for 10 minutes',
    'Read for 20 minutes',
    'No social media for 2 hours',
    'Write down 3 things you are grateful for',
    'Go to bed before 11 PM',
    'Take the stairs instead of the elevator',
    'Call or message a friend',
    'Avoid sugary drinks today',
    'Do 30 squats',
    'Do 20 pushups',
    'Do 10 pullups',
    'Practice deep breathing for 10 minutes',
    'Limit screen time to 2 hours',
    'Eat a serving of vegetables',
    'Walk 5,000 steps',
    'Walk 10,000 steps',
    'Do a random act of kindness',
    'Spend 10 minutes outdoors',
  ];
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          .eq('user_id', user.id);      final todayWeekday = _weekdayName(DateTime.now().weekday);
      final tasks = (rows as List).map((r) => {
            'id': r['id'],
            'name': r['name'].toString(),
            'days': List<String>.from(r['days'] ?? []),
            'end_date': r['end_date'],
            'completed_dates':
                List<String>.from(r['completed_dates'] ?? []),
            'user_id': r['user_id'],
            'is_challenge': (r['is_challenge'] as bool?) ?? false,
          }).where((t) {
        final isChallenge = t['is_challenge'] as bool;
        if (isChallenge) {
          // Challenges are only shown today if they're added
          return true;
        }
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

  Future<void> _toggleChallenge(Map<String, dynamic> challenge) async {
    final today = _todayKey();
    final completed = List<String>.from(challenge['completed_dates'] as List? ?? []);
    if (completed.contains(today)) {
      completed.remove(today);
    } else {
      completed.add(today);
    }
    setState(() => challenge['completed_dates'] = completed);
    try {
      await _supabase
          .from('user_tasks')
          .update({'completed_dates': completed})
          .eq('id', challenge['id']);
      widget.onTasksChanged();
    } catch (_) {}
  }  Future<void> _showAddChallengeDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Get challenges not already added today
    final alreadyAdded = _tasks
        .where((t) => (t['is_challenge'] as bool?) ?? false)
        .map((t) => t['name'] as String)
        .toList();
    
    final availableChallenges = _challengePool
        .where((c) => !alreadyAdded.contains(c))
        .toList();

    if (availableChallenges.isEmpty) {
      // All challenges already added
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All challenges already added for today!')),
      );
      return;
    }

    // Randomly pick one
    availableChallenges.shuffle();
    final selected = availableChallenges.first;

    final id = const Uuid().v4();
    final newChallenge = {
      'id': id,
      'name': selected,
      'days': <String>[],
      'end_date': null,
      'completed_dates': <String>[],
      'user_id': user.id,
      'is_challenge': true,
    };

    setState(() {
      _tasks.add(newChallenge);
    });

    try {
      await _supabase.from('user_tasks').insert({
        'id': id,
        'name': selected,
        'days': [],
        'end_date': null,
        'completed_dates': [],
        'user_id': user.id,
        'is_challenge': true,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add challenge: $e')),
      );
      // Remove from local list if database insert failed
      setState(() => _tasks.removeWhere((t) => t['id'] == id));
    }
  }
  bool _isCompletedToday(Map<String, dynamic> task) =>
      (task['completed_dates'] as List<String>? ?? []).contains(_todayKey());Future<void> _toggleTask(Map<String, dynamic> task) async {
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
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: secondaryColor, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Add Task',
            style: TextStyle(color: secondaryColor, shadows: [])),        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            style: TextStyle(color: textColor),
            cursorColor: textColor,
            decoration: InputDecoration(
              hintText: 'Task name',
              hintStyle: const TextStyle(color: Colors.white38),      // white38
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: secondaryColor),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: secondaryColor, width: 2),
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
            child: Text('Cancel',
                style: TextStyle(color: secondaryColor, shadows: [])),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: secondaryColor),
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, nameCtrl.text.trim());
            },
            child: Text('Add',
                style: TextStyle(color: primaryColor, shadows: [])),
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

    setState(() => _tasks.add(newTask));    try {
      await _supabase.from('user_tasks').insert({
        'id': id,
        'name': result,
        'days': [],
        'end_date': null,
        'completed_dates': [],        'user_id': user.id,
      });
      widget.onTasksChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save task.')),
      );
    }
  }  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    
    // Separate regular tasks and challenges
    final regularTasks = _tasks.where((t) => (t['is_challenge'] as bool?) ?? false ? false : true).toList();
    final challenges = _tasks.where((t) => (t['is_challenge'] as bool?) ?? false).toList();
    
    final incompleteRegular = regularTasks.where((t) => !_isCompletedToday(t)).toList();
    final completedRegular = regularTasks.where((t) => _isCompletedToday(t)).toList();
    
    final incompleteChallenges = challenges.where((c) => !_isCompletedToday(c)).toList();
    final completedChallenges = challenges.where((c) => _isCompletedToday(c)).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: neon, width: 2),
        color: primaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 2, 1),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: neon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DAILY TASKS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
                // Add challenge button
                GestureDetector(
                  onTap: _showAddChallengeDialog,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                    ),
                    child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                  ),
                ),
                const SizedBox(width: 8),
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

          // PageView for tasks (swipe left/right)
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      // Page 0: Incomplete challenges + tasks
                      _buildTaskList(incompleteRegular, incompleteChallenges, neon, isCompleted: false),
                      // Page 1: Completed challenges + tasks
                      _buildTaskList(completedRegular, completedChallenges, neon, isCompleted: true),
                    ],
                  ),
          ),

          // Page indicator dots
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(0, neon),
                const SizedBox(width: 8),
                _buildDot(1, neon),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, Color neon) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isActive ? neon : neon.withOpacity(0.3),
      ),
    );
  }  Widget _buildTaskList(List<Map<String, dynamic>> tasks, List<Map<String, dynamic>> challenges, Color neon, {required bool isCompleted}) {
    // Challenges at the top, then tasks
    final allItems = [...challenges, ...tasks];
    
    if (allItems.isEmpty) {
      return Center(
        child: Text(
          isCompleted
              ? 'No completed tasks yet'
              : ((_tasks.where((t) => (t['is_challenge'] as bool?) ?? false ? false : true).isEmpty &&
                  _tasks.where((t) => (t['is_challenge'] as bool?) ?? false).isEmpty)
                  ? 'No tasks for today.\nTap + to add one.'
                  : 'All tasks completed!'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: neon.withOpacity(0.5),
            fontSize: 13,
            shadows: [],
          ),
        ),
      );
    }

    const Color challengeColor = Color(0xFFFFD700); // Gold/yellow for challenges

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final item = allItems[i];
        final isChallenge = (item['is_challenge'] as bool?) ?? false;
        final itemColor = isChallenge ? challengeColor : neon;
        
        return InkWell(
          onTap: () => isChallenge ? _toggleChallenge(item) : _toggleTask(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCompleted ? itemColor.withOpacity(0.2) : itemColor.withOpacity(0.35),
                width: 1,
              ),
              color: isCompleted ? itemColor.withOpacity(0.05) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCompleted ? itemColor : itemColor.withOpacity(0.4),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['name'] as String,
                    style: TextStyle(
                      color: isCompleted 
                          ? (isChallenge ? Colors.white54 : Colors.white54)     // white54
                          : (isChallenge ? challengeColor : Colors.white),
                      fontSize: 14,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      shadows: [],
                    ),
                  ),
                ),
                // Star icon at the end for challenges
                if (isChallenge)
                  Icon(
                    Icons.star,
                    color: isCompleted ? challengeColor.withOpacity(0.5) : challengeColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
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
        color: primaryColor,
      ),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [          Row(
            children: [
              Expanded(
                child: Text(
                  'REMAINING SCREEN TIME',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                  ),
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
                  style: TextStyle(
                    color: textColor,
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
            Text('Permission Required',
                style:
                    TextStyle(color: textColor, fontSize: 13, shadows: [])),
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
                        color: Colors.white54, fontSize: 12, shadows: []),    // white54
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _NeonProgressBar(value: progress, neon: barColor),
          ],
        ],
        ),
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
        border: Border.all(color: neon.withOpacity(0.95), width: 1.4),
        boxShadow: [
          BoxShadow(color: neon.withOpacity(0.18), blurRadius: 14)
        ],
        color: primaryColor,
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
                    color: neon.withOpacity(0.35), blurRadius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
