import 'package:flutter/material.dart';

import 'game_state.dart';

const herbColors = <String, Color>{
  'green': Color(0xff82d47a),
  'red': Color(0xfff17f73),
  'yellow': Color(0xfff5d36d),
  'mixed': Color(0xff82d47a),
};

/// Lightweight vector illustrations for the case, including its drag preview.
class GameItemTile extends StatelessWidget {
  const GameItemTile({super.key, required this.item});
  final BagItem item;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${itemNames[item.kind]} ${item.count}個',
    child: Container(
      key: ValueKey('bag-item-${item.id}'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff41473c), Color(0xff252a24)],
        ),
        border: Border.all(color: const Color(0xff8d805d)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(child: ItemArtwork(kind: item.kind)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  itemNames[item.kind]!,
                  style: const TextStyle(
                    color: Color(0xffe6dec6),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (item.count > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                color: const Color(0xdd20241e),
                child: Text(
                  '×${item.count}',
                  style: const TextStyle(
                    color: Color(0xffeed9a2),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ItemArtwork extends StatelessWidget {
  const ItemArtwork({super.key, required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) {
    if (herbColors.containsKey(kind)) {
      Widget grass = Text(
        '草',
        key: ValueKey('herb-art-$kind'),
        style: TextStyle(
          color: herbColors[kind],
          fontSize: 48,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      );
      if (kind == 'mixed') {
        grass = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xff82d47a), Color(0xfff17f73)],
            stops: [.48, .52],
          ).createShader(bounds),
          child: grass,
        );
      }
      return Padding(
        padding: const EdgeInsets.all(2),
        child: FittedBox(fit: BoxFit.contain, child: grass),
      );
    }
    return SizedBox.expand(
      child: CustomPaint(
        key: ValueKey('item-art-$kind'),
        painter: _ItemPainter(kind),
      ),
    );
  }
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas c, Size size) {
    final scale = (size.width / 100).clamp(0.0, size.height / 60);
    c.save();
    c.translate((size.width - 100 * scale) / 2, (size.height - 60 * scale) / 2);
    c.scale(scale);
    const metal = Color(0xffaab2b7),
        dark = Color(0xff272c31),
        wood = Color(0xff986c43),
        brass = Color(0xffddbd6f);
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 1,
    ]) => c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
    void line(
      double x,
      double y,
      double xx,
      double yy,
      Color color, [
      double width = 1.5,
    ]) => c.drawLine(
      Offset(x, y),
      Offset(xx, yy),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
    void poly(List<Offset> points, Color color) =>
        c.drawPath(Path()..addPolygon(points, true), Paint()..color = color);
    switch (kind) {
      case 'handgun':
        poly(const [
          Offset(19, 24),
          Offset(40, 25),
          Offset(38, 49),
          Offset(21, 49),
        ], dark);
        rect(18, 16, 66, 13, metal, 2);
        rect(38, 28, 19, 12, metal, 4);
        rect(41, 29, 12, 8, dark, 3);
        line(49, 28, 47, 34, metal, 2);
        rect(75, 13, 5, 4, dark);
        rect(21, 13, 5, 4, dark);
        line(22, 20, 79, 20, const Color(0xffe0e5e7));
        for (var i = 0; i < 5; i++) {
          line(23 + i * 3, 22, 23 + i * 3, 27, dark, 1);
        }
        for (var i = 0; i < 4; i++) {
          line(24, 32 + i * 4, 34, 32 + i * 4, metal, .8);
        }
      case 'rocket':
        rect(10, 19, 80, 17, const Color(0xff718155), 4);
        rect(7, 16, 9, 23, metal, 2);
        rect(84, 16, 9, 23, dark, 2);
        rect(29, 35, 8, 13, dark, 2);
        rect(56, 35, 8, 12, dark, 2);
        rect(36, 10, 25, 7, metal, 2);
        rect(40, 16, 5, 4, dark);
        rect(69, 19, 6, 17, const Color(0xffe7bd50));
        line(18, 23, 80, 23, const Color(0xffa5b282));
      case 'shotgun':
        poly(const [
          Offset(4, 40),
          Offset(25, 26),
          Offset(41, 27),
          Offset(40, 32),
          Offset(25, 35),
          Offset(14, 48),
          Offset(4, 48),
        ], wood);
        rect(37, 23, 55, 5, metal);
        rect(45, 29, 47, 3, dark);
        rect(31, 24, 21, 10, metal);
        rect(51, 28, 20, 9, wood, 3);
        for (var i = 0; i < 5; i++) {
          line(54 + i * 3, 29, 54 + i * 3, 35, dark, 1);
        }
        rect(34, 34, 12, 7, metal, 3);
        rect(36, 34, 8, 4, dark, 2);
        rect(88, 20, 3, 4, dark);
      case 'ammo':
      case 'shells':
        final shells = kind == 'shells';
        rect(
          12,
          24,
          43,
          26,
          shells ? const Color(0xff5f7755) : const Color(0xff995147),
          2,
        );
        rect(12, 21, 43, 7, const Color(0xffd0c8b0));
        rect(17, 33, 31, 8, const Color(0xffe0d6bb));
        for (var i = 0; i < 3; i++) {
          final x = 60.0 + i * 11;
          rect(x, 22, 8, 27, shells ? const Color(0xffb54436) : brass, 2);
          if (!shells) {
            c.drawOval(Rect.fromLTWH(x, 15, 8, 15), Paint()..color = brass);
          }
          rect(x - 1, 45, 10, 5, brass);
          line(x + 2, 24, x + 2, 43, const Color(0xfff0dfa4), 1);
        }
      case 'key':
        c.drawCircle(
          const Offset(32, 23),
          12,
          Paint()
            ..color = brass
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        line(42, 30, 73, 49, brass, 6);
        line(62, 42, 67, 34, brass, 5);
        line(71, 48, 76, 40, brass, 5);
      case 'beer':
        rect(61, 20, 20, 26, metal, 7);
        rect(64, 24, 12, 17, dark, 4);
        rect(25, 14, 40, 39, metal, 4);
        rect(29, 23, 32, 25, brass, 2);
        rect(26, 12, 38, 12, const Color(0xfff5efdc), 5);
        for (var i = 0; i < 3; i++) {
          line(34 + i * 9, 28, 34 + i * 9, 45, const Color(0xfff5e4ad), 2);
        }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ItemPainter oldDelegate) => kind != oldDelegate.kind;
}
