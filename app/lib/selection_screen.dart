import 'package:flutter/material.dart';

import 'app_style.dart';
import 'catch_game.dart';
import 'catch_scene.dart';
import 'character.dart';
import 'character_picker.dart';
import 'drop_preview.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({
    super.key,
    required this.game,
    required this.world,
    required this.onSelect,
    required this.onTime,
    required this.onStart,
    this.onSettings,
    this.onGraphics,
  });
  final CatchGame game;
  final CatchScene world;
  final ValueChanged<CatchCharacter> onSelect;
  final ValueChanged<StageTime> onTime;
  final VoidCallback onStart;
  final VoidCallback? onSettings, onGraphics;
  static const paper = Colors.white, text = brandInk, muted = brandMuted;

  Widget item(bool bad) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bad ? Icons.close : Icons.check,
              size: 15,
              color: bad ? const Color(0xff996b83) : brandBlue,
            ),
            const SizedBox(width: 6),
            Text(
              bad ? 'はずれ' : 'あたり',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Text(
              bad
                  ? '−${game.balance['penalty'].round()}'
                  : '+${game.balance['beerPoints'].round()}〜',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
        Expanded(
          child: DropPreview(
            models: world.dropModels,
            environment: world.previewEnvironment,
            character: game.selectedCharacter,
            bad: bad,
          ),
        ),
        Text(
          bad
              ? game.selectedCharacter.badDrop.label
              : game.selectedCharacter.goodDrops.first.label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          !bad && game.selectedCharacter == CatchCharacter.sobaya
              ? 'つらい・LIGHT'
              : bad
              ? '避ける'
              : 'キャッチする',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: appTheme(),
    child: ColoredBox(
      color: paper,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, size) {
            // Landscape phones keep all actions on one screen; narrow windows scroll.
            final narrow = size.maxWidth < 620;
            final content = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 20 : 32,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ゆめみ採用試験',
                              style: TextStyle(
                                fontSize: 11,
                                color: muted,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'だれで挑む？',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (game.phase == Phase.result)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${game.score} pt',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'あたり ${game.caught}  /  はずれ ${game.bad}  /  逃した ${game.missed}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${game.roundSeconds.round()}秒の一本勝負',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: narrow ? 170 : 205,
                          child: CharacterPicker(
                            selected: game.selectedCharacter,
                            onSelected: onSelect,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.selectedCharacter.hint,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: Row(
                                  children: [
                                    item(false),
                                    const VerticalDivider(
                                      width: 20,
                                      thickness: 1,
                                      color: Color(0xffd3eee9),
                                      indent: 15,
                                      endIndent: 20,
                                    ),
                                    item(true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xffd3eee9)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '傾けて移動、スワイプで見回す。',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                      TimeOfDayToggle(
                        key: const ValueKey('time_of_day'),
                        selected: game.timeOfDay,
                        onChanged: onTime,
                      ),
                      const SizedBox(width: 8),
                      if (onGraphics != null)
                        IconButton(
                          key: const ValueKey('graphics_settings'),
                          tooltip: '画質設定',
                          onPressed: onGraphics,
                          icon: const Icon(
                            Icons.display_settings,
                            size: 17,
                            color: muted,
                          ),
                        ),
                      if (onSettings != null)
                        IconButton(
                          key: const ValueKey('balance_debug'),
                          tooltip: 'バランス調整',
                          onPressed: onSettings,
                          icon: const Icon(Icons.tune, size: 17, color: muted),
                        ),
                      const SizedBox(width: 12),
                      FilledButton(
                        key: const ValueKey('start'),
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff0074bd),
                          foregroundColor: paper,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          game.phase == Phase.result
                              ? 'もう一度挑む  →'
                              : 'このキャラで挑む  →',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            return DefaultTextStyle(
              style: const TextStyle(color: text, fontFamily: null),
              child: narrow || size.maxHeight < 340
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 720,
                        child: SingleChildScrollView(
                          child: SizedBox(height: 380, child: content),
                        ),
                      ),
                    )
                  : content,
            );
          },
        ),
      ),
    ),
  );
}

/// Sky-tinted pill switch for the stage time; the selected side shows its sky.
class TimeOfDayToggle extends StatelessWidget {
  const TimeOfDayToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final StageTime selected;
  final ValueChanged<StageTime> onChanged;

  static const _skies = {
    StageTime.day: [Color(0xffffc85c), Color(0xffff8a3d)],
    StageTime.night: [Color(0xff2b3f8f), Color(0xff121c45)],
  };
  static const _icons = {
    StageTime.day: Icons.wb_sunny_rounded,
    StageTime.night: Icons.nightlight_round,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: brandPale,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffd3eee9)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in StageTime.values)
          GestureDetector(
            key: ValueKey('time_${t.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: t == selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _skies[t]!,
                      )
                    : null,
                boxShadow: t == selected
                    ? [
                        BoxShadow(
                          color: _skies[t]!.last.withValues(alpha: .35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[t],
                    size: 15,
                    color: t == selected ? Colors.white : brandMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t == selected ? Colors.white : brandMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
