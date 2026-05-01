import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'events_page.dart' as events;

const double _cornerRadius = 18.0;

// ─────────────────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {  // ── profile ──────────────────────────────────────────────────────────────
  String _username = '';
  String _avatarSvg = '';
  int _coins = 0;
  // ── ring data ─────────────────────────────────────────────────────────────
  double _eventRing = 0;
  double _taskRing = 0;
  double _macroRing = 0;
  double _weightRing = 0;
  final _supabase = Supabase.instance.client;
  Timer? _ringRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Refresh activity rings every 2 seconds to catch task updates from journal
    _ringRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadRings();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op since we removed screen time functionality
  }

  Future<void> _load() async {
    await Future.wait([_loadProfile(), _loadRings()]);
  }

  // ── profile ───────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {      final row = await _supabase
          .from('profiles')
          .select('username, coins, avatar_svg')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _username = (row?['username'] ?? user.email ?? 'User').toString();
        _coins = (row?['coins'] is num) ? (row!['coins'] as num).toInt() : 0;
        _avatarSvg = (row?['avatar_svg'] ?? '').toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _username = _supabase.auth.currentUser?.email ?? 'User');
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
          const fullWeekdays = [
            'Sunday',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
          ];
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
                  if (now.hour > endH ||
                      (now.hour == endH && now.minute >= endM))
                    done++;
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
                if (now.hour == 23 && now.minute == 59 && now.second >= 59)
                  done++;
              } else {
                final endTime = (r['end_time'] ?? '').toString();
                if (endTime.isNotEmpty) {
                  try {
                    final parts = endTime.split(':');
                    int endH = int.parse(parts[0].trim());
                    int endM = int.parse(parts[1].trim().split(' ')[0]);
                    if (endTime.toUpperCase().contains('PM') && endH < 12)
                      endH += 12;
                    if (endTime.toUpperCase().contains('AM') && endH == 12)
                      endH = 0;
                    final eventEnd = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      endH,
                      endM,
                    );
                    if (eventEnd.isBefore(now)) done++;
                  } catch (_) {}
                }
              }
            }
          }
          if (!mounted) return;
          setState(
            () => _eventRing = total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
          );
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
              if (List<String>.from(
                r['completed_dates'] ?? [],
              ).contains(todayStr)) {
                done++;
              }
            }
          }
          if (!mounted) return;
          setState(
            () => _taskRing = total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
          );
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
  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile ───────────────────────────────────────────────────
            _ProfileWidget(
              username: _username,
              coins: _coins,
              avatarSvg: _avatarSvg,
              onSettingsReturn: _loadProfile,
            ),

            const SizedBox(height: 10),

            // ── Activity Rings ────────────────────────────────────────────
            _ActivityRingsWidget(
              eventRing: _eventRing,
              taskRing: _taskRing,
              macroRing: _macroRing,
              weightRing: _weightRing,
            ),
            const SizedBox(height: 10),
            // ── Daily Tasks (expands to fill remaining space) ─────────────
            Expanded(
              flex: 1,
              child: _DailyTasksWidget(onTasksChanged: () {
                _loadRings();
                _loadProfile();
              }),
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
  final String avatarSvg;
  final VoidCallback? onSettingsReturn;

  const _ProfileWidget({
    required this.username,
    required this.coins,
    this.avatarSvg = '',
    this.onSettingsReturn,
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
        children: [          // Left: Profile avatar
          avatarSvg.isNotEmpty
              ? ClipOval(
                  child: SvgPicture.string(
                    avatarSvg,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              : CircleAvatar(
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
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 18,
                    ),
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
        color: Colors.black,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _InfoButton(
                infoText:
                    'Use this to track progress on your set Events, Tasks, Macros, and Weight from the Journal and Fitness tabs. Once you complete all of the daily requirements for each component, the progression bars will fill up.',
                iconColor: neon,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ProgressBarItem(
            value: eventRing,
            label: 'Events',
            color: const Color(0xFF00FF66),
          ),
          const SizedBox(height: 12),
          _ProgressBarItem(
            value: taskRing,
            label: 'Tasks',
            color: const Color(0xFF00FF66),
          ),
          const SizedBox(height: 12),
          _ProgressBarItem(
            value: macroRing,
            label: 'Macros',
            color: const Color(0xFFFF9500),
          ),
          const SizedBox(height: 12),
          _ProgressBarItem(
            value: weightRing,
            label: 'Weight',
            color: const Color(0xFF2196F3),
          ),
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
              color: Colors.black,
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
  final _supabase = Supabase.instance.client;
  final _pageController = PageController();
  Timer? _refreshTimer;
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
    // Refresh tasks every 2 seconds to catch edits/deletes from journal
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadTasks();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _refreshTimer?.cancel();
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
          .eq('user_id', user.id);
      final today = _todayKey();
      final todayWeekday = _weekdayName(DateTime.now().weekday);
      final tasks = (rows as List)
          .map(
            (r) => {
              'id': r['id'],
              'name': r['name'].toString(),
              'days': List<String>.from(r['days'] ?? []),
              'end_date': r['end_date']?.toString(),
              'completed_dates': List<String>.from(r['completed_dates'] ?? []),
              'user_id': r['user_id'],
              'is_challenge': (r['is_challenge'] as bool?) ?? false,
            },
          )
          .where((t) {
            final isChallenge = t['is_challenge'] as bool;
            if (isChallenge) {
              // Only show challenges created today
              return (t['end_date'] as String?) == today;
            }
            final days = t['days'] as List<String>;
            return days.isEmpty || days.contains(todayWeekday);
          })
          .toList();
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
    final completed = List<String>.from(
      challenge['completed_dates'] as List? ?? [],
    );
    final wasCompleted = completed.contains(today);
    if (wasCompleted) {
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
      await _updateCoins(wasCompleted ? -5 : 5);
      widget.onTasksChanged();
    } catch (_) {}
  }
  Future<void> _showAddChallengeDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final today = _todayKey();

    // Count challenges already added today (end_date used as creation date)
    final todaysChallenges = _tasks
        .where((t) => (t['is_challenge'] as bool?) ?? false)
        .where((t) => (t['end_date'] as String?) == today)
        .toList();

    if (todaysChallenges.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only add 3 daily challenges per day!'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    // Get challenges not already added today
    final alreadyAdded = todaysChallenges
        .map((t) => t['name'] as String)
        .toList();

    final availableChallenges = _challengePool
        .where((c) => !alreadyAdded.contains(c))
        .toList();

    if (availableChallenges.isEmpty) {
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
      'end_date': today, // stamp creation date so we can filter by day
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
        'end_date': today,
        'completed_dates': [],
        'user_id': user.id,
        'is_challenge': true,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add challenge: $e')),
      );
      setState(() => _tasks.removeWhere((t) => t['id'] == id));
    }
  }
  bool _isCompletedToday(Map<String, dynamic> task) =>
      (task['completed_dates'] as List<String>? ?? []).contains(_todayKey());

  /// Adds [delta] coins to the current user's profile (can be negative to remove).
  Future<void> _updateCoins(int delta) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _supabase
          .from('profiles')
          .select('coins')
          .eq('id', user.id)
          .maybeSingle();
      final current = (row?['coins'] as num?)?.toInt() ?? 0;
      final updated = (current + delta).clamp(0, 999999);
      await _supabase
          .from('profiles')
          .update({'coins': updated})
          .eq('id', user.id);
    } catch (_) {}
  }
  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final today = _todayKey();
    final completed = List<String>.from(task['completed_dates'] as List);
    final wasCompleted = completed.contains(today);
    if (wasCompleted) {
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
      await _updateCoins(wasCompleted ? -1 : 1);
      widget.onTasksChanged();
    } catch (_) {}
  }

  void _addTask() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => events.AddEventTaskSheet(
        selectedDay: DateTime.now(),
        initialTab: 1,
        onEventAdded: (_) {},
        onTaskAdded: (task) async {
          final id = const Uuid().v4();
          try {
            await _supabase.from('user_tasks').insert({
              'id': id,
              'name': task['name'],
              'days': task['days'] ?? [],
              'end_date': task['end_date'],
              'completed_dates': [],
              'user_id': user.id,
            });
            setState(() => _loadTasks());
            widget.onTasksChanged();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save task.')),
            );
          }
        },
        formatTime: events.eventsFormatTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    // Separate regular tasks and challenges
    final regularTasks = _tasks
        .where((t) => (t['is_challenge'] as bool?) ?? false ? false : true)
        .toList();
    final challenges = _tasks
        .where((t) => (t['is_challenge'] as bool?) ?? false)
        .toList();

    final incompleteRegular = regularTasks
        .where((t) => !_isCompletedToday(t))
        .toList();
    final completedRegular = regularTasks
        .where((t) => _isCompletedToday(t))
        .toList();

    final incompleteChallenges = challenges
        .where((c) => !_isCompletedToday(c))
        .toList();
    final completedChallenges = challenges
        .where((c) => _isCompletedToday(c))
        .toList();

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
            padding: const EdgeInsets.fromLTRB(16, 2, 2, 1),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: neon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DAILY TASKS',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
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
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFFFFD700),
                      size: 18,
                    ),
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
                _InfoButton(
                  infoText:
                      'Use this to check off or make Daily Tasks. Also press the star button to add additional tasks if you would like to challenge yourself. Swipe right to view your completed tasks for the day.',
                  iconColor: neon,
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
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    children: [
                      // Page 0: Incomplete challenges + tasks
                      _buildTaskList(
                        incompleteRegular,
                        incompleteChallenges,
                        neon,
                        isCompleted: false,
                      ),
                      // Page 1: Completed challenges + tasks
                      _buildTaskList(
                        completedRegular,
                        completedChallenges,
                        neon,
                        isCompleted: true,
                      ),
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
  }

  Widget _buildTaskList(
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> challenges,
    Color neon, {
    required bool isCompleted,
  }) {
    // Challenges at the top, then tasks
    final allItems = [...challenges, ...tasks];

    if (allItems.isEmpty) {
      return Center(
        child: Text(
          isCompleted
              ? 'No completed tasks yet'
              : ((_tasks
                            .where(
                              (t) => (t['is_challenge'] as bool?) ?? false
                                  ? false
                                  : true,
                            )
                            .isEmpty &&
                        _tasks
                            .where((t) => (t['is_challenge'] as bool?) ?? false)
                            .isEmpty)
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

    const Color challengeColor = Color(
      0xFFFFD700,
    ); // Gold/yellow for challenges

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
                color: isCompleted
                    ? itemColor.withOpacity(0.2)
                    : itemColor.withOpacity(0.35),
                width: 1,
              ),
              color: isCompleted
                  ? itemColor.withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? itemColor : itemColor.withOpacity(0.4),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['name'] as String,
                    style: TextStyle(
                      color: isCompleted
                          ? (isChallenge ? Colors.white54 : Colors.white54)
                          : (isChallenge ? challengeColor : Colors.white),
                      fontSize: 14,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      shadows: [],
                    ),
                  ),
                ),
                // Star icon at the end for challenges
                if (isChallenge)
                  Icon(
                    Icons.star,
                    color: isCompleted
                        ? challengeColor.withOpacity(0.5)
                        : challengeColor,
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

class _InfoButton extends StatelessWidget {
  final String? infoText;
  final Color iconColor;
  const _InfoButton({required this.infoText, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final overlay = Overlay.of(context);
        final renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);

        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => entry.remove(),
            child: Stack(
              children: [
                Positioned(
                  right: MediaQuery.of(ctx).size.width - position.dx - 24,
                  top: position.dy + 28,
                  width: 220,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: iconColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        infoText ?? '',
                        style: TextStyle(color: iconColor, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        overlay.insert(entry);
      },
      child: Icon(Icons.help, color: iconColor, size: 20),
    );
  }
}
