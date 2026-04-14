import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../widgets/vertical_sticky_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class EventsPage extends StatefulWidget {
  final VoidCallback? onViewModeChanged;
  
  const EventsPage({super.key, this.onViewModeChanged});

  @override
  EventsPageState createState() => EventsPageState();
}

class EventsPageState extends State<EventsPage> {

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditTaskSheet(
        task: task,
        onTaskUpdated: (updatedTask) async {
          setState(() {
            _tasks[idx] = updatedTask;
          });
          
          // Sync to Supabase
          final taskId = updatedTask['id'];
          if (taskId != null) {
            try {
              await Supabase.instance.client
                  .from('user_tasks')
                  .update({
                    'name': updatedTask['name'],
                    'days': updatedTask['days'],
                    'end_date': updatedTask['end_date'],
                  })
                  .eq('id', taskId);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update task in Supabase.'),
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  void _showEditEventDialog(Map event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditEventSheet(
        event: Map<String, dynamic>.from(event),
        formatTime: formatTime,
        onEventUpdated: (updatedEvent) async {
          final idx = _events.indexWhere((e) => e['id'] == updatedEvent['id']);
          if (idx != -1) setState(() => _events[idx] = updatedEvent);
          
          // Sync to Supabase
          final eventId = updatedEvent['id'];
          if (eventId != null) {
            try {
              await Supabase.instance.client
                  .from('user_events')
                  .update({
                    'title': updatedEvent['title'],
                    'description': updatedEvent['description'],
                    'date': updatedEvent['date'],
                    'start_time': updatedEvent['start_time'],
                    'end_time': updatedEvent['end_time'],
                    'all_day': updatedEvent['all_day'],
                  })
                  .eq('id', eventId);
              if (mounted) {
                setState(() {});
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update event in Supabase.'),
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  List<Map<String, dynamic>> _tasks = [];

  // Show a bottom-aligned date picker that fills the bottom of the screen
  Future<DateTime?> _showBottomDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Calendar
              Expanded(
                child: _CustomCalendar(
                  selectedDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (date) {
                    Navigator.pop(context, date);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    
    return result;
  }

  Future<void> _fetchEventsFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final response = await Supabase.instance.client
        .from('user_events')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: true);
    setState(() {
      _events = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _fetchTasksFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('user_tasks')
          .select()
          .eq('user_id', userId);      final loaded = (response as List).map((taskData) => {
        'id': taskData['id'],
        'name': taskData['name'],
        'days': List<String>.from(taskData['days'] ?? []),
        'end_date': taskData['end_date'],
        'completedDates': List<String>.from(taskData['completed_dates'] ?? []),
        'user_id': taskData['user_id'],
      }).toList();
      if (mounted) setState(() => _tasks = List<Map<String, dynamic>>.from(loaded));
    } catch (e) {
      print('Error fetching tasks from Supabase: $e');
    }
  }  void _markTaskAsCompleted(int idx) async {
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
      
      setState(() {});
      
      // Sync to Supabase
      final taskId = _tasks[idx]['id'];
      if (taskId != null) {
        try {
          await Supabase.instance.client
              .from('user_tasks')
              .update({'completed_dates': completedDates})
              .eq('id', taskId);
        } catch (e) {
          print('Error updating task completion in Supabase: $e');
        }
      }
    }
  }

  // For non-repeating events: check if the event's own date+endTime has passed.
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
      int hour = int.parse(endParts[0].trim());
      int minute = int.parse(endParts[1].trim().split(' ')[0]);
      final now = DateTime.now();
      final eventEnd = DateTime.parse(date);
      DateTime eventEndDateTime = DateTime(
        eventEnd.year, eventEnd.month, eventEnd.day, hour, minute,
      );
      if (endTime.toUpperCase().contains('PM') && hour < 12) {
        eventEndDateTime = eventEndDateTime.add(const Duration(hours: 12));
      }
      if (endTime.toUpperCase().contains('AM') && hour == 12) {
        eventEndDateTime = DateTime(eventEnd.year, eventEnd.month, eventEnd.day, 0, minute);
      }
      return eventEndDateTime.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  // For repeating events: check if today's end_time has passed (not the original date).
  bool _isRepeatingEventCompletedToday(Map event) {
    final endTime = event['end_time'] ?? '';
    if (endTime.isEmpty) return false;
    try {
      final endParts = endTime.split(":");
      int hour = int.parse(endParts[0].trim());
      int minute = int.parse(endParts[1].trim().split(' ')[0]);
      final now = DateTime.now();
      DateTime eventEndDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (endTime.toUpperCase().contains('PM') && hour < 12) {
        eventEndDateTime = eventEndDateTime.add(const Duration(hours: 12));
      }
      if (endTime.toUpperCase().contains('AM') && hour == 12) {
        eventEndDateTime = DateTime(now.year, now.month, now.day, 0, minute);
      }
      return eventEndDateTime.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _events = [];
  DateTime _selectedDay = DateTime.now();
  final _calendarKey = GlobalKey<VerticalStickyCalendarState>();
  Timer? _completionTimer;

  List<Map> _eventsForDay(DateTime day) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    const fullWeekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final dayStr = day.toIso8601String().substring(0, 10);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _events.where((ev) {
      if (ev['user_id'] != userId) return false;
      final List<String> days = List<String>.from(ev['days'] ?? []);
      final isRepeating = days.isNotEmpty;
      if (isRepeating) {
        // Hide if end_time has passed today (time-based, no in-memory state needed)
        if (dayStr == todayStr && _isRepeatingEventCompletedToday(ev)) return false;
        final eventDate = DateTime.tryParse(ev['date'] ?? '');
        if (eventDate == null) return false;
        final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final dayOnly = DateTime(day.year, day.month, day.day);
        if (dayOnly.isBefore(eventDateOnly)) return false;
        return days.contains(fullWeekdays[day.weekday % 7]);
      } else {
        if (_isEventCompleted(ev)) return false;
        return ev['date']?.substring(0, 10) == dayStr;
      }
    }).cast<Map>().toList();
  }

  List<Map> _completedEventsForDay(DateTime day) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    const fullWeekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final dayStr = day.toIso8601String().substring(0, 10);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _events.where((ev) {
      if (ev['user_id'] != userId) return false;
      final List<String> days = List<String>.from(ev['days'] ?? []);
      final isRepeating = days.isNotEmpty;
      if (isRepeating) {
        // Completed if end_time has passed today (time-based, no in-memory state needed)
        if (dayStr != todayStr) return false;
        if (!_isRepeatingEventCompletedToday(ev)) return false;
        final eventDate = DateTime.tryParse(ev['date'] ?? '');
        if (eventDate == null) return false;
        final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final dayOnly = DateTime(day.year, day.month, day.day);
        if (dayOnly.isBefore(eventDateOnly)) return false;
        return days.contains(fullWeekdays[day.weekday % 7]);
      } else {
        if (!_isEventCompleted(ev)) return false;
        return ev['date']?.substring(0, 10) == dayStr;
      }
    }).cast<Map>().toList();
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
      
      // Only show tasks from today onwards
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final isNotBeforeToday = !day.isBefore(todayStart);
      
      // Check end date if it exists
      final endDateStr = task['end_date'];
      final isBeforeEndDate = endDateStr == null || !day.isAfter(DateTime.parse(endDateStr));
      
      // Check if task should appear on this day
      final isRepeatDay = days.isEmpty || days.contains(fullWeekdays[day.weekday % 7]);
      // Don't show completed tasks
      final isNotCompleted = !completedDates.contains(dayStr);
      
      return isRepeatDay && isNotCompleted && isNotBeforeToday && isBeforeEndDate;
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
      
      // Only show tasks from today onwards
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final isNotBeforeToday = !day.isBefore(todayStart);
      
      // Check end date if it exists
      final endDateStr = task['end_date'];
      final isBeforeEndDate = endDateStr == null || !day.isAfter(DateTime.parse(endDateStr));
      
      // Check if task should appear on this day and is completed
      final isRepeatDay = days.isEmpty || days.contains(fullWeekdays[day.weekday % 7]);
      final isCompleted = completedDates.contains(dayStr);
      
      return isRepeatDay && isCompleted && isNotBeforeToday && isBeforeEndDate;
    }).toList();
  }

  void jumpToToday() {
    setState(() {
      _selectedDay = DateTime.now();
    });
    _calendarKey.currentState?.jumpToToday();
  }

  void collapseAll() {
    _calendarKey.currentState?.collapseAll();
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
        initialTab: 0,
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
            'days': event['days'] ?? [],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
          };
          setState(() => _events.add(fullEvent));
          try {            await Supabase.instance.client.from('user_events').insert([
              {
                'id': id,
                'title': event['title'],
                'description': event['description'] ?? '',
                'date': eventDate.toIso8601String(),
                'user_id': userId,
                'start_time': event['start_time'] ?? '00:00',
                'end_time': event['end_time'] ?? '23:59',
                'all_day': event['all_day'] ?? false,
                'days': event['days'] ?? [],
                'latitude': event['latitude'],
                'longitude': event['longitude'],
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
        onTaskAdded: (task) async {
          final id = Uuid().v4();
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final newTask = {
            'id': id,
            'name': task['name'],
            'days': task['days'] ?? [],
            'end_date': task['end_date'], // null means indefinite
            'completedDates': <String>[],
            'user_id': userId,
          };
          setState(() {
            _tasks.add(newTask);
          });
          
          // Sync to Supabase
          try {            await Supabase.instance.client.from('user_tasks').insert([
              {
                'id': id,
                'name': task['name'],
                'days': task['days'] ?? [],
                'end_date': task['end_date'], // null means indefinite
                'completed_dates': [],                'user_id': userId,
              },
            ]);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload task to Supabase.')),
              );
            }
          }
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
    bool changed = false;
    for (int i = 0; i < _events.length; i++) {
      final event = Map<String, dynamic>.from(_events[i]);
      if (event['user_id'] != userId) continue;
      final List<String> days = List<String>.from(event['days'] ?? []);
      final isRepeating = days.isNotEmpty;
      if (isRepeating) {
        // Repeating events: completion is purely time-based, nothing to sync.
      } else {
        // Non-repeating events: mark completed permanently in Supabase.
        if (_isEventCompleted(event) && event['completed'] != true) {
          event['completed'] = true;
          _events[i] = event;
          changed = true;
          Supabase.instance.client
              .from('user_events')
              .update({'completed': true})
              .eq('id', event['id']);
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _fetchEventsFromSupabase();
    _fetchTasksFromSupabase();
    _checkAndMoveCompletedEvents();
    _completionTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkAndMoveCompletedEvents(),
    );
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                  });
                  widget.onViewModeChanged?.call();
                },
                onViewModeChanged: (isWeekView) {
                  widget.onViewModeChanged?.call();
                },
                eventsForDay: _eventsForDay,
                completedEventsForDay: _completedEventsForDay,
                tasksForDay: _tasksForDay,
                completedTasksForDay: _completedTasksForDay,
                showBothSections: true,
                onEventEdit: (event) {
                  _showEditEventDialog(event);
                },
                onEventDelete: (event) async {
                  setState(() {
                    _events.removeWhere((e) => e['id'] == event['id']);
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
                onTaskDelete: (task, index) async {
                  final realIndex = _tasks.indexOf(task);
                  if (realIndex != -1) {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete Task'),
                          content: Text('Are you sure you want to delete "${task['name']}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                    
                    // Only proceed if user confirmed
                    if (confirmed != true) return;
                    
                    final taskId = task['id'];
                    setState(() {
                      _tasks.removeAt(realIndex);
                    });
                    
                    // Delete from Supabase
                    if (taskId != null) {
                      try {
                        await Supabase.instance.client
                            .from('user_tasks')
                            .delete()
                            .eq('id', taskId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task deleted')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Delete error: $e')),
                          );
                        }
                      }
                    }
                  }
                },
                onTaskComplete: (task, index) {
                  final realIndex = _tasks.indexOf(task);
                  if (realIndex != -1) _markTaskAsCompleted(realIndex);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Custom Calendar Widget ──────────────────────────────────────────────────

class _CustomCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  const _CustomCalendar({
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  @override
  State<_CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<_CustomCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  List<DateTime?> _getDaysInMonth() {
    final firstDayOfMonth = _displayedMonth;
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    
    // Get the weekday of the first day (0 = Sunday, 6 = Saturday)
    final firstWeekday = firstDayOfMonth.weekday % 7;
    
    // Create list with null padding for days before the month starts
    List<DateTime?> days = List.filled(firstWeekday, null, growable: true);
    
    // Add all days in the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(_displayedMonth.year, _displayedMonth.month, day));
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    const dayAbbreviations = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    
    return Column(
      children: [
        // Month/Year header with navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousMonth,
              ),
              Text(
                '${_getMonthName(_displayedMonth.month)} ${_displayedMonth.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        // Day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: dayAbbreviations.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Calendar grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 16, // Increased vertical spacing
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                if (date == null) {
                  return const SizedBox.shrink();
                }
                
                final isSelected = date.year == widget.selectedDate.year &&
                    date.month == widget.selectedDate.month &&
                    date.day == widget.selectedDate.day;
                
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                
                final isOutOfRange = date.isBefore(widget.firstDate) || 
                    date.isAfter(widget.lastDate);
                
                return InkWell(
                  onTap: isOutOfRange ? null : () => widget.onDateChanged(date),
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withOpacity(0.2)
                          : isToday
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isOutOfRange
                              ? Colors.grey[700]
                              : isSelected
                                  ? Colors.white
                                  : Colors.white,
                          fontSize: 18,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          shadows: [],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
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
  // Event repeat days
  List<bool> _eventSelectedDays = List.generate(7, (_) => false);
  // Event location
  LatLng? _pickedLocation;
  // Task fields
  final _notesCtl = TextEditingController();
  List<bool> _selectedDays = List.generate(7, (_) => false);
  DateTime? _taskEndDate; // Null means indefinite

  static const List<String> _fullWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _startDate = widget.selectedDay;
    _endDate = widget.selectedDay;
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
                          color: (_titleCtl.text.trim().isEmpty || (_tab == 0 && !_isTimeValid)) ? Colors.grey[700] : const Color(0xFF39FF14),
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

  // Show a bottom-aligned date picker that fills the bottom of the screen
  Future<DateTime?> _showBottomDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Calendar
              Expanded(
                child: _CustomCalendar(
                  selectedDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (date) {
                    Navigator.pop(context, date);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    
    return result;
  }

  // ─── Event form ───────────────────────────────────────────────────────────
  Widget _buildEventForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Title + Description + Location section
          _card(children: [
            _textField(_titleCtl, 'Title'),
            const Divider(height: 1, color: Colors.white12),
            _textField(_locationCtl, 'Description (Optional)'),
            const Divider(height: 1, color: Colors.white12),
            _locationRow(),
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
          const SizedBox(height: 16),
          _card(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                child: Text('Repeat', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            _eventRepeatDaysRow(),
          ]),
        ],
      ),
    );
  }

  Widget _locationRow() {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<LatLng>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _LocationPickerSheet(),
        );
        if (result != null) setState(() => _pickedLocation = result);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF39FF14), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pickedLocation == null
                    ? 'Add Location'
                    : '${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  color: _pickedLocation == null ? Colors.grey[500] : Colors.white,
                  fontSize: 16,
                  shadows: const [],
                ),
              ),
            ),
            if (_pickedLocation != null)
              GestureDetector(
                onTap: () => setState(() => _pickedLocation = null),
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _eventRepeatDaysRow() {
    final dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final sel = _eventSelectedDays[i];
          return GestureDetector(
            onTap: () => setState(() => _eventSelectedDays[i] = !_eventSelectedDays[i]),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF39FF14) : Colors.grey[900],
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF39FF14).withOpacity(sel ? 0.6 : 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(dayLabels[i], style: TextStyle(
                color: sel ? Colors.black : Colors.grey[500], fontWeight: FontWeight.w600, shadows: const [],
              )),
            ),
          );
        }),
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
              final picked = await _showBottomDatePicker(
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
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
          // End Date (optional)
          _card(children: [
            _taskOptionalEndDateRow(),
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
            activeThumbColor: const Color(0xFF39FF14),
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
  Widget _taskOptionalEndDateRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('End Date', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
          const Spacer(),
          if (_taskEndDate != null)
            GestureDetector(
              onTap: () {
                setState(() => _taskEndDate = null);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    shadows: [],
                  ),
                ),
              ),
            ),
          _pillButton(
            _taskEndDate == null ? 'None' : _formatDate(_taskEndDate!),
            () async {
              final picked = await _showBottomDatePicker(
                initialDate: _taskEndDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _taskEndDate = picked);
              }
            },
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
    return List.generate(7, (i) => _selectedDays[i] ? _fullWeekdays[i] : null)
        .whereType<String>()
        .toList();
  }

  bool get _isTimeValid {
    if (_allDay || _tab != 0) return true;
    if (_startDate.isBefore(_endDate)) return true;
    if (_endDate.isBefore(_startDate)) return false;
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    return endMins > startMins;
  }

  void _onAdd() {
    if (_titleCtl.text.trim().isEmpty) return;
    if (_tab == 0 && !_isTimeValid) return;
    if (_tab == 0) {
      widget.onEventAdded({
        'title': _titleCtl.text.trim(),
        'description': _locationCtl.text.trim(),
        'date': _startDate,
        'all_day': _allDay,
        'start_time': _allDay ? '00:00' : _timeToString(_startTime),
        'end_time': _allDay ? '23:59' : _timeToString(_endTime),
        'days': List.generate(7, (i) => _eventSelectedDays[i] ? _fullWeekdays[i] : null).whereType<String>().toList(),
        'latitude': _pickedLocation?.latitude,
        'longitude': _pickedLocation?.longitude,
      });
    } else {
      final days = _resolveRepeatDays();
      widget.onTaskAdded({
        'name': _titleCtl.text.trim(),
        'days': days,
        'end_date': _taskEndDate?.toIso8601String(), // null means indefinite
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

// ─── Edit Task Bottom Sheet ──────────────────────────────────────────────────

class _EditTaskSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function(Map<String, dynamic>) onTaskUpdated;

  const _EditTaskSheet({
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late TextEditingController _titleCtl;
  late List<bool> _selectedDays;
  DateTime? _taskEndDate;

  static const List<String> _fullWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.task['name'] ?? '');
    _selectedDays = List.generate(
      7,
      (i) => (widget.task['days'] as List<String>).contains(_fullWeekdays[i]),
    );
    _taskEndDate = widget.task['end_date'] != null 
        ? DateTime.parse(widget.task['end_date']) 
        : null;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    super.dispose();
  }

  Future<DateTime?> _showBottomDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        DateTime selected = initialDate;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _CustomCalendar(
                      selectedDate: selected,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (date) {
                        setModalState(() => selected = date);
                        Navigator.of(context).pop(selected);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleCtl.text.trim().isNotEmpty;
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
                // ── Header row: Cancel / "Edit Task" / Save ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF39FF14), fontSize: 16, shadows: [])),
                      ),
                      const Spacer(),
                      const Text('Edit Task', style: TextStyle(color: Color(0xFF39FF14), fontSize: 17, fontWeight: FontWeight.w600, shadows: [])),
                      const Spacer(),
                      TextButton(
                        onPressed: canSave
                            ? () {
                                final updatedTask = {
                                  ...widget.task,
                                  'name': _titleCtl.text.trim(),
                                  'days': List.generate(
                                    7,
                                    (i) => _selectedDays[i] ? _fullWeekdays[i] : null,
                                  ).whereType<String>().toList(),
                                  'end_date': _taskEndDate?.toIso8601String(),
                                };
                                widget.onTaskUpdated(updatedTask);
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: canSave ? const Color(0xFF39FF14) : Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: [],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Form body ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _card(children: [
                        _textField(_titleCtl, 'Title'),
                      ]),
                      const SizedBox(height: 16),
                      _card(children: [
                        _taskOptionalEndDateRow(),
                      ]),
                      const SizedBox(height: 16),
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
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _taskOptionalEndDateRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('End Date', style: TextStyle(color: Colors.white, fontSize: 16, shadows: [])),
          const Spacer(),
          if (_taskEndDate != null)
            GestureDetector(
              onTap: () {
                setState(() => _taskEndDate = null);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    shadows: [],
                  ),
                ),
              ),
            ),
          _pillButton(
            _taskEndDate == null ? 'None' : _formatDate(_taskEndDate!),
            () async {
              final picked = await _showBottomDatePicker(
                initialDate: _taskEndDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _taskEndDate = picked);
              }
            },
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

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─── Edit Event Bottom Sheet ─────────────────────────────────────────────────

class _EditEventSheet extends StatefulWidget {
  final Map<String, dynamic> event;
  final Function(Map<String, dynamic>) onEventUpdated;
  final String Function(TimeOfDay?) formatTime;

  const _EditEventSheet({
    required this.event,
    required this.onEventUpdated,
    required this.formatTime,
  });

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late TextEditingController _titleCtl;
  late TextEditingController _locationCtl;
  late bool _allDay;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _expandedTimePicker;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.event['title'] ?? '');
    _locationCtl = TextEditingController(text: widget.event['description'] ?? '');
    _allDay = widget.event['all_day'] ?? false;
    _startDate = widget.event['date'] != null 
        ? DateTime.parse(widget.event['date']) 
        : DateTime.now();
    _endDate = _startDate;
    
    // Parse start time
    if (widget.event['start_time'] != null) {
      final startParts = (widget.event['start_time'] as String).split(':');
      if (startParts.length >= 2) {
        _startTime = TimeOfDay(
          hour: int.tryParse(startParts[0]) ?? 13,
          minute: int.tryParse(startParts[1]) ?? 0,
        );
      } else {
        _startTime = const TimeOfDay(hour: 13, minute: 0);
      }
    } else {
      _startTime = const TimeOfDay(hour: 13, minute: 0);
    }
    
    // Parse end time
    if (widget.event['end_time'] != null) {
      final endParts = (widget.event['end_time'] as String).split(':');
      if (endParts.length >= 2) {
        _endTime = TimeOfDay(
          hour: int.tryParse(endParts[0]) ?? 14,
          minute: int.tryParse(endParts[1]) ?? 0,
        );
      } else {
        _endTime = const TimeOfDay(hour: 14, minute: 0);
      }
    } else {
      _endTime = const TimeOfDay(hour: 14, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<DateTime?> _showBottomDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        DateTime selected = initialDate;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _CustomCalendar(
                      selectedDate: selected,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (date) {
                        setModalState(() => selected = date);
                        Navigator.of(context).pop(selected);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get _isTimeValid {
    if (_allDay) return true;
    if (_startDate.isBefore(_endDate)) return true;
    if (_endDate.isBefore(_startDate)) return false;
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    return endMins > startMins;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleCtl.text.trim().isNotEmpty && _isTimeValid;
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
                // ── Header row: Cancel / "Edit Event" / Save ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF39FF14), fontSize: 16, shadows: [])),
                      ),
                      const Spacer(),
                      const Text('Edit Event', style: TextStyle(color: Color(0xFF39FF14), fontSize: 17, fontWeight: FontWeight.w600, shadows: [])),
                      const Spacer(),
                      TextButton(
                        onPressed: canSave
                            ? () {
                                final updatedEvent = {
                                  ...widget.event,
                                  'title': _titleCtl.text.trim(),
                                  'description': _locationCtl.text.trim(),
                                  'date': _startDate.toIso8601String(),
                                  'all_day': _allDay,
                                  'start_time': _allDay ? '00:00' : _timeToString(_startTime),
                                  'end_time': _allDay ? '23:59' : _timeToString(_endTime),
                                };
                                widget.onEventUpdated(updatedEvent);
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: canSave ? const Color(0xFF39FF14) : Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: [],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Form body ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Title + Description section
                      _card(children: [
                        _textField(_titleCtl, 'Title'),
                        const Divider(height: 1, color: Colors.white12),
                        _textField(_locationCtl, 'Description (Optional)'),
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
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            activeThumbColor: const Color(0xFF39FF14),
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
              final picked = await _showBottomDatePicker(
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
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

  Widget _inlineTimePicker(TimeOfDay current, ValueChanged<TimeOfDay> onChanged) {
    final isPm = current.period == DayPeriod.pm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour picker
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 40,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: current.hourOfPeriod == 0 ? 11 : current.hourOfPeriod - 1,
                  ),
                  onSelectedItemChanged: (i) {
                    int h12 = i + 1;
                    int h24 = h12 % 12;
                    if (isPm) h24 += 12;
                    onChanged(TimeOfDay(hour: h24, minute: current.minute));
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final val = (index % 12) + 1;
                      return Center(
                        child: Text('$val', style: const TextStyle(color: Colors.white, fontSize: 24, shadows: [])),
                      );
                    },
                  ),
                ),
              ),
              const Text(':', style: TextStyle(color: Colors.white, fontSize: 28, shadows: [])),
              // Minute picker
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 40,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(initialItem: current.minute),
                  onSelectedItemChanged: (i) {
                    onChanged(TimeOfDay(hour: current.hour, minute: i));
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final val = index % 60;
                      return Center(
                        child: Text(val.toString().padLeft(2, '0'),
                            style: const TextStyle(color: Colors.white, fontSize: 24, shadows: [])),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // AM/PM toggle
              SizedBox(
                width: 80,
                child: ToggleButtons(
                  direction: Axis.vertical,
                  isSelected: [!isPm, isPm],
                  onPressed: (v) {
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
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _timeToString(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ─── Location Picker Sheet ────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  LatLng? _pinned;
  LatLng _center = const LatLng(32.5252, -92.6382); // default: Ruston, LA
  final MapController _mapController = MapController();
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
      _mapController.move(_center, 14);
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF39FF14), fontSize: 16, shadows: [])),
                ),
                const Spacer(),
                const Text('Pick Location', style: TextStyle(color: Color(0xFF39FF14), fontSize: 17, fontWeight: FontWeight.w600, shadows: [])),
                const Spacer(),
                TextButton(
                  onPressed: _pinned == null ? null : () => Navigator.pop(context, _pinned),
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: _pinned == null ? Colors.grey[700] : const Color(0xFF39FF14),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: const [],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF39FF14)),
          // Map
          Expanded(
            child: _loadingLocation
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF39FF14)))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 14,
                      onTap: (_, latlng) => setState(() => _pinned = latlng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_application_1',
                      ),
                      if (_pinned != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pinned!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Color(0xFF39FF14), size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          if (_pinned != null)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_pinned!.latitude.toStringAsFixed(5)}, ${_pinned!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13, shadows: []),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}


