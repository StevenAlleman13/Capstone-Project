// import 'dart:ffi';

// import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:namer_app/main.dart' as m;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_picker_page.dart';
// import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';

const Color _neonGreen = Color(0xFF00FF66);
const double _cornerRadius = 4.0;

Color primaryColor = m.primaryColor;
Color secondaryColor = m.secondaryColor;
Color textColor = m.textColor;


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

  // load from supabase settings table into local variables. can not fathom the reason but it does not work.
  // for context: this function imitates every other load function in this project but one element that is exactly
  // the same in the same context and everything is throwing an error consistently both in VSCode and when ran.
  // No solution of the many I've tried works. Will fix it but don't have time right now -3/27/2026
  /*
  Future<void> _loadSettings() async { ... }
  */

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _neonGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          /* PROFILE TAB */  

          const _SectionFrame(
            title: 'PROFILE',
            child: _Profile(),  
          ),

          /* DIFFICULTY TAB */

          const SizedBox(height: 14),
          const _SectionFrame(
            title: 'DIFFICULTY',
            child: _DifficultySelector(),
          ),          /* THEME TAB */

          const SizedBox(height: 14),
          const _SectionFrame(
            title: 'THEME',
            child: _ThemeSelector(),
          ),
    
          /* ADVANCED TAB */
          const SizedBox(height: 14),
          const _SectionFrame(
            title: 'ADVANCED',
            child: _AdvancedSettings(),
            ),

          /* PERMISSIONS TAB */

          const SizedBox(height: 14),
          _SectionFrame(
            title: 'PERMISSIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,                  title: const Text(
                    'Locked Apps',
                    style: TextStyle(color: Colors.white, fontSize: 15),
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
              alignment: Alignment.centerLeft,              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Log out', style: TextStyle(color: Colors.white)),
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
      contentPadding: EdgeInsets.zero,      title: Text(
        'App Overlay',
        style: TextStyle(
          color: Colors.white,
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
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,      title: Text(
        'Notifications',
        style: TextStyle(
          color: Colors.white,
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
  String _difficulty = 'normal';

  static const _options = [
    ('easy', 'Easy', '4 hrs'),
    ('normal', 'Normal', '2 hrs'),
    ('hardcore', 'Hardcore', '1 hr'),
    ('custom', 'Custom', '? hrs'),
  ];

  @override
  void initState() {
    super.initState();
    _difficulty = Hive.box('selected_apps').get('difficulty', defaultValue: 'normal') as String;
  }

  void _select(String value) {
    Hive.box('selected_apps').put('difficulty', value);
    setState(() => _difficulty = value);
  }
  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _options.map((opt) {
          final (value, label, hours) = opt;
          final isSelected = _difficulty == value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
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
                  children: [                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? neon : Colors.white, shadows: [],
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hours,
                      style: TextStyle(
                        color: isSelected ? neon.withValues(alpha: 0.8) : Colors.white70,
                        fontSize: 11,
                        shadows: [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

/* --------------------------- THEME SELECTOR ----------------------------- */

class _ThemeSelector extends StatefulWidget {
  const _ThemeSelector();

  @override
  State<_ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<_ThemeSelector> {
  String _theme = 'dark';

  static const _options = [
    ('dark', 'Dark', Icons.dark_mode),
    ('light', 'Light', Icons.light_mode),
    ('custom', 'Custom', Icons.palette),
  ];

  @override
  void initState() {
    super.initState();
    _theme = Hive.box('selected_apps').get('theme', defaultValue: 'dark') as String;
  }

  void _select(String value) {
    Hive.box('selected_apps').put('theme', value);
    setState(() => _theme = value);
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _options.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = _theme == value;
        return GestureDetector(
          onTap: () => _select(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? neon : Colors.grey.shade700,
                width: isSelected ? 1.8 : 1.0,
              ),
              color: isSelected ? neon.withValues(alpha: 0.08) : Colors.transparent,
            ),
            child: Column(
              children: [                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? neon : Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? neon : Colors.white,
                    shadows: [],
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
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

/* -------------------------- SHARED SECTION FRAME (cont.) -------------------------- */

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
        color: primaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),

          child ??
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neon.withValues(alpha: 0.35), width: 1),
                  color: primaryColor,
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
  final _screentimeController = TextEditingController();
  int? _maxScreentime;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _screentimeController.dispose();
    super.dispose();
  }

  Future<void> _saveMaxScreentime(int screentimeLimit) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('settings').upsert({
        'user_id': user.id,
        'max_screentime': screentimeLimit,
      }, onConflict: 'user_id');

      if (mounted) setState(() => _maxScreentime = screentimeLimit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save max screentime.',
                style: TextStyle(color: secondaryColor)),
          ),
        );
      }
    }
  }

  void _showSetScreentimeDialog() {
    _screentimeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: secondaryColor, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Set Max Screentime', style: TextStyle(color: secondaryColor)),        content: TextField(
          controller: _screentimeController,
          cursorColor: Colors.white,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: secondaryColor),
          decoration: InputDecoration(
            labelText: 'Max Screentime (minutes)',
            labelStyle: TextStyle(color: secondaryColor),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: secondaryColor),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: secondaryColor, width: 2),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: secondaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final timevar = int.tryParse(_screentimeController.text.trim());
              if (timevar != null) _saveMaxScreentime(timevar);
            },
            child: Text(
              'Set',
              style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _showSetScreentimeDialog,          style: OutlinedButton.styleFrom(
            side: BorderSide(color: secondaryColor, width: 1.5),
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
          ),
          child: Text(
            _maxScreentime != null
                ? 'Set Max Screentime (${_maxScreentime!} min)'
                : 'Set Max Screentime',
          ),
        ),
      ],
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
  final _usernameController = TextEditingController();
  String _username = '...';
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final fetched = (row?['username'] ?? '').toString();
      if (fetched.isNotEmpty && fetched != _username) {
        setState(() {
          _username = fetched;
          _usernameController.text = _username;
        });
      }
    } catch (_) {
      // keep current _username as-is
    }
  }

  Future<void> _saveUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty || newName == _username) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'username': newName,
      }, onConflict: 'id');

      if (!mounted) return;
      setState(() {
        _username = newName;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username updated!', style: TextStyle(color: secondaryColor)),
          backgroundColor: Colors.grey[900],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update username.', style: TextStyle(color: Colors.red)),
          backgroundColor: Colors.grey[900],
        ),
      );
    }
  }

  void _showEditUsernameDialog() {
    _usernameController.text = _username;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: secondaryColor, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Edit Username', style: TextStyle(color: secondaryColor)),        content: TextField(
          controller: _usernameController,
          cursorColor: textColor,
          style: TextStyle(color: secondaryColor),
          maxLength: 24,
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: secondaryColor.withOpacity(0.7)),
            counterStyle: TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: secondaryColor),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: secondaryColor, width: 2),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: secondaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveUsername();
            },
            child: Text(
              'Save',
              style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {    final displayName = _saving ? 'Saving...' : _username;

    return Row(
      children: [
        // ── Profile picture (left) ──
        GestureDetector(
          onTap: () {
            // TODO: implement profile picture upload
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile picture upload coming soon!',
                  style: TextStyle(color: secondaryColor),
                ),
                backgroundColor: Colors.grey[900],
              ),
            );
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [              CircleAvatar(
                backgroundColor: const Color.fromARGB(255, 46, 46, 46),
                radius: 45,
                child: const Icon(Icons.person, size: 49, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: _neonGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 14, color: Colors.black),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // ── Username (right) ──
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showEditUsernameDialog,
                child: const Icon(Icons.edit, color: _neonGreen, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}