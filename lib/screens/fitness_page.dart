import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/offline_sync.dart';

const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 18.0;
const String _macroApiKey = '160eeec24f1f43d5b642881f1be44243';

class FitnessPage extends StatefulWidget {
  const FitnessPage({super.key});

  @override
  State<FitnessPage> createState() => FitnessPageState();
}

class FitnessPageState extends State<FitnessPage> {
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
  double? _goalCalories;
  double? _goalCarbs;
  double? _goalFat;
  double? _goalProtein;
  bool _macroGoalsLoading = true;

  double _todayCalories = 0;
  double _todayCarbs = 0;
  double _todayFat = 0;
  double _todayProtein = 0;

  List<_MacroLogEntry> _todayLogs = [];
  bool _logsLoading = true;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void refresh() {
    _loadMacroGoals();
    _loadTodayLogs();
    _loadWeightsFromSupabase();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadGraphSettingsFromSupabase(),
      _loadWeightsFromSupabase(),
      _loadMacroGoals(),
      _loadTodayLogs(),
    ]);
  }

  Future<void> _loadUserSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final sync = SyncService.instance;
    final cachedSettings = sync.getCachedSingle('user_settings', user.id);
    if (cachedSettings != null && mounted) setState(() => _suppressResumeWarning = cachedSettings['suppress_resume_warning'] == true);
    try {
      final row = await _client
          .from('user_settings')
          .select('suppress_resume_warning')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row != null) {
        sync.cacheSingle('user_settings', user.id, Map<String, dynamic>.from(row));
        if (mounted) setState(() => _suppressResumeWarning = row['suppress_resume_warning'] == true);
      }
    } catch (_) {}
  }

  Future<void> _saveUserSettings({required bool suppressResumeWarning}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _suppressResumeWarning = suppressResumeWarning);
    final data = {'user_id': user.id, 'suppress_resume_warning': suppressResumeWarning};
    SyncService.instance.patchCachedSingle('user_settings', user.id, data);
    try {
      await _client.from('user_settings').upsert(data, onConflict: 'user_id');
    } catch (_) {
      SyncService.instance.enqueue(table: 'user_settings', type: 'upsert', data: data);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _goalController.dispose();
    _trainerCtrl.dispose();
    _trainerScroll.dispose();
    super.dispose();
  }

  void expandTrainer() {
    setState(() => _trainerExpanded = true);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadGraphSettingsFromSupabase() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _statusText = 'Not signed in (no user session found).');
      }
      return;
    }

    final sync = SyncService.instance;
    Map<String, dynamic>? row = sync.getCachedSingle('weight_tracker_settings', user.id);
    if (row != null) _applyGraphSettings(row);
    try {
      final fresh = await _client
          .from('weight_tracker_settings')
          .select('weight_graph_min, weight_graph_max, goal_weight')
          .eq('user_id', user.id)
          .maybeSingle();
      if (fresh != null) {
        sync.cacheSingle('weight_tracker_settings', user.id, Map<String, dynamic>.from(fresh));
        _applyGraphSettings(fresh);
      }
    } catch (_) {}
  }

  void _applyGraphSettings(Map<String, dynamic> row) {
    final minRaw = row['weight_graph_min'];
    final maxRaw = row['weight_graph_max'];
    final goalRaw = row['goal_weight'];
    final minVal = (minRaw is num) ? minRaw.toDouble() : double.tryParse('$minRaw');
    final maxVal = (maxRaw is num) ? maxRaw.toDouble() : double.tryParse('$maxRaw');
    final goalVal = (goalRaw is num) ? goalRaw.toDouble() : double.tryParse('$goalRaw');
    if (!mounted) return;
    setState(() {
      _graphMin = minVal;
      _graphMax = maxVal;
      _goalWeight = goalVal;
      if (minVal != null) _minController.text = _format(minVal);
      if (maxVal != null) _maxController.text = _format(maxVal);
      if (goalVal != null) _goalController.text = _format(goalVal);
    });
  }

  Future<void> _saveGraphSettingsToSupabase(
    double minVal,
    double maxVal,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _statusText = 'Not signed in (cannot save settings).');
      }
      return;
    }

    final data = <String, dynamic>{
      'user_id': user.id,
      'weight_graph_min': minVal,
      'weight_graph_max': maxVal,
      if (_goalWeight != null) 'goal_weight': _goalWeight,
    };
    SyncService.instance.patchCachedSingle('weight_tracker_settings', user.id, data);
    try {
      await _client.from('weight_tracker_settings').upsert(data, onConflict: 'user_id');
      if (mounted) setState(() => _statusText = null);
    } catch (_) {
      SyncService.instance.enqueue(table: 'weight_tracker_settings', type: 'upsert', data: data);
    }
  }

  Future<void> _saveGoalWeightToSupabase(double goalVal) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final data = <String, dynamic>{
      'user_id': user.id,
      'goal_weight': goalVal,
      if (_graphMin != null) 'weight_graph_min': _graphMin,
      if (_graphMax != null) 'weight_graph_max': _graphMax,
    };
    SyncService.instance.patchCachedSingle('weight_tracker_settings', user.id, data);
    try {
      await _client.from('weight_tracker_settings').upsert(data, onConflict: 'user_id');
    } catch (_) {
      SyncService.instance.enqueue(table: 'weight_tracker_settings', type: 'upsert', data: data);
    }
  }

  Future<void> _loadWeightsFromSupabase() async {
    if (mounted) setState(() => _loading = true);

    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusText ??= 'Not signed in (no user session found).';
        });
      }
      return;
    }

    final sync = SyncService.instance;
    final cachedRows = sync.getCachedList('weight_entries', user.id);
    if (cachedRows.isNotEmpty) {
      _weightsByDay.clear();
      for (final r in cachedRows) {
        final date = (r['entry_date'] ?? '').toString().substring(0, 10);
        final w = r['weight'];
        if (date.isEmpty) continue;
        final wv = (w is num) ? w.toDouble() : double.tryParse(w.toString());
        if (wv != null) _weightsByDay[date] = wv;
      }
      if (mounted) setState(() { _loading = false; _statusText = _weightsByDay.isEmpty ? 'No weight entries yet.' : null; });
    }
    List<dynamic> rows;
    try {
      rows = await _client
          .from('weight_entries')
          .select('entry_date, weight')
          .eq('user_id', user.id)
          .order('entry_date', ascending: true);
      sync.cacheList('weight_entries', user.id, List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      rows = cachedRows;
    }
    _weightsByDay.clear();
    for (final r in rows) {
      final dateRaw = r['entry_date'];
      final date = (dateRaw ?? '').toString().substring(0, 10);
      final w = r['weight'];
      if (date.isEmpty) continue;
      final weightVal = (w is num) ? w.toDouble() : double.tryParse(w.toString());
      if (weightVal == null) continue;
      _weightsByDay[date] = weightVal;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _statusText = _weightsByDay.isEmpty ? 'No weight entries yet.' : null;
    });
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
    final weightData = {'user_id': user.id, 'entry_date': dateKey, 'weight': weight};
    // Upsert into cache: update existing entry for today or add new one
    final sync = SyncService.instance;
    final wList = sync.getCachedList('weight_entries', user.id);
    final wIdx = wList.indexWhere((e) => e['entry_date']?.toString().startsWith(dateKey) ?? false);
    if (wIdx != -1) {
      wList[wIdx] = {...wList[wIdx], 'weight': weight};
      sync.cacheList('weight_entries', user.id, wList);
    } else {
      sync.addToCachedList('weight_entries', user.id, weightData);
    }
    try {
      await _client.from('weight_entries').upsert(weightData, onConflict: 'user_id,entry_date');
    } catch (_) {
      sync.enqueue(table: 'weight_entries', type: 'upsert', data: weightData);
    }
    if (mounted) {
      setState(() {
        _weightsByDay[dateKey] = weight;
        _weightController.clear();
        _statusText = null;
      });
      if (_goalWeight != null && weight <= _goalWeight!) _showGoalReachedBanner();
    }
    await _loadWeightsFromSupabase();
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

    if (mounted) {
      setState(() {
        _graphMin = minVal;
        _graphMax = maxVal;
      });
    }

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
      if (mounted) {
        setState(() => _statusText = 'Not signed in (cannot clear).');
      }
      return;
    }

    final ok = await _confirmClear(context);
    if (!ok) return;

    try {
      await _client.from('weight_entries').delete().eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _weightsByDay.clear();
          _weightController.clear();
          _statusText = 'No weight entries yet.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Could not clear weights from Supabase.');
      }
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

  Future<void> _loadMacroGoals() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _macroGoalsLoading = false);
      return;
    }

    try {
      final row = await _client
          .from('macro_goals')
          .select('calorie_goal, carbs_goal, fat_goal, protein_goal')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;
      if (row != null) {
        setState(() {
          _goalCalories = (row['calorie_goal'] is num)
              ? (row['calorie_goal'] as num).toDouble()
              : null;
          _goalCarbs = (row['carbs_goal'] is num)
              ? (row['carbs_goal'] as num).toDouble()
              : null;
          _goalFat = (row['fat_goal'] is num)
              ? (row['fat_goal'] as num).toDouble()
              : null;
          _goalProtein = (row['protein_goal'] is num)
              ? (row['protein_goal'] as num).toDouble()
              : null;
          _macroGoalsLoading = false;
        });
      } else {
        setState(() => _macroGoalsLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _macroGoalsLoading = false);
    }
  }

  Future<void> _saveMacroGoals(
    double cal,
    double carbs,
    double fat,
    double protein,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = {'user_id': user.id, 'calorie_goal': cal, 'carbs_goal': carbs, 'fat_goal': fat, 'protein_goal': protein};
    SyncService.instance.patchCachedSingle('macro_goals', user.id, data);
    try {
      await _client.from('macro_goals').upsert(data, onConflict: 'user_id');
    } catch (_) {
      SyncService.instance.enqueue(table: 'macro_goals', type: 'upsert', data: data);
    }
    if (mounted) setState(() { _goalCalories = cal; _goalCarbs = carbs; _goalFat = fat; _goalProtein = protein; });
  }

  void _showSetMacroGoalsDialog() {
    final calCtrl = TextEditingController(
      text: _goalCalories?.toStringAsFixed(0) ?? '',
    );
    final carbsCtrl = TextEditingController(
      text: _goalCarbs?.toStringAsFixed(0) ?? '',
    );
    final fatCtrl = TextEditingController(
      text: _goalFat?.toStringAsFixed(0) ?? '',
    );
    final proteinCtrl = TextEditingController(
      text: _goalProtein?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Set Macro Goals', style: TextStyle(color: _neonGreen)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your daily targets below.',
                style: TextStyle(
                  color: _neonGreen.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _neonGreen),
                decoration: _inputDecoration('Calories (e.g. 2000)'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: carbsCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _neonGreen),
                decoration: _inputDecoration('Carbs in grams (e.g. 250)'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: fatCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _neonGreen),
                decoration: _inputDecoration('Fat in grams (e.g. 65)'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: proteinCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: _neonGreen),
                decoration: _inputDecoration('Protein in grams (e.g. 50)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () {
              final cal = double.tryParse(calCtrl.text.trim());
              final carbs = double.tryParse(carbsCtrl.text.trim());
              final fat = double.tryParse(fatCtrl.text.trim());
              final protein = double.tryParse(proteinCtrl.text.trim());
              if (cal == null ||
                  carbs == null ||
                  fat == null ||
                  protein == null) {
                return;
              }
              Navigator.pop(ctx);
              _saveMacroGoals(cal, carbs, fat, protein);
            },
            child: Text(
              'Save',
              style: TextStyle(color: _neonGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTodayLogs() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _logsLoading = false);
      return;
    }

    if (mounted) setState(() => _logsLoading = true);
    final sync = SyncService.instance;
    final todayKey = _todayKey();
    final cachedLogs = sync.getCachedList('daily_macro_logs_$todayKey', user.id);
    if (cachedLogs.isNotEmpty) {
      final cl = cachedLogs.map((r) => _MacroLogEntry.fromMap(r)).toList();
      double cc = 0, ccarbs = 0, cfat = 0, cprot = 0;
      for (final l in cl) { cc += l.calories; ccarbs += l.carbs; cfat += l.fat; cprot += l.protein; }
      if (mounted) setState(() { _todayLogs = cl; _todayCalories = cc; _todayCarbs = ccarbs; _todayFat = cfat; _todayProtein = cprot; _logsLoading = false; });
    }
    List<dynamic> rows;
    try {
      rows = await _client
          .from('daily_macro_logs')
          .select()
          .eq('user_id', user.id)
          .eq('log_date', todayKey)
          .order('created_at', ascending: true);
      sync.cacheList('daily_macro_logs_$todayKey', user.id, List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      rows = cachedLogs;
    }
    final logs = rows.map((r) => _MacroLogEntry.fromMap(r)).toList();
    double cal = 0, carbs = 0, fat = 0, protein = 0;
    for (final l in logs) { cal += l.calories; carbs += l.carbs; fat += l.fat; protein += l.protein; }
    if (!mounted) return;
    setState(() { _todayLogs = logs; _todayCalories = cal; _todayCarbs = carbs; _todayFat = fat; _todayProtein = protein; _logsLoading = false; });
  }

  Future<void> _removeLog(_MacroLogEntry entry) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    SyncService.instance.removeFromCachedList('daily_macro_logs_${_todayKey()}', user.id, 'id', entry.id);
    try {
      await _client.from('daily_macro_logs').delete().eq('id', entry.id);
    } catch (_) {
      SyncService.instance.enqueue(table: 'daily_macro_logs', type: 'delete', data: {}, match: {'id': entry.id});
    }
    await _loadTodayLogs();
  }

  Future<void> _showEatDialog() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    List<_EatOption> options = [];

    final sync = SyncService.instance;
    List<dynamic> ingRows = sync.getCachedList('ingredients', user.id);
    List<dynamic> recipeRows = sync.getCachedList('favorite_recipes', user.id);
    try {
      final freshIng = await _client
          .from('ingredients')
          .select('name, calories, carbs_g, protein_g, fat_g')
          .eq('user_id', user.id);
      sync.cacheList('ingredients', user.id, List<Map<String, dynamic>>.from(freshIng));
      ingRows = freshIng;
      final freshRecipes = await _client
          .from('favorite_recipes')
          .select('recipe_id, title')
          .eq('user_id', user.id);
      sync.cacheList('favorite_recipes', user.id, List<Map<String, dynamic>>.from(freshRecipes));
      recipeRows = freshRecipes;
    } catch (_) {}
    for (final r in ingRows) {
      final cal = r['calories'], carbs = r['carbs_g'], fat = r['fat_g'], protein = r['protein_g'];
      final hasNutrition = cal != null && carbs != null && fat != null && protein != null;
      options.add(_EatOption(
        name: r['name'].toString(), type: 'ingredient',
        calories: hasNutrition ? (cal as num).toDouble() : null,
        carbs: hasNutrition ? (carbs as num).toDouble() : null,
        fat: hasNutrition ? (fat as num).toDouble() : null,
        protein: hasNutrition ? (protein as num).toDouble() : null,
      ));
    }
    for (final r in recipeRows) {
      options.add(_EatOption(name: r['title'].toString(), type: 'recipe', spoonacularId: (r['recipe_id'] as num).toInt()));
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
        side: BorderSide(color: _neonGreen, width: 1.5),
      ),
      builder: (ctx) => _EatBottomSheet(
        options: options,
        onEat: (option, servings) => _logEaten(option, servings),
      ),
    );
  }

  Future<void> _logEaten(_EatOption option, double servings) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    double? cal, carbs, fat, protein;

    if (option.type == 'ingredient') {
      if (option.calories == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.black,
              content: Text(
                '${option.name} has no nutrition data. Please sync it on the Health tab first.',
                style: TextStyle(color: _neonGreen),
              ),
            ),
          );
        }
        return;
      }
      cal = option.calories! * servings;
      carbs = option.carbs! * servings;
      fat = option.fat! * servings;
      protein = option.protein! * servings;
    } else {
      final nutrition = await _fetchRecipeNutrition(option.spoonacularId!);
      if (nutrition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not fetch recipe nutrition.',
                style: TextStyle(color: _neonGreen),
              ),
            ),
          );
        }
        return;
      }
      final perServing = nutrition['servings'] ?? 1.0;
      cal = (nutrition['calories'] as double) / perServing * servings;
      carbs = (nutrition['carbs'] as double) / perServing * servings;
      fat = (nutrition['fat'] as double) / perServing * servings;
      protein = (nutrition['protein'] as double) / perServing * servings;
    }
    final logData = {
      'user_id': user.id, 'log_date': _todayKey(), 'item_name': option.name,
      'item_type': option.type, 'calories': cal, 'carbs': carbs, 'fat': fat,
      'protein': protein, 'servings': servings,
    };
    SyncService.instance.addToCachedList('daily_macro_logs_${_todayKey()}', user.id, logData);
    try {
      await _client.from('daily_macro_logs').insert(logData);
    } catch (_) {
      SyncService.instance.enqueue(table: 'daily_macro_logs', type: 'insert', data: logData);
    }
    await _loadTodayLogs();
  }

  Future<Map<String, double>?> _fetchRecipeNutrition(int recipeId) async {
    try {
      final uri = Uri.parse(
        'https://api.spoonacular.com/recipes/$recipeId/nutritionWidget.json?apiKey=$_macroApiKey',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      double parseNutrient(String name) {
        final nutrients = (data['nutrients'] as List?) ?? [];
        for (final n in nutrients) {
          if ((n['name'] ?? '').toString().toLowerCase() ==
              name.toLowerCase()) {
            final amt = n['amount'];
            if (amt is num) return amt.toDouble();
            if (amt is String) return double.tryParse(amt) ?? 0;
          }
        }
        return 0;
      }

      final servings = data['servings'];
      final servingsVal = (servings is num) ? servings.toDouble() : 1.0;

      return {
        'calories': parseNutrient('Calories'),
        'carbs': parseNutrient('Carbohydrates'),
        'fat': parseNutrient('Fat'),
        'protein': parseNutrient('Protein'),
        'servings': servingsVal,
      };
    } catch (e) {
      return null;
    }
  }

  void _showRemoveLogDialog() {
    if (_todayLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nothing logged today.',
            style: TextStyle(color: _neonGreen),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
        side: BorderSide(color: _neonGreen, width: 1.5),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Remove Logged Item',
                style: TextStyle(
                  color: _neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: EdgeInsets.all(12),
                itemCount: _todayLogs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: _neonGreen.withOpacity(0.2)),
                itemBuilder: (context, i) {
                  final log = _todayLogs[i];
                  return ListTile(
                    title: Text(
                      log.itemName,
                      style: TextStyle(color: _neonGreen),
                    ),
                    subtitle: Text(
                      '${log.calories.toStringAsFixed(1)} cal • ${log.servings.toStringAsFixed(1)} serving(s)',
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removeLog(log);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosContent() {
    final goalsSet =
        _goalCalories != null &&
        _goalCarbs != null &&
        _goalFat != null &&
        _goalProtein != null;

    final displayCalGoal = _goalCalories ?? 2000;
    final displayCarbsGoal = _goalCarbs ?? 250;
    final displayFatGoal = _goalFat ?? 65;
    final displayProteinGoal = _goalProtein ?? 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _showSetMacroGoalsDialog,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _neonGreen, width: 1.5),
            foregroundColor: _neonGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
          ),
          child: Text(goalsSet ? 'Update Macro Goals' : 'Set Goal Macros'),
        ),
        if (!goalsSet) ...[
          SizedBox(height: 8),
          Text(
            'Set your goals above, showing defaults for now.',
            style: TextStyle(color: _neonGreen.withOpacity(0.5), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: 16),
        if (_logsLoading)
          Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          _MacroBar(
            label: 'Calories',
            value: _todayCalories,
            goal: displayCalGoal,
            unit: '',
          ),
          SizedBox(height: 14),
          _MacroBar(
            label: 'Carbs',
            value: _todayCarbs,
            goal: displayCarbsGoal,
            unit: 'g',
          ),
          SizedBox(height: 14),
          _MacroBar(
            label: 'Fat',
            value: _todayFat,
            goal: displayFatGoal,
            unit: 'g',
          ),
          SizedBox(height: 14),
          _MacroBar(
            label: 'Protein',
            value: _todayProtein,
            goal: displayProteinGoal,
            unit: 'g',
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showEatDialog,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Eat'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _neonGreen, width: 1.5),
                    foregroundColor: _neonGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_cornerRadius),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showRemoveLogDialog,
                  icon: Icon(Icons.remove_circle_outline, size: 18),
                  label: Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent, width: 1.5),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_cornerRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
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
              infoText:
                  'Use this to log your daily weight and set a goal weight to achieve. Set your goal weight using the Set Goal button. Also customize the minimun and maximun amount shown on the graph by setting the graph min and graph max.',
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
              infoText:
                  'Track your macronutrients throughout the day by using the Eat button to consume an ingredient or recipe you have logged on the Health tab. Eaten items can be removed by using the Remove button. You may also set and update goals for each macronutrient based on your preferred diet plan by entering them after using the Update Macro Goals button. Feel free to ask the trainer if you are unsure about which diet plan is best for your goals.',
              expanded: _macrosExpanded,
              onToggle: () =>
                  setState(() => _macrosExpanded = !_macrosExpanded),
              child: _macroGoalsLoading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _buildMacrosContent(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadArchivedConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _archivedLoading = true);
    final sync = SyncService.instance;
    final cachedConvs = sync.getCachedList('archived_conversations', user.id);
    if (cachedConvs.isNotEmpty && mounted) {
      setState(() {
        _archivedConversations = cachedConvs.map((r) => _ArchivedConversation.fromMap(r)).toList();
        _archivedLoading = false;
      });
    }
    List<dynamic> rows;
    try {
      rows = await _client
          .from('archived_conversations')
          .select('id, name, messages, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      sync.cacheList('archived_conversations', user.id, List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      rows = cachedConvs;
    }
    if (!mounted) return;
    setState(() {
      _archivedConversations = rows.map((r) => _ArchivedConversation.fromMap(r)).toList();
      _archivedLoading = false;
    });
  }

  Future<void> _showSaveConversationDialog() async {
    if (_trainerMsgs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start a conversation before saving.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: const Text(
          'Save Conversation',
          style: TextStyle(color: _neonGreen),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Warning: Your current conversation will be lost without saving it before another is opened!',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: _neonGreen),
              decoration: InputDecoration(
                hintText: 'Name this conversation…',
                hintStyle: TextStyle(color: _neonGreen.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _neonGreen),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _neonGreen, width: 2),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: _neonGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await _saveConversation(name);
  }

  Future<void> _saveConversation(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final messages = _trainerMsgs
          .map(
            (m) => {
              'role': m.role == _TrainerRole.user ? 'user' : 'model',
              'text': m.text,
            },
          )
          .toList();

      final convData = {'user_id': user.id, 'name': name, 'messages': messages};
      SyncService.instance.addToCachedList('archived_conversations', user.id, convData);
      try {
        await _client.from('archived_conversations').insert(convData);
      } catch (_) {
        SyncService.instance.enqueue(table: 'archived_conversations', type: 'insert', data: convData);
      }
      await _loadArchivedConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(side: BorderSide(color: _neonGreen, width: 1.5), borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          content: Text('Conversation saved as "$name"', style: const TextStyle(color: _neonGreen)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save conversation: $e')));
    }
  }

  Future<void> _deleteArchivedConversation(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    SyncService.instance.removeFromCachedList('archived_conversations', user.id, 'id', id);
    try {
      await _client.from('archived_conversations').delete().eq('id', id).eq('user_id', user.id);
    } catch (_) {
      SyncService.instance.enqueue(table: 'archived_conversations', type: 'delete', data: {}, match: {'id': id});
    }
    await _loadArchivedConversations();
  }

  void _doResume(_ArchivedConversation conv) {
    setState(() {
      _trainerMsgs.clear();
      _trainerMsgs.addAll(conv.messages);
      _viewingConversation = null;
      _sidebarOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollTrainerToBottom(),
    );
  }

  Future<void> _resumeConversation(_ArchivedConversation conv) async {
    final hasUnsaved = _trainerMsgs.length > 1;

    if (!hasUnsaved || _suppressResumeWarning) {
      _doResume(conv);
      return;
    }

    bool dontShowAgain = false;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: _neonGreen, width: 1.5),
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          title: const Text(
            'Resume Conversation?',
            style: TextStyle(color: _neonGreen),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent, width: 1.2),
                  color: Colors.redAccent.withOpacity(0.06),
                ),
                child: const Text(
                  'Warning: Your current conversation will be lost if you resume without saving it first!',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _neonGreen, width: 1.5),
                  foregroundColor: _neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Save & Resume',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'resume'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Resume Anyway',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _neonGreen, width: 1.5),
                  foregroundColor: _neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, color: _neonGreen),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (v) =>
                        setDialogState(() => dontShowAgain = v ?? false),
                    activeColor: _neonGreen,
                    checkColor: Colors.black,
                    side: BorderSide(color: _neonGreen),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Expanded(
                    child: Text(
                      "Don't show this again",
                      style: TextStyle(color: _neonGreen, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: const [],
        ),
      ),
    );

    if (result == null || result == 'cancel') return;

    if (dontShowAgain) {
      await _saveUserSettings(suppressResumeWarning: true);
    }

    if (result == 'save') {
      await _showSaveConversationDialog();
      _doResume(conv);
    } else if (result == 'resume') {
      _doResume(conv);
    }
  }

  Future<void> _sendTrainer() async {
    final text = _trainerCtrl.text.trim();
    if (text.isEmpty || _trainerSending) return;

    setState(() {
      _trainerSending = true;
      _trainerMsgs.add(_TrainerMsg(role: _TrainerRole.user, text: text));
      _trainerCtrl.clear();
    });
    _scrollTrainerToBottom();

    try {
      final reply = await _geminiTrainerReply();
      if (!mounted) return;
      setState(() {
        _trainerMsgs.add(_TrainerMsg(role: _TrainerRole.model, text: reply));
      });
      _scrollTrainerToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trainerMsgs.add(
          _TrainerMsg(role: _TrainerRole.model, text: 'Trainer error: $e'),
        );
      });
      _scrollTrainerToBottom();
    } finally {
      if (mounted) setState(() => _trainerSending = false);
    }
  }

  void _scrollTrainerToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_trainerScroll.hasClients) return;
      _trainerScroll.animateTo(
        _trainerScroll.position.maxScrollExtent + 200,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  static const List<Map<String, dynamic>> _geminiTools = [
    {
      'function_declarations': [
        {
          'name': 'log_weight_entry',
          'description':
              'Log todays weight for the user. Call when user states their current weight or asks to log it.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'weight': {
                'type': 'NUMBER',
                'description': 'Weight value to log.',
              },
            },
            'required': ['weight'],
          },
        },
        {
          'name': 'update_goal_weight',
          'description':
              'Update the users goal weight. Call when user asks to change or set their target weight.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'goal_weight': {
                'type': 'NUMBER',
                'description': 'New goal weight.',
              },
            },
            'required': ['goal_weight'],
          },
        },
        {
          'name': 'update_macro_goals',
          'description':
              'Update the users daily macro targets. Call when user asks to change macros or agrees to apply recommended targets.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'calorie_goal': {
                'type': 'NUMBER',
                'description': 'Daily calorie target.',
              },
              'carbs_goal': {
                'type': 'NUMBER',
                'description': 'Daily carbs in grams.',
              },
              'fat_goal': {
                'type': 'NUMBER',
                'description': 'Daily fat in grams.',
              },
              'protein_goal': {
                'type': 'NUMBER',
                'description': 'Daily protein in grams.',
              },
            },
            'required': [
              'calorie_goal',
              'carbs_goal',
              'fat_goal',
              'protein_goal',
            ],
          },
        },
      ],
    },
  ];

  Future<String> _buildUserContext() async {
    final user = _client.auth.currentUser;
    if (user == null) return '';

    try {
      final settings = await _client
          .from('weight_tracker_settings')
          .select('goal_weight')
          .eq('user_id', user.id)
          .maybeSingle();

      final macros = await _client
          .from('macro_goals')
          .select('calorie_goal, carbs_goal, fat_goal, protein_goal')
          .eq('user_id', user.id)
          .maybeSingle();

      final weights = await _client
          .from('weight_entries')
          .select('entry_date, weight')
          .eq('user_id', user.id)
          .order('entry_date', ascending: false)
          .limit(7);

      final since = DateTime.now().subtract(const Duration(days: 6));
      final sinceKey =
          '${since.year.toString().padLeft(4, '0')}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
      final logs = await _client
          .from('daily_macro_logs')
          .select('log_date, item_name, calories, carbs, fat, protein')
          .eq('user_id', user.id)
          .gte('log_date', sinceKey)
          .order('log_date', ascending: false);

      final buffer = StringBuffer();
      buffer.writeln('--- USER DATA (today: ${_todayKey()}) ---');

      final gw = settings?['goal_weight'];
      buffer.writeln('Goal weight: ${gw ?? 'not set'}');

      if (macros != null) {
        buffer.writeln(
          'Daily macro goals: ${macros['calorie_goal']} cal, '
          '${macros['carbs_goal']}g carbs, ${macros['fat_goal']}g fat, ${macros['protein_goal']}g protein',
        );
      } else {
        buffer.writeln('Macro goals: not set');
      }

      if ((weights as List).isNotEmpty) {
        buffer.writeln('Recent weights (newest first):');
        for (final w in weights) {
          buffer.writeln('  ${w['entry_date']}: ${w['weight']} lbs');
        }
      } else {
        buffer.writeln('Weight entries: none');
      }

      if ((logs as List).isNotEmpty) {
        buffer.writeln('Food logged this week:');
        for (final l in logs) {
          buffer.writeln(
            '  ${l['log_date']} - ${l['item_name']}: ${l['calories']} cal, '
            '${l['carbs']}g carbs, ${l['fat']}g fat, ${l['protein']}g protein',
          );
        }
      } else {
        buffer.writeln('Food logs this week: none');
      }

      buffer.writeln('--- END USER DATA ---');
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> _executeTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return {'error': 'User not signed in.'};

    try {
      switch (name) {        case 'log_weight_entry':
          final weight = (args['weight'] as num).toDouble();
          final dateKey = _todayKey();
          await _client.from('weight_entries').upsert({
            'user_id': user.id,
            'entry_date': dateKey,
            'weight': weight,          }, onConflict: 'user_id,entry_date');
          if (mounted) {
            setState(() => _weightsByDay[dateKey] = weight);
            if (_goalWeight != null && weight <= _goalWeight!) {
              _showGoalReachedBanner();
            }
          }
          await _loadWeightsFromSupabase();
          return {'success': true, 'logged_weight': weight, 'date': dateKey};

        case 'update_goal_weight':
          final goal = (args['goal_weight'] as num).toDouble();
          await _client.from('weight_tracker_settings').upsert({
            'user_id': user.id,
            'goal_weight': goal,
            if (_graphMin != null) 'weight_graph_min': _graphMin,
            if (_graphMax != null) 'weight_graph_max': _graphMax,
          }, onConflict: 'user_id');
          if (mounted) setState(() => _goalWeight = goal);
          return {'success': true, 'new_goal_weight': goal};

        case 'update_macro_goals':
          final cal = (args['calorie_goal'] as num).toDouble();
          final carbs = (args['carbs_goal'] as num).toDouble();
          final fat = (args['fat_goal'] as num).toDouble();
          final protein = (args['protein_goal'] as num).toDouble();
          await _client.from('macro_goals').upsert({
            'user_id': user.id,
            'calorie_goal': cal,
            'carbs_goal': carbs,
            'fat_goal': fat,
            'protein_goal': protein,
          }, onConflict: 'user_id');
          if (mounted) {
            setState(() {
              _goalCalories = cal;
              _goalCarbs = carbs;
              _goalFat = fat;
              _goalProtein = protein;
            });
          }
          return {
            'success': true,
            'calorie_goal': cal,
            'carbs_goal': carbs,
            'fat_goal': fat,
            'protein_goal': protein,
          };

        default:
          return {'error': 'Unknown tool: $name'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<String> _geminiTrainerReply() async {
    if (_geminiApiKey.isEmpty) {
      return 'Missing GEMINI_API_KEY. Run: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY';
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent',
    );

    final userContext = await _buildUserContext();

    final systemText =
        'You are a personal fitness and nutrition coach with access to the users real data. '
        'Be consice, use short sentences or bullet points to get the point across. '
        'Do not repeat what the user said back to them. '
        'Maximum of 3 to 5 bullet points per response unless the user explicitly asks for a full plan. '
        'Only ask 1 clarifying question if you need more information before answering. '
        'When you use a tool to update the database, confirm it with a short sentence. '
        'Avoid medical diagnosis, if symptoms are serious, ask the user to see a doctor.'
        '\n\n$userContext';

    final systemPrompt = {
      'parts': [
        {'text': systemText},
      ],
    };

    final history = _trainerMsgs.length <= 10
        ? _trainerMsgs
        : _trainerMsgs.sublist(_trainerMsgs.length - 10);

    final contents = history
        .map(
          (m) => {
            'role': m.role == _TrainerRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
        )
        .toList();

    for (int round = 0; round < 2; round++) {
      final body = {
        'system_instruction': systemPrompt,
        'contents': contents,
        'tools': _geminiTools,
      };

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = (data['candidates'] as List?) ?? const [];
      if (candidates.isEmpty) return 'No response from trainer.';

      final candidate = candidates.first as Map<String, dynamic>;
      final contentBlock = candidate['content'] as Map<String, dynamic>?;
      final parts = (contentBlock?['parts'] as List?) ?? const [];

      final toolCallParts = parts
          .where((p) => (p as Map<String, dynamic>).containsKey('functionCall'))
          .toList();

      if (toolCallParts.isEmpty) {
        final textPart = parts.firstWhere(
          (p) => (p as Map<String, dynamic>).containsKey('text'),
          orElse: () => null,
        );
        final text = textPart != null
            ? (textPart['text'] ?? '').toString()
            : '';
        return text.isEmpty ? 'No text returned from trainer.' : text;
      }

      contents.add({'role': 'model', 'parts': parts});

      final toolResponses = <Map<String, dynamic>>[];
      for (final part in toolCallParts) {
        final fc =
            (part as Map<String, dynamic>)['functionCall']
                as Map<String, dynamic>;
        final toolName = fc['name'].toString();
        final toolArgs = (fc['args'] as Map<String, dynamic>?) ?? {};
        final result = await _executeTool(toolName, toolArgs);
        toolResponses.add({
          'functionResponse': {'name': toolName, 'response': result},
        });
      }

      contents.add({'role': 'user', 'parts': toolResponses});
    }

    return 'No response from trainer.';
  }

  Widget _buildTrainerChat() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cornerRadius),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cornerRadius),
              border: Border.all(color: _neonGreen, width: 2),
              color: Colors.black,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showSaveConversationDialog,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _neonGreen, width: 1.5),
                          foregroundColor: _neonGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_cornerRadius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontSize: 13, color: _neonGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _sidebarOpen = !_sidebarOpen),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _neonGreen, width: 1.5),
                          foregroundColor: _neonGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_cornerRadius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'View Saved Conversations',
                          style: TextStyle(fontSize: 13, color: _neonGreen),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    controller: _trainerScroll,
                    itemCount: _trainerMsgs.length + (_trainerSending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_trainerSending && i == _trainerMsgs.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: _TypingBubble(),
                        );
                      }
                      final m = _trainerMsgs[i];
                      final isUser = m.role == _TrainerRole.user;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.grey.shade900
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _neonGreen.withOpacity(0.8),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonGreen.withOpacity(0.12),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              m.text,
                              style: const TextStyle(
                                color: _neonGreen,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _trainerCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendTrainer(),
                        style: const TextStyle(color: _neonGreen),
                        decoration: InputDecoration(
                          hintText: 'Ask about workouts, diet plans, macros…',
                          hintStyle: TextStyle(
                            color: _neonGreen.withOpacity(0.55),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _neonGreen,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _neonGreen,
                              width: 2,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _trainerSending ? null : _sendTrainer,
                      icon: _trainerSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: _neonGreen),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_sidebarOpen)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _sidebarOpen = false),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  ),
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border(
                        left: BorderSide(color: _neonGreen, width: 1.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                          child: Row(
                            children: [
                              const Text(
                                'Saved',
                                style: TextStyle(
                                  color: _neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: _neonGreen,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _sidebarOpen = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: _neonGreen, height: 1),
                        Expanded(
                          child: _archivedLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _archivedConversations.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'No saved conversations yet.',
                                    style: TextStyle(
                                      color: _neonGreen.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: _archivedConversations.length,
                                  separatorBuilder: (_, __) => Divider(
                                    color: _neonGreen.withOpacity(0.15),
                                    height: 1,
                                  ),
                                  itemBuilder: (ctx, i) {
                                    final conv = _archivedConversations[i];
                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 2,
                                          ),
                                      title: Text(
                                        conv.name,
                                        style: const TextStyle(
                                          color: _neonGreen,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        conv.formattedDate,
                                        style: TextStyle(
                                          color: _neonGreen.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent.withOpacity(
                                            0.7,
                                          ),
                                          size: 16,
                                        ),
                                        onPressed: () =>
                                            _confirmDeleteConversation(conv),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _viewingConversation = conv;
                                          _sidebarOpen = false;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_viewingConversation != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  border: Border.all(color: _neonGreen, width: 2),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _viewingConversation!.name,
                              style: const TextStyle(
                                color: _neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _resumeConversation(_viewingConversation!),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: _neonGreen,
                                width: 1.5,
                              ),
                              foregroundColor: _neonGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _cornerRadius,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Resume',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: _neonGreen,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _viewingConversation = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: _neonGreen, height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _viewingConversation!.messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _viewingConversation!.messages[i];
                          final isUser = m.role == _TrainerRole.user;
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Colors.grey.shade900
                                      : Colors.black,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _neonGreen.withOpacity(0.6),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  m.text,
                                  style: TextStyle(
                                    color: _neonGreen.withOpacity(0.9),
                                    height: 1.25,
                                    fontSize: 13,
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
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteConversation(_ArchivedConversation conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: const Text(
          'Delete Conversation',
          style: TextStyle(color: _neonGreen),
        ),
        content: Text(
          'Delete "${conv.name}"? This cannot be undone.',
          style: TextStyle(color: _neonGreen.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteArchivedConversation(conv.id);
  }

  Widget _collapsibleCard({
    required String title,
    required IconData icon,
    String? subtitle,
    String? infoText,
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
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
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
                  if (infoText != null) ...[
                    _InfoButton(infoText: infoText, iconColor: _neonGreen),
                    SizedBox(width: 4),
                  ],
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
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

class _MacroLogEntry {
  final String id;
  final String itemName;
  final String itemType;
  final double calories;
  final double carbs;
  final double fat;
  final double protein;
  final double servings;

  _MacroLogEntry({
    required this.id,
    required this.itemName,
    required this.itemType,
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.servings,
  });

  factory _MacroLogEntry.fromMap(Map<String, dynamic> m) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return _MacroLogEntry(
      id: m['id'].toString(),
      itemName: m['item_name'].toString(),
      itemType: m['item_type'].toString(),
      calories: n(m['calories']),
      carbs: n(m['carbs']),
      fat: n(m['fat']),
      protein: n(m['protein']),
      servings: n(m['servings']),
    );
  }
}

class _EatOption {
  final String name;
  final String type;
  final double? calories;
  final double? carbs;
  final double? fat;
  final double? protein;
  final int? spoonacularId;

  _EatOption({
    required this.name,
    required this.type,
    this.calories,
    this.carbs,
    this.fat,
    this.protein,
    this.spoonacularId,
  });
}

class _EatBottomSheet extends StatefulWidget {
  final List<_EatOption> options;
  final Future<void> Function(_EatOption option, double servings) onEat;

  const _EatBottomSheet({required this.options, required this.onEat});

  @override
  State<_EatBottomSheet> createState() => _EatBottomSheetState();
}

class _EatBottomSheetState extends State<_EatBottomSheet> {
  _EatOption? _selected;
  final _servingsCtrl = TextEditingController(text: '1');
  String _unit = 'serving';
  bool _loading = false;

  @override
  void dispose() {
    _servingsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = widget.options
        .where((o) => o.type == 'ingredient')
        .toList();
    final recipes = widget.options.where((o) => o.type == 'recipe').toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'What did you eat?',
              style: TextStyle(
                color: _neonGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (ingredients.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'INGREDIENTS',
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.6),
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final opt in ingredients) _optionTile(opt),
                ],
                if (recipes.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'FAVORITED RECIPES',
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.6),
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final opt in recipes) _optionTile(opt),
                ],
                if (ingredients.isEmpty && recipes.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No ingredients or favorited recipes found.\nAdd ingredients on the Health tab or favorite some recipes.',
                      style: TextStyle(color: _neonGreen.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          if (_selected != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _neonGreen.withOpacity(0.3)),
                ),
                color: Colors.black,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selected!.name,
                    style: TextStyle(
                      color: _neonGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _servingsCtrl,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: _neonGreen),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            labelStyle: TextStyle(color: _neonGreen),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _neonGreen),
                              borderRadius: BorderRadius.circular(
                                _cornerRadius,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _neonGreen,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(
                                _cornerRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _unit,
                        dropdownColor: Colors.black,
                        style: TextStyle(color: _neonGreen),
                        underline: Container(height: 1, color: _neonGreen),
                        items: ['serving', 'grams', 'cups']
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _unit = v ?? 'serving'),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_cornerRadius),
                      ),
                    ),
                    onPressed: _loading
                        ? null
                        : () async {
                            final servings =
                                double.tryParse(_servingsCtrl.text.trim()) ??
                                1.0;
                            setState(() => _loading = true);
                            await widget.onEat(_selected!, servings);
                            if (mounted) Navigator.pop(context);
                          },
                    child: _loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Log It',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionTile(_EatOption opt) {
    final isSelected = _selected == opt;
    final noNutrition = opt.type == 'ingredient' && opt.calories == null;

    return GestureDetector(
      onTap: noNutrition ? null : () => setState(() => _selected = opt),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _neonGreen
                : _neonGreen.withOpacity(noNutrition ? 0.2 : 0.45),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? _neonGreen.withOpacity(0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              opt.type == 'ingredient' ? Icons.restaurant : Icons.menu_book,
              color: noNutrition ? _neonGreen.withOpacity(0.3) : _neonGreen,
              size: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.name,
                    style: TextStyle(
                      color: noNutrition
                          ? _neonGreen.withOpacity(0.35)
                          : _neonGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (noNutrition)
                    Text(
                      'Nutrition not synced, go to Health tab',
                      style: TextStyle(
                        color: Colors.redAccent.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    )
                  else if (opt.type == 'ingredient')
                    Text(
                      '${opt.calories!.toStringAsFixed(0)} cal, ${opt.carbs!.toStringAsFixed(1)}g carbs, ${opt.protein!.toStringAsFixed(1)}g protein',
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.65),
                        fontSize: 11,
                      ),
                    )
                  else
                    Text(
                      'Tap to log, nutrition fetched from Spoonacular',
                      style: TextStyle(
                        color: _neonGreen.withOpacity(0.65),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: _neonGreen, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final String unit;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final overGoal = value > goal;
    final displayMax = overGoal ? value * 1.1 : goal;
    final fillFraction = (displayMax > 0
        ? (value / displayMax).clamp(0.0, 1.0)
        : 0.0);
    final goalFraction = (displayMax > 0
        ? (goal / displayMax).clamp(0.0, 1.0)
        : 1.0);

    final valueLabel = unit.isEmpty
        ? value.toStringAsFixed(1)
        : '${value.toStringAsFixed(1)}$unit';
    final goalLabel = unit.isEmpty
        ? goal.toStringAsFixed(0)
        : '${goal.toStringAsFixed(0)}$unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _neonGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final fillWidth = totalWidth * fillFraction;
            final goalX = totalWidth * goalFraction;

            return SizedBox(
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _neonGreen, width: 1.5),
                      color: Colors.black,
                    ),
                  ),
                  if (fillWidth > 0)
                    Container(
                      height: 20,
                      width: fillWidth.clamp(0.0, totalWidth),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: overGoal
                            ? _neonGreen.withOpacity(0.5)
                            : _neonGreen,
                        boxShadow: [
                          BoxShadow(
                            color: _neonGreen.withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: (goalX - 1).clamp(0.0, totalWidth - 2),
                    top: -2,
                    child: Container(
                      width: 2,
                      height: 24,
                      color: overGoal
                          ? Colors.amber.withOpacity(0.6)
                          : Colors.amber,
                    ),
                  ),
                  Positioned(
                    left: (fillWidth - 1).clamp(0.0, totalWidth - 2),
                    top: 22,
                    child: Text(
                      valueLabel,
                      style: TextStyle(
                        color: _neonGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (goalX - 1).clamp(0.0, totalWidth - 40),
                    top: 22,
                    child: Text(
                      goalLabel,
                      style: TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
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

      tp.paint(
        canvas,
        Offset(plotRect.left - tp.width - 10, y - tp.height / 2),
      );
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
        indices.add((t * lastIdx).round());
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

      tp.paint(canvas, Offset(max(0.0, x - tp.width / 2), plotRect.bottom + 6));
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
