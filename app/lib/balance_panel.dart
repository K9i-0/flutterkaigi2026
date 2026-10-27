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
}

class BalancePanel extends StatefulWidget {
  const BalancePanel({
    super.key,
    required this.balance,
    this.seed,
    this.showFps = false,
    this.onFps,
  });
  final Balance balance;
  final int? seed;
  final bool showFps;

  /// Applied immediately and kept on cancel: it is a view option, not balance.
  final ValueChanged<bool>? onFps;
  @override
  State<BalancePanel> createState() => _BalancePanelState();
}

class _BalancePanelState extends State<BalancePanel> {
  late Map<String, double> values = Map.of(widget.balance.values);
  late bool fixedLayout = widget.seed == null;
  late final seed = TextEditingController(text: '${widget.seed ?? 1}');
  final json = TextEditingController();
  String? error;
  late bool showFps = widget.showFps;

  int? get seedOverride {
    if (fixedLayout) return null;
    final n = int.tryParse(seed.text);
    if (n == null || n < 0 || n > 999999999) {
      throw const FormatException('seedは0〜999999999の整数');
    }
    return n;
  }

  BalanceSelection selection() =>
      BalanceSelection(Balance.fromMap(values), seedOverride);

  void attempt(VoidCallback action) {
    try {
      action();
      setState(() => error = null);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    seed.dispose();
    json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BalanceField>>{};
    for (final f in Balance.fields) {
      (groups[f.group] ??= []).add(f);
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: brandBlue),
                  const SizedBox(width: 8),
                  const Text(
                    'バランス調整',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  const _Tag('DEBUG'),
                  const Spacer(),
                  if (widget.onFps != null) ...[
                    const Text('FPS表示', style: TextStyle(fontSize: 13)),
                    Switch(
                      key: const ValueKey('fps_toggle'),
                      value: showFps,
                      onChanged: (v) {
                        setState(() => showFps = v);
                        widget.onFps!(v);
                      },
                    ),
                  ],
                  IconButton(
                    tooltip: 'キャンセル',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Two slider columns whenever the dialog is wide enough.
                  final columns = box.maxWidth >= 600 ? 2 : 1;
                  final tileWidth =
                      (box.maxWidth - 40 - 16 * (columns - 1)) / columns;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      const Text(
                        '編集中は一時停止。保存すると同じ配置で最初から開始する。'
                        '移動速度と輪の半径はキャラクター固有値。判定はあたりだけ輪より広い。',
                        style: TextStyle(fontSize: 12, color: brandMuted),
                      ),
                      const SizedBox(height: 10),
                      _Section('キャラクター別の実効値'),
                      _effectiveTable(),
                      const SizedBox(height: 4),
                      _layoutRow(),
                      for (final g in groups.entries) ...[
                        _Section(g.key),
                        Wrap(
                          spacing: 16,
                          children: [
                            for (final f in g.value)
                              SizedBox(width: tileWidth, child: _slider(f)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _jsonTile(),
                    ],
                  );
                },
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xffb63c32)),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 20, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    key: const ValueKey('balance_defaults'),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('標準に戻す'),
                    onPressed: () => setState(() {
                      values = Map.of(Balance.defaults().values);
                      fixedLayout = true;
                      error = null;
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('balance_apply'),
                    onPressed: () {
                      try {
                        Navigator.pop(context, selection());
                      } catch (e) {
                        setState(() => error = '$e');
                      }
                    },
                    child: const Text('保存して最初から試す'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each character's actual round from the edited base values.
  Widget _effectiveTable() {
    final rows = <CatchGame>[];
    try {
      final b = Balance.fromMap(values);
      final override = seedOverride;
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: w,
    );
    return Table(
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
              'キャラクター',
              '出現間隔',
              '落下時間',
              'はずれ割合',
              'あたり／はずれ',
              '速度',
              '輪／判定',
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
                  '${g.roundCharacter.label}（${g.roundCharacter.difficulty}）',
                  style: cell.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              pad(Text('${g.spawnInterval.toStringAsFixed(2)}秒', style: cell)),
              pad(Text('${g.fallSeconds.toStringAsFixed(2)}秒', style: cell)),
              pad(Text('${(g.badRatio * 100).round()}%', style: cell)),
              pad(
                Text(
                  '${g.goodTotal}／${g.drops.length - g.goodTotal}',
                  style: cell,
                ),
              ),
              pad(Text(g.moveSpeed.toStringAsFixed(1), style: cell)),
              pad(
                Text(
                  '${g.catchRadius.toStringAsFixed(2)}／${g.goodCatchRadius.toStringAsFixed(2)}',
                  style: cell,
                ),
              ),
              pad(
                Text(
                  '#${g.seed}${g.seed == g.roundCharacter.layoutSeed ? '（固定）' : ''}',
                  style: cell,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _layoutRow() => Row(
    children: [
      const Text('キャラクターごとの固定配置', style: TextStyle(fontSize: 13)),
      Switch(
        key: const ValueKey('balance_fixed_layout'),
        value: fixedLayout,
        onChanged: (v) => setState(() {
          fixedLayout = v;
          error = null;
        }),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 160,
        child: TextField(
          key: const ValueKey('balance_seed'),
          controller: seed,
          enabled: !fixedLayout,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            labelText: '全員共通のseed',
          ),
        ),
      ),
    ],
  );

  Widget _slider(BalanceField f) {
    final v = values[f.key]!;
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
                  onTap: () => setState(() => values[f.key] = f.initial),
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
              onChanged: (n) => setState(() => values[f.key] = n),
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
        controller: json,
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
            onPressed: () => attempt(() {
              final s = selection();
              json.text = jsonEncode({
                'seed': ?s.seed,
                'balance': s.balance.values,
              });
              Clipboard.setData(ClipboardData(text: json.text));
            }),
          ),
          TextButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('読み込み'),
            onPressed: () => attempt(() {
              final data = jsonDecode(json.text) as Map<String, dynamic>;
              final b = Balance.fromMap(
                Map<String, dynamic>.from(data['balance'] as Map),
              );
              final n = data['seed'];
              if (n != null && (n is! int || n < 0 || n > 999999999)) {
                throw const FormatException('Invalid seed');
              }
              values = Map.of(b.values);
              fixedLayout = n == null;
              if (n != null) seed.text = '$n';
            }),
          ),
        ],
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xfffff1e0),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xffb0610a),
      ),
    ),
  );
}
