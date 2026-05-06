import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 18.0;

class TrainerWidget extends StatefulWidget {
  final VoidCallback? onWorkoutSaved;
  const TrainerWidget({super.key, this.onWorkoutSaved});

  @override
  State<TrainerWidget> createState() => _TrainerWidgetState();
}

class _TrainerWidgetState extends State<TrainerWidget> {
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _geminiModel = 'gemini-2.5-flash';

  final List<_TrainerMsg> _trainerMsgs = <_TrainerMsg>[
    _TrainerMsg(
      role: _TrainerRole.model,
      text:
          "Hi, I'm your personal fitness trainer! I can answer fitness and nutrition questions, build diet and workout plans, and directly add ingredients, events, tasks, and workouts for you. What can I help you with?",
    ),
  ];

  final TextEditingController _trainerCtrl = TextEditingController();
  final ScrollController _trainerScroll = ScrollController();
  bool _trainerSending = false;
  bool _sidebarOpen = false;
  List<_ArchivedConversation> _archivedConversations = [];
  bool _archivedLoading = false;
  _ArchivedConversation? _viewingConversation;
  bool _suppressResumeWarning = false;

  SupabaseClient get _client => Supabase.instance.client;

  String _generateUuid() => const Uuid().v4();

  String _to12Hr(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1].padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0)
        hour = 12;
      else if (hour > 12)
        hour -= 12;
      return '$hour:$minute $ampm';
    } catch (_) {
      return time;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadArchivedConversations();
  }

  @override
  void dispose() {
    _trainerCtrl.dispose();
    _trainerScroll.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadUserSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _client
          .from('user_settings')
          .select('suppress_resume_warning')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        setState(() {
          _suppressResumeWarning = row['suppress_resume_warning'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveUserSettings({required bool suppressResumeWarning}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('user_settings').upsert({
        'user_id': user.id,
        'suppress_resume_warning': suppressResumeWarning,
      }, onConflict: 'user_id');
      if (mounted)
        setState(() => _suppressResumeWarning = suppressResumeWarning);
    } catch (_) {}
  }

  Future<void> _loadArchivedConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      if (mounted) setState(() => _archivedLoading = true);
      final rows = await _client
          .from('archived_conversations')
          .select('id, name, messages, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _archivedConversations = (rows as List)
            .map((r) => _ArchivedConversation.fromMap(r))
            .toList();
        _archivedLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _archivedLoading = false);
    }
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
          side: const BorderSide(color: _neonGreen, width: 1.5),
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
                  borderSide: const BorderSide(color: _neonGreen),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _neonGreen, width: 2),
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
              final n = ctrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, n);
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
      await _client.from('archived_conversations').insert({
        'user_id': user.id,
        'name': name,
        'messages': messages,
      });
      await _loadArchivedConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _neonGreen, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Conversation saved as "$name"',
              style: const TextStyle(color: _neonGreen),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save conversation: $e')),
        );
      }
    }
  }

  Future<void> _deleteArchivedConversation(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from('archived_conversations')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
      await _loadArchivedConversations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
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
            side: const BorderSide(color: _neonGreen, width: 1.5),
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
                    side: const BorderSide(color: _neonGreen),
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
    if (dontShowAgain) await _saveUserSettings(suppressResumeWarning: true);
    if (result == 'save') {
      await _showSaveConversationDialog();
      _doResume(conv);
    } else if (result == 'resume') {
      _doResume(conv);
    }
  }

  Future<void> _confirmDeleteConversation(_ArchivedConversation conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _neonGreen, width: 1.5),
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
        duration: const Duration(milliseconds: 250),
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
        {
          'name': 'log_ingredient',
          'description':
              'Add an ingredient to the users pantry on the Health tab. Ask for name, amount, and unit (g or cups) before calling.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'name': {'type': 'STRING', 'description': 'Ingredient name.'},
              'amount': {
                'type': 'NUMBER',
                'description': 'Serving amount, default 100.',
              },
              'unit': {
                'type': 'STRING',
                'description': 'Unit: g or cups. Default g.',
              },
            },
            'required': ['name'],
          },
        },
        {
          'name': 'add_event',
          'description':
              'Add an event to the users Events tab. Ask for title and date before calling. All other fields are optional.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING', 'description': 'Event title.'},
              'date': {
                'type': 'STRING',
                'description': 'Date in YYYY-MM-DD format.',
              },
              'description': {
                'type': 'STRING',
                'description': 'Optional description.',
              },
              'start_time': {
                'type': 'STRING',
                'description': 'Optional start time, e.g. 09:00.',
              },
              'end_time': {
                'type': 'STRING',
                'description': 'Optional end time, e.g. 10:00.',
              },
              'all_day': {
                'type': 'BOOLEAN',
                'description': 'Whether this is an all-day event.',
              },
            },
            'required': ['title', 'date'],
          },
        },
        {
          'name': 'add_task',
          'description':
              'Add a task to the users Events tab. First ask the user for the task name if not provided. Then ask if they want it to repeat on specific days. If they say no or want it as a one-time task, pass an empty list for days. Only pass day names if the user explicitly wants repetition.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'name': {'type': 'STRING', 'description': 'Task name.'},
              'days': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
                'description':
                    'Days to repeat e.g. ["Monday", "Wednesday"]. Pass empty list [] if the task should not repeat.',
              },
              'end_date': {
                'type': 'STRING',
                'description':
                    'Optional end date YYYY-MM-DD. Omit if indefinite.',
              },
            },
            'required': ['name', 'days'],
          },
        },
        {
          'name': 'log_workout',
          'description':
              'Save a workout to the users Workouts tab. Title is required, collect it first if not provided. '
              'Then ask if they want to add exercises if they are not provided. For each exercise ask for the name, then ask how many sets and for each set ask for lbs and reps. '
              'If the user skips optional fields, ask if they would like to add them and omit if the user does not want to. Always confirm before saving.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {
                'type': 'STRING',
                'description': 'Workout title, e.g. "Push Day".',
              },
              'date': {
                'type': 'STRING',
                'description':
                    'Date in YYYY-MM-DD format. Defaults to today if omitted.',
              },
              'exercises': {
                'type': 'ARRAY',
                'description':
                    'Optional list of exercises. Omit if user does not want to add any.',
                'items': {
                  'type': 'OBJECT',
                  'properties': {
                    'name': {
                      'type': 'STRING',
                      'description': 'Exercise name, e.g. "Bench Press".',
                    },
                    'sets': {
                      'type': 'ARRAY',
                      'description':
                          'List of sets. Omit if user does not want to add sets.',
                      'items': {
                        'type': 'OBJECT',
                        'properties': {
                          'lbs': {
                            'type': 'STRING',
                            'description':
                                'Weight in lbs, e.g. "135". Leave empty string if not provided.',
                          },
                          'reps': {
                            'type': 'STRING',
                            'description':
                                'Reps performed, e.g. "10". Leave empty string if not provided.',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            'required': ['title'],
          },
        },
        {
          'name': 'get_workouts',
          'description':
              'Fetch the users saved workouts for a specific date or today. Use this when the user asks about their workouts, wants to review past sessions, or asks what they did on a given day.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'date': {
                'type': 'STRING',
                'description':
                    'Date in YYYY-MM-DD format. Defaults to today if omitted.',
              },
            },
            'required': [],
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
      switch (name) {
        case 'log_weight_entry':
          final weight = (args['weight'] as num).toDouble();
          final dateKey = _todayKey();
          await _client.from('weight_entries').upsert({
            'user_id': user.id,
            'entry_date': dateKey,
            'weight': weight,
          }, onConflict: 'user_id,entry_date');
          return {'success': true, 'logged_weight': weight, 'date': dateKey};

        case 'update_goal_weight':
          final goal = (args['goal_weight'] as num).toDouble();
          await _client.from('weight_tracker_settings').upsert({
            'user_id': user.id,
            'goal_weight': goal,
          }, onConflict: 'user_id');
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
          return {
            'success': true,
            'calorie_goal': cal,
            'carbs_goal': carbs,
            'fat_goal': fat,
            'protein_goal': protein,
          };

        case 'log_ingredient':
          final ingName = args['name'].toString();
          final amount = (args['amount'] as num?)?.toDouble() ?? 100.0;
          final unit = (args['unit'] ?? 'g').toString();
          try {
            await _client.from('ingredients').insert({
              'user_id': user.id,
              'name': ingName,
              'serving_amount': amount,
              'serving_unit': unit,
            });
          } catch (_) {
            await _client.from('ingredients').insert({
              'user_id': user.id,
              'name': ingName,
            });
          }
          return {'success': true, 'added_ingredient': ingName};

        case 'add_event':
          final eventId = _generateUuid();
          await _client.from('user_events').insert({
            'id': eventId,
            'user_id': user.id,
            'title': args['title'].toString(),
            'date': '${args['date']}T00:00:00.000',
            'description': (args['description'] ?? '').toString(),
            'start_time': _to12Hr((args['start_time'] ?? '00:00').toString()),
            'end_time': _to12Hr((args['end_time'] ?? '23:59').toString()),
            'all_day': args['all_day'] ?? false,
            'days': [],
          });
          return {'success': true, 'added_event': args['title']};

        case 'add_task':
          final taskId = _generateUuid();
          await _client.from('user_tasks').insert({
            'id': taskId,
            'user_id': user.id,
            'name': args['name'].toString(),
            'days': args['days'] ?? [],
            'end_date': args['end_date'],
            'completed_dates': [],
          });
          return {'success': true, 'added_task': args['name']};

        case 'log_workout':
          final workoutId = _generateUuid();
          final workoutDate = (args['date'] as String?)?.isNotEmpty == true
              ? args['date'].toString()
              : _todayKey();
          final rawExercises = (args['exercises'] as List?) ?? [];
          final exercises = rawExercises.map((ex) {
            final exMap = ex as Map<String, dynamic>;
            final rawSets = (exMap['sets'] as List?) ?? [];
            final sets = rawSets.map((s) {
              final sMap = s as Map<String, dynamic>;
              return {
                'lbs': (sMap['lbs'] ?? '').toString(),
                'reps': (sMap['reps'] ?? '').toString(),
              };
            }).toList();
            return {'name': (exMap['name'] ?? '').toString(), 'sets': sets};
          }).toList();
          await _client.from('user_workouts').insert({
            'id': workoutId,
            'user_id': user.id,
            'title': args['title'].toString(),
            'workout_date': workoutDate,
            'exercises': exercises,
          });
          widget.onWorkoutSaved?.call();
          return {
            'success': true,
            'saved_workout': args['title'],
            'date': workoutDate,
            'exercise_count': exercises.length,
          };

        case 'get_workouts':
          final fetchDate = (args['date'] as String?)?.isNotEmpty == true
              ? args['date'].toString()
              : _todayKey();
          final rows = await _client
              .from('user_workouts')
              .select('title, workout_date, exercises')
              .eq('user_id', user.id)
              .eq('workout_date', fetchDate)
              .order('workout_date', ascending: false);
          if ((rows as List).isEmpty) {
            return {'date': fetchDate, 'workouts': []};
          }
          final summary = rows.map((w) {
            final exList = (w['exercises'] as List?) ?? [];
            return {
              'title': w['title'],
              'exercises': exList.map((e) {
                final sets = (e['sets'] as List?) ?? [];
                return {
                  'name': e['name'],
                  'sets': sets
                      .map((s) => '${s['lbs']}lbs x ${s['reps']} reps')
                      .toList(),
                };
              }).toList(),
            };
          }).toList();
          return {'date': fetchDate, 'workouts': summary};

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
        'You are a personal fitness, nutrition, and lifestyle coach with access to the users real data. '
        'You can add ingredients to their Health tab pantry, add events or tasks to their Events tab, and log or retrieve workouts on their Workouts tab. '
        'For workouts: only the title is required, collect it first, then optionally ask about exercises, sets, lbs, and reps one step at a time. '
        'Always ask for required fields before calling any tool. '
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

  @override
  Widget build(BuildContext context) {
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
                          side: const BorderSide(color: _neonGreen, width: 1.5),
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
                                      onTap: () => setState(() {
                                        _viewingConversation = conv;
                                        _sidebarOpen = false;
                                      }),
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
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neonGreen.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neonGreen.withOpacity(0.12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3.0;
              final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
              final opacity = (t < 0.5 ? t * 2 : (1.0 - t) * 2).clamp(
                0.25,
                1.0,
              );
              final offset = (t < 0.5 ? t * 2 : (1.0 - t) * 2) * -4.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, offset),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _neonGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _neonGreen.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ArchivedConversation {
  final String id;
  final String name;
  final List<_TrainerMsg> messages;
  final DateTime createdAt;

  _ArchivedConversation({
    required this.id,
    required this.name,
    required this.messages,
    required this.createdAt,
  });

  factory _ArchivedConversation.fromMap(Map<String, dynamic> m) {
    final msgs = (m['messages'] as List? ?? []).map((e) {
      final map = e as Map<String, dynamic>;
      final role = map['role'] == 'user'
          ? _TrainerRole.user
          : _TrainerRole.model;
      return _TrainerMsg(role: role, text: map['text'].toString());
    }).toList();
    return _ArchivedConversation(
      id: m['id'].toString(),
      name: m['name'].toString(),
      messages: msgs,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get formattedDate {
    final d = createdAt.toLocal();
    return '${d.month}/${d.day}/${d.year}';
  }
}

enum _TrainerRole { user, model }

class _TrainerMsg {
  final _TrainerRole role;
  final String text;
  _TrainerMsg({required this.role, required this.text});
}
