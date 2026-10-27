import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_style.dart';
import 'balance.dart';
import 'catch_game.dart';
import 'character.dart';

class BalanceSelection {
  const BalanceSelection(this.balance, this.seed);
  final Balance balance;

  /// Null plays each character's fixed layout.
  final int? seed;
  bool sameAs(Balance other, int? otherSeed) =>
      seed == otherSeed &&
      Balance.fields.every((f) => balance[f.key] == other[f.key]);
}

/// Balance values being edited in the settings; nothing applies until the
/// settings are saved.
class BalanceDraft extends ChangeNotifier {
  BalanceDraft(Balance balance, int? seed)
    : values = Map.of(balance.values),
      fixedLayout = seed == null,
      seed = TextEditingController(text: '${seed ?? 1}');
  Map<String, double> values;
  bool fixedLayout;
  final TextEditingController seed;
  final json = TextEditingController();
  String? error;

  int? get seedOverride {
    if (fixedLayout) return null;
    final n = int.tryParse(seed.text);
    if (n == null || n < 0 || n > 999999999) {
      throw const FormatException('seedは0〜999999999の整数');
    }
    return n;
  }

  /// Throws a [FormatException] for invalid values.
  BalanceSelection selection() =>
      BalanceSelection(Balance.fromMap(values), seedOverride);

  void edit(VoidCallback change) {
    try {
      change();
      error = null;
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  void reset() => edit(() {
    values = Map.of(Balance.defaults().values);
    fixedLayout = true;
  });

  @override
  void dispose() {
    seed.dispose();
    json.dispose();
    super.dispose();
  }
}

/// Contents of the balance tab: effective values, layout and sliders.
class BalanceEditor extends StatelessWidget {
  const BalanceEditor({super.key, required this.draft});
  final BalanceDraft draft;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) {
      final groups = <String, List<BalanceField>>{};
      for (final f in Balance.fields) {
        (groups[f.group] ??= []).add(f);
      }
      return LayoutBuilder(
        builder: (context, box) {
          // Two slider columns whenever the pane is wide enough.
          final columns = box.maxWidth >= 560 ? 2 : 1;
          final tileWidth = (box.maxWidth - 40 - 16 * (columns - 1)) / columns;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            children: [
              const Text(
                '保存すると同じ配置で最初から開始する。移動速度と輪の半径は'
                'キャラクター固有値。判定はあたりだけ輪より広い。',
                style: TextStyle(fontSize: 12, color: brandMuted),
              ),
              if (draft.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    draft.error!,
                    style: const TextStyle(color: Color(0xffb63c32)),
                  ),
                ),
              const SettingsSection('キャラクター別の実効値'),
              _effectiveTable(),
              const SizedBox(height: 4),
              _layoutRow(),
              for (final g in groups.entries) ...[
                SettingsSection(g.key),
                Wrap(
                  spacing: 16,
                  children: [
                    for (final f in g.value)
                      SizedBox(width: tileWidth, child: _slider(context, f)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _jsonTile(),
            ],
          );
        },
      );
    },
  );

  /// Each character's actual round from the edited base values.
  Widget _effectiveTable() {
    final rows = <CatchGame>[];
    try {
      final b = Balance.fromMap(draft.values);
      final override = draft.seedOverride;
      for (final c in pickerOrder) {
        rows.add(
          CatchGame()
            ..balance = b
            ..selectCharacter(c)
            ..start(seed: override),
        );
      }
    } catch (_) {
      return const Text(
        '設定値が不正なため計算できません',
        style: TextStyle(fontSize: 12, color: Color(0xffb63c32)),
      );
    }
    const head = TextStyle(fontSize: 11, color: brandMuted);
    const cell = TextStyle(
      fontSize: 12,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    Widget pad(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: w,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        key: const ValueKey('balance_effective'),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xffe3ecf0)),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: brandPale),
            children: [
              for (final h in [
                '',
                '出現間隔',
                '落下時間',
                'はずれ率',
                'あたり/はずれ',
                '速度',
                '輪/判定',
                '配置',
              ])
                pad(Text(h, style: head)),
            ],
          ),
          for (final g in rows)
            TableRow(
              children: [
                pad(
                  Text(
                    g.roundCharacter.label,
                    style: cell.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                pad(
                  Text('${g.spawnInterval.toStringAsFixed(2)}秒', style: cell),
                ),
                pad(Text('${g.fallSeconds.toStringAsFixed(2)}秒', style: cell)),
                pad(Text('${(g.badRatio * 100).round()}%', style: cell)),
                pad(
                  Text(
                    '${g.goodTotal}/${g.drops.length - g.goodTotal}',
                    style: cell,
                  ),
                ),
                pad(Text(g.moveSpeed.toStringAsFixed(1), style: cell)),
                pad(
                  Text(
                    '${g.catchRadius.toStringAsFixed(2)}/'
                    '${g.goodCatchRadius.toStringAsFixed(2)}',
                    style: cell,
                  ),
                ),
                pad(
                  Text(
                    '#${g.seed}'
                    '${g.seed == g.roundCharacter.layoutSeed ? '（固定）' : ''}',
                    style: cell,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _layoutRow() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('キャラクターごとの固定配置', style: TextStyle(fontSize: 13)),
          Switch(
            key: const ValueKey('balance_fixed_layout'),
            value: draft.fixedLayout,
            onChanged: (v) => draft.edit(() => draft.fixedLayout = v),
          ),
        ],
      ),
      SizedBox(
        width: 160,
        child: TextField(
          key: const ValueKey('balance_seed'),
          controller: draft.seed,
          enabled: !draft.fixedLayout,
          keyboardType: TextInputType.number,
          onChanged: (_) => draft.edit(() {}),
          decoration: const InputDecoration(
            isDense: true,
            labelText: '全員共通のseed',
          ),
        ),
      ),
    ],
  );

  Widget _slider(BuildContext context, BalanceField f) {
    final v = draft.values[f.key]!;
    final changed = (v - f.initial).abs() > 1e-9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  f.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (changed)
                InkWell(
                  onTap: () =>
                      draft.edit(() => draft.values[f.key] = f.initial),
                  child: Text(
                    '標準 ${f.format(f.initial)}  ',
                    style: const TextStyle(fontSize: 11, color: brandMuted),
                  ),
                ),
              Text(
                f.format(v),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: changed ? brandBlue : brandInk,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: SliderTheme(
            // Fine steps would otherwise draw a row of dots.
            data: SliderTheme.of(context)
                .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
            child: Slider(
              key: ValueKey('balance_${f.key}'),
              padding: EdgeInsets.zero,
              value: v,
              min: f.min,
              max: f.max,
              divisions: ((f.max - f.min) / f.step).round(),
              label: f.format(v),
              onChanged: (n) => draft.edit(() => draft.values[f.key] = n),
            ),
          ),
        ),
      ],
    );
  }

  Widget _jsonTile() => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('設定JSON（比較条件の記録・復元）', style: TextStyle(fontSize: 13)),
    children: [
      TextField(
        key: const ValueKey('balance_json'),
        controller: draft.json,
        minLines: 2,
        maxLines: 4,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '{"seed":123,"balance":{...}}（seedを省くと固定配置）',
        ),
      ),
      Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('コピー'),
            onPressed: () => draft.edit(() {
              final s = draft.selection();
              draft.json.text = jsonEncode({
                'seed': ?s.seed,
                'balance': s.balance.values,
              });
              Clipboard.setData(ClipboardData(text: draft.json.text));
            }),
          ),
          TextButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('読み込み'),
            onPressed: () => draft.edit(() {
              final data = jsonDecode(draft.json.text) as Map<String, dynamic>;
              final b = Balance.fromMap(
                Map<String, dynamic>.from(data['balance'] as Map),
              );
              final n = data['seed'];
              if (n != null && (n is! int || n < 0 || n > 999999999)) {
                throw const FormatException('Invalid seed');
              }
              draft.values = Map.of(b.values);
              draft.fixedLayout = n == null;
              if (n != null) draft.seed.text = '$n';
            }),
          ),
        ],
      ),
    ],
  );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 2),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: brandBlue,
        letterSpacing: .5,
      ),
    ),
  );
}
