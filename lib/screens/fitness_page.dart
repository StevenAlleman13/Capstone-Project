import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 18.0;

class FitnessPage extends StatefulWidget {
  const FitnessPage({super.key});

  @override
  State<FitnessPage> createState() => _FitnessPageState();
}

class _FitnessPageState extends State<FitnessPage> {
  final _weightController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _goalController = TextEditingController();

  double? _graphMin;
  double? _graphMax;
  double? _goalWeight;

  final Map<String, double> _weightsByDay = {};

  bool _loading = true;
  String? _statusText;

  bool _weightExpanded = false;
  bool _macrosExpanded = false;
  bool _trainerExpanded = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadGraphSettingsFromSupabase();
    await _loadWeightsFromSupabase();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadGraphSettingsFromSupabase() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() => _statusText = 'Not signed in (no user session found).');
      return;
    }

    try {
      final row = await _client
          .from('weight_tracker_settings')
          .select('weight_graph_min, weight_graph_max, goal_weight')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return;

      final minRaw = row['weight_graph_min'];
      final maxRaw = row['weight_graph_max'];
      final goalRaw = row['goal_weight'];

      final minVal = (minRaw is num)
          ? minRaw.toDouble()
          : double.tryParse('$minRaw');
      final maxVal = (maxRaw is num)
          ? maxRaw.toDouble()
          : double.tryParse('$maxRaw');
      final goalVal = (goalRaw is num)
          ? goalRaw.toDouble()
          : double.tryParse('$goalRaw');

      if (!mounted) return;
      setState(() {
        _graphMin = minVal;
        _graphMax = maxVal;
        _goalWeight = goalVal;
        if (minVal != null) _minController.text = _format(minVal);
        if (maxVal != null) _maxController.text = _format(maxVal);
        if (goalVal != null) _goalController.text = _format(goalVal);
      });
    } catch (e) {
      if (mounted)
        setState(() => _statusText = 'Could not load graph settings.');
    }
  }

  Future<void> _saveGraphSettingsToSupabase(
    double minVal,
    double maxVal,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() => _statusText = 'Not signed in (cannot save settings).');
      return;
    }

    try {
      await _client.from('weight_tracker_settings').upsert({
        'user_id': user.id,
        'weight_graph_min': minVal,
        'weight_graph_max': maxVal,
        if (_goalWeight != null) 'goal_weight': _goalWeight,
      }, onConflict: 'user_id');
      if (mounted) setState(() => _statusText = null);
    } catch (e) {
      if (mounted)
        setState(() => _statusText = 'Could not save graph settings.');
    }
  }

  Future<void> _saveGoalWeightToSupabase(double goalVal) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('weight_tracker_settings').upsert({
        'user_id': user.id,
        'goal_weight': goalVal,
        if (_graphMin != null) 'weight_graph_min': _graphMin,
        if (_graphMax != null) 'weight_graph_max': _graphMax,
      }, onConflict: 'user_id');
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Could not save goal weight.');
    }
  }

  Future<void> _loadWeightsFromSupabase() async {
    if (mounted) setState(() => _loading = true);

    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _loading = false;
          _statusText ??= 'Not signed in (no user session found).';
        });
      return;
    }

    try {
      final rows = await _client
          .from('weight_entries')
          .select('entry_date, weight')
          .eq('user_id', user.id)
          .order('entry_date', ascending: true);

      _weightsByDay.clear();
      for (final r in rows) {
        final dateRaw = r['entry_date'];
        final date = (dateRaw ?? '').toString().substring(0, 10);
        final w = r['weight'];
        if (date.isEmpty) continue;
        final weightVal = (w is num)
            ? w.toDouble()
            : double.tryParse(w.toString());
        if (weightVal == null) continue;
        _weightsByDay[date] = weightVal;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = _weightsByDay.isEmpty ? 'No weight entries yet.' : null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _statusText = 'Could not load weights from Supabase.';
        });
    }
  }

  Future<void> _saveTodayWeight() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _statusText = 'Not signed in (cannot save).');
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null) return;

    final dateKey = _todayKey();

    try {
      await _client.from('weight_entries').upsert({
        'user_id': user.id,
        'entry_date': dateKey,
        'weight': weight,
      }, onConflict: 'user_id,entry_date');

      if (mounted) {
        setState(() {
          _weightsByDay[dateKey] = weight;
          _weightController.clear();
          _statusText = null;
        });

        if (_goalWeight != null && weight <= _goalWeight!) {
          _showGoalReachedBanner();
        }
      }

      await _loadWeightsFromSupabase();
    } catch (e) {
      if (mounted)
        setState(() => _statusText = 'Could not save weight to Supabase.');
    }
  }

  void _showGoalReachedBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black,
        duration: Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.emoji_events, color: _neonGreen),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Congratulations you reached your goal!',
                style: TextStyle(
                  color: _neonGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyGraphLimits() async {
    final minVal = double.tryParse(_minController.text.trim());
    final maxVal = double.tryParse(_maxController.text.trim());
    if (minVal == null || maxVal == null) return;
    if (maxVal <= minVal) return;

    if (mounted)
      setState(() {
        _graphMin = minVal;
        _graphMax = maxVal;
      });

    await _saveGraphSettingsToSupabase(minVal, maxVal);
  }

  Future<void> _setGoalWeight() async {
    final goal = double.tryParse(_goalController.text.trim());
    if (goal == null) return;

    if (mounted) setState(() => _goalWeight = goal);

    await _saveGoalWeightToSupabase(goal);
  }

  void _showSetGoalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Set Goal Weight', style: TextStyle(color: _neonGreen)),
        content: TextField(
          controller: _goalController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _neonGreen),
          decoration: _inputDecoration('Goal weight'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _setGoalWeight();
            },
            child: Text(
              'Set',
              style: TextStyle(color: _neonGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmClear(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text(
              'Clear Graph Data',
              style: TextStyle(color: _neonGreen),
            ),
            content: Text(
              'This will permanently delete all your saved weight entries.',
              style: TextStyle(color: _neonGreen.withOpacity(0.9)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: _neonGreen)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _clearGraphData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() => _statusText = 'Not signed in (cannot clear).');
      return;
    }

    final ok = await _confirmClear(context);
    if (!ok) return;

    try {
      await _client.from('weight_entries').delete().eq('user_id', user.id);

      if (mounted)
        setState(() {
          _weightsByDay.clear();
          _weightController.clear();
          _statusText = 'No weight entries yet.';
        });
    } catch (e) {
      if (mounted)
        setState(() => _statusText = 'Could not clear weights from Supabase.');
    }
  }

  List<_WeightPoint> _sortedPoints() {
    final keys = _weightsByDay.keys.toList()..sort();
    return keys
        .map((k) => _WeightPoint(dateKey: k, weight: _weightsByDay[k]!))
        .toList();
  }

  double? _autoMin(List<_WeightPoint> pts) {
    if (pts.isEmpty) return null;
    return pts.map((p) => p.weight).reduce(min);
  }

  double? _autoMax(List<_WeightPoint> pts) {
    if (pts.isEmpty) return null;
    return pts.map((p) => p.weight).reduce(max);
  }

  @override
  Widget build(BuildContext context) {
    final points = _sortedPoints();

    final autoMin = _autoMin(points);
    final autoMax = _autoMax(points);

    final minY = _graphMin ?? autoMin;
    final maxY = _graphMax ?? autoMax;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _collapsibleCard(
              title: 'Weight Tracker',
              icon: Icons.show_chart,
              subtitle: _statusText,
              expanded: _weightExpanded,
              onToggle: () =>
                  setState(() => _weightExpanded = !_weightExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: _neonGreen),
                          decoration: _inputDecoration("Today's weight"),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_cornerRadius),
                          ),
                        ),
                        onPressed: _loading ? null : _saveTodayWeight,
                        child: Text('Save'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: _neonGreen),
                          decoration: _inputDecoration('Graph Min'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: _neonGreen),
                          decoration: _inputDecoration('Graph Max'),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_cornerRadius),
                          ),
                        ),
                        onPressed: _loading ? null : _applyGraphLimits,
                        child: Text('Set'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_cornerRadius),
                        border: Border.all(color: _neonGreen, width: 1.5),
                      ),
                      child: _loading
                          ? Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _WeightGraphPainter(
                                points: points,
                                minY: minY,
                                maxY: maxY,
                                goalWeight: _goalWeight,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _showSetGoalDialog,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _neonGreen, width: 1.5),
                            foregroundColor: _neonGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                _cornerRadius,
                              ),
                            ),
                          ),
                          child: Text(
                            _goalWeight != null
                                ? 'Set Goal (${_format(_goalWeight!)})'
                                : 'Set Goal',
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _clearGraphData,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _neonGreen, width: 1.5),
                            foregroundColor: _neonGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                _cornerRadius,
                              ),
                            ),
                          ),
                          child: Text('Clear Graph Data'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _collapsibleCard(
              title: 'Macronutrients',
              icon: Icons.restaurant,
              expanded: _macrosExpanded,
              onToggle: () =>
                  setState(() => _macrosExpanded = !_macrosExpanded),
              child: SizedBox(height: 120),
            ),
            SizedBox(height: 16),
            _collapsibleCard(
              title: 'Trainer',
              icon: Icons.fitness_center,
              expanded: _trainerExpanded,
              onToggle: () =>
                  setState(() => _trainerExpanded = !_trainerExpanded),
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapsibleCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: _neonGreen, width: 2),
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(_cornerRadius),
              bottom: expanded ? Radius.zero : Radius.circular(_cornerRadius),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: _neonGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: _neonGreen),
                        ),
                        if (!expanded && subtitle != null) ...[
                          SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: _neonGreen.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.remove : Icons.add,
                    color: _neonGreen,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                  child,
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _neonGreen),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _neonGreen),
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _neonGreen, width: 2),
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
    );
  }

  String _format(double v) {
    final s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }
}

class _WeightPoint {
  final String dateKey;
  final double weight;

  _WeightPoint({required this.dateKey, required this.weight});
}

class _WeightGraphPainter extends CustomPainter {
  final List<_WeightPoint> points;
  final double? minY;
  final double? maxY;
  final double? goalWeight;

  _WeightGraphPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    this.goalWeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = _neonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const leftPad = 48.0;
    const topPad = 10.0;
    const bottomPad = 36.0;
    const rightPad = 10.0;

    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      max(0, size.width - leftPad - rightPad),
      max(0, size.height - topPad - bottomPad),
    );

    canvas.drawRect(plotRect, borderPaint);

    final minVal = minY;
    final maxVal = maxY;

    if (minVal == null || maxVal == null || maxVal <= minVal) {
      _drawAxisLabels(canvas, plotRect, 0, 1);
      _drawNoData(canvas, plotRect);
      return;
    }

    _drawAxisLabels(canvas, plotRect, minVal, maxVal);
    _drawGridLines(canvas, plotRect);
    _drawXAxisLabels(canvas, plotRect, points);

    if (goalWeight != null && goalWeight! >= minVal && goalWeight! <= maxVal) {
      _drawGoalLine(canvas, plotRect, minVal, maxVal, goalWeight!);
    }

    if (points.isEmpty) {
      _drawNoData(canvas, plotRect);
      return;
    }

    if (points.length == 1) {
      final p = _mapPoint(points.first, plotRect, minVal, maxVal, 0, 1);
      final dotPaint = Paint()..color = _neonGreen;
      canvas.drawCircle(p, 3, dotPaint);
      return;
    }

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = _mapPoint(
        points[i],
        plotRect,
        minVal,
        maxVal,
        i,
        points.length - 1,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final linePaint = Paint()
      ..color = _neonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = _neonGreen;
    for (int i = 0; i < points.length; i++) {
      final p = _mapPoint(
        points[i],
        plotRect,
        minVal,
        maxVal,
        i,
        points.length - 1,
      );
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  void _drawGoalLine(
    Canvas canvas,
    Rect plotRect,
    double minVal,
    double maxVal,
    double goal,
  ) {
    final yNorm = (goal.clamp(minVal, maxVal) - minVal) / (maxVal - minVal);
    final y = plotRect.bottom - (plotRect.height * yNorm);

    final goalPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    double startX = plotRect.left;
    while (startX < plotRect.right) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(min(startX + dashWidth, plotRect.right), y),
        goalPaint,
      );
      startX += dashWidth + dashSpace;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'Goal: ${_format(goal)}',
        style: TextStyle(color: Colors.amber, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(plotRect.right - tp.width - 2, y - tp.height - 2));
  }

  void _drawNoData(Canvas canvas, Rect plotRect) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'No data yet',
        style: TextStyle(color: _neonGreen, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      plotRect.left + (plotRect.width - textPainter.width) / 2,
      plotRect.top + (plotRect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawAxisLabels(
    Canvas canvas,
    Rect plotRect,
    double minVal,
    double maxVal,
  ) {
    final labelStyle = TextStyle(color: _neonGreen, fontSize: 11);

    for (int i = 0; i < 5; i++) {
      final t = i / 4.0;
      final y = plotRect.top + plotRect.height * t;
      final value = maxVal - (maxVal - minVal) * t;

      final tp = TextPainter(
        text: TextSpan(text: _format(value), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final dx = plotRect.left - tp.width - 10;
      final dy = y - tp.height / 2;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  void _drawGridLines(Canvas canvas, Rect plotRect) {
    final gridPaint = Paint()
      ..color = _neonGreen.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final t = i / 4.0;
      final y = plotRect.top + plotRect.height * t;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect plotRect, List<_WeightPoint> pts) {
    if (pts.isEmpty) return;

    final labelStyle = TextStyle(color: _neonGreen, fontSize: 10);

    final labelCount = min(5, pts.length);
    final lastIdx = pts.length - 1;

    final indices = <int>{};
    if (labelCount == 1) {
      indices.add(0);
    } else {
      for (int i = 0; i < labelCount; i++) {
        final t = i / (labelCount - 1);
        final idx = (t * lastIdx).round();
        indices.add(idx);
      }
    }

    for (final idx in indices.toList()..sort()) {
      final p = pts[idx];

      String label = p.dateKey;
      final parts = p.dateKey.split('-');
      if (parts.length == 3) {
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (m != null && d != null) label = '$m/$d';
      }

      final x = (lastIdx == 0)
          ? plotRect.left
          : plotRect.left + (plotRect.width * (idx / lastIdx.toDouble()));

      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final dx = max(0.0, x - tp.width / 2);
      final dy = plotRect.bottom + 6;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  Offset _mapPoint(
    _WeightPoint p,
    Rect plotRect,
    double minVal,
    double maxVal,
    int idx,
    int lastIdx,
  ) {
    final x = (lastIdx == 0)
        ? plotRect.left
        : plotRect.left + (plotRect.width * (idx / lastIdx.toDouble()));

    final clamped = p.weight.clamp(minVal, maxVal);
    final yNorm = (clamped - minVal) / (maxVal - minVal);
    final y = plotRect.bottom - (plotRect.height * yNorm);
    return Offset(x, y);
  }

  String _format(double v) {
    final s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  @override
  bool shouldRepaint(covariant _WeightGraphPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.goalWeight != goalWeight;
  }
}
