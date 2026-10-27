import 'package:flutter/material.dart';

import 'app_style.dart';
import 'balance.dart';
import 'balance_panel.dart';
import 'graphics_settings.dart';
import 'l10n.dart';

enum SettingsTab { graphics, demo, balance }

class SettingsResult {
  const SettingsResult({
    required this.graphics,
    required this.balance,
    required this.tas,
    required this.fps,
    required this.sound,
  });
  final GraphicsSettings graphics;
  final BalanceSelection balance;
  final bool tas, fps, sound;
}

/// Graphics, demo and balance settings on one screen. Nothing applies until
/// the apply button; cancel leaves everything as it was.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.graphics,
    required this.balance,
    this.seed,
    this.tas = false,
    this.fps = true,
    this.sound = true,
    this.inRound = false,
    this.tab = SettingsTab.graphics,
  });
  final GraphicsSettings graphics;
  final Balance balance;
  final int? seed;
  final bool tas, fps, sound;

  /// Opened during a round: balance or TAS changes restart it.
  final bool inRound;
  final SettingsTab tab;
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsTab tab = widget.tab;
  late GraphicsSettings graphics = widget.graphics;
  late bool tas = widget.tas, fps = widget.fps, sound = widget.sound;
  late final draft = BalanceDraft(widget.balance, widget.seed);

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  bool get restarts {
    if (!widget.inRound) return false;
    if (tas != widget.tas) return true;
    try {
      return !draft.selection().sameAs(widget.balance, widget.seed);
    } catch (_) {
      return false;
    }
  }

  void apply() {
    try {
      Navigator.pop(
        context,
        SettingsResult(
          graphics: graphics,
          balance: draft.selection(),
          tas: tas,
          fps: fps,
          sound: sound,
        ),
      );
    } catch (e) {
      draft.edit(() => throw e);
      setState(() => tab = SettingsTab.balance);
    }
  }

  void reset() => setState(() {
    switch (tab) {
      case SettingsTab.graphics:
        graphics = GraphicsSettings.standard;
      case SettingsTab.demo:
        tas = false;
        fps = true;
        sound = true;
      case SettingsTab.balance:
        draft.reset();
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Dialog(
      key: const ValueKey('settings'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: brandBlue),
                  const SizedBox(width: 10),
                  Text(
                    t.settings,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('settings_close'),
                    tooltip: t.cancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 140,
                    color: brandPale,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        for (final (id, icon, label, caption) in [
                          (
                            SettingsTab.graphics,
                            Icons.display_settings,
                            t.graphicsTab,
                            null,
                          ),
                          (
                            SettingsTab.demo,
                            Icons.smart_display_outlined,
                            t.demoTab,
                            null,
                          ),
                          (
                            SettingsTab.balance,
                            Icons.tune,
                            t.balanceTab,
                            t.forDevelopers,
                          ),
                        ])
                          _TabTile(
                            key: ValueKey('settings_tab_${id.name}'),
                            icon: icon,
                            label: label,
                            caption: caption,
                            selected: tab == id,
                            onTap: () => setState(() => tab = id),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: switch (tab) {
                      SettingsTab.graphics => _graphicsTab(t),
                      SettingsTab.demo => _demoTab(t),
                      SettingsTab.balance => BalanceEditor(draft: draft),
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
              child: ListenableBuilder(
                listenable: draft,
                builder: (context, _) => Row(
                  children: [
                    TextButton.icon(
                      key: const ValueKey('settings_reset'),
                      icon: const Icon(Icons.restart_alt),
                      label: Text(t.resetTab),
                      onPressed: reset,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('settings_apply'),
                      onPressed: apply,
                      child: Text(restarts ? t.applyRestart : t.apply),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphicsTab(Strings t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    children: [
      Row(
        children: [
          for (final (key, label, preset) in [
            ('graphics_standard', t.standard, GraphicsSettings.standard),
            ('graphics_high', t.highQuality, GraphicsSettings.highQuality),
            ('graphics_light', t.lightQuality, GraphicsSettings.light),
          ]) ...[
            if (key != 'graphics_standard') const SizedBox(width: 10),
            Expanded(
              child: graphics == preset
                  ? FilledButton.tonal(
                      key: ValueKey(key),
                      onPressed: () {},
                      child: Text(label),
                    )
                  : OutlinedButton(
                      key: ValueKey(key),
                      onPressed: () => setState(() => graphics = preset),
                      child: Text(label),
                    ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      for (final option in t.graphicsOptions)
        SwitchListTile(
          key: ValueKey('graphics_${option.$1}'),
          contentPadding: EdgeInsets.zero,
          title: Text(option.$2),
          subtitle: Text(option.$3),
          value: graphics.toMap()[option.$1]!,
          onChanged: (v) =>
              setState(() => graphics = graphics.withOption(option.$1, v)),
        ),
    ],
  );

  Widget _demoTab(Strings t) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tas ? brandBlue : const Color(0xffd5e3ea)),
          color: tas ? brandPale : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: brandGradient,
              ),
              child: const Icon(
                Icons.precision_manufacturing,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tasTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.tasBody,
                    style: const TextStyle(fontSize: 12, color: brandMuted),
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('tas_toggle'),
              value: tas,
              onChanged: (v) => setState(() => tas = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const ValueKey('sound_toggle'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(t.soundTitle),
        subtitle: Text(t.soundBody),
        value: sound,
        onChanged: (v) => setState(() => sound = v),
      ),
      SwitchListTile(
        key: const ValueKey('fps_toggle'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(t.fpsTitle),
        subtitle: Text(t.fpsBody),
        value: fps,
        onChanged: (v) => setState(() => fps = v),
      ),
    ],
  );
}

class _TabTile extends StatelessWidget {
  const _TabTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
  });
  final IconData icon;
  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected ? brandBlue : brandInk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                      if (caption != null)
                        Text(
                          caption!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: brandMuted,
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
    );
  }
}
