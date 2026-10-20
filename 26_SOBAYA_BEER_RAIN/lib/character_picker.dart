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
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final character in CatchCharacter.values)
        ChoiceChip(
          key: ValueKey('character_${character.id}'),
          selected: selected == character,
          onSelected: (_) => onSelected(character),
          label: Text(
            '${character.label}\n速度 ${character.moveSpeed}  /  半径 ${character.catchRadius}',
            maxLines: 2,
          ),
        ),
    ],
  );
}
