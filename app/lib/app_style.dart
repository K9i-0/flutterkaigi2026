import 'package:flutter/material.dart';

const brandMint = Color(0xff64f0d7);
const brandBlue = Color(0xff008ce6);
const brandInk = Color(0xff16394d);
const brandMuted = Color(0xff526e7d);
const brandPale = Color(0xffe7faf7);
const brandGradient = LinearGradient(colors: [brandMint, brandBlue]);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: brandInk,
      backgroundColor: Colors.white.withValues(alpha: .9),
    ),
  ),
  colorScheme: ColorScheme.fromSeed(seedColor: brandBlue).copyWith(
    primary: const Color(0xff0074bd),
    onPrimary: Colors.white,
    secondary: brandMint,
    onSecondary: brandInk,
    surface: Colors.white,
    onSurface: brandInk,
    primaryContainer: brandPale,
    onPrimaryContainer: brandInk,
  ),
);
