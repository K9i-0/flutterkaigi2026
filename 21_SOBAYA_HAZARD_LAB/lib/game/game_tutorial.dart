part of 'game_state.dart';

const tutorialSteps = [
  'move',
  'aim',
  'shoot',
  'reload',
  'sneak',
  'escape',
  'complete',
];

extension HazardTutorial on HazardGameState {
  bool get tutorialActive => tutorialStep != null;
  String tutorialControlHint(bool mobile) => switch (tutorialStep) {
    'move' =>
      mobile ? '左スティックで移動。右の空いている画面をドラッグして周りを見る。' : 'WASDで移動。画面をドラッグして周りを見る。',
    'aim' =>
      mobile
          ? '左の「構える」で切り替え、右の画面で照準を動かす。'
          : 'Qで構える／解除。右クリックを押している間も構えられる。ドラッグで照準を動かす。',
    'shoot' =>
      mobile
          ? '構えてから右の「撃つ」。画面中央の照準を標的に重ねる。'
          : '構えてから左クリック／Space。画面中央の照準を標的に重ねる。',
    'reload' => mobile ? '弾数表示の「装填」を押す。装填が終わるまで待つ。' : 'Rで装填。装填が終わるまで待つ。',
    'sneak' =>
      mobile
          ? '右の「忍び足」を選び、左スティックで移動。訓練用のそば屋は持ち場から動かない。'
          : 'Zを押しながらWASDで移動。訓練用のそば屋は持ち場から動かない。',
    'escape' =>
      mobile
          ? '右の「走る」で物陰へ。隠れたら忍び足に戻し、捜索ゲージが消えるまで待つ。'
          : 'Shift＋WASDで物陰へ。隠れたらZで音を抑え、捜索ゲージが消えるまで待つ。',
    _ => '練習中の弾薬・体力・撃破数は本編へ持ち越さず、出発時に整えます。',
  };
  String get tutorialObjective => switch (tutorialStep) {
    'move' => '黄色い目印まで歩く',
    'aim' => '構えて正面の黄色い標的を狙う',
    'shoot' => '黄色い標的に弾を当てる',
    'reload' => '弾を装填する',
    'sneak' => '訓練用そば屋の背後を忍び足で黄色い目印まで進む',
    'escape' =>
      tutorialWasSeen ? '左の家の裏へ隠れ、警戒が解けるまで待つ' : 'そば屋の前へ出て、見つかる状態を確かめる',
    _ => '練習完了 — 村へ出発する',
  };
  ({double x, double z}) get tutorialWaypoint => switch (tutorialStep) {
    'move' => (x: 0, z: -17),
    'sneak' => (x: -3, z: -15),
    'escape' => tutorialWasSeen ? (x: -8, z: -20) : (x: 0, z: -15),
    _ => (x: 0, z: -13),
  };
  void beginTutorial({String step = 'move'}) {
    if (zoneId != 'village' || !tutorialSteps.contains(step)) return;
    restart();
    tutorialStep = step;
    for (final e in enemies) {
      e.active = false;
    }
    pickups.clear();
    crates.clear();
    pistolLoaded = step == 'reload' ? 9 : 10;
    addItem('ammo', 30);
    if (['sneak', 'escape'].contains(step)) {
      x = step == 'sneak' ? 2 : -3;
      z = -16;
      _prepareTutorialGuard();
    }
    tutorialLastX = x;
    tutorialLastZ = z;
    say(tutorialObjective);
  }

  void _prepareTutorialGuard() {
    final guard = enemies.first;
    guard.active = true;
    guard.x = 0;
    guard.z = -12;
    guard.heading = tutorialStep == 'escape' ? math.pi : 0;
    guard.hp = 100;
    guard.alive = true;
    _disengage(guard);
    clearStealthNoise();
  }

  void advanceTutorial() {
    if (!tutorialActive || tutorialStep == 'complete') return;
    tutorialStep = tutorialSteps[tutorialSteps.indexOf(tutorialStep!) + 1];
    tutorialProgress = 0;
    tutorialWasSeen = false;
    stopInput();
    if (tutorialStep == 'sneak' || tutorialStep == 'escape') {
      _prepareTutorialGuard();
    }
    tutorialRevision++;
    say(tutorialObjective);
  }

  void tickTutorial(double dt) {
    if (!tutorialActive || !running) return;
    final distance = math.sqrt(
      math.pow(x - tutorialLastX, 2) + math.pow(z - tutorialLastZ, 2),
    );
    tutorialLastX = x;
    tutorialLastZ = z;
    final point = tutorialWaypoint;
    final near = math.pow(x - point.x, 2) + math.pow(z - point.z, 2) < 1;
    switch (tutorialStep) {
      case 'move':
        if (inputX != 0 || inputY != 0) tutorialProgress += distance;
        if (near && tutorialProgress > 2) advanceTutorial();
      case 'aim':
        tutorialProgress = aiming ? tutorialProgress + dt : 0;
        if (tutorialProgress >= .6) advanceTutorial();
      case 'sneak':
        final guard = enemies.first;
        if (sneaking && !guard.seesPlayer && !guard.alerted) {
          tutorialProgress += distance;
        }
        if (near && sneaking && !guard.alerted && tutorialProgress > 2) {
          advanceTutorial();
        }
      case 'escape':
        final guard = enemies.first;
        tutorialWasSeen = tutorialWasSeen || guard.seesPlayer;
        if (tutorialWasSeen && near && !guard.alerted && !guard.seesPlayer) {
          advanceTutorial();
        }
    }
  }
}
