import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'app_style.dart';
import 'billboards.dart';
import 'cached_skin.dart';
import 'catch_game.dart';
import 'catch_scene.dart';
import 'drop_models.dart';
import 'gallery.dart';
import 'l10n.dart';
import 'selection_screen.dart';

final Future<List<Billboard>> billboardCatalog = loadBillboards();

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({
    super.key,
    required this.controller,
    required this.world,
    required this.game,
    required this.onTime,
    required this.onBack,
  });
  final GalleryController controller;
  final CatchScene world;
  final CatchGame game;
  final ValueChanged<StageTime> onTime;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Theme(
        data: appTheme(),
        child: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            child: DefaultTextStyle(
              style: const TextStyle(color: brandInk),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          key: const ValueKey('gallery_back'),
                          tooltip: t.close,
                          onPressed: onBack,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.gallery,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        SegmentedButton<GalleryTab>(
                          key: const ValueKey('gallery_tabs'),
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            ButtonSegment(
                              value: GalleryTab.models,
                              icon: const Icon(Icons.view_in_ar, size: 18),
                              label: Text(
                                t.galleryModels,
                                key: const ValueKey('gallery_tab_models'),
                              ),
                            ),
                            ButtonSegment(
                              value: GalleryTab.billboards,
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(
                                t.galleryBillboards,
                                key: const ValueKey('gallery_tab_billboards'),
                              ),
                            ),
                          ],
                          selected: {controller.tab},
                          onSelectionChanged: (s) => controller.setTab(s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: controller.tab == GalleryTab.models
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: GalleryViewer(
                                      controller: controller,
                                      world: world,
                                      game: game,
                                      onTime: onTime,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 196,
                                  child: _SubjectList(controller: controller),
                                ),
                              ],
                            )
                          : BillboardGallery(controller: controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String subjectName(Strings t, GallerySubject s) => switch (s.group) {
  SubjectGroup.character => t.character(s.character!),
  SubjectGroup.drop => t.galleryDrop(s.drop!),
  SubjectGroup.stage => t.stageName,
};

class _SubjectList extends StatelessWidget {
  const _SubjectList({required this.controller});
  final GalleryController controller;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: brandMuted,
          letterSpacing: 1,
        ),
      ),
    );
    return ListView(
      key: const ValueKey('gallery_subjects'),
      padding: EdgeInsets.zero,
      children: [
        for (final group in SubjectGroup.values) ...[
          header(switch (group) {
            SubjectGroup.character => t.galleryCharacters,
            SubjectGroup.drop => t.galleryDrops,
            SubjectGroup.stage => t.galleryStage,
          }),
          for (final s in GallerySubject.all.where((s) => s.group == group))
            _SubjectTile(
              subject: s,
              selected: s == controller.subject,
              label: subjectName(t, s),
              onTap: () => controller.select(s),
            ),
        ],
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final GallerySubject subject;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final character = subject.character;
    return Material(
      color: selected ? brandPale : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: ValueKey('gallery_subject_${subject.id}'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? brandBlue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 26,
                child: character != null
                    ? ClipOval(
                        child: Image.asset(
                          character.portraitAsset,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      )
                    : Icon(
                        subject.isStage
                            ? Icons.location_city
                            : subject.drop!.isBad
                            ? Icons.close
                            : Icons.check,
                        size: 18,
                        color: subject.isStage
                            ? brandMuted
                            : subject.drop!.isBad
                            ? const Color(0xff996b83)
                            : brandBlue,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

/// A clone of a loaded game model, posed in the studio scene.
class _ViewModel {
  _ViewModel(this.root, Node model) {
    // Resting first, then by pace; other actions follow by name.
    const order = ['Idle', 'Walk', 'Run'];
    int rank(String n) => order.contains(n) ? order.indexOf(n) : order.length;
    final names = [for (final a in model.parsedAnimations) a.name]
      ..sort((a, b) {
        final r = rank(a) - rank(b);
        return r != 0 ? r : a.compareTo(b);
      });
    clips = names;
    if (names.isNotEmpty) {
      motion = CharacterMotionPlayer(
        model,
        sources: {for (final n in names) n: n},
        initial: names.first,
      );
    }
  }
  final Node root;
  late final List<String> clips;
  CharacterMotionPlayer? motion;
}

/// Orbit viewer. Characters and items render in their own studio scene; the
/// stage renders the live game scene through the gallery camera.
class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.controller,
    required this.world,
    required this.game,
    required this.onTime,
  });
  final GalleryController controller;
  final CatchScene world;
  final CatchGame game;
  final ValueChanged<StageTime> onTime;
  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  final studio = Scene();
  final models = <String, _ViewModel>{};
  _ViewModel? shown;
  double lastScale = 1;
  GalleryController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    studio.environment = widget.world.previewEnvironment;
    studio.environmentIntensity = 1.4;
    studio.exposure = 1.15;
    studio.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.5, -1, -.6),
      intensity: 2.8,
    );
    c.addListener(sync);
    sync();
  }

  @override
  void dispose() {
    c.removeListener(sync);
    widget.world.halo.visible = true;
    super.dispose();
  }

  _ViewModel build3d(GallerySubject s) {
    final root = Node();
    final Node model;
    if (s.character != null) {
      model = widget.world.characters[s.character]!.clone()
        ..position = vm.Vector3.zero()
        // Game characters face -Z at rest; turn them toward the camera on +Z.
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
      root.add(model);
    } else {
      final kind = s.drop!;
      model = widget.world.dropModels.prototypes[kind]!.clone();
      DropModel.fit(kind, model);
      root
        ..add(model)
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          DropModel.frontYaw(kind),
        );
    }
    cacheSkinUploads(model);
    return _ViewModel(root, model);
  }

  void sync() {
    final s = c.subject;
    // The game's catch ring means nothing in a gallery.
    widget.world.halo.visible = !s.isStage;
    final next = s.isStage ? null : models.putIfAbsent(s.id, () => build3d(s));
    if (!identical(next, shown)) {
      if (shown != null) studio.remove(shown!.root);
      if (next != null) studio.add(next.root);
      shown = next;
    }
    c.setClips(next?.clips ?? const []);
    if (mounted) setState(() {});
  }

  void tick(double dt) {
    dt = dt.clamp(0, .1);
    c.tick(dt);
    if (c.subject.isStage) {
      widget.world.update(widget.game, dt);
      return;
    }
    final motion = shown?.motion;
    if (motion == null) return;
    motion.controller.select(c.clip ?? shown!.clips.first);
    if (c.playing) motion.controller.advance(dt);
    motion.sample();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final s = c.subject;
    final dark = c.dark && !s.isStage;
    final fg = dark ? Colors.white : brandInk;
    final view = LayoutBuilder(
      builder: (context, box) => Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            c.zoom(math.exp(-e.scrollDelta.dy / 300));
          }
        },
        child: GestureDetector(
          key: const ValueKey('gallery_view'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: c.reset,
          onScaleStart: (_) {
            lastScale = 1;
            c.touch();
          },
          onScaleUpdate: (e) {
            final h = math.max(1.0, box.maxHeight);
            if (e.pointerCount < 2) {
              c.orbit(
                -e.focalPointDelta.dx / h * 3.2,
                e.focalPointDelta.dy / h * 2.4,
              );
            } else {
              c.zoom(e.scale / lastScale);
              lastScale = e.scale;
              c.panBy(e.focalPointDelta.dx / h, e.focalPointDelta.dy / h);
            }
          },
          child: SceneView(
            s.isStage ? widget.world.scene : studio,
            key: ValueKey(s.isStage ? 'gallery_stage' : 'gallery_studio'),
            cameraBuilder: (_) => c.camera(),
            onTick: (_, dt) => tick(dt),
          ),
        ),
      ),
    );
    Widget chip(String key, String label, bool on, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            key: ValueKey(key),
            label: Text(label),
            selected: on,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 12),
            onSelected: (_) => onTap(),
          ),
        );
    Widget tool(
      String key,
      String tip,
      IconData icon,
      VoidCallback onTap, {
      bool on = false,
    }) => IconButton(
      key: ValueKey(key),
      tooltip: tip,
      onPressed: onTap,
      isSelected: on,
      style: IconButton.styleFrom(
        backgroundColor: on ? brandBlue : Colors.white.withValues(alpha: .9),
        foregroundColor: on ? Colors.white : brandInk,
      ),
      icon: Icon(icon, size: 20),
    );
    final clips = shown?.clips ?? const <String>[];
    final current = c.clip ?? clips.firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? const Color(0xff10202b) : const Color(0xfff2f7f9),
            child: view,
          ),
        ),
        Positioned(
          left: 12,
          top: 10,
          right: 12,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName(t, s),
                  key: const ValueKey('gallery_name'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: s.isStage ? Colors.white : fg,
                    shadows: s.isStage
                        ? const [Shadow(blurRadius: 6, color: Colors.black54)]
                        : null,
                  ),
                ),
                Text(
                  t.galleryHint,
                  style: TextStyle(
                    fontSize: 10,
                    color: s.isStage ? Colors.white : fg.withValues(alpha: .7),
                    shadows: s.isStage
                        ? const [Shadow(blurRadius: 4, color: Colors.black54)]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Row(
            children: [
              tool(
                'gallery_reset',
                t.resetView,
                Icons.center_focus_strong,
                c.reset,
              ),
              const SizedBox(width: 6),
              tool('gallery_auto_rotate', t.autoRotate, Icons.threesixty, () {
                c.autoRotate = !c.autoRotate;
                setState(() {});
              }, on: c.autoRotate),
              const SizedBox(width: 6),
              if (s.isStage)
                TimeOfDayToggle(
                  key: const ValueKey('gallery_time'),
                  selected: widget.game.timeOfDay,
                  label: t.time,
                  onChanged: (time) {
                    widget.onTime(time);
                    setState(() {});
                  },
                )
              else ...[
                tool(
                  'gallery_dark',
                  t.darkBackground,
                  Icons.dark_mode_outlined,
                  () {
                    c.dark = !c.dark;
                    setState(() {});
                  },
                  on: c.dark,
                ),
                if (clips.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  tool(
                    'gallery_play',
                    c.playing ? t.pauseMotion : t.playMotion,
                    c.playing ? Icons.pause : Icons.play_arrow,
                    () {
                      c.playing = !c.playing;
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final name in clips)
                            chip(
                              'gallery_clip_$name',
                              t.clip(name),
                              name == current,
                              () {
                                c.clip = name;
                                c.playing = true;
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class BillboardGallery extends StatelessWidget {
  const BillboardGallery({super.key, required this.controller});
  final GalleryController controller;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return FutureBuilder(
      future: billboardCatalog,
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return Center(
            child: snap.hasError
                ? Text('${snap.error}')
                : const CircularProgressIndicator(),
          );
        }
        final open = controller.openBillboard;
        final grid = ListView(
          key: const ValueKey('billboard_list'),
          children: [
            for (final group in BillboardGroup.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                child: Text(
                  t.billboardGroup(group),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: brandMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (i, b) in list.indexed)
                    if (b.group == group)
                      _BillboardCard(
                        billboard: b,
                        label: t.billboard(b.id),
                        height: group == BillboardGroup.sign ? 140 : 84,
                        onTap: () => controller.showBillboard(i),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],
        );
        return Stack(
          children: [
            Positioned.fill(child: grid),
            if (open != null && open < list.length)
              Positioned.fill(
                child: _BillboardViewer(
                  key: ValueKey('billboard_view_$open'),
                  billboards: list,
                  index: open,
                  onIndex: controller.showBillboard,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BillboardCard extends StatelessWidget {
  const _BillboardCard({
    required this.billboard,
    required this.label,
    required this.height,
    required this.onTap,
  });
  final Billboard billboard;
  final String label;
  final double height;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final width = height * billboard.size.width / billboard.size.height;
    return InkWell(
      key: ValueKey('billboard_${billboard.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: math.max(width, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffd3eee9)),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: BillboardImage(billboard),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: brandMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-size view; arrows step through so pinch-zoom never fights a pager.
class _BillboardViewer extends StatelessWidget {
  const _BillboardViewer({
    super.key,
    required this.billboards,
    required this.index,
    required this.onIndex,
  });
  final List<Billboard> billboards;
  final int index;
  final ValueChanged<int?> onIndex;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final b = billboards[index];
    Widget arrow(String key, String tip, IconData icon, int step) => IconButton(
      key: ValueKey(key),
      tooltip: tip,
      onPressed: () =>
          onIndex((index + step + billboards.length) % billboards.length),
      icon: Icon(icon),
    );
    return ColoredBox(
      color: const Color(0xff101a22),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              key: const ValueKey('billboard_zoom'),
              maxScale: 6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(64, 44, 64, 16),
                  child: BillboardImage(b),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 8,
            right: 60,
            child: Text(
              '${t.billboard(b.id)}  ·  ${t.billboardGroup(b.group)}',
              key: const ValueKey('billboard_name'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 4,
            child: IconButton(
              key: const ValueKey('billboard_close'),
              tooltip: t.close,
              onPressed: () => onIndex(null),
              icon: const Icon(Icons.close),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: arrow('billboard_prev', t.previous, Icons.chevron_left, -1),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: arrow('billboard_next', t.next, Icons.chevron_right, 1),
          ),
        ],
      ),
    );
  }
}
