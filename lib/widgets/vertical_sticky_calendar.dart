import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final void Function(bool isWeekView)? onViewModeChanged;

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
    this.onViewModeChanged,
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

  /// Collapse both the events and tasks sections
  void collapseAll() {
    setState(() {
      _workoutsExpanded = false;
      _eventsExpanded = false;
      _tasksExpanded = false;
    });
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
              selectedDayPredicate: (day) => DateUtils.isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.week,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
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
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                decoration: BoxDecoration(color: Color(0xFF232323)),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white, shadows: []),
                weekendTextStyle: const TextStyle(color: Color(0xFF7A7A7A), shadows: []),
                todayDecoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, shadows: []),
                todayTextStyle: const TextStyle(color: Colors.white, shadows: []),
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, shadows: []),
                weekendStyle: TextStyle(color: Color(0xFF7A7A7A), fontWeight: FontWeight.w600, shadows: []),
              ),
            ),
          ),
          // Neon line
          Container(
            width: double.infinity,
            height: 1,
            decoration: BoxDecoration(
              color: const Color(0xFF39FF14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF39FF14).withOpacity(0.4),
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
          const Divider(height: 1, thickness: 1, color: const Color(0xFF39FF14)),
          Expanded(
            child: widget.showBothSections
                ? _buildBothSections()
                : (widget.isShowingEvents ? _buildEventsList() : _buildTasksList()),
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
    const neon = Color(0xFF39FF14);
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
                    onTap: () => setState(() => _workoutsExpanded = !_workoutsExpanded),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(18),
                      bottom: _workoutsExpanded ? Radius.zero : const Radius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center, color: neon, size: 20),
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
                          Icon(
                            _workoutsExpanded ? Icons.remove : Icons.add,
                            color: neon,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_workoutsExpanded)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Center(
                        child: Text(
                          'No workouts',
                          style: TextStyle(color: Colors.white54, fontSize: 16, shadows: []),
                        ),
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
                  InkWell(
                    onTap: () => setState(() => _eventsExpanded = !_eventsExpanded),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(18),
                      bottom: _eventsExpanded ? Radius.zero : const Radius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: neon, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Events',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: [],
                              ),
                            ),
                          ),
                          Icon(
                            _eventsExpanded ? Icons.remove : Icons.add,
                            color: neon,
                            size: 22,
                          ),
                        ],
                      ),
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
                  InkWell(
                    onTap: () => setState(() => _tasksExpanded = !_tasksExpanded),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(18),
                      bottom: _tasksExpanded ? Radius.zero : const Radius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.task_alt, color: neon, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tasks',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: [],
                              ),
                            ),
                          ),
                          Icon(
                            _tasksExpanded ? Icons.remove : Icons.add,
                            color: neon,
                            size: 22,
                          ),
                        ],
                      ),
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
      return const Text('No events function provided',
          style: TextStyle(color: Colors.white54, shadows: []));
    }
    final events = widget.eventsForDay!(_selectedDay);
    final completedEvents = widget.completedEventsForDay?.call(_selectedDay) ?? [];
    if (events.isEmpty && completedEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No events',
              style: TextStyle(color: Colors.white54, fontSize: 16, shadows: [])),
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
            child: Text('ALL DAY',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5, shadows: [])),
          ),
          ...allDayEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                event: Map<String, dynamic>.from(entry.value),
                index: entry.key,
                isCompleted: false,
                isJiggling: _jiggleMode,
                onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                onEdit: () => widget.onEventEdit?.call(entry.value),
                onDelete: () => widget.onEventDelete?.call(entry.value),
              )),
          const SizedBox(height: 8),
        ],
        if (timedEvents.isNotEmpty) ...[
          if (allDayEvents.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text('SCHEDULED',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5, shadows: [])),
            ),
          ...timedEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                event: Map<String, dynamic>.from(entry.value),
                index: allDayEvents.length + entry.key,
                isCompleted: false,
                isJiggling: _jiggleMode,
                onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                onEdit: () => widget.onEventEdit?.call(entry.value),
                onDelete: () => widget.onEventDelete?.call(entry.value),
              )),
        ],
        if (completedEvents.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text('COMPLETED',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5, shadows: [])),
          ),
          ...completedEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                event: Map<String, dynamic>.from(entry.value),
                index: allDayEvents.length + timedEvents.length + entry.key,
                isCompleted: true,
                isJiggling: _jiggleMode,
                onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                onEdit: () {},
                onDelete: () => widget.onEventDelete?.call(entry.value),
              )),
        ],
      ],
    );
  }

  Widget _buildTasksContent() {
    if (widget.tasksForDay == null) {
      return const Text('No tasks function provided',
          style: TextStyle(color: Colors.white54, shadows: []));
    }
    final tasks = widget.tasksForDay!(_selectedDay);
    final completedTasks = widget.completedTasksForDay?.call(_selectedDay) ?? [];
    if (tasks.isEmpty && completedTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No tasks',
              style: TextStyle(color: Colors.white54, fontSize: 16, shadows: [])),
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
            child: Text('TASKS',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5, shadows: [])),
          ),
          ...tasks.asMap().entries.map((entry) => _TaskDismissibleOverlay(
                task: entry.value,
                index: entry.key,
                isCompleted: false,
                isJiggling: _jiggleMode,
                onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                onEdit: () => widget.onTaskEdit?.call(entry.value, entry.key),
                onDelete: () async => await widget.onTaskDelete?.call(entry.value, entry.key),
                onComplete: () => widget.onTaskComplete?.call(entry.value, entry.key),
              )),
          if (completedTasks.isNotEmpty) const SizedBox(height: 8),
        ],
        if (completedTasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text('COMPLETED',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5, shadows: [])),
          ),
          ...completedTasks.asMap().entries.map((entry) => _TaskDismissibleOverlay(
                task: entry.value,
                index: entry.key,
                isCompleted: true,
                isJiggling: _jiggleMode,
                onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                onEdit: () {},
                onDelete: () async => await widget.onTaskDelete?.call(entry.value, entry.key),
                onComplete: () {},
              )),
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
    final completedEvents = widget.completedEventsForDay?.call(_selectedDay) ?? [];

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
                      style: TextStyle(color: Colors.white54, fontSize: 16, shadows: []),
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
                        ...allDayEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                          event: Map<String, dynamic>.from(entry.value),
                          index: entry.key,
                          isCompleted: false,
                          isJiggling: _jiggleMode,
                          onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                          onEdit: () { widget.onEventEdit?.call(entry.value); },
                          onDelete: () { widget.onEventDelete?.call(entry.value); },
                        )),
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
                        ...timedEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                          event: Map<String, dynamic>.from(entry.value),
                          index: allDayEvents.length + entry.key,
                          isCompleted: false,
                          isJiggling: _jiggleMode,
                          onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                          onEdit: () { widget.onEventEdit?.call(entry.value); },
                          onDelete: () { widget.onEventDelete?.call(entry.value); },
                        )),
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
                        ...completedEvents.asMap().entries.map((entry) => _EventDismissibleOverlay(
                          event: Map<String, dynamic>.from(entry.value),
                          index: allDayEvents.length + timedEvents.length + entry.key,
                          isCompleted: true,
                          isJiggling: _jiggleMode,
                          onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                          onEdit: () {},
                          onDelete: () { widget.onEventDelete?.call(entry.value); },
                        )),
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
    final completedTasks = widget.completedTasksForDay?.call(_selectedDay) ?? [];

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
                      style: TextStyle(color: Colors.white54, fontSize: 16, shadows: []),
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
                            onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () { widget.onTaskEdit?.call(task, index); },
                            onDelete: () async { await widget.onTaskDelete?.call(task, index); },
                            onComplete: () { widget.onTaskComplete?.call(task, index); },
                          );
                        }),
                        if (completedTasks.isNotEmpty) const SizedBox(height: 16),
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
                            onLongPress: () => setState(() => _jiggleMode = !_jiggleMode),
                            onEdit: () {},
                            onDelete: () async { await widget.onTaskDelete?.call(task, index); },
                            onComplete: () {},
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
      Future.delayed(Duration(milliseconds: (widget.index * 25).clamp(0, 150)), () {
        if (mounted) _shakeController.repeat(reverse: true);
      });
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
    final hasDescription = widget.event['description'] != null &&
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
                  color: widget.isCompleted ? Colors.grey[700]! : const Color(0xFF39FF14),
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
                          color: widget.isCompleted ? Colors.grey[600] : const Color(0xFF39FF14),
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
                                  color: widget.isCompleted ? Colors.grey[600] : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [],
                                ),
                              ),
                            ),
                            if (hasDescription && !widget.isJiggling && !widget.isCompleted)
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
                              color: widget.isCompleted ? Colors.grey[700] : Colors.white60,
                              fontSize: 12,
                              shadows: const [],
                            ),
                          ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: _expanded && hasDescription && !widget.isJiggling
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
                    child: const Icon(Icons.remove, color: Colors.white, size: 14),
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
  final VoidCallback onLongPress;
  final bool isJiggling;

  const _TaskDismissibleOverlay({
    required this.task,
    required this.index,
    required this.isCompleted,
    required this.onDelete,
    required this.onEdit,
    required this.onComplete,
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
      Future.delayed(Duration(milliseconds: (widget.index * 25).clamp(0, 150)), () {
        if (mounted) _shakeController.repeat(reverse: true);
      });
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
                  color: widget.isCompleted ? Colors.grey[700]! : const Color(0xFF39FF14),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task['name'] ?? 'Unnamed Task',
                          style: TextStyle(
                            color: widget.isCompleted ? Colors.grey[600] : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: const [],
                          ),
                        ),
                        if ((widget.task['days'] as List?)?.isNotEmpty ?? false)
                          Text(
                            'Repeats on: ${(widget.task['days'] as List).join(", ")}',
                            style: TextStyle(
                              color: widget.isCompleted ? Colors.grey[700] : Colors.white60,
                              fontSize: 12,
                              shadows: const [],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.isCompleted && !widget.isJiggling)
                    GestureDetector(
                      onTap: widget.onComplete,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(left: 12, top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF39FF14),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF39FF14),
                          size: 16,
                        ),
                      ),
                    ),
                  if (widget.isCompleted)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(left: 12, top: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF39FF14),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 16,
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
                    child: const Icon(Icons.remove, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
