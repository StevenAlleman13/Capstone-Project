import 'package:flutter/material.dart';
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
        border: Border.all(color: neon.withOpacity(0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.12), blurRadius: 16)],
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
                  border: Border.all(color: neon.withOpacity(0.35), width: 1),
                  color: Colors.black,
                ),
              ),
        ],
      ),
    );
  }
}
