import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'events_page.dart' as events;
import '../services/offline_sync.dart';

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
    final sync = SyncService.instance;
    final cached = sync.getCachedSingle('profiles', user.id);
    if (cached != null && mounted) {
      setState(() {
        _username = (cached['username'] ?? user.email ?? 'User').toString();
        _coins = (cached['coins'] is num) ? (cached['coins'] as num).toInt() : 0;
      });
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('username, coins, avatar_svg')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) sync.cacheSingle('profiles', user.id, Map<String, dynamic>.from(row));
      if (!mounted) return;
      setState(() {
        _username = (row?['username'] ?? user.email ?? 'User').toString();
        _coins = (row?['coins'] is num) ? (row!['coins'] as num).toInt() : 0;
        _avatarSvg = (row?['avatar_svg'] ?? '').toString();
      });
      final rawList = List<Map<String, dynamic>>.from(rows);
      sync.cacheList('user_tasks_dash', user.id, rawList);
      _applyTaskRows(rawList);
    } catch (_) {
      if (cached.isEmpty && mounted) setState(() => _loading = false);
    }
  }

  void _applyTaskRows(List<Map<String, dynamic>> rows) {
    final todayWeekday = _weekdayName(DateTime.now().weekday);
    final tasks = rows.map((r) => <String, dynamic>{
          'id': r['id'],
          'name': r['name'].toString(),
          'days': List<String>.from(r['days'] ?? []),
          'end_date': r['end_date'],
          'completed_dates': List<String>.from(r['completed_dates'] ?? []),
          'user_id': r['user_id'],
          'is_challenge': (r['is_challenge'] as bool?) ?? false,
        }).where((t) {
      final isChallenge = t['is_challenge'] as bool;
      if (isChallenge) return true;
      final days = t['days'] as List<String>;
      return days.isEmpty || days.contains(todayWeekday);
    }).toList();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
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
    SyncService.instance.patchCachedList('user_tasks_dash', _supabase.auth.currentUser?.id ?? '', 'id', challenge['id'].toString(), {'completed_dates': completed});
    try {
      await _supabase.from('user_tasks').update({'completed_dates': completed}).eq('id', challenge['id']);
      widget.onTasksChanged();
    } catch (_) {
      SyncService.instance.enqueue(table: 'user_tasks', type: 'update', data: {'completed_dates': completed}, match: {'id': challenge['id']});
    }
  }  Future<void> _showAddChallengeDialog() async {
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

    setState(() => _tasks.add(newChallenge));
    final challengeData = {
      'id': id, 'name': selected, 'days': <String>[], 'end_date': null,
      'completed_dates': <String>[], 'user_id': user.id, 'is_challenge': true,
    };
    SyncService.instance.addToCachedList('user_tasks_dash', user.id, challengeData);
    try {
      await _supabase.from('user_tasks').insert(challengeData);
    } catch (_) {
      SyncService.instance.enqueue(table: 'user_tasks', type: 'insert', data: challengeData);
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
    SyncService.instance.patchCachedList('user_tasks_dash', _supabase.auth.currentUser?.id ?? '', 'id', task['id'].toString(), {'completed_dates': completed});
    try {
      await _supabase.from('user_tasks').update({'completed_dates': completed}).eq('id', task['id']);
      widget.onTasksChanged();
    } catch (_) {
      SyncService.instance.enqueue(table: 'user_tasks', type: 'update', data: {'completed_dates': completed}, match: {'id': task['id']});
    }
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
          final taskData = {
            'id': id, 'name': task['name'], 'days': task['days'] ?? [],
            'end_date': task['end_date'], 'completed_dates': <String>[], 'user_id': user.id,
          };
          SyncService.instance.addToCachedList('user_tasks_dash', user.id, taskData);
          try {
            await _supabase.from('user_tasks').insert(taskData);
          } catch (_) {
            SyncService.instance.enqueue(table: 'user_tasks', type: 'insert', data: taskData);
          }
          setState(() => _loadTasks());
          widget.onTasksChanged();
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
