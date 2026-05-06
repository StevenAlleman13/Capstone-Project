import 'package:flutter/material.dart';
import '../widgets/trainer_widget.dart';
import 'package:namer_app/main.dart' as m;

// const Color _neonGreen = Color(0xFF00FF66);

Future<void> showQuickAddSheet(
  BuildContext context, {
  required Function(int) onNavigate,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: MediaQuery.of(ctx).viewInsets,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: m.primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: m.secondaryColor, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: m.secondaryColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'AI TRAINER',
                style: TextStyle(
                  color: m.secondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [Shadow(color: m.secondaryColor, blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: TrainerWidget(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
