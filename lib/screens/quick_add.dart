import 'package:flutter/material.dart';
import 'fitness_page.dart' show FitnessPageState;

const Color _neonGreen = Color(0xFF00FF66);

void showQuickAddSheet(
  BuildContext context, {
  required Function(int) onNavigate,
  required GlobalKey<FitnessPageState> fitnessPageKey,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _neonGreen, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _neonGreen.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'QUICK ADD',
            style: TextStyle(
              color: _neonGreen,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              shadows: [Shadow(color: _neonGreen, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 20),
          // Top row — Journal and Barcode side by side
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuickAddButton(
                  icon: Icons.book_outlined,
                  label: 'Journal',
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: open journal
                  },
                ),
                const SizedBox(width: 12),
                _QuickAddButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Barcode\nScan',
                  onTap: () {
                    Navigator.pop(ctx);
                    // TODO: open barcode scanner
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              onNavigate(4);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fitnessPageKey.currentState?.expandTrainer();
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _neonGreen.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: _neonGreen, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trainer',
                          style: TextStyle(
                            color: _neonGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add ingredients, events & tasks, or ask fitness and nutrition questions',
                          style: TextStyle(
                            color: _neonGreen.withOpacity(0.6),
                            fontSize: 11,
                            shadows: [],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: _neonGreen.withOpacity(0.4),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickAddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonGreen.withOpacity(0.4), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _neonGreen, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
