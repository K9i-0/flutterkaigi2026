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
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final character in [
        CatchCharacter.fukuchan,
        CatchCharacter.ctoOdatetsu,
        CatchCharacter.sobaya,
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Semantics(
            selected: selected == character,
            button: true,
            label: '${character.label}、${character.difficulty}',
            child: InkWell(
              key: ValueKey('character_${character.id}'),
              onTap: () => onSelected(character),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected == character
                      ? const Color(0xffe8e5df)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: selected == character
                          ? const Color(0xffc6542b)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Transform.scale(
                          scale: character == CatchCharacter.fukuchan ? 1.8 : 1,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            character.difficulty,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff72716b),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
