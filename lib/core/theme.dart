import 'package:flutter/material.dart';
const _seed = Color(0xFF2563EB);
ThemeData buildLightTheme() => _theme(ColorScheme.fromSeed(seedColor: _seed));
ThemeData buildDarkTheme() => _theme(ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark));
ThemeData _theme(ColorScheme scheme) => ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  ),
);
