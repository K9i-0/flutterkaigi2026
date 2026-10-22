import 'package:flutter/material.dart';

import 'app_style.dart';
import 'catch_game.dart';
import 'catch_scene.dart';
import 'character.dart';
import 'character_picker.dart';
import 'drop_preview.dart';
import 'l10n.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({
    super.key,
    required this.game,
    required this.world,
    required this.onSelect,
    required this.onTime,
    required this.onStart,
    required this.onPractice,
    required this.onRanking,
    required this.lang,
    required this.onLang,
    required this.onTitle,
    this.rank,
    this.onSettings,
    this.onGraphics,
  });
  final CatchGame game;
  final CatchScene world;
  final ValueChanged<CatchCharacter> onSelect;
  final ValueChanged<StageTime> onTime;
  final VoidCallback onStart, onPractice, onRanking;
  final AppLang lang;
  final ValueChanged<AppLang> onLang;
  final VoidCallback onTitle;

  /// Saved rank of the round shown in the result header, if recorded.
  final String? rank;
  final VoidCallback? onSettings, onGraphics;
  static const paper = Colors.white, text = brandInk, muted = brandMuted;

  Widget item(Strings t, bool bad) {
    final character = game.selectedCharacter;
    final detail = t.dropDetail(
      bad ? character.badDrop : character.goodDrops.first,
    );
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                bad ? Icons.close : Icons.check,
                size: 14,
                color: bad ? const Color(0xff996b83) : brandBlue,
              ),
              const SizedBox(width: 4),
              Text(
                bad ? t.bad : t.good,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bad
                    ? '−${game.balance['penalty'].round()}'
                    : '+${game.balance['beerPoints'].round()}〜',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DropPreview(
              models: world.dropModels,
              environment: world.previewEnvironment,
              character: character,
              bad: bad,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          // Two note lines are reserved so both names stay on one baseline.
          SizedBox(
            height: 27,
            child: Text(
              detail.note ??
                  (!bad && character == CatchCharacter.sobaya
                      ? t.sobayaBrands
                      : bad
                      ? t.avoidIt
                      : t.catchIt),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 10, color: muted, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Theme(
      data: appTheme(),
      child: ColoredBox(
        color: paper,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, size) {
              // Landscape phones keep all actions on one screen; narrow windows scroll.
              final narrow = size.maxWidth < 620;
              final content = Padding(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 20 : 28,
                  10,
                  narrow ? 20 : 28,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          key: const ValueKey('back_to_title'),
                          tooltip: t.backToTitle,
                          onPressed: onTitle,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.chooseCharacter,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.appTitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: muted,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (game.phase == Phase.result)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${game.score} pt${rank == null ? '' : '  ·  $rank'}',
                                key: const ValueKey('result_score'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                t.results(game.caught, game.bad, game.missed),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            t.roundLength(game.roundSeconds.round()),
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        const SizedBox(width: 12),
                        LanguageToggle(selected: lang, onChanged: onLang),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 11,
                            child: CharacterPicker(
                              selected: game.selectedCharacter,
                              onSelected: onSelect,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 9,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  t.hint(game.selectedCharacter),
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      item(t, false),
                                      const VerticalDivider(
                                        width: 16,
                                        thickness: 1,
                                        color: Color(0xffd3eee9),
                                        indent: 15,
                                        endIndent: 20,
                                      ),
                                      item(t, true),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xffd3eee9)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.controls,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        TimeOfDayToggle(
                          key: const ValueKey('time_of_day'),
                          selected: game.timeOfDay,
                          label: t.time,
                          onChanged: onTime,
                        ),
                        const SizedBox(width: 4),
                        if (onGraphics != null)
                          IconButton(
                            key: const ValueKey('graphics_settings'),
                            tooltip: t.graphics,
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
                            icon: const Icon(
                              Icons.tune,
                              size: 17,
                              color: muted,
                            ),
                          ),
                        IconButton(
                          key: const ValueKey('ranking_open'),
                          tooltip: t.ranking,
                          onPressed: onRanking,
                          icon: const Icon(
                            Icons.emoji_events_outlined,
                            size: 20,
                            color: brandBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          key: const ValueKey('practice'),
                          onPressed: onPractice,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(t.practice),
                        ),
                        const SizedBox(width: 8),
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
                          child: Text('${t.play}  →'),
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
                          width: 760,
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
}

/// Two-option pill for the UI language.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.overArt = false,
  });
  final AppLang selected;
  final ValueChanged<AppLang> onChanged;

  /// Translucent dark pill for the title art, matching its other buttons.
  final bool overArt;
  @override
  Widget build(BuildContext context) => Container(
    // Same height as the title's about button beside it.
    height: overArt ? 40 : null,
    padding: EdgeInsets.all(overArt ? 4 : 2),
    decoration: BoxDecoration(
      color: overArt ? Colors.black.withValues(alpha: .35) : brandPale,
      borderRadius: BorderRadius.circular(overArt ? 20 : 16),
      border: overArt ? null : Border.all(color: const Color(0xffd3eee9)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: overArt
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        for (final l in AppLang.values)
          GestureDetector(
            key: ValueKey('lang_${l.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(l),
            child: Container(
              alignment: overArt ? Alignment.center : null,
              padding: overArt
                  ? const EdgeInsets.symmetric(horizontal: 14)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: l == selected
                    ? (overArt ? Colors.white : brandBlue)
                    : null,
                borderRadius: BorderRadius.circular(overArt ? 16 : 14),
              ),
              child: Text(
                l.label,
                style: TextStyle(
                  fontSize: overArt ? 13 : 11,
                  fontWeight: FontWeight.w700,
                  color: switch ((l == selected, overArt)) {
                    (true, true) => brandInk,
                    (true, false) => Colors.white,
                    (false, true) => Colors.white70,
                    (false, false) => brandMuted,
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Sky-tinted pill switch for the stage time; the selected side shows its sky.
class TimeOfDayToggle extends StatelessWidget {
  const TimeOfDayToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label,
  });
  final StageTime selected;
  final String Function(StageTime)? label;
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
                    label?.call(t) ?? t.label,
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
