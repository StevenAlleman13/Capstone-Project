import 'package:flutter/material.dart';
import 'dart:async';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../widgets/vertical_sticky_calendar.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Overlay Dismissible widget for task row
class _TaskDismissibleOverlay extends StatefulWidget {
  final Map<String, dynamic> task;
  final int idx;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onMarkDone;
  const _TaskDismissibleOverlay({
    required this.task,
    required this.idx,
    required this.onDelete,
    required this.onEdit,
    this.onMarkDone,
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Color(0xFF39FF14), // Neon green
                width: 2.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(
                      widget.task['name'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      (widget.task['days'] as List<String>).isNotEmpty
                          ? 'Repeats on: ${(widget.task['days'] as List<String>).join(", ")}'
                          : 'No repeat days selected',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
                if (!_showActions && widget.task['completed'] != true)
                  Container(
                    margin: const EdgeInsets.only(
                      top: 6,
                      bottom: 6,
                      right: 24,
                      left: 2,
                    ),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF39FF14), width: 3.0),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF39FF14).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.check, color: Color(0xFF39FF14)),
                      tooltip: 'Mark as done',
                      onPressed: widget.onMarkDone,
                    ),
                  ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _showActions ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _showActions
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF39FF14),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF39FF14).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'Edit',
                          onPressed: widget.onEdit,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(
                          top: 6,
                          bottom: 6,
                          right: 24,
                          left: 2,
                        ),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF39FF14),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF39FF14).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: widget.onDelete,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Color(0xFF39FF14), // Neon green
                width: 2.0,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                widget.event['title'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event['description'] != null &&
                            widget.event['description'].toString().isNotEmpty
                        ? widget.event['description']
                        : 'No description',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.event['all_day'] == true
                        ? 'All Day'
                        : (widget.event['start_time'] != null &&
                                  widget.event['end_time'] != null
                              ? '${widget.event['start_time']} - ${widget.event['end_time']}'
                              : 'Time not set'),
                    style: const TextStyle(
                      color: Color(0xFF39FF14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _showActions ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _showActions
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF39FF14),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF39FF14).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'Edit',
                          onPressed: widget.onEdit,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(
                          top: 6,
                          bottom: 6,
                          right: 24,
                          left: 2,
                        ),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF39FF14),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF39FF14).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: widget.onDelete,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class EventsPage extends StatefulWidget {
  final VoidCallback? onViewModeChanged;
  
  const EventsPage({super.key, this.onViewModeChanged});

  @override
  EventsPageState createState() => EventsPageState();
}

class EventsPageState extends State<EventsPage> {
  String _currentMonthLabel = "";

  static const List<String> _fullWeekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  void _showEditTaskDialog(int idx) {
    final task = _tasks[idx];
    final TextEditingController taskNameController = TextEditingController(
      text: task['name'] ?? '',
    );
    List<bool> selectedDays = List.generate(
      _fullWeekdays.length,
      (i) => (task['days'] as List<String>).contains(_fullWeekdays[i]),
    );
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: taskNameController,
                      decoration: const InputDecoration(
                        labelText: 'Task Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Repeat on:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: List.generate(_fullWeekdays.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedDays[i]
                                  ? Colors.green[400]
                                  : Colors.grey[800],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedDays[i] = !selectedDays[i];
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _fullWeekdays[i],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (selectedDays[i]) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check, color: Colors.white),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final updatedTask = {
                      ...task,
                      'name': taskNameController.text,
                      'days': List.generate(
                        _fullWeekdays.length,
                        (i) => selectedDays[i] ? _fullWeekdays[i] : null,
                      ).whereType<String>().toList(),
                    };
                    setState(() {
                      _tasks[idx] = updatedTask;
                      if (_tasksBox != null && _tasksBox!.isOpen) {
                        _tasksBox!.putAt(idx, updatedTask);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Persistent task list using Hive
  List<Map<String, dynamic>> _tasks = [];
  Box? _tasksBox;

  // Duplicate initState removed. Only one initState should exist in this class.

  Future<void> _fetchEventsFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final response = await Supabase.instance.client
        .from('user_events')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: true);
    for (final ev in response) {
      if (ev['id'] != null) {
        _box.put(ev['id'], ev);
      }
    }
    setState(() {});
  }

  void _loadTasksFromHive() {
    if (_tasksBox == null) return;
    final loaded = _tasksBox!.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    setState(() {
      _tasks = loaded;
    });
  }

  void _markTaskAsCompleted(int idx) {
    setState(() {
      if (idx >= 0 && idx < _tasks.length) {
        final todayStr = _selectedDay.toIso8601String().substring(0, 10);
        if (_tasks[idx]['completedDates'] == null) {
          _tasks[idx]['completedDates'] = <String>[];
        }
        final List completedDates = List<String>.from(
          _tasks[idx]['completedDates'] ?? [],
        );
        if (!completedDates.contains(todayStr)) {
          completedDates.add(todayStr);
        }
        _tasks[idx]['completedDates'] = completedDates;
        if (_tasksBox != null && _tasksBox!.isOpen) {
          _tasksBox!.putAt(idx, _tasks[idx]);
        }
      }
    });
  }

  bool _isEventCompleted(Map event) {
    if (event['all_day'] == true) {
      final eventDate =
          DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
      final now = DateTime.now();
      if (eventDate.isBefore(DateTime(now.year, now.month, now.day))) {
        return true;
      }
      if (eventDate.year == now.year &&
          eventDate.month == now.month &&
          eventDate.day == now.day) {
        return now.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
      }
      return false;
    }
    final date = event['date'] ?? '';
    final endTime = event['end_time'] ?? '';
    if (date.isEmpty || endTime.isEmpty) return false;
    try {
      final endParts = endTime.split(":");
      int hour = int.parse(endParts[0]);
      int minute = int.parse(endParts[1]);
      final now = DateTime.now();
      // Use the event's date and end time to get the correct DateTime
      final eventEnd = DateTime.parse(date);
      DateTime eventEndDateTime = DateTime(
        eventEnd.year,
        eventEnd.month,
        eventEnd.day,
        hour,
        minute,
      );
      // If endTime is in PM format, adjust hour
      if (event['end_time'].toString().toUpperCase().contains('PM')) {
        if (hour < 12) {
          eventEndDateTime = eventEndDateTime.add(Duration(hours: 12));
        }
      }
      // If endTime is in AM format and hour is 12, set hour to 0
      if (event['end_time'].toString().toUpperCase().contains('AM') &&
          hour == 12) {
        eventEndDateTime = DateTime(
          eventEnd.year,
          eventEnd.month,
          eventEnd.day,
          0,
          minute,
        );
      }
      return eventEndDateTime.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  // 0 = Events, 1 = Tasks
  int _selectedTab = 0;
  final Box _box = Hive.box('events');
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _selectedWeekday = DateTime.now().weekday % 7;
  bool _showMonthView = false;
  bool _isCalendarInWeekView = true; // Tracks VerticalStickyCalendar's internal view state
  final _calendarKey = GlobalKey<VerticalStickyCalendarState>();
  final List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  List<Map> _eventsForDay(DateTime day) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return _box.values
        .where(
          (ev) =>
              ev['date']?.substring(0, 10) ==
                  day.toIso8601String().substring(0, 10) &&
              (ev['user_id'] == userId),
        )
        .cast<Map>()
        .toList();
  }

  List<Map<String, dynamic>> _tasksForDay(DateTime day) {
    final List<String> fullWeekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    
    return _tasks.where((task) {
      final List<String> days = List<String>.from(task['days'] ?? []);
      final List completedDates = List<String>.from(task['completedDates'] ?? []);
      final dayStr = day.toIso8601String().substring(0, 10);
      
      // Check if task should appear on this day
      final isRepeatDay = days.isEmpty || days.contains(fullWeekdays[day.weekday % 7]);
      // Don't show completed tasks
      final isNotCompleted = !completedDates.contains(dayStr);
      
      return isRepeatDay && isNotCompleted;
    }).toList();
  }

  List<Map<String, dynamic>> _completedTasksForDay(DateTime day) {
    final List<String> fullWeekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    
    return _tasks.where((task) {
      final List<String> days = List<String>.from(task['days'] ?? []);
      final List completedDates = List<String>.from(task['completedDates'] ?? []);
      final dayStr = day.toIso8601String().substring(0, 10);
      
      // Check if task should appear on this day and is completed
      final isRepeatDay = days.isEmpty || days.contains(fullWeekdays[day.weekday % 7]);
      final isCompleted = completedDates.contains(dayStr);
      
      return isRepeatDay && isCompleted;
    }).toList();
  }

  // Public methods for button actions
  int get selectedTab => _selectedTab;
  bool get showMonthView => !_isCalendarInWeekView;

  void jumpToToday() {
    setState(() {
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
      _showMonthView = false;
    });
    _calendarKey.currentState?.jumpToToday();
  }

  void toggleTab() {
    setState(() {
      _selectedTab = _selectedTab == 0 ? 1 : 0;
    });
  }

  void addEventOrTask() {
    _showAddSheet();
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEventTaskSheet(
        selectedDay: _selectedDay,
        initialTab: _selectedTab,
        onEventAdded: (event) async {
          final id = Uuid().v4();
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final eventDate = event['date'] as DateTime? ?? _selectedDay;
          final fullEvent = {
            'id': id,
            'title': event['title'],
            'description': event['description'] ?? '',
            'date': eventDate.toIso8601String(),
            'user_id': userId,
            'start_time': event['start_time'] ?? '00:00',
            'end_time': event['end_time'] ?? '23:59',
            'all_day': event['all_day'] ?? false,
          };
          _box.put(id, fullEvent);
          try {
            await Supabase.instance.client.from('user_events').insert([
              {
                'id': id,
                'title': event['title'],
                'description': event['description'] ?? '',
                'date': eventDate.toIso8601String(),
                'user_id': userId,
                'start_time': event['start_time'] ?? '00:00',
                'end_time': event['end_time'] ?? '23:59',
                'all_day': event['all_day'] ?? false,
              },
            ]);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload event to Supabase.')),
              );
            }
          }
          setState(() {});
        },
        onTaskAdded: (task) {
          final newTask = Map<String, dynamic>.from(task);
          newTask['completedDates'] = <String>[];
          setState(() {
            _tasks.add(newTask);
          });
          _tasksBox?.add(newTask);
        },
        formatTime: formatTime,
      ),
    );
  }

  String formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  // Update event completion logic and sync with Supabase
  void _checkAndMoveCompletedEvents() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final events = _box.values
        .where((ev) => ev['user_id'] == userId)
        .cast<Map>()
        .toList();
    for (final ev in events) {
      final event = Map<String, dynamic>.from(ev);
      if (_isEventCompleted(event) && event['completed'] != true) {
        event['completed'] = true;
        _box.put(event['id'], event);
        // Optionally sync with Supabase here
        Supabase.instance.client
            .from('user_events')
            .update({'completed': true})
            .eq('id', event['id']);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Set initial month label
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentMonthLabel = _formatMonthLabel(_focusedDay ?? DateTime.now());
      });
    });
    _currentMonthLabel = _formatMonthLabel(_focusedDay ?? DateTime.now());

    if (Hive.isBoxOpen('tasks')) {
      _tasksBox = Hive.box('tasks');
      _loadTasksFromHive();
    } else {
      Hive.openBox('tasks').then((box) {
        setState(() {
          _tasksBox = box;
          _loadTasksFromHive();
        });
      });
    }

    // Supabase realtime subscription for user_events
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final channel = Supabase.instance.client.channel('public:user_events');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_events',
        callback: (payload) {
          _fetchEventsFromSupabase();
        },
      );
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'user_events',
        callback: (payload) {
          _fetchEventsFromSupabase();
        },
      );
      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'user_events',
        callback: (payload) {
          _fetchEventsFromSupabase();
        },
      );
      channel.subscribe();
    }
    Future.delayed(Duration.zero, () {
      _checkAndMoveCompletedEvents();
    });
  }

  void _onCalendarScroll() {
    // Fallback: just update the label based on the last selected or focused day
    final focusDate = _selectedDay ?? _focusedDay ?? DateTime.now();
    final newLabel = _formatMonthLabel(focusDate);
    if (newLabel != _currentMonthLabel) {
      setState(() {
        _currentMonthLabel = newLabel;
      });
    }
  }

  String _formatMonthLabel(DateTime date) {
    return "${_monthName(date.month)} ${date.year}";
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_showMonthView)
            Flexible(
              fit: FlexFit.loose,
              child: VerticalStickyCalendar(
                key: _calendarKey,
                firstDay: DateTime(DateTime.now().year, 1, 1),
                lastDay: DateTime(DateTime.now().year, 12, 31),
                selectedDay: _selectedDay.year == DateTime.now().year
                    ? _selectedDay
                    : DateTime.now(),
                onDaySelected: (date) {
                  setState(() {
                    _selectedDay = date;
                    _focusedDay = date;
                    // Always start on events when selecting a day
                    _selectedTab = 0;
                  });
                  // Notify main page
                  widget.onViewModeChanged?.call();
                },
                onViewModeChanged: (isWeekView) {
                  setState(() {
                    _isCalendarInWeekView = isWeekView;
                    if (isWeekView) {
                      _selectedTab = 0; // Always start on events when entering week view
                    }
                  });
                  widget.onViewModeChanged?.call();
                },
                selectedColor: Colors.blue[400],
                todayColor: Colors.green[400],
                textColor: Colors.white,
                weekendColor: Color(0xFF7A7A7A),
                showEventsBelow: true,
                eventsForDay: _selectedTab == 0 ? _eventsForDay : null,
                tasksForDay: _selectedTab == 1 ? _tasksForDay : null,
                completedTasksForDay: _selectedTab == 1 ? _completedTasksForDay : null,
                isShowingEvents: _selectedTab == 0,
                onEventEdit: (event) {
                  // TODO: Implement edit event dialog
                },
                onEventDelete: (event) async {
                  setState(() {
                    _box.delete(event['id']);
                  });
                  try {
                    await Supabase.instance.client
                        .from('user_events')
                        .delete()
                        .eq('id', event['id']);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event deleted'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete error: $e'),
                        ),
                      );
                    }
                  }
                },
                onTaskEdit: (task, index) {
                  final realIndex = _tasks.indexOf(task);
                  if (realIndex != -1) _showEditTaskDialog(realIndex);
                },
                onTaskDelete: (task, index) {
                  final realIndex = _tasks.indexOf(task);
                  if (realIndex != -1) {
                    setState(() {
                      _tasks.removeAt(realIndex);
                      if (_tasksBox != null && _tasksBox!.isOpen) {
                        _tasksBox!.deleteAt(realIndex);
                      }
                    });
                  }
                },
                onTaskComplete: (task, index) {
                  final realIndex = _tasks.indexOf(task);
                  if (realIndex != -1) _markTaskAsCompleted(realIndex);
                },
              ),
            ),
          // Month view - show calendar grid when _showMonthView is true
          if (_showMonthView) ...[
            Container(
              color: Color(0xFF232323),
              child: Column(
                children: [
                  // Back button at the top left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 8,
                        bottom: 4,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[900],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _showMonthView = false;
                            // Reset selected day highlight when returning to week view
                            _selectedDay = DateTime.now();
                            // Always start on events when returning to week view
                            _selectedTab = 0;
                          });
                          // Notify main page to update button bar
                          widget.onViewModeChanged?.call();
                          // Force update of month label immediately
                          Future.delayed(Duration.zero, () {
                            if (mounted) {
                              setState(() {});
                            }
                          });
                        },
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_weekdays.length, (i) {
                        // ...existing code...
                        final startOfWeek = _selectedDay.subtract(
                          Duration(days: _selectedDay.weekday % 7),
                        );
                        final dayDate = startOfWeek.add(Duration(days: i));
                        final isSelected =
                            _selectedDay.day == dayDate.day &&
                            _selectedDay.month == dayDate.month &&
                            _selectedDay.year == dayDate.year;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              // ...existing code...
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Colors.black
                                    : Colors.grey[800],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(18, 48),
                                maximumSize: const Size(22, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: isSelected
                                      ? const BorderSide(
                                          color: Color(0xFF39FF14),
                                          width: 2.5,
                                        )
                                      : BorderSide.none,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 0,
                                ),
                                shadowColor: isSelected
                                    ? Color(0xFF39FF14)
                                    : null,
                                elevation: isSelected ? 8 : 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedDay = dayDate;
                                  _focusedDay = dayDate;
                                  _selectedWeekday = i;
                                  // Return to week view and start on events tab
                                  _showMonthView = false;
                                  _selectedTab = 0;
                                });
                                // Notify main page to update button bar
                                widget.onViewModeChanged?.call();
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _weekdays[i],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Color(0xFF39FF14)
                                          : Colors.white,
                                    ),
                                  ),
                                  Text(
                                    dayDate.day.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Color(0xFF39FF14)
                                          : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Divider below weekday buttons
                  const Divider(
                    thickness: 2,
                    height: 0,
                    color: Color(0xFF232323),
                  ),
                ],
              ),
            ),
            // Month view displays the calendar grid only
            // Events and tasks are handled in the week view
            Expanded(
              child: Container(
                color: Colors.grey[800],
                child: Center(
                  child: Text(
                    'Month view - Calendar grid would go here\n(Events & Tasks handled in Week View)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Unified Add Event / Task Bottom Sheet ───────────────────────────────────

class _AddEventTaskSheet extends StatefulWidget {
  final DateTime selectedDay;
  final int initialTab;
  final Function(Map<String, dynamic>) onEventAdded;
  final Function(Map<String, dynamic>) onTaskAdded;
  final String Function(TimeOfDay?) formatTime;

  const _AddEventTaskSheet({
    required this.selectedDay,
    required this.initialTab,
    required this.onEventAdded,
    required this.onTaskAdded,
    required this.formatTime,
  });

  @override
  State<_AddEventTaskSheet> createState() => _AddEventTaskSheetState();
}

class _AddEventTaskSheetState extends State<_AddEventTaskSheet> {
  late int _tab; // 0 = Event, 1 = Task
  final _titleCtl = TextEditingController();
  // Event fields
  final _locationCtl = TextEditingController();
  bool _allDay = false;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  // Which time picker is expanded: null, 'start', or 'end'
  String? _expandedTimePicker;
  // Task fields
  final _notesCtl = TextEditingController();
  DateTime? _taskDate;
  TimeOfDay? _taskTime;
  bool _taskTimeEnabled = false;
  String _repeatOption = 'Never';
  List<bool> _selectedDays = List.generate(7, (_) => false);

  static const List<String> _fullWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _startDate = widget.selectedDay;
    _endDate = widget.selectedDay;
    _taskDate = widget.selectedDay;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _locationCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: const Color(0xFF39FF14).withOpacity(0.3), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header row: Cancel / "New" / Add ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF39FF14), fontSize: 16, shadows: [])),
                      ),
                      const Spacer(),
                      const Text('New', style: TextStyle(color: Color(0xFF39FF14), fontSize: 17, fontWeight: FontWeight.w600, shadows: [])),
                      const Spacer(),
                      TextButton(
                        onPressed: _onAdd,
                        child: Text('Add', style: TextStyle(
                          color: _titleCtl.text.trim().isEmpty ? Colors.grey[700] : const Color(0xFF39FF14),
                          fontSize: 16, fontWeight: FontWeight.w600, shadows: [],
                        )),
                      ),
                    ],
                  ),
                ),

                // ── Event / Task toggle ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        _tabButton('Event', 0),
                        _tabButton('Task', 1),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Form body ──
                _tab == 0 ? _buildEventForm() : _buildTaskForm(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF39FF14).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: selected ? Border.all(color: const Color(0xFF39FF14).withOpacity(0.4)) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF39FF14) : Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: [],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Event form ───────────────────────────────────────────────────────────
  Widget _buildEventForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Title + Location section
          _card(children: [
            _textField(_titleCtl, 'Title'),
            const Divider(height: 1, color: Colors.white12),
            _textField(_locationCtl, 'Location'),
          ]),
          const SizedBox(height: 16),
          // Date / time section
          _card(children: [
            _switchRow('All-day', _allDay, (v) => setState(() {
              _allDay = v;
              _expandedTimePicker = null;
            })),
            const Divider(height: 1, color: Colors.white12),
            _eventDateTimeRow('Starts', _startDate, _allDay ? null : _startTime, 'start', (d) {
              setState(() {
                _startDate = d;
                if (_endDate.isBefore(_startDate)) _endDate = _startDate;
              });
            }),
            if (!_allDay && _expandedTimePicker == 'start')
              _inlineTimePicker(_startTime, (t) => setState(() => _startTime = t)),
            const Divider(height: 1, color: Colors.white12),
            _eventDateTimeRow('Ends', _endDate, _allDay ? null : _endTime, 'end', (d) {
              setState(() => _endDate = d);
            }),
            if (!_allDay && _expandedTimePicker == 'end')
              _inlineTimePicker(_endTime, (t) => setState(() => _endTime = t)),
          ]),
        ],
      ),
    );
  }

  Widget _eventDateTimeRow(
    String label,
    DateTime date,
    TimeOfDay? time,
    String pickerKey,
    ValueChanged<DateTime> onDatePicked,
  ) {
    final isExpanded = _expandedTimePicker == pickerKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
          const Spacer(),
          _pillButton(
            _formatDate(date),
            () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Color(0xFF39FF14), surface: Color(0xFF121212)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onDatePicked(picked);
            },
          ),
          if (time != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedTimePicker = isExpanded ? null : pickerKey;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpanded ? const Color(0xFF39FF14).withOpacity(0.15) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF39FF14).withOpacity(isExpanded ? 0.4 : 0.2)),
                ),
                child: Text(
                  widget.formatTime(time),
                  style: const TextStyle(color: Color(0xFF39FF14), fontSize: 14, shadows: []),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Implements a scroll wheel time picker that expands below the date row when the time is tapped
  Widget _inlineTimePicker(TimeOfDay current, ValueChanged<TimeOfDay> onChanged) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Selection highlight box behind the center row
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF39FF14).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.25), width: 1),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour wheel (1-12)
                SizedBox(
                  width: 56,
                  child: ListWheelScrollView.useDelegate(
                    controller: FixedExtentScrollController(
                      initialItem: (current.hourOfPeriod == 0 ? 12 : current.hourOfPeriod) - 1,
                    ),
                    itemExtent: 36,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (v) {
                      final newHour12 = v + 1;
                      int h24 = newHour12 % 12;
                      if (current.period == DayPeriod.pm) h24 += 12;
                      onChanged(TimeOfDay(hour: h24, minute: current.minute));
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (ctx, idx) => Center(
                        child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 20, shadows: [])),
                      ),
                      childCount: 12,
                    ),
                  ),
                ),
                const Text(':', style: TextStyle(color: Colors.white, fontSize: 20, shadows: [])),
                // Minute wheel (00-59)
                SizedBox(
                  width: 56,
                  child: ListWheelScrollView.useDelegate(
                    controller: FixedExtentScrollController(initialItem: current.minute),
                    itemExtent: 36,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (v) {
                      onChanged(TimeOfDay(hour: current.hour, minute: v));
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (ctx, idx) => Center(
                        child: Text(idx.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 20, shadows: [])),
                      ),
                      childCount: 60,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // AM/PM wheel
                SizedBox(
                  width: 56,
                  child: ListWheelScrollView(
                    controller: FixedExtentScrollController(
                      initialItem: current.period == DayPeriod.am ? 0 : 1,
                    ),
                    itemExtent: 36,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (v) {
                      final isAm = v == 0;
                      int h12 = current.hourOfPeriod == 0 ? 12 : current.hourOfPeriod;
                      int h24 = h12 % 12;
                      if (!isAm) h24 += 12;
                      onChanged(TimeOfDay(hour: h24, minute: current.minute));
                    },
                    children: const [
                      Center(child: Text('AM', style: TextStyle(color: Colors.white, fontSize: 20, shadows: []))),
                      Center(child: Text('PM', style: TextStyle(color: Colors.white, fontSize: 20, shadows: []))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds the tasks that will be listed when the Task tab is selected
  Widget _buildTaskForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Title
          _card(children: [
            _textField(_titleCtl, 'Title'),
          ]),
          const SizedBox(height: 16),
          // 
          _card(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                child: Text('Repeat', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            _customRepeatDays(),
          ]),
        ],
      ),
    );
  }

  // ─── Shared small widgets ─────────────────────────────────────────────────

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.15)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _textField(TextEditingController ctl, String hint) {
    return TextField(
      controller: ctl,
      style: const TextStyle(color: Colors.white, fontSize: 16, shadows: []),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], shadows: []),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF39FF14),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.2)),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF39FF14), fontSize: 14, shadows: [])),
      ),
    );
  }

  // ─── Task-specific rows ───────────────────────────────────────────────────

  Widget _taskDateRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
              Text(
                _taskDate != null ? _formatDate(_taskDate!) : 'None',
                style: TextStyle(color: Colors.green[400], fontSize: 13, shadows: []),
              ),
            ],
          ),
          const Spacer(),
          _pillButton('Change', () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _taskDate ?? widget.selectedDay,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: Colors.green, surface: Color(0xFF2C2C2E)),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _taskDate = picked);
          }),
        ],
      ),
    );
  }

  Widget _taskTimeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.access_time, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
              if (_taskTimeEnabled && _taskTime != null)
                Text(
                  widget.formatTime(_taskTime),
                  style: TextStyle(color: Colors.green[400], fontSize: 13, shadows: []),
                ),
            ],
          ),
          const Spacer(),
          Switch(
            value: _taskTimeEnabled,
            onChanged: (v) {
              setState(() {
                _taskTimeEnabled = v;
                if (v && _taskTime == null) _taskTime = const TimeOfDay(hour: 13, minute: 0);
              });
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _repeatRow() {
    final options = ['Never', 'Daily', 'Weekdays', 'Weekly', 'Custom'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.repeat, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Repeat', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final idx = options.indexOf(_repeatOption);
              setState(() {
                _repeatOption = options[(idx + 1) % options.length];
                if (_repeatOption == 'Daily') {
                  _selectedDays = List.generate(7, (_) => true);
                } else if (_repeatOption == 'Weekdays') {
                  _selectedDays = [false, true, true, true, true, true, false];
                } else if (_repeatOption == 'Weekly') {
                  _selectedDays = List.generate(7, (_) => false);
                  _selectedDays[(_taskDate ?? widget.selectedDay).weekday % 7] = true;
                } else if (_repeatOption == 'Never') {
                  _selectedDays = List.generate(7, (_) => false);
                }
              });
            },
            child: Row(
              children: [
                Text(_repeatOption, style: TextStyle(color: Colors.grey[400], fontSize: 15, shadows: [])),
                Icon(Icons.chevron_right, color: Colors.grey[500], size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customRepeatDays() {
    final dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final sel = _selectedDays[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedDays[i] = !_selectedDays[i]),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF39FF14) : Colors.grey[900],
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF39FF14).withOpacity(sel ? 0.6 : 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(dayLabels[i], style: TextStyle(
                color: sel ? Colors.black : Colors.grey[500], fontWeight: FontWeight.w600, shadows: [],
              )),
            ),
          );
        }),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<String> _resolveRepeatDays() {
    if (_repeatOption == 'Never') return [];
    return List.generate(7, (i) => _selectedDays[i] ? _fullWeekdays[i] : null)
        .whereType<String>()
        .toList();
  }

  void _onAdd() {
    if (_titleCtl.text.trim().isEmpty) return;
    if (_tab == 0) {
      widget.onEventAdded({
        'title': _titleCtl.text.trim(),
        'description': _locationCtl.text.trim(),
        'date': _startDate,
        'all_day': _allDay,
        'start_time': _allDay ? '00:00' : _timeToString(_startTime),
        'end_time': _allDay ? '23:59' : _timeToString(_endTime),
      });
    } else {
      final days = _resolveRepeatDays();
      widget.onTaskAdded({
        'name': _titleCtl.text.trim(),
        'days': days,
        'completed': false,
        'completedDates': <String>[],
      });
    }
    Navigator.pop(context);
  }

  String _timeToString(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

