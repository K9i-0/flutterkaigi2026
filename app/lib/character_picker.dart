import 'package:flutter/material.dart';

import 'app_style.dart';
import 'character.dart';
import 'l10n.dart';

/// Three tiles share the full column height so the characters lead the screen.
class CharacterPicker extends StatelessWidget {
  const CharacterPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final CatchCharacter selected;
  final ValueChanged<CatchCharacter> onSelected;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final character in pickerOrder)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Semantics(
                selected: selected == character,
                button: true,
                label: '${t.character(character)}、${t.difficulty(character)}',
                child: InkWell(
                  key: ValueKey('character_${character.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(character),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: selected == character
                          ? brandPale
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: 2,
                        color: selected == character
                            ? brandBlue
                            : const Color(0xffd3eee9),
                      ),
                    ),
                    child: Row(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Transform.scale(
                              scale: character == CatchCharacter.fukuchan
                                  ? 1.8
                                  : 1,
                              alignment: Alignment.topCenter,
                              child: Image.asset(
                                character.portraitAsset,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.character(character),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t.difficulty(character),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: brandMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected == character)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.check_circle,
                              color: brandBlue,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
