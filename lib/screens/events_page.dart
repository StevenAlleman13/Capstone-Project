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
  const _TaskDismissibleOverlay({super.key, required this.task, required this.idx, required this.onDelete, required this.onEdit, this.onMarkDone});

  @override
  State<_TaskDismissibleOverlay> createState() => _TaskDismissibleOverlayState();
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(widget.task['name'] ?? '', style: const TextStyle(color: Colors.white)),
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
                    margin: const EdgeInsets.only(top: 6, bottom: 6, right: 24, left: 2),
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
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
                        margin: const EdgeInsets.only(top: 6, bottom: 6, right: 24, left: 2),
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
  const _EventDismissibleOverlay({super.key, required this.event, required this.onDelete, required this.onEdit});

  @override
  State<_EventDismissibleOverlay> createState() => _EventDismissibleOverlayState();
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(widget.event['title'] ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event['description'] != null && widget.event['description'].toString().isNotEmpty
                        ? widget.event['description']
                        : 'No description',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.event['all_day'] == true
                        ? 'All Day'
                        : (widget.event['start_time'] != null && widget.event['end_time'] != null
                            ? '${widget.event['start_time']} - ${widget.event['end_time']}'
                            : 'Time not set'),
                    style: const TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold),
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
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
                        margin: const EdgeInsets.only(top: 6, bottom: 6, right: 24, left: 2),
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
  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String _currentMonthLabel = "";

  static const List<String> _fullWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  void _showEditTaskDialog(int idx) {
    final task = _tasks[idx];
    final TextEditingController taskNameController = TextEditingController(text: task['name'] ?? '');
    List<bool> selectedDays = List.generate(_fullWeekdays.length, (i) => (task['days'] as List<String>).contains(_fullWeekdays[i]));
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
                    const Text('Repeat on:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: List.generate(_fullWeekdays.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedDays[i] ? Colors.green[400] : Colors.grey[800],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedDays[i] = !selectedDays[i];
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_fullWeekdays[i], style: const TextStyle(fontSize: 16)),
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
                      'days': List.generate(_fullWeekdays.length, (i) => selectedDays[i] ? _fullWeekdays[i] : null).whereType<String>().toList(),
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
    if (response is List) {
      for (final ev in response) {
        if (ev['id'] != null) {
          _box.put(ev['id'], ev);
        }
      }
      setState(() {});
    }
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
        final List completedDates = List<String>.from(_tasks[idx]['completedDates'] ?? []);
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
  void _showAddTaskDialog() {
    final TextEditingController taskNameController = TextEditingController();
    List<bool> selectedDays = List.generate(7, (_) => false);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Task'),
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
                    const Text('Repeat on:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: List.generate(_fullWeekdays.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedDays[i] ? Colors.green[400] : Colors.grey[800],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedDays[i] = !selectedDays[i];
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_fullWeekdays[i], style: const TextStyle(fontSize: 16)),
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
                    final newTask = {
                      'name': taskNameController.text,
                      'days': List.generate(_fullWeekdays.length, (i) => selectedDays[i] ? _fullWeekdays[i] : null).whereType<String>().toList(),
                      'completed': false,
                    };
                    setState(() {
                      _tasks.add(newTask);
                    });
                    _tasksBox?.add(newTask);
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
        bool _isEventCompleted(Map event) {
          if (event['all_day'] == true) {
            final eventDate = DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
            final now = DateTime.now();
            if (eventDate.isBefore(DateTime(now.year, now.month, now.day))) {
              return true;
            }
            if (eventDate.year == now.year && eventDate.month == now.month && eventDate.day == now.day) {
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
              if (hour < 12) eventEndDateTime = eventEndDateTime.add(Duration(hours: 12));
            }
            // If endTime is in AM format and hour is 12, set hour to 0
            if (event['end_time'].toString().toUpperCase().contains('AM') && hour == 12) {
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
      void _showTaskPlaceholder() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tasks Placeholder'),
            content: const Text('Task creation coming soon!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    // 0 = Events, 1 = Tasks
    int _selectedTab = 0;
  final Box _box = Hive.box('events');
  final TextEditingController titleCtl = TextEditingController();
  final TextEditingController descController = TextEditingController();
  bool allDay = false;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _selectedWeekday = DateTime.now().weekday % 7;
  bool _showMonthView = false;
  final List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  List<Map> _eventsForDay(DateTime day) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return _box.values
        .where((ev) =>
            ev['date']?.substring(0, 10) == day.toIso8601String().substring(0, 10) &&
            (ev['user_id'] == userId))
        .cast<Map>()
        .toList();
  }

  String formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Future<TimeOfDay?> showCustomTimePicker(BuildContext context, TimeOfDay initial) async {
    int hour = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
    int minute = initial.minute;
    bool isAm = initial.period == DayPeriod.am;
    // Set hourController to scroll to the current hour by default
    int hourIndex = hour - 1; // 0-based index for ListWheelScrollView (1-12)
    FixedExtentScrollController hourController = FixedExtentScrollController(initialItem: hourIndex);
    FixedExtentScrollController minuteController = FixedExtentScrollController(initialItem: minute);
    FixedExtentScrollController ampmController = FixedExtentScrollController(initialItem: isAm ? 0 : 1);
    return await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text('Pick Time'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                child: ListWheelScrollView.useDelegate(
                  controller: hourController,
                  itemExtent: 28,
                  diameterRatio: 0.8,
                  physics: FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (v) => hour = v + 1,
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (ctx, idx) => Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 18))),
                    childCount: 12,
                  ),
                  squeeze: 1.2,
                  perspective: 0.003,
                  useMagnifier: true,
                  magnification: 1.1,
                  scrollBehavior: ScrollConfiguration.of(context),
                ),
              ),
              const Text(':', style: TextStyle(fontSize: 18)),
              SizedBox(
                width: 60,
                child: ListWheelScrollView.useDelegate(
                  controller: minuteController,
                  itemExtent: 28,
                  diameterRatio: 0.8,
                  physics: FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (v) => setState(() { minute = v; }),
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (ctx, idx) => Center(child: Text(idx.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18))),
                    childCount: 60,
                  ),
                  squeeze: 1.2,
                  perspective: 0.003,
                  useMagnifier: true,
                  magnification: 1.1,
                  scrollBehavior: ScrollConfiguration.of(context),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: ListWheelScrollView(
                  controller: ampmController,
                  itemExtent: 28,
                  diameterRatio: 0.8,
                  physics: FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (v) => setState(() { isAm = v == 0; }),
                  squeeze: 1.2,
                  perspective: 0.003,
                  useMagnifier: true,
                  magnification: 1.1,
                  scrollBehavior: ScrollConfiguration.of(context),
                  children: [
                    Center(child: Text('AM', style: const TextStyle(fontSize: 18))),
                    Center(child: Text('PM', style: const TextStyle(fontSize: 18))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            TextButton(
              onPressed: () {
                int h = hour % 12;
                if (!isAm) h += 12;
                Navigator.pop(context, TimeOfDay(hour: h, minute: minute));
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addEvent(DateTime day) async {
    titleCtl.clear();
    descController.clear();
    allDay = false;
    startTime = null;
    endTime = null;
    bool titleError = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[800],
              title: const Text('Add Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtl,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        errorText: titleError ? 'Title is required.' : null,
                        labelStyle: TextStyle(
                          color: titleError ? Colors.redAccent : Colors.white,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: titleError ? Colors.redAccent : Colors.white,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: titleError ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(labelText: 'Description'),
                      maxLines: 1,
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: allDay,
                          onChanged: (val) {
                            setState(() { allDay = val ?? false; });
                          },
                        ),
                        Text('All Day'),
                      ],
                    ),
                    if (!allDay) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Start Time:'),
                          ElevatedButton(
                            onPressed: () async {
                              final picked = await showCustomTimePicker(context, startTime ?? TimeOfDay.now());
                              if (picked != null) setState(() { startTime = picked; });
                            },
                            child: Text(formatTime(startTime)),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('End Time:'),
                          ElevatedButton(
                            onPressed: () async {
                              final picked = await showCustomTimePicker(context, endTime ?? TimeOfDay.now());
                              if (picked != null) {
                                if (startTime != null) {
                                  final startMinutes = startTime!.hour * 60 + startTime!.minute;
                                  final endMinutes = picked.hour * 60 + picked.minute;
                                  if (endMinutes <= startMinutes) {
                                    // Set end time to one minute after start time
                                    int newHour = startTime!.hour;
                                    int newMinute = startTime!.minute + 1;
                                    if (newMinute >= 60) {
                                      newMinute = 0;
                                      newHour = (newHour + 1) % 24;
                                    }
                                    setState(() {
                                      endTime = TimeOfDay(hour: newHour, minute: newMinute);
                                    });
                                  } else {
                                    setState(() { endTime = picked; });
                                  }
                                } else {
                                  setState(() { endTime = picked; });
                                }
                              }
                            },
                            child: Text(formatTime(endTime)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleCtl.text.trim().isEmpty) {
                      setState(() {
                        titleError = true;
                      });
                      return;
                    }
                    final id = Uuid().v4();
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    final event = {
                      'id': id,
                      'title': titleCtl.text,
                      'description': descController.text,
                      'date': day.toIso8601String(),
                      'user_id': userId,
                      'start_time': allDay ? '00:00' : startTime?.format(context) ?? '00:00',
                      'end_time': allDay ? '23:59' : endTime?.format(context) ?? '23:59',
                      'all_day': allDay,
                    };
                    _box.put(id, event);
                    // Upload to Supabase
                    try {
                      final response = await Supabase.instance.client
                        .from('user_events')
                        .insert([
                          {
                            'id': id,
                            'title': titleCtl.text,
                            'description': descController.text,
                            'date': day.toIso8601String(),
                            'user_id': userId,
                            'start_time': allDay ? '00:00' : startTime?.format(context) ?? '00:00',
                            'end_time': allDay ? '23:59' : endTime?.format(context) ?? '23:59',
                            'all_day': allDay,
                          }
                        ]);
                      print('Supabase upload response: $response');
                    } catch (e) {
                      print('Supabase upload error: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to upload event to Supabase.')),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    setState(() {});
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
                firstDay: DateTime(DateTime.now().year, 1, 1),
                lastDay: DateTime(DateTime.now().year, 12, 31),
                selectedDay: _selectedDay.year == DateTime.now().year ? _selectedDay : DateTime.now(),
                onDaySelected: (date) {
                  setState(() {
                    _selectedDay = date;
                    _focusedDay = date;
                    _showMonthView = true; // Switch to week view when a day is pressed
                    _selectedWeekday = date.weekday % 7;
                    _selectedTab = 0; // Always start on Events tab in week view
                  });
                },
                selectedColor: Colors.blue[400],
                todayColor: Colors.green[400],
                textColor: Colors.white,
                weekendColor: Color(0xFF7A7A7A),
              ),
            ),
          if (_showMonthView) ...[
            Container(
              color: Color(0xFF232323),
              child: Column(
                children: [
                  // Back button at the top left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[900],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _showMonthView = false;
                            // Reset selected day highlight when returning to month view
                            _selectedDay = DateTime.now();
                          });
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_weekdays.length, (i) {
                        // ...existing code...
                        final startOfWeek = _selectedDay.subtract(Duration(days: _selectedDay.weekday % 7));
                        final dayDate = startOfWeek.add(Duration(days: i));
                        final isSelected = _selectedDay.day == dayDate.day && _selectedDay.month == dayDate.month && _selectedDay.year == dayDate.year;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              // ...existing code...
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? Colors.black : Colors.grey[800],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(18, 48),
                                maximumSize: const Size(22, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: isSelected
                                      ? const BorderSide(color: Color(0xFF39FF14), width: 2.5)
                                      : BorderSide.none,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                                shadowColor: isSelected ? Color(0xFF39FF14) : null,
                                elevation: isSelected ? 8 : 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedDay = dayDate;
                                  _focusedDay = dayDate;
                                  _selectedWeekday = i;
                                });
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _weekdays[i],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Color(0xFF39FF14) : Colors.white,
                                    ),
                                  ),
                                  Text(
                                    dayDate.day.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected ? Color(0xFF39FF14) : Colors.white70,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), // Match weekday row width
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.black : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                            border: _selectedTab == 0
                                ? Border.all(color: Color(0xFF39FF14), width: 2.5)
                                : null,
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Color(0xFF39FF14).withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Events',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: _selectedTab == 0
                                  ? [
                                      Shadow(
                                        color: Color(0xFF39FF14),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.black : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                            border: _selectedTab == 1
                                ? Border.all(color: Color(0xFF39FF14), width: 2.5)
                                : null,
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Color(0xFF39FF14).withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tasks',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: _selectedTab == 1
                                  ? [
                                      Shadow(
                                        color: Color(0xFF39FF14),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Main content (Events or Tasks) only show in week view
          if (_showMonthView) ...[
            Expanded(
              child: _selectedTab == 0
                ? ValueListenableBuilder(
                    valueListenable: _box.listenable(),
                    builder: (context, Box box, _) {
                      final events = _eventsForDay(_selectedDay);
                      for (final ev in events) {
                        final event = Map<String, dynamic>.from(ev);
                        if (_isEventCompleted(event) && event['completed'] != true) {
                          event['completed'] = true;
                          _box.put(event['id'], event);
                          Supabase.instance.client
                            .from('user_events')
                            .update({'completed': true})
                            .eq('id', event['id']);
                        }
                      }
                      final upcoming = events.where((ev) {
                        final event = Map<String, dynamic>.from(ev);
                        return event['completed'] != true;
                      }).toList();
                      final completed = events.where((ev) {
                        final event = Map<String, dynamic>.from(ev);
                        return event['completed'] == true;
                      }).toList();
                      return ListView(
                        children: [
                          // Upcoming Events section with contrast box
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: Color(0xFF39FF14), // Neon green
                                  width: 2.5,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                                        child: Center(
                                          child: Text('Upcoming Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: 3,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF39FF14), // Neon green
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (upcoming.isNotEmpty) ...[
                                      ...upcoming.map((ev) => _EventDismissibleOverlay(
                                        event: Map<String, dynamic>.from(ev),
                                        onEdit: () {
                                          // TODO: Implement edit event dialog
                                        },
                                        onDelete: () async {
                                          setState(() {
                                            _box.delete(ev['id']);
                                        });
                                        try {
                                          print('Attempting to delete event with id: \\${ev['id']}');
                                          final response = await Supabase.instance.client
                                            .from('user_events')
                                            .delete()
                                            .eq('id', ev['id']);
                                          print('Supabase delete response: \\${response}');
                                          final check = await Supabase.instance.client
                                            .from('user_events')
                                            .select()
                                            .eq('id', ev['id']);
                                          print('Event after delete: \\${check}');
                                          if (response is Map && response['error'] != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to delete event from Supabase.')),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Event deleted from Supabase.')),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Supabase delete error: \\${e}')),
                                          );
                                        }
                                      },
                                      )),
                                    ]
                                    else ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                                        child: Center(
                                          child: Text('No Upcoming Events', style: TextStyle(color: Colors.white54)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (completed.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Color(0xFF39FF14), // Neon green
                                    width: 2.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 8, bottom: 6),
                                          child: Center(
                                            child: Text('Completed Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 3,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF39FF14), // Neon green
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...completed.map((ev) => _EventDismissibleOverlay(
                                        event: Map<String, dynamic>.from(ev),
                                        onEdit: () {
                                          // TODO: Implement edit event dialog
                                        },
                                        onDelete: () {
                                          setState(() {
                                            _box.delete(ev['id']);
                                          });
                                          Supabase.instance.client
                                            .from('user_events')
                                            .delete()
                                            .eq('id', ev['id']);
                                        },
                                      )),
                                      if (completed.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                                          child: Center(
                                            child: Text('No completed tasks.', style: TextStyle(color: Colors.white54)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                : ListView(
                    children: [
                      // To-Do List Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: Color(0xFF39FF14), // Neon green
                              width: 2.5,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                                    child: Center(
                                      child: Text('To-Do List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 3,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF39FF14), // Neon green
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._tasks.asMap().entries.where((entry) {
                                  final task = entry.value;
                                  final List<String> days = List<String>.from(task['days'] ?? []);
                                  final List completedDates = List<String>.from(task['completedDates'] ?? []);
                                  final todayStr = _selectedDay.toIso8601String().substring(0, 10);
                                  // Show in To-Do if:
                                  // - Not completed for today
                                  // - AND (either not repeating, or today is a repeat day)
                                  final isRepeatToday = days.isEmpty || days.contains(_fullWeekdays[_selectedDay.weekday % 7]);
                                  return isRepeatToday && !completedDates.contains(todayStr);
                                }).map((entry) {
                                  final idx = entry.key;
                                  final task = entry.value;
                                  return _TaskDismissibleOverlay(
                                    key: ValueKey('task-$idx'),
                                    task: task,
                                    idx: idx,
                                    onDelete: () {
                                      setState(() {
                                        _tasks.removeAt(idx);
                                        if (_tasksBox != null && _tasksBox!.isOpen) {
                                          _tasksBox!.deleteAt(idx);
                                        }
                                      });
                                    },
                                    onEdit: () {
                                      _showEditTaskDialog(idx);
                                    },
                                    onMarkDone: () {
                                      _markTaskAsCompleted(idx);
                                    },
                                  );
                                }),
                                if (_tasks.asMap().entries.where((entry) {
                                  final task = entry.value;
                                  final List<String> days = List<String>.from(task['days'] ?? []);
                                  final List completedDates = List<String>.from(task['completedDates'] ?? []);
                                  final todayStr = _selectedDay.toIso8601String().substring(0, 10);
                                  final isRepeatToday = days.isEmpty || days.contains(_fullWeekdays[_selectedDay.weekday % 7]);
                                  return isRepeatToday && !completedDates.contains(todayStr);
                                }).isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                                    child: Center(
                                      child: Text('No tasks added.', style: TextStyle(color: Colors.white54)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Completed Tasks Section (always show when Tasks tab is active)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: Color(0xFF39FF14), // Neon green
                              width: 2.5,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                                    child: Center(
                                      child: Text('Completed Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 3,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF39FF14), // Neon green
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._tasks.asMap().entries.where((entry) {
                                  final task = entry.value;
                                  final List<String> days = List<String>.from(task['days'] ?? []);
                                  final List completedDates = List<String>.from(task['completedDates'] ?? []);
                                  final todayStr = _selectedDay.toIso8601String().substring(0, 10);
                                  final isRepeatToday = days.isEmpty || days.contains(_fullWeekdays[_selectedDay.weekday % 7]);
                                  return isRepeatToday && completedDates.contains(todayStr);
                                }).map((entry) {
                                  final idx = entry.key;
                                  final task = entry.value;
                                  return _TaskDismissibleOverlay(
                                    key: ValueKey('task-completed-$idx'),
                                    task: task,
                                    idx: idx,
                                    onDelete: () {
                                      setState(() {
                                        _tasks.removeAt(idx);
                                        if (_tasksBox != null && _tasksBox!.isOpen) {
                                          _tasksBox!.deleteAt(idx);
                                        }
                                      });
                                    },
                                    onEdit: () {
                                      // No edit for completed
                                    },
                                  );
                                }),
                                if (_tasks.asMap().entries.where((entry) {
                                  final task = entry.value;
                                  final List<String> days = List<String>.from(task['days'] ?? []);
                                  final List completedDates = List<String>.from(task['completedDates'] ?? []);
                                  final todayStr = _selectedDay.toIso8601String().substring(0, 10);
                                  final isRepeatToday = days.isEmpty || days.contains(_fullWeekdays[_selectedDay.weekday % 7]);
                                  return isRepeatToday && completedDates.contains(todayStr);
                                }).isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                                    child: Center(
                                      child: Text('No completed tasks.', style: TextStyle(color: Colors.white54)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedTab == 0) {
            _addEvent(_selectedDay);
          } else {
            _showAddTaskDialog();
          }
        },
        backgroundColor: Color(0xFF39FF14),
        foregroundColor: Colors.black,
        child: Icon(Icons.add),
      ),
    );
  }
}