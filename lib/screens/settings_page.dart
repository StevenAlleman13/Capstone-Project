import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_picker_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          const _SectionFrame(title: 'ADVANCED'),
          const SizedBox(height: 14),
          _SectionFrame(
            title: 'SCREEN TIME',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.apps),
                label: const Text('Select Apps'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppPickerPage()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _SectionFrame(
            title: 'DIFFICULTY',
            child: _DifficultySelector(),
          ),
          const SizedBox(height: 14),
          const _SectionFrame(title: 'LIGHT / DARK MODE'),
          const SizedBox(height: 14),

          _SectionFrame(
            title: 'ACCOUNT',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _options.map((opt) {
        final (value, label, hours) = opt;
        final isSelected = _difficulty == value;
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
