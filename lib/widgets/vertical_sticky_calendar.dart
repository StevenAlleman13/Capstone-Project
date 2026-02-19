import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VerticalStickyCalendar extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDaySelected;
  final Color? selectedColor;
  final Color? todayColor;
  final Color? textColor;
  final Color? weekendColor;
  final List<Map> Function(DateTime)? eventsForDay;
  final List<Map<String, dynamic>> Function(DateTime)? tasksForDay;
  final List<Map<String, dynamic>> Function(DateTime)? completedTasksForDay;
  final bool isShowingEvents;
  final bool showEventsBelow;
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
    this.selectedColor,
    this.todayColor,
    this.textColor,
    this.weekendColor,
    this.eventsForDay,
    this.tasksForDay,
    this.completedTasksForDay,
    this.isShowingEvents = true,
    this.showEventsBelow = false,
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

class VerticalStickyCalendarState extends State<VerticalStickyCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final ScrollController _scrollController = ScrollController();
  late final ValueNotifier<String> _currentMonth;
  bool _showWeekView = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Store a GlobalKey for each month section
  List<GlobalKey> _monthKeys = [];

  /// Public method to jump the calendar to today's date in week view
  void jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = now;
      _showWeekView = true;
    });
    _animationController.forward();
    _updateMonthLabel();
    widget.onDaySelected?.call(now);
    widget.onViewModeChanged?.call(true);
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay ?? DateTime.now();
    _selectedDay = widget.selectedDay ?? DateTime.now();
    _currentMonth = ValueNotifier(DateFormat('MMMM yyyy').format(_focusedDay));
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0, // Start fully visible so week view shows on load
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMonthLabel());
    _scrollController.addListener(_onScroll);
    // Initialize month keys after months are generated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _monthKeys = List.generate(
          _generateMonths().length,
          (_) => GlobalKey(),
        );
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentMonth.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Find the month that is most prominent at the top of the viewport
    if (_monthKeys.isEmpty) return;
    final RenderBox? listBox = context.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    final viewportHeight = listBox.size.height;
    // Use top third of viewport as the detection zone
    final threshold = viewportHeight * 0.33;
    int bestIndex = 0;
    for (int i = 0; i < _monthKeys.length; i++) {
      final key = _monthKeys[i];
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero, ancestor: listBox);
          final bottom = pos.dy + box.size.height;
          // Pick this month if its content is still visible in the top portion
          if (bottom > 0 && pos.dy < threshold) {
            bestIndex = i;
          }
        }
      }
    }
    final months = _generateMonths();
    if (bestIndex < months.length) {
      final label = DateFormat('MMMM yyyy').format(months[bestIndex]);
      if (_currentMonth.value != label) {
        _currentMonth.value = label;
      }
    }
  }

  void _updateMonthLabel() {
    _currentMonth.value = DateFormat('MMMM yyyy').format(_focusedDay);
  }

  List<DateTime> _generateMonths() {
    final months = <DateTime>[];
    DateTime current = DateTime(widget.firstDay.year, widget.firstDay.month);
    while (!current.isAfter(widget.lastDay)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1);
    }
    return months;
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final days = <DateTime>[];
    for (
      int i = 0;
      i < DateUtils.getDaysInMonth(month.year, month.month);
      i++
    ) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final months = _generateMonths();
    _monthKeys = _monthKeys.length == months.length
        ? _monthKeys
        : List.generate(months.length, (_) => GlobalKey());
    // Days of week labels, starting on Sunday
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Column(
      children: [
        // Animated header that transitions between month and week view
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          color: const Color(0xFF232323),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row with back button and year/month name
              if (_showWeekView)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 24,
                    bottom: 0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _animationController.reverse().then((_) {
                            setState(() {
                              _showWeekView = false;
                            });
                            widget.onViewModeChanged?.call(false);
                          });
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 4),
                            ValueListenableBuilder<String>(
                              valueListenable: _currentMonth,
                              builder: (context, value, _) {
                                final monthName = value.split(' ')[0];
                                return Text(
                                  monthName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    shadows: [],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Large month name in month view
              if (!_showWeekView)
                ValueListenableBuilder<String>(
                  valueListenable: _currentMonth,
                  builder: (context, value, _) {
                    final monthName = value.split(' ')[0];
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 42, bottom: 0),
                      child: Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [],
                        ),
                      ),
                    );
                  },
                ),
              // Days of week labels in month view
              if (!_showWeekView)
                Container(
                  height: 28,
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      weekDays.length,
                      (i) => Expanded(
                        child: Center(
                          child: Text(
                            weekDays[i],
                            style: TextStyle(
                              color: (i == 0 || i == 6)
                                  ? const Color(0xFF7A7A7A)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              shadows: [],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Week view buttons appear in week view
              if (_showWeekView) _buildWeekViewContent(),
            ],
          ),
        ),
        // Neon horizontal line below header, expanded to screen borders
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
        Expanded(
          child: Stack(
            children: [
              // Calendar month view - fades and slides down
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                top: _showWeekView ? 100 : 0,
                left: 0,
                right: 0,
                bottom: _showWeekView ? -100 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showWeekView ? 0.0 : 1.0,
                  child: ListView.builder(
                    key: const ValueKey('month-view'),
                    controller: _scrollController,
                    itemCount: months.length,
                    physics: _showWeekView
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemBuilder: (context, index) =>
                        _buildMonthGrid(months, index),
                  ),
                ),
              ),
              // Events list - slides up from bottom
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                top: _showWeekView ? 0 : 500,
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showWeekView ? 1.0 : 0.0,
                  child: _showWeekView
                      ? (widget.isShowingEvents ? _buildEventsList() : _buildTasksList())
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(List<DateTime> months, int index) {
    final month = months[index];
    final days = _daysInMonth(month);
    final firstWeekday = (days.first.weekday % 7);
    final offset = days.first.weekday == DateTime.sunday
        ? 0
        : days.first.weekday;
    return Container(
      key: _monthKeys[index],
      child: Column(
        children: [
          // Month abbreviation above the horizontal line, aligned with the 1st
          Row(
            children: [
              Expanded(flex: firstWeekday, child: const SizedBox.shrink()),
              Expanded(
                flex: 7 - firstWeekday,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 4),
                  child: Text(
                    DateFormat('MMM').format(month).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      shadows: [],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Thin horizontal line above each new month, starting at the weekday of the 1st
          Row(
            children: [
              Expanded(flex: firstWeekday, child: const SizedBox.shrink()),
              Expanded(
                flex: 7 - firstWeekday,
                child: Container(height: 1, color: Colors.white24),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 40,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: days.length + ((days.first.weekday % 7)),
              itemBuilder: (context, i) {
                if (i < (days.first.weekday % 7)) {
                  return const SizedBox.shrink();
                }
                final day = days[i - (days.first.weekday % 7)];
                final isSelected = DateUtils.isSameDay(day, _selectedDay);
                final isToday = DateUtils.isSameDay(day, DateTime.now());
                final isWeekend =
                    day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                      _focusedDay = day;
                      _showWeekView = true;
                    });
                    _animationController.forward();
                    widget.onDaySelected?.call(day);
                    widget.onViewModeChanged?.call(true);
                    _updateMonthLabel();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (widget.selectedColor ?? Colors.blue[400])
                          : isToday
                          ? (widget.todayColor ?? Colors.green[400])
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 20,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? Colors.white
                              : isWeekend
                              ? (widget.weekendColor ?? Color(0xFFB0B0B0))
                              : (widget.textColor ?? Colors.white),
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          shadows: [],
                        ),
                      ),
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

  Widget _buildWeekViewContent() {
    final weekDaysShort = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final startOfWeek = _selectedDay.subtract(
      Duration(days: _selectedDay.weekday % 7),
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top spacing to align horizontal line with month view
          const SizedBox(height: 2),
          // Day names row
          SizedBox(
            height: 18,
            child: Row(
              children: List.generate(7, (i) {
                return Expanded(
                  child: Center(
                    child: Text(
                      weekDaysShort[i],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (i == 0 || i == 6)
                            ? const Color(0xFF7A7A7A)
                            : Colors.white70,
                        shadows: [],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 0),
          // Week day buttons row
          SizedBox(
            height: 48,
            child: Row(
              children: List.generate(7, (i) {
                final dayDate = startOfWeek.add(Duration(days: i));
                final isSelected = DateUtils.isSameDay(dayDate, _selectedDay);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = dayDate;
                        _focusedDay = dayDate;
                      });
                      widget.onDaySelected?.call(dayDate);
                      widget.onViewModeChanged?.call(true);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          dayDate.day.toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.black : Colors.white,
                            shadows: [],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Horizontal divider at same height as month view
          const Divider(height: 1, thickness: 1, color: Color(0xFF39FF14)),
          // Date label
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
        ],
      ),
    );
  }

  Widget _buildWeekButtonsInline() {
    return _buildWeekViewContent();
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
            child: events.isEmpty
                ? const Center(
                    child: Text(
                      'No events',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
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
                        ...allDayEvents.map((event) => _EventDismissibleOverlay(
                          event: Map<String, dynamic>.from(event),
                          onEdit: () {
                            widget.onEventEdit?.call(event);
                          },
                          onDelete: () {
                            widget.onEventDelete?.call(event);
                          },
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
                        ...timedEvents.map((event) => _EventDismissibleOverlay(
                          event: Map<String, dynamic>.from(event),
                          onEdit: () {
                            widget.onEventEdit?.call(event);
                          },
                          onDelete: () {
                            widget.onEventDelete?.call(event);
                          },
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
            style: TextStyle(color: Colors.white54),
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
                      style: TextStyle(color: Colors.white54, fontSize: 16),
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
                            onEdit: () {
                              widget.onTaskEdit?.call(task, index);
                            },
                            onDelete: () async {
                              await widget.onTaskDelete?.call(task, index);
                            },
                            onComplete: () {
                              widget.onTaskComplete?.call(task, index);
                            },
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
                            onEdit: () {
                              // No edit for completed tasks
                            },
                            onDelete: () async {
                              await widget.onTaskDelete?.call(task, index);
                            },
                            onComplete: () {
                              // Already completed
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
  const _EventDismissibleOverlay({
    required this.event,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_EventDismissibleOverlay> createState() =>
      _EventDismissibleOverlayState();
}

class _EventDismissibleOverlayState extends State<_EventDismissibleOverlay> {
  double _swipeAmount = 0.0;
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _swipeAmount += details.delta.dx;
          if (_swipeAmount < -60) {
            _showActions = true;
          } else if (_swipeAmount > -20) {
            _showActions = false;
          }
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          if (_swipeAmount < -60) {
            _showActions = true;
            _swipeAmount = -60;
          } else {
            _showActions = false;
            _swipeAmount = 0.0;
          }
        });
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Main event card
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF39FF14),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.event['all_day'] != true && widget.event['start_time'] != null)
                  Container(
                    width: 70,
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      widget.event['start_time'],
                      style: const TextStyle(
                        color: Color(0xFF39FF14),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [],
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event['title'] ?? 'Unnamed Event',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [],
                        ),
                      ),
                      if (widget.event['all_day'] != true && widget.event['end_time'] != null)
                        Text(
                          'Until ${widget.event['end_time']}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            shadows: [],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Overlay buttons (appear on swipe)
          if (_showActions)
            Positioned(
              right: 0,
              top: 0,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: const Color(0xFF39FF14),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF39FF14).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: const Color(0xFF39FF14),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF39FF14).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
  
  const _TaskDismissibleOverlay({
    required this.task,
    required this.index,
    required this.isCompleted,
    required this.onDelete,
    required this.onEdit,
    required this.onComplete,
  });

  @override
  State<_TaskDismissibleOverlay> createState() =>
      _TaskDismissibleOverlayState();
}

class _TaskDismissibleOverlayState extends State<_TaskDismissibleOverlay> {
  double _swipeAmount = 0.0;
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _swipeAmount += details.delta.dx;
          if (_swipeAmount < -60) {
            _showActions = true;
          } else if (_swipeAmount > -20) {
            _showActions = false;
          }
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          if (_swipeAmount < -60) {
            _showActions = true;
            _swipeAmount = -60;
          } else {
            _showActions = false;
            _swipeAmount = 0.0;
          }
        });
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Main task card
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isCompleted ? Colors.grey[900] : Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isCompleted 
                    ? const Color(0xFF39FF14).withOpacity(0.5)
                    : const Color(0xFF39FF14),
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
                          color: widget.isCompleted ? Colors.white54 : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: const [],
                          decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if ((widget.task['days'] as List?)?.isNotEmpty ?? false)
                        Text(
                          'Repeats on: ${(widget.task['days'] as List).join(", ")}',
                          style: TextStyle(
                            color: widget.isCompleted ? Colors.white38 : Colors.white60,
                            fontSize: 12,
                            shadows: const [],
                            decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                    ],
                  ),
                ),
                // Complete checkbox - moved to right side
                if (!widget.isCompleted)
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
                // Completed checkmark - filled for completed tasks
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
          // Overlay buttons (appear on swipe)
          if (_showActions && !widget.isCompleted)
            Positioned(
              right: 0,
              top: 0,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: const Color(0xFF39FF14),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF39FF14).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: const Color(0xFF39FF14),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF39FF14).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Once a task is completed, only allows for the delete button to show
          // as the event no longer needs to be edited
          if (_showActions && widget.isCompleted)
            Positioned(
              right: 0,
              top: 0,
              bottom: 8,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF39FF14),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF39FF14).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
