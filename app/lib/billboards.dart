import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum BillboardGroup { sponsor, yumemin, vision }

/// A stage picture as the city shows it, cropped from its atlas when shared.
class Billboard {
  const Billboard(this.id, this.group, this.asset, this.size, {this.crop});
  final String id;
  final BillboardGroup group;

  /// Null for the street screen, which is composed in code like its texture.
  final String? asset;
  final Size size;

  /// Pixel rectangle inside [asset]; null shows the whole image.
  final Rect? crop;
}

const _atlas = 'assets/billboards/ad_sponsors.png';

/// The atlas pixel size, read with the rectangles the stage build wrote.
Size sponsorAtlasSize = const Size(2048, 1920);

/// The ad boards on the current stage. Street signs and the retired
/// recruitment, exam-hall, ACCIDENCHUA and safety-first panels are left out.
Future<List<Billboard>> loadBillboards() async {
  final data = jsonDecode(
    await rootBundle.loadString('assets/billboards/ad_sponsors.json'),
  ) as Map<String, dynamic>;
  final size = (data['size'] as List).cast<num>();
  sponsorAtlasSize = Size(size[0].toDouble(), size[1].toDouble());
  return [
    for (final MapEntry(:key, :value)
        in (data['rects'] as Map<String, dynamic>).entries)
      () {
        final r = (value as List).cast<num>();
        final rect = Rect.fromLTWH(
          r[0].toDouble(),
          r[1].toDouble(),
          r[2].toDouble(),
          r[3].toDouble(),
        );
        return Billboard(
          key,
          BillboardGroup.sponsor,
          _atlas,
          rect.size,
          crop: rect,
        );
      }(),
    const Billboard(
      'yumemin',
      BillboardGroup.yumemin,
      'assets/billboards/ad_yumemin.png',
      Size(1024, 384),
    ),
    const Billboard(
      'okayaman_vision',
      BillboardGroup.vision,
      null,
      Size(1024, 768),
    ),
  ];
}

/// Shows [Billboard.crop] of a shared atlas at any size.
class BillboardImage extends StatelessWidget {
  const BillboardImage(this.billboard, {super.key});
  final Billboard billboard;
  @override
  Widget build(BuildContext context) {
    final b = billboard;
    final Widget child;
    if (b.asset == null) {
      child = const OkayamanVisionArt();
    } else if (b.crop == null) {
      child = Image.asset(b.asset!, fit: BoxFit.fill);
    } else {
      child = LayoutBuilder(
        builder: (context, box) {
          final s = box.maxWidth / b.crop!.width;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -b.crop!.left * s,
                  top: -b.crop!.top * s,
                  width: sponsorAtlasSize.width * s,
                  height: sponsorAtlasSize.height * s,
                  child: Image.asset(
                    b.asset!,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return AspectRatio(aspectRatio: b.size.width / b.size.height, child: child);
  }
}

/// The same composition as the street-screen texture in okayaman_vision.dart.
class OkayamanVisionArt extends StatelessWidget {
  const OkayamanVisionArt({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox(
      width: 1024,
      height: 768,
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/okayaman.jpg',
                fit: BoxFit.fitHeight,
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 662,
              child: Text(
                '大変驚いております。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 76,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 5),
                    Shadow(color: Colors.black, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
