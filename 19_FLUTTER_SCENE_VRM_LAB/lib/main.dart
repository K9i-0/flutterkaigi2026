import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:flutter_scene_vrm/flutter_scene_vrm.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VrmLabApp());
}

class VrmLabApp extends StatelessWidget {
  const VrmLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff59d7c8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff0b1020),
      useMaterial3: true,
    ),
    home: const VrmLabPage(),
  );
}

class VrmLabPage extends StatefulWidget {
  const VrmLabPage({super.key});

  @override
  State<VrmLabPage> createState() => _VrmLabPageState();
}

class _VrmLabPageState extends State<VrmLabPage> {
  final VrmLabController _lab = VrmLabController();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _lab.load().catchError((Object error, StackTrace stackTrace) {
      if (mounted) setState(() => _error = error);
    });
  }

  @override
  void dispose() {
    _lab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: _lab,
      builder: (context, _) {
        if (_error case final error?) {
          return Center(child: SelectableText('VRM load failed\n$error'));
        }
        if (!_lab.ready) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            SceneView(
              _lab.scene,
              cameraBuilder: _lab.camera,
              onTick: (_, delta) => _lab.tick(delta),
              warmUp: true,
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: _ControlPanel(lab: _lab),
              ),
            ),
            const SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '2層検証: Flutter UI / flutter_scene_vrm / flutter_scene fork',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class VrmLabController extends ChangeNotifier {
  final Scene scene = Scene();
  VrmAvatar? avatar;
  bool ready = false;
  bool autoBlink = true;
  String emotion = 'neutral';
  double mouth = 0;
  double _elapsed = 0;
  double _blinkPhase = 0;

  VrmDocument get document => avatar!.document;

  Future<void> load() async {
    await Scene.initializeStaticResources();
    final data = await rootBundle.load('assets/models/validation-avatar.vrm');
    avatar = await VrmAvatar.fromBytes(data.buffer.asUint8List());
    final avatarStage = Node(name: 'AvatarStage')
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    avatarStage.add(avatar!.root);
    scene.add(avatarStage);
    avatar!.setExpression(emotion, 1);
    ready = true;
    notifyListeners();
  }

  PerspectiveCamera camera(Duration elapsed) => PerspectiveCamera(
    fovRadiansY: 34 * math.pi / 180,
    position: vm.Vector3(0, 1.32, 3.15),
    target: vm.Vector3(0, 1.12, 0),
    fovNear: 0.05,
    fovFar: 20,
  );

  void setEmotion(String value) {
    avatar!.setExpression(emotion, 0);
    emotion = value;
    avatar!.setExpression(value, 1);
    notifyListeners();
  }

  void setMouth(double value) {
    mouth = value;
    avatar!.setExpression('aa', value);
    notifyListeners();
  }

  void setAutoBlink(bool value) {
    autoBlink = value;
    if (!value) avatar!.setExpression('blink', 0);
    notifyListeners();
  }

  void tick(double deltaSeconds) {
    if (!autoBlink || avatar == null) return;
    _elapsed += deltaSeconds;
    final cycle = _elapsed % 3.2;
    final next = cycle > 2.98
        ? math.sin((cycle - 2.98) / 0.22 * math.pi).clamp(0.0, 1.0)
        : 0.0;
    if ((next - _blinkPhase).abs() > 0.03) {
      _blinkPhase = next;
      avatar!.setExpression('blink', next);
    }
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.lab});

  final VrmLabController lab;

  @override
  Widget build(BuildContext context) {
    final doc = lab.document;
    return Card(
      margin: const EdgeInsets.all(12),
      color: const Color(0xe6192435),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.meta.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '公式VRM 1.0検証モデル · ${doc.expressions.length} expressions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusChip(label: 'Morph', supported: true),
                  _StatusChip(label: 'Humanoid', supported: true),
                  _StatusChip(label: 'MToon fallback', supported: doc.hasMToon),
                  _StatusChip(
                    label: 'SpringBone parsed',
                    supported: doc.hasSpringBone,
                  ),
                  _StatusChip(
                    label: 'Constraint parsed',
                    supported: doc.hasNodeConstraint,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'neutral', label: Text('Neutral')),
                  ButtonSegment(value: 'happy', label: Text('Happy')),
                  ButtonSegment(value: 'angry', label: Text('Angry')),
                  ButtonSegment(value: 'sad', label: Text('Sad')),
                ],
                selected: {lab.emotion},
                onSelectionChanged: (values) => lab.setEmotion(values.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('口パク AA'),
                  Expanded(
                    child: Slider(value: lab.mouth, onChanged: lab.setMouth),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('自動まばたき'),
                value: lab.autoBlink,
                onChanged: lab.setAutoBlink,
              ),
              const Divider(),
              const Text(
                '緑: このPoCで動作。MToon / SpringBone / Constraintは検出のみで、描画・物理適用は次段階。',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.supported});

  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(
      supported ? Icons.check_circle : Icons.remove_circle_outline,
      size: 16,
      color: supported ? const Color(0xff5ee3bd) : Colors.amber,
    ),
    label: Text(label),
  );
}
