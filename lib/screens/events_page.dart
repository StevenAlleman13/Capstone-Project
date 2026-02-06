import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsPage extends StatefulWidget {
  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
              // Temporary in-memory task list for demonstration
              List<Map<String, dynamic>> _tasks = [];
            static const List<String> _fullWeekdays = [
              'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
            ];
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
                            // Save the task with name and selectedDays
                            setState(() {
                              _tasks.add({
                                'name': taskNameController.text,
                                'days': List.generate(_fullWeekdays.length, (i) => selectedDays[i] ? _fullWeekdays[i] : null).whereType<String>().toList(),
                              });
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
        bool _isEventCompleted(Map event) {
          if (event['allDay'] == true) {
            // For all day events, consider completed if the day is before today
            final eventDate = DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
            return eventDate.isBefore(DateTime.now());
          }
          // Parse end time
          final date = event['date'] ?? '';
          final endAt = event['endAt'] ?? '';
          if (date.isEmpty || endAt.isEmpty) return false;
          try {
            final endParts = endAt.split(":");
            int hour = int.parse(endParts[0]);
            int minute = int.parse(endParts[1].split(' ')[0]);
            final ampm = endParts[1].split(' ').length > 1 ? endParts[1].split(' ')[1] : '';
            if (ampm == 'PM' && hour != 12) hour += 12;
            if (ampm == 'AM' && hour == 12) hour = 0;
            final eventEnd = DateTime.parse(date).add(Duration(hours: hour, minutes: minute));
            return eventEnd.isBefore(DateTime.now());
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
            (ev['userId'] == userId))
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
                  onPressed: () {
                    if (titleCtl.text.trim().isEmpty) {
                      setState(() {
                        titleError = true;
                      });
                      return;
                    }
                    final id = Uuid().v4();
                    final event = {
                      'id': id,
                      'title': titleCtl.text,
                      'description': descController.text,
                      'date': day.toIso8601String(),
                      'userId': Supabase.instance.client.auth.currentUser?.id,
                      'allDay': allDay,
                      'startAt': allDay ? null : startTime?.format(context),
                      'endAt': allDay ? null : endTime?.format(context),
                    };
                    _box.put(id, event);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events Calendar')),
      body: Column(
        children: [
          // Week/Month view toggle buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showMonthView ? Colors.black : Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: !_showMonthView
                          ? const BorderSide(color: Color(0xFF39FF14), width: 2.5)
                          : BorderSide.none,
                    ),
                    shadowColor: !_showMonthView ? Color(0xFF39FF14) : null,
                    elevation: !_showMonthView ? 8 : 2,
                  ),
                  onPressed: () {
                    setState(() {
                      _showMonthView = false;
                    });
                  },
                  child: Text(
                    'Week',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: !_showMonthView
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
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showMonthView ? Colors.black : Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: _showMonthView
                          ? const BorderSide(color: Color(0xFF39FF14), width: 2.5)
                          : BorderSide.none,
                    ),
                    shadowColor: _showMonthView ? Color(0xFF39FF14) : null,
                    elevation: _showMonthView ? 8 : 2,
                  ),
                  onPressed: () {
                    setState(() {
                      _showMonthView = true;
                    });
                  },
                  child: Text(
                    'Month',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: _showMonthView
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
              ],
            ),
          ),
          // Show TableCalendar only in month view
          if (_showMonthView)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF39FF14), width: 2.5),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF39FF14).withOpacity(0.18),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    onFormatChanged: (_) {}, // Disable swipe format change
                    headerVisible: true,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.green[400],
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue[400],
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: const TextStyle(color: Colors.redAccent),
                      defaultTextStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          // Show weekday and tab buttons only in week view
          if (!_showMonthView) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), // Increased horizontal padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_weekdays.length, (i) {
                  final isSelected = _selectedWeekday == i;
                  // Calculate the date for this weekday in the current week
                  final today = DateTime.now();
                  final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
                  final dayDate = startOfWeek.add(Duration(days: i));
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
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
                            _selectedWeekday = i;
                            final diff = i - _selectedDay.weekday % 7;
                            _selectedDay = _selectedDay.add(Duration(days: diff));
                            _focusedDay = _selectedDay;
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
                                shadows: isSelected
                                    ? [
                                        Shadow(
                                          color: Color(0xFF39FF14),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                            SizedBox(height: 0),
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
          // Main content (Events or Tasks)
          Expanded(
            child: _selectedTab == 0
              ? ValueListenableBuilder(
                  valueListenable: _box.listenable(),
                  builder: (context, Box box, _) {
                    final events = _eventsForDay(_selectedDay);
                    final upcoming = events.where((ev) => !_isEventCompleted(ev)).toList();
                    final completed = events.where((ev) => _isEventCompleted(ev)).toList();
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
                                    ...upcoming.map((ev) => Container(
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
                                              title: Text(ev['title'] ?? '', style: const TextStyle(color: Colors.white)),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ev['description'] != null && ev['description'].toString().isNotEmpty
                                                        ? ev['description']
                                                        : 'No description',
                                                    style: const TextStyle(color: Colors.white60),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    ev['allDay'] == true
                                                        ? 'All Day'
                                                        : (ev['startAt'] != null && ev['endAt'] != null
                                                            ? '${ev['startAt']} - ${ev['endAt']}'
                                                            : 'Time not set'),
                                                    style: const TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.white70),
                                                tooltip: 'Edit',
                                                onPressed: () {
                                                  // TODO: Implement edit event functionality
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                tooltip: 'Delete',
                                                onPressed: () {
                                                  // TODO: Implement delete event functionality
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
                                    ...completed.map((ev) => Container(
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
                                              title: Text(ev['title'] ?? '', style: const TextStyle(color: Colors.white)),
                                              subtitle: Text(
                                                ev['description'] != null && ev['description'].toString().isNotEmpty
                                                    ? ev['description']
                                                    : 'No description',
                                                style: const TextStyle(color: Colors.white60),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.white70),
                                                tooltip: 'Edit',
                                                onPressed: () {
                                                  // TODO: Implement edit event functionality
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                tooltip: 'Delete',
                                                onPressed: () {
                                                  // TODO: Implement delete event functionality
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )),
                                    if (completed.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                                        child: Center(
                                          child: Text('No Completed Events', style: TextStyle(color: Colors.white54)),
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
                          padding: EdgeInsets.only(bottom: 12), // Remove top padding so black background touches border
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
                              if (_tasks.isNotEmpty) ...[
                                ..._tasks.map((task) => Container(
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
                                          title: Text(task['name'] ?? '', style: const TextStyle(color: Colors.white)),
                                          subtitle: Text(
                                            (task['days'] as List<String>).isNotEmpty
                                              ? 'Repeats on: ${(task['days'] as List<String>).join(", ")}'
                                              : 'No repeat days selected',
                                            style: const TextStyle(color: Colors.white60),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.white70),
                                            tooltip: 'Edit',
                                            onPressed: () {
                                              // TODO: Implement edit task functionality
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            tooltip: 'Delete',
                                            onPressed: () {
                                              setState(() {
                                                _tasks.remove(task);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )),
                              ]
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(
                                    child: Text('No tasks added.', style: TextStyle(color: Colors.white54)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
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
