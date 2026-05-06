import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:app_settings/app_settings.dart'; -- 
import 'package:namer_app/main.dart' as m;
import 'package:namer_app/main.dart' show refresh;

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

  Future<void> refreshPage(BuildContext context) async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: m.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: m.secondaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(color: m.textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          /* PROFILE TAB */
          _SectionFrame(
            title: 'PROFILE',
            infoText:
                'Use on the pencil button at the bottom right of the profile image to change your profile character. Use the other pencil button on the right to change your username.',
            child: _Profile(),
          ),          
          /* THEME TAB */
          const SizedBox(height: 14),
          _SectionFrame(
            title: 'THEME',
            infoText:
                'Change your theme from dark, light, or custom mode for the app appearance.',
            child: _ThemeSelector(),
          ),
          const SizedBox(height: 14),

          /* LOG OUT */
          _SectionFrame(
            title: 'LOG OUT',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: Icon(Icons.logout, color: m.textColor),
                label: Text(
                  'Log out',
                  style: TextStyle(color: m.textColor),
                ),
                onPressed: () => _logout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------- THEME SELECTOR ----------------------------- */

class _ThemeSelector extends StatefulWidget {
  const _ThemeSelector();

  @override
  State<_ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<_ThemeSelector> {
  String _theme = 'dark';
  bool changedFlag = false;

  static const _options = [
    ('dark', 'Dark', Icons.dark_mode),
    ('light', 'Light', Icons.light_mode),
    ('custom', 'Custom', Icons.palette),
  ];

  @override
  void initState() {
    super.initState();
    _theme =
        Hive.box('selected_apps').get('theme', defaultValue: 'dark') as String;
  }

  void _select(String value) {
    Hive.box('selected_apps').put('theme', value);
    setState(() {
      _theme = value;
      changedFlag = true; 
      }
    );
    _SettingsPageState().refreshPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    // set theme
    if (_theme == 'dark' && changedFlag) {
      // color vars
      m.primaryColor = m.primaryColorDark;
      m.secondaryColor = m.secondaryColorDark;
      m.textColor = m.textColorDark;
      m.accent0 = m.primaryAccent0Dark;
      m.accent1 = m.primaryAccent1Dark;
      m.accent2 = m.primaryAccent2Dark;
      m.accent3 = m.primaryAccent3Dark;
      m.accent4 = m.primaryAccent4Dark;
      // flag
      changedFlag = false;
      refresh();
    }
    else if (_theme == 'light' && changedFlag) {
      // color vars
      m.primaryColor = m.primaryColorLight;
      m.secondaryColor = m.secondaryColorLight;
      m.textColor = m.textColorLight;
      m.accent0 = m.primaryAccent0Light;
      m.accent1 = m.primaryAccent1Light;
      m.accent2 = m.primaryAccent2Light;
      m.accent3 = m.primaryAccent3Light;
      m.accent4 = m.primaryAccent4Light;
      // flag
      changedFlag = false;
      refresh();
    }
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
                color: isSelected ? neon : m.accent3,
                width: isSelected ? 1.8 : 1.0,
              ),
              color: isSelected
                  ? neon.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Column(
              children: [
                Icon(icon, size: 24, color: isSelected ? neon : m.textColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? neon : m.textColor,
                    shadows: [],
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
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
  final String? infoText;

  const _SectionFrame({required this.title, this.child, this.infoText});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(color: neon.withValues(alpha: 0.12), blurRadius: 16),
        ],
        color: m.primaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: m.textColor,
                  ),
                ),
              ),
              if (infoText != null) ...[
                _InfoButton(infoText: infoText, iconColor: neon),
              ],
            ],
          ),
          const SizedBox(height: 10),

          child ??
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: neon.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  color: m.primaryColor,
                ),
              ),
        ],
      ),    );
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
  final _avatarMakerKey = GlobalKey();
  String _username = '...';
  bool _saving = false;
  String _avatarSvg = ''; // Store avatar SVG as string

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
  }  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('profiles')
          .select('username, avatar_svg')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final fetched = (row?['username'] ?? '').toString();
      final avatarSvg = (row?['avatar_svg'] ?? '').toString();
      
      if (fetched.isNotEmpty) {
        setState(() {
          _username = fetched;
          _usernameController.text = _username;
          if (avatarSvg.isNotEmpty) {
            _avatarSvg = avatarSvg;
          }
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
          content: Text(
            'Username updated!',
            style: TextStyle(color: m.secondaryColor),
          ),
          backgroundColor: m.accent1,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update username.',
            style: TextStyle(color: Colors.red),
          ),
          backgroundColor: m.accent1,
        ),      );
    }
  }  Future<void> _openAvatarMaker() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    String? newAvatarSvg;

    // Open avatar maker customizer in a dialog
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: m.primaryColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: m.secondaryColor, width: 1.5),
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Customize Avatar',
                    style: TextStyle(color: m.secondaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: AvatarMakerCustomizer(
                  key: _avatarMakerKey,
                ),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: m.secondaryColor)),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        final controller = Get.find<AvatarMakerController>();
                        await controller.saveAvatarSVG();
                        newAvatarSvg = controller.displayedAvatarSVG.value;
                      } catch (e) {
                        newAvatarSvg = null;
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Save',
                      style: TextStyle(color: m.secondaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Save avatar SVG if we got one
    if (newAvatarSvg == null || newAvatarSvg!.isEmpty) return;

    try {
      setState(() => _saving = true);
      
      await _client.from('profiles').upsert({
        'id': user.id,
        'avatar_svg': newAvatarSvg,
      }, onConflict: 'id');

      if (!mounted) return;
      setState(() {
        _avatarSvg = newAvatarSvg!;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Avatar updated!',
            style: TextStyle(color: m.secondaryColor),
          ),
          backgroundColor: m.accent1,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      print('Error saving avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save avatar: $e',
            style: TextStyle(color: Colors.red),
          ),
          backgroundColor: m.accent1,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

    void _showEditUsernameDialog() {
    _usernameController.text = _username;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: m.primaryColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: m.secondaryColor, width: 1.5),
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
        title: Text('Edit Username', style: TextStyle(color: m.secondaryColor)),
        content: TextField(
          controller: _usernameController,
          cursorColor: m.textColor,
          style: TextStyle(color: m.secondaryColor),
          maxLength: 24,
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: m.secondaryColor.withOpacity(0.7)),
            counterStyle: TextStyle(color: m.accent4),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: m.secondaryColor),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: m.secondaryColor, width: 2),
              borderRadius: BorderRadius.circular(_cornerRadius),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: m.secondaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveUsername();
            },
            child: Text(
              'Save',
              style: TextStyle(color: m.secondaryColor, fontWeight: FontWeight.bold),
            ),          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _saving ? 'Saving...' : _username;
    final userInitial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';

    return Row(
      children: [
        // ── Profile picture (left) ──
        GestureDetector(
          onTap: _openAvatarMaker,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: _avatarSvg.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: m.secondaryColor, width: 2),
                          ),
                          child: SvgPicture.string(
                            _avatarSvg,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                m.secondaryColor.withValues(alpha: 0.3),
                                m.secondaryColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: m.secondaryColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              userInitial,
                              style: TextStyle(
                                color: m.secondaryColor,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: m.secondaryColor,
                                    blurRadius: 8.0,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: m.secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit, size: 14, color: m.primaryColor),
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
                  style: TextStyle(
                    color: m.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showEditUsernameDialog,
                child: Icon(Icons.edit, color: m.secondaryColor, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
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
                        color: m.primaryColor,
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
