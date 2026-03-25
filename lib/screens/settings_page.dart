// import 'dart:ffi';

// import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_picker_page.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';

const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 4.0;

/* test settings page stateful widget 
  
I decided to not go for the extendable tabs for settings, just didn't feel like it made sense. 
Leaving it here if we want to revisit it.

- A (3/23/2026)

// settings tab superclass
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// settings page state
class _SettingsPageState extends State<SettingsPage> {
  // page settings
  String? entrytab; // tracks tab you entered settings page from to return to when done

  // default values for settings (if null/new user, these are default values)
  final String DEFAULT_DIFFICULTY = "normal";
  final String DEFAULT_THEME = "darkmode";
  final int DEFAULT_MAX = 120;

  // settings
  String? _difficulty;
  String? _theme;
  int? _maxScreenTime; // in minutes


  // flags and page vars 
  bool _loading = true; 
  String? _statusText;

  bool _profileExpanded = false; // edit profile, change password, log out function
  bool _generalExpanded = false; // difficulty, notifications
  bool _advancedExpanded = false; // permissions, exact time limit (would set difficulty to 'custom' automatically if used)

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadSettingsFromSupabase(),
      // _loadProfileFromSupabase()   does not need implementation yet (3/20/2026)
    ]);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /*----------------------------------- Settings ---------------------------------- */

  Future<void> _loadSettingsFromSupabase() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        
        return;
      }
    }

    try {
      final row = await _client
          .from('settings')
          .select('difficulty, max_screentime, theme')
          .eq('userid', user.id)
          .maybeSingle();

      if (row == null) return;

      final difficulty = row['difficulty'];
      final maxScreentime = row['max_screentime'];
      final theme = row['theme'];


      if (!mounted) return;
      setState(() {
        _difficulty = difficulty;
        _theme = theme;
        _maxScreenTime = maxScreentime;
        if (difficulty != null) _difficulty = "normal";
        if (maxScreentime != null) _maxScreenTime = 120;
        if (theme != null) _theme = "darkmode";
      });
    } catch (e) {
      if (mounted)
        setState(() => _statusText = 'Could not load settings.');
    }
  }
}

*/


// settings tab superclass
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _screentimeController = TextEditingController();

  // default values for settings (if null/new user, these are default values)
  final String DEFAULT_DIFFICULTY = "normal";
  final String DEFAULT_THEME = "darkmode";
  final int DEFAULT_MAX = 120; // in minutes

  // settings
  String? _difficulty;
  String? _theme;
  int? _maxScreenTime; // in minutes


  // flags and page vars 
  bool _loading = true;
  String? _statusText;

  // supabase client
  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      // _loadSettings(),
      // _loadProfileFromSupabase()   will not be implemented until sprint 5 (3/20/2026)
    ]);
  }

  @override
  void dispose() {
    _screentimeController.dispose();
    super.dispose();
  }

  // load from supabase settings table into local variables. can not fathom the reason but it does not work
  /*
  Future<void> _loadSettings() async {
    if (mounted) setState(() => _loading = true);

    User? user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        if (mounted) setState(() => _statusText = "Not signed in (no user session found)");
        return;
      }
    }
    try {
      final row = await _client
          .from('user_settings')
          .select('difficulty max_screentime, theme')
          .eq('user_id', user.id)
          .single();

      if (row == null) return;

      final difficulty = row['difficulty'];
      final maxScreentime = row['max_screentime'];
      final theme = row['theme'];


      if (!mounted) return;
      setState(() {
        _difficulty = difficulty;
        _theme = theme;
        _maxScreenTime = maxScreentime;
        if (difficulty != null) _difficulty = 'normal';
        if (maxScreentime != null) _maxScreenTime = 120;
        if (theme != null) _theme = 'darkmode';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Could not load settings.');
      }
    }
  }
  */
  // save max screentime to supabase
  Future<void> _saveMaxScreentime(int screentimeLimit) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('settings').upsert({
        'user_id': user.id,
        'max_screentime': screentimeLimit,
      }, onConflict: 'user_id');

      if (mounted) {
        setState(() {
          _maxScreenTime = screentimeLimit;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save max screentime.',
              style: TextStyle(color: _neonGreen),
            ),
          ),
        );
      }
    }
  }

  // save difficulty to supabase
  Future<void> _saveDifficulty(String newDifficulty) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('settings').upsert({
        'user_id': user.id,
        'difficulty': newDifficulty,
      }, onConflict: 'user_id');

      if (mounted) {
        setState(() {
          _difficulty = newDifficulty;
          if (_difficulty == 'easy') {
            _saveMaxScreentime(240);
          } 
          else if (_difficulty == 'normal') {
            _saveMaxScreentime(120);
          }
          else if (_difficulty == 'hardcore') {
            _saveMaxScreentime(60);
          }
          
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save difficulty.',
              style: TextStyle(color: _neonGreen),
            ),
          ),
        );
      }
    }
  }
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
  // pop up that prompts user to enter in
  void _showSetScreentimeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Set Max Screentime', style: TextStyle(color: _neonGreen)),
        content: TextField(
          controller: _screentimeController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _neonGreen),
          decoration: _inputDecoration('Max Screentime'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _setScreentime();
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
  // parse text controller for data and check validity
  Future<void> _setScreentime() async {
    final timevar = int.tryParse(_screentimeController.text.trim());
    if (timevar == null) return;

    if (mounted) setState(() => _maxScreenTime = timevar);

    await _saveMaxScreentime(timevar);
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          /* PROFILE TAB */  

           // -- will be fully implemented in sprint 5. -3/23/2026

          const _SectionFrame(
            title: 'PROFILE',
            child: _Profile(),  
          ),

          /* DIFFICULTY TAB */

          const SizedBox(height: 14),
          const _SectionFrame(
            title: 'DIFFICULTY',
            child: _DifficultySelector(),
          ),

          /* THEME TAB */

          const SizedBox(height: 14),
          const _SectionFrame(title: 'THEME'),
    
          /* ADVANCED TAB */

          const _SectionFrame(
            title: 'ADVANCED',
            child: _AdvancedSettings(),
            ),

          const SizedBox(height: 14),

          /* PERMISSIONS TAB */

          const SizedBox(height: 14),
          _SectionFrame(
            title: 'PERMISSIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,

                  title: const Text(
                    'Locked Apps',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppPickerPage()),
                  ),
                ),

                const Divider(color: Colors.white12, height: 20),

                const _OverlayPermissionButton(),

                const Divider(color: Colors.white12, height: 20),

                const _NotificationButton(),

              ],
            ),
          ),
          const SizedBox(height: 14),

          /* LOG OUT */

          _SectionFrame(
            title: 'LOG OUT',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () => _logout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------- OVERLAY PERMISSION BUTTON ----------------------- */

class _OverlayPermissionButton extends StatefulWidget {
  const _OverlayPermissionButton();

  @override
  State<_OverlayPermissionButton> createState() => _OverlayPermissionButtonState();
}

class _OverlayPermissionButtonState extends State<_OverlayPermissionButton>
    with WidgetsBindingObserver {
  static final _channel = MethodChannel('lockin/monitor');
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
      if (mounted) setState(() => _granted = granted);
    } catch (_) {}
  }

  Future<void> _request() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'App Overlay',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
      ),
      trailing: Switch(
        value: _granted,
        onChanged: _granted ? null : (_) => _request(),
        activeThumbColor: neon,
      ),
    );
  }
}

/* ----------------------- NOTIFICATIONS PERMISSION BUTTON ----------------------- */

class _NotificationButton extends StatefulWidget {
  const _NotificationButton();

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton>
    with WidgetsBindingObserver {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }
  // checks permission settings for notifications
  // attempts to redirect user
  Future<bool> _checkNotificationSettings() async {
    PermissionStatus status = await Permission.notification.status;

    if (status.isGranted) 
    {
      return true;
    } 
    else if (status.isDenied) 
    {
      // requests permission 
      await _request();
      return false;
    } 
    else if (status.isPermanentlyDenied) 
    {
      // redirect user to app settings
      await openAppSettings();
      return false;
    } 
    else 
    {
      return false;
    }
  }
  // updates '_granted' var based on return value
  Future<void> _checkPermission() async {
    try {
      final granted = await _checkNotificationSettings();
      if (mounted) setState(() => _granted = granted);
    } catch (_) {}
  }

  Future<void> _request() async {
    PermissionStatus newStatus = await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Notifications',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
      ),
      trailing: Switch(
        value: _granted,
        onChanged: _granted ? null : (_) => _request(),
        activeThumbColor: neon,
      ),
    );
  }
}




/* -------------------------- DIFFICULTY SELECTOR --------------------------- */

class _DifficultySelector extends StatefulWidget {
  const _DifficultySelector();

  @override
  State<_DifficultySelector> createState() => _DifficultySelectorState();
}

class _DifficultySelectorState extends State<_DifficultySelector> {
  String difficulty = 'normal';

  static const _options = [
    ('easy', 'Easy', '4 hrs'),
    ('normal', 'Normal', '2 hrs'),
    ('hardcore', 'Hardcore', '1 hr'),
    ('custom', 'Custom', '? hrs'),
  ];

  @override
  void initState() {
    super.initState();
    difficulty = Hive.box('selected_apps').get('difficulty', defaultValue: _SettingsPageState()._difficulty) as String;
  }

  void _select(String value) {
    Hive.box('selected_apps').put('difficulty', value);
    setState(() => _SettingsPageState()._difficulty = value);
    _SettingsPageState()._saveDifficulty(difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _options.map((opt) {
        final (value, label, hours) = opt;
        final isSelected = difficulty == value;
        return GestureDetector(
          onTap: () => _select(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? neon : Colors.grey.shade700,
                width: isSelected ? 1.8 : 1.0,
              ),
              color: isSelected ? neon.withValues(alpha: 0.08) : Colors.transparent,
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? neon : Colors.grey, shadows: [],
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hours,
                  style: TextStyle(
                    color: isSelected ? neon.withValues(alpha: 0.8) : Colors.grey.shade600,
                    fontSize: 11,
                    shadows: [],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

class _SectionFrame extends StatelessWidget {
  final String title;
  final Widget? child;

  const _SectionFrame({
    required this.title,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withValues(alpha: 0.12), blurRadius: 16)],
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: neon,
                ),
          ),
          const SizedBox(height: 10),

          child ??
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neon.withValues(alpha: 0.35), width: 1),
                  color: Colors.black,
                ),
              ),
        ],
      ),
    );
  }
}


/* -------------------------- ADVANCED SECTION FRAME -------------------------- */



class _AdvancedSettings extends StatefulWidget {
  const _AdvancedSettings();

  @override
  State<_AdvancedSettings> createState() => _AdvancedSettingsState();
}

class _AdvancedSettingsState extends State<_AdvancedSettings> {
  int? maxScreentime = _SettingsPageState()._maxScreenTime;


  // pop up that prompts user to enter in
  /*
  void _showSetScreentimeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _neonGreen, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Set Max Screentime', style: TextStyle(color: _neonGreen)),
        content: TextField(
          controller: _SettingsPageState()._screentimeController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _neonGreen),
          decoration: _SettingsPageState()._inputDecoration('Max Screentime'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _neonGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _SettingsPageState()._setScreentime();
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
  */

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlinedButton(
        onPressed: _SettingsPageState()._loading ? null : _SettingsPageState()._showSetScreentimeDialog,
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
          maxScreentime != null
              ? 'Set Max Screentime (${(maxScreentime!)})'
              : 'Set Max Screentime',
          ),
        ),
      ]
    );
  }
}



/* -------------------------- USER PROFILE SECTION FRAME -------------------------- */

class _Profile extends StatefulWidget {
  const _Profile();

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {


  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar( 
          backgroundColor: const Color.fromARGB(255, 46, 46, 46),
          radius: 128,
          child: const Text(
            'Profile Picture Sample',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(255, 112, 112, 112))
          ),
        )
      ],
    );
  }

}