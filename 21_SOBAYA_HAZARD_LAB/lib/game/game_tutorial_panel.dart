import 'package:flutter/material.dart';

import 'game_state.dart';
import 'game_tutorial_text.dart';

/// Keep the aiming area and movement controls free; spoken coaching is optional text.
class HazardTutorialPanel extends StatelessWidget {
  const HazardTutorialPanel({
    super.key,
    required this.state,
    required this.mobile,
    required this.onRetry,
    required this.onFinish,
  });
  final HazardGameState state;
  final bool mobile;
  final VoidCallback onRetry, onFinish;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xffc8b077);
    final s = state;
    return Material(
      key: const ValueKey('game-tutorial-panel'),
      color: const Color(0xb8181b17),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '実地研修 ${tutorialSteps.indexOf(s.tutorialStep!) + 1} / 7',
                    style: const TextStyle(color: gold, fontSize: 12),
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('game-tutorial-menu'),
                  tooltip: '研修の説明・やり直し',
                  icon: const Icon(Icons.more_horiz, color: gold, size: 20),
                  onSelected: (value) {
                    if (value == 'retry') onRetry();
                    if (value == 'skip') onFinish();
                    if (value == 'help') {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('やめ太郎の説明'),
                          content: Text(
                            '${tutorialCoachLines[s.tutorialStep]}\n\n${s.tutorialControlHint(mobile)}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('閉じる'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'help', child: Text('説明を読む')),
                    PopupMenuItem(value: 'retry', child: Text('この練習をやり直す')),
                    PopupMenuItem(value: 'skip', child: Text('練習をスキップ')),
                  ],
                ),
              ],
            ),
            Text(
              s.tutorialObjective,
              key: const ValueKey('game-tutorial-objective'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.tutorialControlHint(mobile),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (s.tutorialStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  s.tutorialStatus,
                  key: const ValueKey('game-tutorial-status'),
                  style: const TextStyle(color: gold, fontSize: 12),
                ),
              ),
            if (s.tutorialStep == 'complete')
              FilledButton(onPressed: onFinish, child: const Text('村へ出発')),
          ],
        ),
      ),
    );
  }
}
