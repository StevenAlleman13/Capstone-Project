import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar is handled by main.dart already
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: const [
          _SectionFrame(title: 'PROGRESS BAR'),
          SizedBox(height: 14),
          _SectionFrame(title: 'DAILY TASKS'),
          SizedBox(height: 14),
          _SectionFrame(title: 'REMAINING SCREEN TIME'),
        ],
      ),
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

class _SectionFrame extends StatelessWidget {
  final String title;

  const _SectionFrame({
    required this.title,
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

          // Placeholder space so the widget doesn't look empty
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
