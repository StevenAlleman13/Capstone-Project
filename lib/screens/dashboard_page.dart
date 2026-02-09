import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _progress = 0;

  void _completeTask() {
    setState(() {
      if (_progress < 10) _progress++;
    });
  }

  void _resetProgress() {
    setState(() {
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _ProgressSectionFrame(title: 'PROGRESS BAR', progress: _progress),
          const SizedBox(height: 14),
          _DailyTasksSectionFrame(
            title: 'DAILY TASKS',
            progress: _progress,
            onComplete: _completeTask,
            onReset: _resetProgress,
          ),
          const SizedBox(height: 14),
          const _SectionFrame(title: 'REMAINING SCREEN TIME'),
        ],
      ),
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

class _SectionFrame extends StatelessWidget {
  final String title;

  const _SectionFrame({required this.title});

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

class _ProgressSectionFrame extends StatelessWidget {
  final String title;
  final int progress;

  const _ProgressSectionFrame({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final fillFraction = progress.clamp(0, 10) / 10.0;

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
          Row(
            children: [
              Expanded(
                child: _NeonProgressBar(value: fillFraction, neon: neon),
              ),
              const SizedBox(width: 12),
              Text(
                '$progress/10',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: neon,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeonProgressBar extends StatelessWidget {
  final double value;
  final Color neon;

  const _NeonProgressBar({required this.value, required this.neon});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: neon.withOpacity(0.95), width: 1.4),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.18), blurRadius: 14)],
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: neon,
              boxShadow: [
                BoxShadow(color: neon.withOpacity(0.35), blurRadius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyTasksSectionFrame extends StatelessWidget {
  final String title;
  final int progress;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  const _DailyTasksSectionFrame({
    required this.title,
    required this.progress,
    required this.onComplete,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;
    final isMaxed = progress >= 10;

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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isMaxed ? null : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: neon,
                    side: BorderSide(color: neon.withOpacity(0.9), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isMaxed ? 'All Done' : 'Complete Task'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: neon,
                    side: BorderSide(color: neon.withOpacity(0.9), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
