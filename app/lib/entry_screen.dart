import 'package:flutter/material.dart';

import 'about_dialog.dart';
import 'app_style.dart';
import 'l10n.dart';
import 'selection_screen.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({
    super.key,
    required this.onStart,
    required this.lang,
    required this.onLang,
  });
  final VoidCallback onStart;
  final AppLang lang;
  final ValueChanged<AppLang> onLang;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    // Visitors see this before the language switch, so both languages show.
    final other = Strings(t.ja ? AppLang.en : AppLang.ja);
    return Semantics(
      button: true,
      label: '${t.tapToStart} / ${other.tapToStart}',
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
                alignment: Alignment.topLeft,
                // Inner buttons win the tap over the full-screen start gesture.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    LanguageToggle(
                      selected: lang,
                      onChanged: onLang,
                      overArt: true,
                    ),
                    SizedBox(
                      height: 40,
                      child: TextButton.icon(
                        key: const ValueKey('about'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const AboutAppDialog(),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black.withValues(alpha: .35),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: Text(
                          t.about,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.bottomRight,
                // Only a hint: the whole screen starts, so no button to aim at.
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.tapToStart,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        other.tapToStart,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandLoading extends StatelessWidget {
  const BrandLoading({super.key});
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: brandGradient.createShader,
              blendMode: BlendMode.srcIn,
              // The mask clips to its child; pad so the centered stroke isn't cut.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4,
                    semanticsLabel: t.loading,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t.loading,
              style: const TextStyle(color: brandMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
