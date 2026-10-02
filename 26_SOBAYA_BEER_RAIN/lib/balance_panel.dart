import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'balance.dart';

class BalanceSelection {
  const BalanceSelection(this.balance, this.seed);
  final Balance balance;
  final int seed;
}

class BalancePanel extends StatefulWidget {
  const BalancePanel({super.key, required this.balance, required this.seed});
  final Balance balance;
  final int seed;
  @override
  State<BalancePanel> createState() => _BalancePanelState();
}

class _BalancePanelState extends State<BalancePanel> {
  late Map<String, double> values = Map.of(widget.balance.values);
  late final seed = TextEditingController(text: '${widget.seed}');
  final json = TextEditingController();
  String? error;
  BalanceSelection selection() {
    final n = int.tryParse(seed.text);
    if (n == null || n < 0 || n > 999999999) {
      throw const FormatException('seedは0〜999999999の整数');
    }
    return BalanceSelection(Balance.fromMap(values), n);
  }

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
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 660,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('バランス調整 / DEBUG', style: TextStyle(fontSize: 20)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
            const Text(
              '編集中は一時停止。適用すると保存し、同じseedで最初から開始。転落なし。',
              style: TextStyle(fontSize: 12),
            ),
            Expanded(
              child: ListView(
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in {
                        'default': '標準',
                        'easy': 'やさしい',
                        'hard': '難しい',
                      }.entries)
                        ActionChip(
                          label: Text(p.value),
                          onPressed: () => setState(() {
                            values = Map.of(Balance.preset(p.key).values);
                            error = null;
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    key: const ValueKey('balance_seed'),
                    controller: seed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '配置seed（同じ値で再現）',
                    ),
                  ),
                  for (final f in Balance.fields)
                    Row(
                      children: [
                        SizedBox(
                          width: 235,
                          child: Text(
                            '${f.label}\n${values[f.key]!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            key: ValueKey('balance_${f.key}'),
                            value: values[f.key]!,
                            min: f.min,
                            max: f.max,
                            divisions: ((f.max - f.min) / f.step).round(),
                            label: values[f.key]!.toStringAsFixed(2),
                            onChanged: (v) => setState(() => values[f.key] = v),
                          ),
                        ),
                      ],
                    ),
                  TextField(
                    key: const ValueKey('balance_json'),
                    controller: json,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '設定JSON（貼り付けて読み込み）',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => attempt(() {
                          final s = selection();
                          json.text = jsonEncode({
                            'seed': s.seed,
                            'balance': s.balance.values,
                          });
                          Clipboard.setData(ClipboardData(text: json.text));
                        }),
                        child: const Text('JSONをコピー'),
                      ),
                      TextButton(
                        onPressed: () => attempt(() {
                          final data =
                              jsonDecode(json.text) as Map<String, dynamic>;
                          final b = Balance.fromMap(
                            Map<String, dynamic>.from(data['balance'] as Map),
                          );
                          final n = data['seed'];
                          if (n is! int || n < 0 || n > 999999999) {
                            throw const FormatException('Invalid seed');
                          }
                          values = Map.of(b.values);
                          seed.text = '$n';
                        }),
                        child: const Text('JSONを読み込み'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
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
    ),
  );
}
