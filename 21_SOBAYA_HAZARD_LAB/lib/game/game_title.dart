import 'dart:math' as math;

import 'package:flutter/material.dart';

const _ivory = Color(0xffe6dec6);
const _gold = Color(0xffc8b077);
const _ink = Color(0xff181b17);

/// Keeps the title's actions on screen, including short landscape phones.
class HazardTitleScreen extends StatelessWidget {
  const HazardTitleScreen({
    super.key,
    required this.hasCheckpoint,
    required this.collectedCount,
    required this.galleryCount,
    required this.saveStatus,
    required this.onContinue,
    required this.onNewGame,
    required this.onSettings,
  });

  final bool hasCheckpoint;
  final int collectedCount;
  final int galleryCount;
  final String saveStatus;
  final VoidCallback onContinue;
  final VoidCallback onNewGame;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xf010140f), Color(0x8810140f)]),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final desktop = bounds.maxWidth >= 1000 && bounds.maxHeight >= 620;
            final inset = desktop ? 48.0 : 12.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
              child: LayoutBuilder(
                builder: (context, content) {
                  final landscape = content.maxWidth > content.maxHeight;
                  final textScale = MediaQuery.textScalerOf(context);
                  final menuWidth = math.min(
                    content.maxWidth,
                    math.max(224.0, textScale.scale(16) * 7 + 32),
                  );
                  if (landscape && !desktop) {
                    final actionWidth = math.min(
                      menuWidth,
                      content.maxWidth * .6,
                    );
                    return Row(
                      key: const ValueKey('game-title-landscape'),
                      children: [
                        Expanded(child: _hero(compact: true)),
                        const SizedBox(width: 20),
                        SizedBox(width: actionWidth, child: _menu()),
                      ],
                    );
                  }
                  return Align(
                    alignment: desktop
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: SizedBox(
                      width: desktop ? 820 : 480,
                      child: Column(
                        key: const ValueKey('game-title-stacked'),
                        crossAxisAlignment: desktop
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _hero(compact: !desktop)),
                          SizedBox(height: desktop ? 24 : 12),
                          SizedBox(
                            width: desktop ? menuWidth : double.infinity,
                            child: _menu(),
                          ),
                          if (desktop) const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _hero({required bool compact}) => LayoutBuilder(
    builder: (context, bounds) {
      final align = compact ? Alignment.center : Alignment.centerLeft;
      final showEyebrow = bounds.maxHeight >= 220 && bounds.maxWidth >= 200;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (showEyebrow) ...[
            const Text(
              '窓際族物語',
              maxLines: 1,
              style: TextStyle(color: _gold, fontSize: 13, letterSpacing: 4),
            ),
            SizedBox(height: compact ? 12 : 24),
          ],
          Flexible(
            child: SizedBox(
              width: bounds.maxWidth,
              height: bounds.maxWidth * 3 / 8,
              child: Image.asset(
                'assets/cinematics/title_logo.png',
                key: const ValueKey('game-title-logo'),
                fit: BoxFit.contain,
                alignment: align,
                cacheWidth: 1640,
                semanticLabel: 'そば屋ハザード',
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 24),
          Text(
            compact
                ? '廃村に潜むそば屋から、生き延びろ。'
                : '窓際社員の島流し先、廃村ゆめみ村。\n炎上して捨てられた秘密案件が、まだ動いている。',
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              color: const Color(0xffb6bda9),
              height: 1.5,
              fontSize: compact ? 13 : 15,
            ),
          ),
        ],
      );
    },
  );

  Widget _menu() {
    final primaryStyle = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: _gold,
      foregroundColor: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: const TextStyle(fontSize: 16, height: 1.2, letterSpacing: 1),
    );
    final secondaryStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      foregroundColor: _ivory,
      backgroundColor: const Color(0x55181b17),
      side: const BorderSide(color: Color(0xff6c654d)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: const TextStyle(fontSize: 16, height: 1.2, letterSpacing: 1),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCheckpoint) ...[
          FilledButton(
            key: const ValueKey('game-continue'),
            style: primaryStyle,
            onPressed: onContinue,
            child: const Text('続きから'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('game-start'),
            style: secondaryStyle,
            onPressed: onNewGame,
            child: const Text('新しく始める'),
          ),
        ] else
          FilledButton(
            key: const ValueKey('game-start'),
            style: primaryStyle,
            onPressed: onNewGame,
            child: const Text('新しく始める'),
          ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('game-title-settings'),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: _ivory,
            textStyle: const TextStyle(fontSize: 15, height: 1.2),
          ),
          onPressed: onSettings,
          child: const Text('設定'),
        ),
        const SizedBox(height: 12),
        Row(
          key: const ValueKey('game-title-collection'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(
              child: Text(
                'COLLECTION',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _gold, letterSpacing: 1, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$collectedCount / $galleryCount',
              style: const TextStyle(color: _gold, fontSize: 11),
            ),
          ],
        ),
        if (saveStatus.isNotEmpty) ...[
          const SizedBox(height: 8),
          Tooltip(
            message: saveStatus,
            child: Text(
              saveStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _gold, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
