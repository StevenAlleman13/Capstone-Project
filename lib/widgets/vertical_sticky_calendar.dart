import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class VerticalStickyCalendar extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDaySelected;
  final List<Map> Function(DateTime)? eventsForDay;
  final List<Map> Function(DateTime)? completedEventsForDay;
  final List<Map<String, dynamic>> Function(DateTime)? tasksForDay;
  final List<Map<String, dynamic>> Function(DateTime)? completedTasksForDay;
  final bool isShowingEvents;
  final bool showBothSections;
  final void Function(Map)? onEventEdit;
  final void Function(Map)? onEventDelete;
  final void Function(Map<String, dynamic>, int)? onTaskEdit;
  final Future<void> Function(Map<String, dynamic>, int)? onTaskDelete;
  final void Function(Map<String, dynamic>, int)? onTaskComplete;
  final void Function(Map<String, dynamic>, int)? onTaskUncomplete;
  final void Function(bool isWeekView)? onViewModeChanged;
  final VoidCallback? onAddEvent;
  final VoidCallback? onAddTask;

  const VerticalStickyCalendar({
    super.key,
    required this.firstDay,
    required this.lastDay,
    this.selectedDay,
    this.onDaySelected,
    this.eventsForDay,
    this.completedEventsForDay,
    this.tasksForDay,
    this.completedTasksForDay,
    this.isShowingEvents = true,
    this.showBothSections = false,
    this.onEventEdit,
    this.onEventDelete,
    this.onTaskEdit,
    this.onTaskDelete,
    this.onTaskComplete,
    this.onTaskUncomplete,
    this.onViewModeChanged,
    this.onAddEvent,
    this.onAddTask,
  });

  @override
  VerticalStickyCalendarState createState() => VerticalStickyCalendarState();
}

class VerticalStickyCalendarState extends State<VerticalStickyCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _jiggleMode = false;
  bool _workoutsExpanded = false;
  bool _eventsExpanded = false;
  bool _tasksExpanded = false;
  bool _showWorkoutForm = false;
  String? _editingWorkoutId;
  final TextEditingController _workoutTitleController = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _workoutsByDay = {};
  final List<Map<String, dynamic>> _savedWorkoutsForDay = [];
  bool _loadingWorkouts = false;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  String get _dayKey {
    final d = _selectedDay;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> get _exercises =>
      _workoutsByDay.putIfAbsent(_dayKey, () => []);

  Future<void> _loadWorkoutsForDay() async {
    if (_userId == null) return;
    setState(() => _loadingWorkouts = true);
    final rows = await _supabase
        .from('user_workouts')
        .select()
        .eq('user_id', _userId!)
        .eq('workout_date', _dayKey)
        .order('created_at', ascending: true);
    setState(() {
      _savedWorkoutsForDay
        ..clear()
        ..addAll(rows);
      _loadingWorkouts = false;
    });
  }

  void _openWorkoutForEditing(Map<String, dynamic> workout) {
    final exercises = (workout['exercises'] as List).map((ex) {
      final sets = (ex['sets'] as List)
          .map(
            (s) => <String, TextEditingController>{
              'lbs': TextEditingController(text: s['lbs'] ?? ''),
              'reps': TextEditingController(text: s['reps'] ?? ''),
            },
          )
          .toList();
      return <String, dynamic>{
        'name': TextEditingController(text: ex['name'] ?? ''),
        'rows': sets,
      };
    }).toList();

    setState(() {
      _editingWorkoutId = workout['id'] as String;
      _workoutTitleController.text = workout['title'] ?? '';
      _workoutsByDay[_dayKey] = exercises;
      _showWorkoutForm = true;
    });
  }

  Future<void> _saveWorkout() async {
    if (_userId == null) return;
    final exercisesData = _exercises.map((ex) {
      final rows = ex['rows'] as List<Map<String, TextEditingController>>;
      return {
        'name': (ex['name'] as TextEditingController).text.trim(),
        'sets': rows
            .map(
              (r) => {
                'lbs': r['lbs']!.text.trim(),
                'reps': r['reps']!.text.trim(),
              },
            )
            .toList(),
      };
    }).toList();

    final payload = {
      'title': _workoutTitleController.text.trim(),
      'exercises': exercisesData,
    };

    if (_editingWorkoutId != null) {
      await _supabase
          .from('user_workouts')
          .update(payload)
          .eq('id', _editingWorkoutId!);
    } else {
      await _supabase.from('user_workouts').insert({
        ...payload,
        'user_id': _userId,
        'workout_date': _dayKey,
      });
    }

    setState(() {
      _showWorkoutForm = false;
      _editingWorkoutId = null;
      _workoutTitleController.clear();
      _workoutsByDay.remove(_dayKey);
    });

    await _loadWorkoutsForDay();
  }

  /// Collapse both the events and tasks sections
  void collapseAll() {
    setState(() {
      _workoutsExpanded = false;
      _eventsExpanded = false;
      _tasksExpanded = false;
    });
  }

  void refreshWorkouts() {
    _loadWorkoutsForDay();
  }

  /// Public method to jump the calendar to today's date in week view
  void jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = now;
    });
    widget.onDaySelected?.call(now);
    widget.onViewModeChanged?.call(true);
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay ?? DateTime.now();
    _selectedDay = widget.selectedDay ?? DateTime.now();
    _loadWorkoutsForDay();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_jiggleMode) setState(() => _jiggleMode = false);
      },
      child: Column(
        children: [
          Container(
            color: const Color(0xFF232323),
            child: TableCalendar(
              firstDay: widget.firstDay,
              lastDay: widget.lastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  DateUtils.isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.week,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _showWorkoutForm = false;
                  _workoutTitleController.clear();
                });
                _loadWorkoutsForDay();
                widget.onDaySelected?.call(selectedDay);
                widget.onViewModeChanged?.call(true);
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                headerPadding: EdgeInsets.only(top: 24, bottom: 4),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  shadows: [],
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
                decoration: BoxDecoration(color: Color(0xFF232323)),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(
                  color: Colors.white,
                  shadows: [],
                ),
                weekendTextStyle: const TextStyle(
                  color: Color(0xFF7A7A7A),
                  shadows: [],
                ),
                todayDecoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  shadows: [],
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.white,
                  shadows: [],
                ),
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  shadows: [],
                ),
                weekendStyle: TextStyle(
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w600,
                  shadows: [],
                ),
              ),
            ),
          ),
          // Neon line
          Container(
            width: double.infinity,
            height: 1,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF66),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF66).withOpacity(0.4),
                  blurRadius: 2,
                  spreadRadius: 0.2,
                ),
              ],
            ),
          ),
          // Selected date label
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Center(
              child: Text(
                DateFormat('EEEE — MMM d, y').format(_selectedDay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF00FF66)),
          Expanded(
            child: widget.showBothSections
                ? _buildBothSections()
                : (widget.isShowingEvents
                      ? _buildEventsList()
                      : _buildTasksList()),
          ),
        ],
      ),
    );
  }

  // Helper function to parse time strings and convert to minutes for sorting
  int _parseTimeToMinutes(String timeStr) {
    try {
      // Handle formats like "2:30 PM" or "14:30"
      final parts = timeStr.trim().split(' ');
      final timePart = parts[0];
      final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      final isAM = parts.length > 1 && parts[1].toUpperCase() == 'AM';

      final hourMinute = timePart.split(':');
      if (hourMinute.length != 2) return 0;

      int hour = int.tryParse(hourMinute[0]) ?? 0;
      final minute = int.tryParse(hourMinute[1]) ?? 0;

      // Convert to 24-hour format if AM/PM present
      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return hour * 60 + minute;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildBothSections() {
    const neon = Color(0xFF00FF66);
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Workouts collapsible
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neon, width: 2),
                color: Colors.black,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () =>
                        setState(() => _workoutsExpanded = !_workoutsExpanded),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(18),
                      bottom: _workoutsExpanded
                          ? Radius.zero
                          : const Radius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            color: neon,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Workouts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: [],
                              ),
                            ),
                          ),
                          const _InfoButton(
                            infoText:
                                'Use this to create workouts. When making a workout, you can give the workout a title, add exercises, and add sets to that exercise with set weight and rep amounts. You can also delete a workout by using the Delete Workout button at the bottom of each one created or delete exercises in a workout by using the trash can button on the exercise created.',
                            iconColor: neon,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _workoutsExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            color: neon,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_workoutsExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _showWorkoutForm
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _workoutTitleController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [],
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Workout Title',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 18,
                                    ),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: neon),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: neon,
                                        width: 2,
                                      ),
                                    ),
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(
                                      bottom: 4,
                                    ),
                                  ),
                                ),
                                ..._exercises.map((exercise) {
                                  final nameController =
                                      exercise['name'] as TextEditingController;
                                  final repRows =
                                      exercise['rows']
                                          as List<
                                            Map<String, TextEditingController>
                                          >;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: neon.withValues(alpha: 0.4),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        children: [
                                          // Exercise header row
                                          Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: neon),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: nameController,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      shadows: [],
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: 'Exercise Name',
                                                      hintStyle: TextStyle(
                                                        color: Colors.grey[500],
                                                      ),
                                                      border: InputBorder.none,
                                                      filled: false,
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets.only(
                                                            bottom: 0,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () => setState(
                                                    () => _exercises.remove(
                                                      exercise,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.delete_outline,
                                                    color: neon,
                                                    size: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Rep rows
                                          ...repRows.asMap().entries.map((
                                            entry,
                                          ) {
                                            final i = entry.key;
                                            final row = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Row(
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 46,
                                                        height: 30,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: neon
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: TextField(
                                                          controller:
                                                              row['lbs'],
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          textAlign:
                                                              TextAlign.center,
                                                          textAlignVertical:
                                                              TextAlignVertical
                                                                  .center,
                                                          expands: true,
                                                          maxLines: null,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                                shadows: [],
                                                              ),
                                                          decoration:
                                                              const InputDecoration(
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'lbs',
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 13,
                                                          shadows: [],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Expanded(
                                                    child: Center(
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 46,
                                                            height: 30,
                                                            decoration: BoxDecoration(
                                                              border: Border.all(
                                                                color: neon
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            child: TextField(
                                                              controller:
                                                                  row['reps'],
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              textAlignVertical:
                                                                  TextAlignVertical
                                                                      .center,
                                                              expands: true,
                                                              maxLines: null,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        14,
                                                                    shadows: [],
                                                                  ),
                                                              decoration: const InputDecoration(
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          const Text(
                                                            'Reps',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 13,
                                                              shadows: [],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () => setState(
                                                      () => repRows.removeAt(i),
                                                    ),
                                                    child: const Icon(
                                                      Icons.remove,
                                                      color: neon,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          const Divider(
                                            color: Colors.white12,
                                            height: 16,
                                          ),
                                          Center(
                                            child: TextButton(
                                              onPressed: () => setState(
                                                () => repRows.add({
                                                  'lbs':
                                                      TextEditingController(),
                                                  'reps':
                                                      TextEditingController(),
                                                }),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 0,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Add Set',
                                                style: TextStyle(
                                                  color: neon,
                                                  fontSize: 12,
                                                  shadows: [],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _exercises.add({
                                      'name': TextEditingController(),
                                      'rows':
                                          <
                                            Map<String, TextEditingController>
                                          >[],
                                    }),
                                  ),
                                  child: const Text(
                                    '+ Add Exercise',
                                    style: TextStyle(color: neon, shadows: []),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _saveWorkout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: neon,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save Workout',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      shadows: [],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loadingWorkouts)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: neon,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else ...[
                                  ..._savedWorkoutsForDay.map(
                                    (w) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: GestureDetector(
                                        onTap: () => _openWorkoutForEditing(w),
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: neon,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[800],
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          12,
                                                        ),
                                                      ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    w['title'] ?? 'Untitled',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                      shadows: [],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      10,
                                                      2,
                                                      10,
                                                      8,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    ...((w['exercises'] as List).asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final idx = entry.key;
                                                      final ex = entry.value;
                                                      final sets =
                                                          ex['sets'] as List;
                                                      return Column(
                                                        children: [
                                                          if (idx > 0)
                                                            const Divider(
                                                              color: neon,
                                                              thickness: 0.5,
                                                              height: 8,
                                                            ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: 2,
                                                                ),
                                                            child: Center(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Text(
                                                                    ex['name'] ??
                                                                        '',
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      shadows:
                                                                          [],
                                                                    ),
                                                                  ),
                                                                  ...sets.map(
                                                                    (s) => Text(
                                                                      '${s['lbs']} lbs × ${s['reps']} reps',
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .grey[500],
                                                                        fontSize:
                                                                            12,
                                                                        shadows:
                                                                            const [],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    })),
                                                  ],
                                                ),
                                              ),
                                              const Divider(
                                                color: Colors.white12,
                                                height: 8,
                                              ),
                                              Center(
                                                child: TextButton(
                                                  onPressed: () async {
                                                    await _supabase
                                                        .from('user_workouts')
                                                        .delete()
                                                        .eq('id', w['id']);
                                                    await _loadWorkoutsForDay();
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    alignment: Alignment.center,
                                                  ),
                                                  child: const Text(
                                                    'Delete Workout',
                                                    style: TextStyle(
                                                      color: neon,
                                                      fontSize: 13,
                                                      shadows: [],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                Center(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _showWorkoutForm = true),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: neon),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Create Workout',
                                      style: TextStyle(
                                        color: neon,
                                        shadows: [],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Events collapsible
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neon, width: 2),
                color: Colors.black,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(
                              () => _eventsExpanded = !_eventsExpanded,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event,
                                    color: neon,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Events',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      shadows: [],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onAddEvent,
                          child: const Icon(Icons.add, color: neon, size: 22),
                        ),
                        const SizedBox(width: 8),
                        const _InfoButton(
                          infoText:
                              'Add events by using the + button. When adding an event, you can give it a title, description, location, schedule it for all-day or a specific start and end time, and make it repeatable on certain days. These events will be tracked on the calendar at the top of this tab.',
                          iconColor: neon,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(
                            () => _eventsExpanded = !_eventsExpanded,
                          ),
                          child: Icon(
                            _eventsExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            color: neon,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_eventsExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildEventsContent(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tasks collapsible
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neon, width: 2),
                color: Colors.black,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(
                              () => _tasksExpanded = !_tasksExpanded,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.task_alt,
                                    color: neon,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Tasks',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      shadows: [],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onAddTask,
                          child: const Icon(Icons.add, color: neon, size: 22),
                        ),
                        const SizedBox(width: 8),
                        const _InfoButton(
                          infoText:
                              'Add tasks to complete as a checklist by using the + button. When adding a task, you may give it a title and make it repeatable on certain days of the week.',
                          iconColor: neon,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _tasksExpanded = !_tasksExpanded),
                          child: Icon(
                            _tasksExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            color: neon,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tasksExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildTasksContent(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsContent() {
    if (widget.eventsForDay == null) {
      return const Text(
        'No events function provided',
        style: TextStyle(color: Colors.white54, shadows: []),
      );
    }
    final events = widget.eventsForDay!(_selectedDay);
    final completedEvents =
        widget.completedEventsForDay?.call(_selectedDay) ?? [];
    if (events.isEmpty && completedEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No events',
            style: TextStyle(color: Colors.white54, fontSize: 16, shadows: []),
          ),
        ),
      );
    }
    final allDayEvents = events.where((e) => e['all_day'] == true).toList();
    final timedEvents = events.where((e) => e['all_day'] != true).toList();
    timedEvents.sort((a, b) {
      final aTime = a['start_time'] as String?;
      final bTime = b['start_time'] as String?;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return _parseTimeToMinutes(aTime).compareTo(_parseTimeToMinutes(bTime));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (allDayEvents.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'ALL DAY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [],
              ),
            ),
          ),
          ...allDayEvents.asMap().entries.map(
            (entry) => _EventDismissibleOverlay(
              event: Map<String, dynamic>.from(entry.value),
              index: entry.key,
              isCompleted: false,
              isJiggling: _jiggleMode,
              onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
              onEdit: () => widget.onEventEdit?.call(entry.value),
              onDelete: () => widget.onEventDelete?.call(entry.value),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (timedEvents.isNotEmpty) ...[
          if (allDayEvents.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'SCHEDULED',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  shadows: [],
                ),
              ),
            ),
          ...timedEvents.asMap().entries.map(
            (entry) => _EventDismissibleOverlay(
              event: Map<String, dynamic>.from(entry.value),
              index: allDayEvents.length + entry.key,
              isCompleted: false,
              isJiggling: _jiggleMode,
              onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
              onEdit: () => widget.onEventEdit?.call(entry.value),
              onDelete: () => widget.onEventDelete?.call(entry.value),
            ),
          ),
        ],
        if (completedEvents.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'COMPLETED',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [],
              ),
            ),
          ),
          ...completedEvents.asMap().entries.map(
            (entry) => _EventDismissibleOverlay(
              event: Map<String, dynamic>.from(entry.value),
              index: allDayEvents.length + timedEvents.length + entry.key,
              isCompleted: true,
              isJiggling: _jiggleMode,
              onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
              onEdit: () {},
              onDelete: () => widget.onEventDelete?.call(entry.value),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTasksContent() {
    if (widget.tasksForDay == null) {
      return const Text(
        'No tasks function provided',
        style: TextStyle(color: Colors.white54, shadows: []),
      );
    }
    final tasks = widget.tasksForDay!(_selectedDay);
    final completedTasks =
        widget.completedTasksForDay?.call(_selectedDay) ?? [];
    if (tasks.isEmpty && completedTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No tasks',
            style: TextStyle(color: Colors.white54, fontSize: 16, shadows: []),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (tasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'TASKS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [],
              ),
            ),
          ),
          ...tasks.asMap().entries.map(
            (entry) => _TaskDismissibleOverlay(
              task: entry.value,
              index: entry.key,
              isCompleted: false,
              isJiggling: _jiggleMode,
              onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
              onEdit: () => widget.onTaskEdit?.call(entry.value, entry.key),
              onDelete: () async =>
                  await widget.onTaskDelete?.call(entry.value, entry.key),
              onComplete: () =>
                  widget.onTaskComplete?.call(entry.value, entry.key),
              onUncomplete: () {},
            ),
          ),
          if (completedTasks.isNotEmpty) const SizedBox(height: 8),
        ],
        if (completedTasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'COMPLETED',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [],
              ),
            ),
          ),
          ...completedTasks.asMap().entries.map(
            (entry) => _TaskDismissibleOverlay(
              task: entry.value,
              index: entry.key,
              isCompleted: true,
              isJiggling: _jiggleMode,
              onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
              onEdit: () {},
              onDelete: () async =>
                  await widget.onTaskDelete?.call(entry.value, entry.key),
              onComplete: () {},
              onUncomplete: () =>
                  widget.onTaskUncomplete?.call(entry.value, entry.key),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventsList() {
    if (widget.eventsForDay == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'No events function provided',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final events = widget.eventsForDay!(_selectedDay);
    final completedEvents =
        widget.completedEventsForDay?.call(_selectedDay) ?? [];

    // Separate all-day and timed events
    final allDayEvents = events.where((e) => e['all_day'] == true).toList();
    final timedEvents = events.where((e) => e['all_day'] != true).toList();

    // Sort timed events by start time
    timedEvents.sort((a, b) {
      final aTime = a['start_time'] as String?;
      final bTime = b['start_time'] as String?;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return _parseTimeToMinutes(aTime).compareTo(_parseTimeToMinutes(bTime));
    });

    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: events.isEmpty && completedEvents.isEmpty
                ? const Center(
                    child: Text(
                      'No events',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        shadows: [],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // All-day events section
                      if (allDayEvents.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            'ALL DAY',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...allDayEvents.asMap().entries.map(
                          (entry) => _EventDismissibleOverlay(
                            event: Map<String, dynamic>.from(entry.value),
                            index: entry.key,
                            isCompleted: false,
                            isJiggling: _jiggleMode,
                            onLongPress: () =>
                                setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {
                              widget.onEventEdit?.call(entry.value);
                            },
                            onDelete: () {
                              widget.onEventDelete?.call(entry.value);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Timed events section
                      if (timedEvents.isNotEmpty) ...[
                        if (allDayEvents.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              'SCHEDULED',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ...timedEvents.asMap().entries.map(
                          (entry) => _EventDismissibleOverlay(
                            event: Map<String, dynamic>.from(entry.value),
                            index: allDayEvents.length + entry.key,
                            isCompleted: false,
                            isJiggling: _jiggleMode,
                            onLongPress: () =>
                                setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {
                              widget.onEventEdit?.call(entry.value);
                            },
                            onDelete: () {
                              widget.onEventDelete?.call(entry.value);
                            },
                          ),
                        ),
                      ],
                      // Completed events section
                      if (completedEvents.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...completedEvents.asMap().entries.map(
                          (entry) => _EventDismissibleOverlay(
                            event: Map<String, dynamic>.from(entry.value),
                            index:
                                allDayEvents.length +
                                timedEvents.length +
                                entry.key,
                            isCompleted: true,
                            isJiggling: _jiggleMode,
                            onLongPress: () =>
                                setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {},
                            onDelete: () {
                              widget.onEventDelete?.call(entry.value);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    if (widget.tasksForDay == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'No tasks function provided',
            style: TextStyle(color: Colors.white54, shadows: []),
          ),
        ),
      );
    }

    final tasks = widget.tasksForDay!(_selectedDay);
    final completedTasks =
        widget.completedTasksForDay?.call(_selectedDay) ?? [];

    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: (tasks.isEmpty && completedTasks.isEmpty)
                ? const Center(
                    child: Text(
                      'No tasks',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        shadows: [],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Active tasks section
                      if (tasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            'TASKS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              shadows: [],
                            ),
                          ),
                        ),
                        ...tasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return _TaskDismissibleOverlay(
                            task: task,
                            index: index,
                            isCompleted: false,
                            isJiggling: _jiggleMode,
                            onLongPress: () =>
                                setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {
                              widget.onTaskEdit?.call(task, index);
                            },
                            onDelete: () async {
                              await widget.onTaskDelete?.call(task, index);
                            },
                            onComplete: () {
                              widget.onTaskComplete?.call(task, index);
                            },
                            onUncomplete: () {},
                          );
                        }),
                        if (completedTasks.isNotEmpty)
                          const SizedBox(height: 16),
                      ],
                      // Completed tasks section
                      if (completedTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...completedTasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return _TaskDismissibleOverlay(
                            task: task,
                            index: index,
                            isCompleted: true,
                            isJiggling: _jiggleMode,
                            onLongPress: () =>
                                setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {},
                            onDelete: () async {
                              await widget.onTaskDelete?.call(task, index);
                            },
                            onComplete: () {},
                            onUncomplete: () {
                              widget.onTaskUncomplete?.call(task, index);
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// Overlay Dismissible widget for events
class _EventDismissibleOverlay extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;
  final bool isJiggling;
  final bool isCompleted;
  final int index;

  const _EventDismissibleOverlay({
    required this.event,
    required this.onDelete,
    required this.onEdit,
    required this.onLongPress,
    required this.isJiggling,
    required this.isCompleted,
    required this.index,
  });

  @override
  State<_EventDismissibleOverlay> createState() =>
      _EventDismissibleOverlayState();
}

class _EventDismissibleOverlayState extends State<_EventDismissibleOverlay>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 110),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_EventDismissibleOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isJiggling && !old.isJiggling) {
      Future.delayed(
        Duration(milliseconds: (widget.index * 25).clamp(0, 150)),
        () {
          if (mounted) _shakeController.repeat(reverse: true);
        },
      );
    } else if (!widget.isJiggling && old.isJiggling) {
      _shakeController.stop();
      _shakeController.value = 0;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        widget.event['description'] != null &&
        widget.event['description'].toString().isNotEmpty;

    return GestureDetector(
      onTap: widget.isJiggling
          ? widget.onEdit
          : () {
              if (hasDescription) setState(() => _expanded = !_expanded);
            },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) => Transform.rotate(
          angle: widget.isJiggling ? _shakeAnimation.value : 0,
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0, 6, 6, 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: widget.isCompleted ? Colors.grey[900] : Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isCompleted
                      ? Colors.grey[700]!
                      : const Color(0xFF00FF66),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.event['all_day'] != true &&
                      widget.event['start_time'] != null)
                    Container(
                      width: 70,
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        widget.event['start_time'],
                        style: TextStyle(
                          color: widget.isCompleted
                              ? Colors.grey[600]
                              : const Color(0xFF00FF66),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: const [],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.event['title'] ?? 'Unnamed Event',
                                style: TextStyle(
                                  color: widget.isCompleted
                                      ? Colors.grey[600]
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [],
                                ),
                              ),
                            ),
                            if (hasDescription &&
                                !widget.isJiggling &&
                                !widget.isCompleted)
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.white54,
                                size: 18,
                              ),
                          ],
                        ),
                        if (widget.event['all_day'] != true &&
                            widget.event['end_time'] != null)
                          Text(
                            'Until ${widget.event['end_time']}',
                            style: TextStyle(
                              color: widget.isCompleted
                                  ? Colors.grey[700]
                                  : Colors.white60,
                              fontSize: 12,
                              shadows: const [],
                            ),
                          ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child:
                              _expanded && hasDescription && !widget.isJiggling
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    widget.event['description'],
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      shadows: [],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isJiggling)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Overlay Dismissible widget for tasks
class _TaskDismissibleOverlay extends StatefulWidget {
  final Map<String, dynamic> task;
  final int index;
  final bool isCompleted;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback onLongPress;
  final bool isJiggling;

  const _TaskDismissibleOverlay({
    required this.task,
    required this.index,
    required this.isCompleted,
    required this.onDelete,
    required this.onEdit,
    required this.onComplete,
    required this.onUncomplete,
    required this.onLongPress,
    required this.isJiggling,
  });

  @override
  State<_TaskDismissibleOverlay> createState() =>
      _TaskDismissibleOverlayState();
}

class _TaskDismissibleOverlayState extends State<_TaskDismissibleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 110),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_TaskDismissibleOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isJiggling && !old.isJiggling) {
      Future.delayed(
        Duration(milliseconds: (widget.index * 25).clamp(0, 150)),
        () {
          if (mounted) _shakeController.repeat(reverse: true);
        },
      );
    } else if (!widget.isJiggling && old.isJiggling) {
      _shakeController.stop();
      _shakeController.value = 0;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isJiggling
          ? (widget.isCompleted ? null : widget.onEdit)
          : (widget.isCompleted ? null : widget.onComplete),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) => Transform.rotate(
          angle: widget.isJiggling ? _shakeAnimation.value : 0,
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0, 6, 6, 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: widget.isCompleted ? Colors.grey[900] : Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isCompleted
                      ? Colors.grey[700]!
                      : const Color(0xFF00FF66),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: widget.isJiggling
                        ? null
                        : widget.isCompleted
                        ? widget.onUncomplete
                        : widget.onComplete,
                    child: widget.isCompleted
                        ? Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00FF66),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 16,
                            ),
                          )
                        : Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00FF66),
                                width: 2,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.task['name'] ?? 'Unnamed Task',
                                style: TextStyle(
                                  color: widget.isCompleted
                                      ? Colors.grey[600]
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: widget.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: Colors.grey[600],
                                  shadows: const [],
                                ),
                              ),
                            ),
                            if ((widget.task['is_challenge'] as bool?) ?? false)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF66),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Challenge',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    shadows: [],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if ((widget.task['days'] as List?)?.isNotEmpty ?? false)
                          Text(
                            'Repeats on: ${(widget.task['days'] as List).join(", ")}',
                            style: TextStyle(
                              color: widget.isCompleted
                                  ? Colors.grey[700]
                                  : Colors.white60,
                              fontSize: 12,
                              shadows: const [],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isJiggling)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
