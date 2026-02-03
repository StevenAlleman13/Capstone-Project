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
  final List<String> _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
                    builder: (ctx, idx) => Center(child: Text('${idx.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18))),
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
                  children: [
                    Center(child: Text('AM', style: const TextStyle(fontSize: 18))),
                    Center(child: Text('PM', style: const TextStyle(fontSize: 18))),
                  ],
                  squeeze: 1.2,
                  perspective: 0.003,
                  useMagnifier: true,
                  magnification: 1.1,
                  scrollBehavior: ScrollConfiguration.of(context),
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
                      decoration: InputDecoration(labelText: 'Title'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_showMonthView ? Color(0xFF39FF14) : Colors.grey[800],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: !_showMonthView ? 6 : 0,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() { _showMonthView = false; });
                },
                child: Row(
                  children: [
                    Icon(Icons.view_week, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showMonthView ? Color(0xFF39FF14) : Colors.grey[800],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: _showMonthView ? 6 : 0,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() { _showMonthView = true; });
                },
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          if (!_showMonthView) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (i) {
                  final today = DateTime.now();
                  final weekStart = today.subtract(Duration(days: today.weekday % 7));
                  final buttonDay = weekStart.add(Duration(days: i));
                  final isSelected = _selectedWeekday == i;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Color(0xFF39FF14) : Colors.grey[800],
                      foregroundColor: isSelected ? Colors.black : Colors.white,
                      minimumSize: Size(40, 48),
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: isSelected ? 6 : 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedWeekday = i;
                        _selectedDay = buttonDay;
                        _focusedDay = _selectedDay;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_weekdays[i], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${buttonDay.day}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              ),
                            ),
                            backgroundColor: Colors.grey[800],
                          ),
                          onPressed: () {},
                          child: Text('Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            backgroundColor: Colors.grey[800],
                          ),
                          onPressed: () {},
                          child: Text('Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _box.listenable(),
                builder: (context, Box box, _) {
                  final events = _eventsForDay(_selectedDay);
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, idx) {
                      final ev = events[idx];
                      return ListTile(
                        title: Text(ev['title'] ?? '', style: const TextStyle()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ev['description'] != null && ev['description'].toString().isNotEmpty)
                              Text(ev['description'], style: const TextStyle(fontSize: 13)),
                            Text(ev['allDay'] == true ? 'All Day' : '${ev['startAt']} - ${ev['endAt']}', style: const TextStyle()),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  '${_focusedDay.month == 1 ? "January" : _focusedDay.month == 2 ? "February" : _focusedDay.month == 3 ? "March" : _focusedDay.month == 4 ? "April" : _focusedDay.month == 5 ? "May" : _focusedDay.month == 6 ? "June" : _focusedDay.month == 7 ? "July" : _focusedDay.month == 8 ? "August" : _focusedDay.month == 9 ? "September" : _focusedDay.month == 10 ? "October" : _focusedDay.month == 11 ? "November" : "December"} ${_focusedDay.year}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            TableCalendar<Map>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              eventLoader: _eventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              headerVisible: false,
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _box.listenable(),
                builder: (context, Box box, _) {
                  final events = _eventsForDay(_selectedDay);
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, idx) {
                      final ev = events[idx];
                      return ListTile(
                        title: Text(ev['title'] ?? '', style: const TextStyle()),
                        subtitle: Text(ev['allDay'] == true ? 'All Day' : '${ev['startAt']} - ${ev['endAt']}', style: const TextStyle()),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEvent(_selectedDay),
        backgroundColor: Color(0xFF39FF14),
        foregroundColor: Colors.black,
        child: Icon(Icons.add),
      ),
    );
  }
}
