import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:namer_app/main.dart' as m;

// const Color _neonGreen = Color(0xFF00FF66);

class AppPickerPage extends StatefulWidget {
  const AppPickerPage({super.key});

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  List<AppInfo> _apps = [];
  Set<String> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final box = Hive.box('selected_apps');
      final saved = List<String>.from(box.get('packages', defaultValue: <String>[]));

      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _apps = apps;
        _selected = Set<String>.from(saved);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final box = Hive.box('selected_apps');
    await box.put('packages', _selected.toList());
    if (mounted) Navigator.pop(context);
  }

  void _toggle(String packageName) {
    setState(() {
      if (_selected.contains(packageName)) {
        _selected.remove(packageName);
      } else {
        _selected.add(packageName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: m.primaryColor,
      appBar: AppBar(
        backgroundColor: m.accent1,
        title: Text(
          'Select Apps',
          style: TextStyle(
            color: m.textColor,
            letterSpacing: 1.2,
            shadows: [],
          ),
        ),
        iconTheme: IconThemeData(color: m.textColor), 
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: m.textColor),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: m.secondaryColor),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load apps:\n$_error',
                      style: TextStyle(color: Colors.red[400], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    final isSelected = _selected.contains(app.packageName);

                    final iconWidget = app.icon != null
                        ? Image.memory(
                            app.icon!,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, _, _) =>
                                Icon(Icons.android, color: m.secondaryColor, size: 40),
                          )
                        : Icon(Icons.android, color: m.secondaryColor, size: 40);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => _toggle(app.packageName),
                      activeColor: m.secondaryColor,
                      checkColor: m.primaryColor,
                      tileColor: m.primaryColor,
                      secondary: iconWidget,
                      title: Text(
                        app.name,
                        style: TextStyle(color: m.secondaryColor),
                      ),
                    );
                  },
                ),
    );
  }
}
