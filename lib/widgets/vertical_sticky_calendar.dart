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

  const VerticalStickyCalendar({
    Key? key,
    required this.firstDay,
    required this.lastDay,
    this.selectedDay,
    this.onDaySelected,
    this.selectedColor,
    this.todayColor,
    this.textColor,
    this.weekendColor,
  }) : super(key: key);

  @override
  State<VerticalStickyCalendar> createState() => _VerticalStickyCalendarState();
}

class _VerticalStickyCalendarState extends State<VerticalStickyCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final ScrollController _scrollController = ScrollController();
  late final ValueNotifier<String> _currentMonth;

  // Store a GlobalKey for each month section
  List<GlobalKey> _monthKeys = [];

  @override
  void initState() {
    _focusedDay = widget.selectedDay ?? DateTime.now();
    _selectedDay = widget.selectedDay ?? DateTime.now();
    _currentMonth = ValueNotifier(
      DateFormat('MMMM yyyy').format(_focusedDay),
    );
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMonthLabel());
    _scrollController.addListener(_onScroll);
    // Initialize month keys after months are generated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _monthKeys = List.generate(_generateMonths().length, (_) => GlobalKey());
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentMonth.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Find the first month whose top is visible in the viewport
    if (_monthKeys.isEmpty) return;
    final RenderBox? listBox = context.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    double minDy = double.infinity;
    int minIndex = 0;
    for (int i = 0; i < _monthKeys.length; i++) {
      final key = _monthKeys[i];
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero, ancestor: listBox);
          if (pos.dy.abs() < minDy) {
            minDy = pos.dy.abs();
            minIndex = i;
          }
        }
      }
    }
    final months = _generateMonths();
    if (minIndex < months.length) {
      final label = DateFormat('MMMM yyyy').format(months[minIndex]);
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
    for (int i = 0; i < DateUtils.getDaysInMonth(month.year, month.month); i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final months = _generateMonths();
    _monthKeys = _monthKeys.length == months.length ? _monthKeys : List.generate(months.length, (_) => GlobalKey());
    // Days of week labels, starting on Sunday
    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Column(
      children: [
        // Removed top spacing to allow header to touch the top of the screen
        // Header with dark grey background expanded to screen borders, but titles padded down
        Container(
          width: double.infinity,
          color: const Color(0xFF232323), // dark grey
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _currentMonth,
                builder: (context, value, _) => Container(
                  alignment: Alignment.centerLeft,
                  height: 56,
                  padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [],
                    ),
                  ),
                ),
              ),
              Container(
                height: 28,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(weekDays.length, (i) => Expanded(
                    child: Center(
                      child: Text(
                        weekDays[i],
                        style: TextStyle(
                          color: (i == 0 || i == 6) ? const Color(0xFF7A7A7A) : Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [],
                        ),
                      ),
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
        // Neon horizontal line (full width, no vertical padding)
        SizedBox(
          width: double.infinity,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF39FF14),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF39FF14).withOpacity(0.4),
                  blurRadius: 2,
                  spreadRadius: 0.2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final days = _daysInMonth(month);
              final firstWeekday = (days.first.weekday % 7);
              final offset = days.first.weekday == DateTime.sunday ? 0 : days.first.weekday;
              return Container(
                key: _monthKeys[index],
                child: Column(
                  children: [
                    // Thin horizontal line above each new month, starting at the weekday of the 1st
                    Row(
                      children: [
                        Expanded(
                          flex: firstWeekday,
                          child: const SizedBox.shrink(),
                        ),
                        Expanded(
                          flex: 7 - firstWeekday,
                          child: Container(
                            height: 1,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 32,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: days.length + ((days.first.weekday % 7)),
                        itemBuilder: (context, i) {
                          if (i < (days.first.weekday % 7)) {
                            return const SizedBox.shrink();
                          }
                          final day = days[i - (days.first.weekday % 7)];
                          final isSelected = DateUtils.isSameDay(day, _selectedDay);
                          final isToday = DateUtils.isSameDay(day, DateTime.now());
                          final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDay = day;
                                _focusedDay = day;
                              });
                              widget.onDaySelected?.call(day);
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
                                    fontSize: 26,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                            ? Colors.white
                                            : isWeekend
                                                ? (widget.weekendColor ?? Color(0xFFB0B0B0))
                                                : (widget.textColor ?? Colors.white),
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
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
