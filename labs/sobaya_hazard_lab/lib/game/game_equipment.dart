import 'package:flutter/material.dart';

import 'game_mobile.dart';

const _ivory = Color(0xffe6dec6), _gold = Color(0xffc8b077);

/// Direct equipment selection. The owner pauses play and handles returning to
/// exploration; choosing an item never aims or fires it.
class HazardQuickEquipment extends StatelessWidget {
  const HazardQuickEquipment({
    super.key,
    required this.currentWeapon,
    required this.hasShotgun,
    required this.hasRocket,
    required this.beers,
    required this.pistolLoaded,
    required this.shotgunLoaded,
    required this.onSelect,
    required this.onClose,
  });

  final String currentWeapon;
  final bool hasShotgun, hasRocket;
  final int beers, pistolLoaded, shotgunLoaded;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final choices = <({String id, String name, String amount, bool enabled})>[
      (
        id: 'handgun',
        name: 'ハンドガン',
        amount: '装填 $pistolLoaded / 10',
        enabled: true,
      ),
      if (hasShotgun)
        (
          id: 'shotgun',
          name: 'ショットガン',
          amount: '装填 $shotgunLoaded / 5',
          enabled: true,
        ),
      if (hasRocket)
        (id: 'rocket', name: 'ロケットランチュア', amount: '弾数 ∞', enabled: true),
      (
        id: 'beer',
        name: 'ビール',
        amount: beers > 0 ? '$beers 杯' : '0 杯・拾って補充',
        enabled: beers > 0,
      ),
    ];
    return HazardAdaptivePanel(
      heading: '装備を選ぶ',
      width: 440,
      onClose: onClose,
      body: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in choices)
                SizedBox(
                  width: (bounds.maxWidth - 8) / 2,
                  child: Semantics(
                    key: ValueKey('game-equip-${choice.id}'),
                    button: true,
                    enabled: choice.enabled,
                    selected: currentWeapon == choice.id,
                    label: '${choice.name}、${choice.amount}',
                    excludeSemantics: true,
                    onTap: choice.enabled ? () => onSelect(choice.id) : null,
                    child: OutlinedButton(
                      onPressed: choice.enabled
                          ? () => onSelect(choice.id)
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 76),
                        padding: const EdgeInsets.all(8),
                        foregroundColor: _ivory,
                        disabledForegroundColor: _ivory.withValues(alpha: .4),
                        backgroundColor: currentWeapon == choice.id
                            ? const Color(0xff3c4630)
                            : const Color(0xff20271f),
                        side: BorderSide(
                          color: currentWeapon == choice.id
                              ? _gold
                              : const Color(0xff60654f),
                          width: currentWeapon == choice.id ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (currentWeapon == choice.id) ...[
                                const Icon(Icons.check, size: 16),
                                const SizedBox(width: 3),
                              ],
                              Expanded(
                                child: Text(
                                  choice.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            choice.amount,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
