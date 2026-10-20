import 'package:flutter/material.dart';

import 'app_style.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'タップして開始',
    child: GestureDetector(
      key: const ValueKey('title_start'),
      behavior: HitTestBehavior.opaque,
      onTap: onStart,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff07192d)),
          Image.asset(
            'assets/images/title-night.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: brandMint, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 12),
                  ],
                ),
                child: const Text(
                  'タップして開始',
                  style: TextStyle(
                    color: brandInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class BrandLoading extends StatelessWidget {
  const BrandLoading({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: brandGradient.createShader,
            blendMode: BlendMode.srcIn,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 4,
                semanticsLabel: '読み込み中',
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '読み込み中',
            style: TextStyle(color: brandMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
