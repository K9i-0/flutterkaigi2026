import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'game/game_page.dart';

void main() {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized(
      const MarionetteConfiguration(maxScreenshotSize: Size(800, 600)),
    );
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const SobayaHazardApp());
}

class SobayaHazardApp extends StatelessWidget {
  const SobayaHazardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'そば屋ハザード',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffc6af75),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff10120f),
    ),
    home: const HazardGamePage(),
  );
}
