import 'package:flutter/material.dart';

import 'character.dart';

class CharacterPicker extends StatelessWidget {
  const CharacterPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final CatchCharacter selected;
  final ValueChanged<CatchCharacter> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final character in CatchCharacter.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              selected: selected == character,
              button: true,
              label:
                  '${character.label}、速度 ${character.moveSpeed}、半径 ${character.catchRadius}',
              child: InkWell(
                key: ValueKey('character_${character.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(character),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected == character
                                ? const Color(0xffffce69)
                                : Colors.white24,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
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
                      const SizedBox(height: 4),
                      Text(
                        '${selected == character ? '✓ ' : ''}${character.label}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected == character
                              ? const Color(0xffffce69)
                              : null,
                        ),
                      ),
                      Text(
                        '速度 ${character.moveSpeed} / 半径 ${character.catchRadius}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
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
