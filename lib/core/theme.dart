import 'package:flutter/material.dart';

const _seed = Color(0xFF2563EB);

ThemeData buildLightTheme() => _theme(
  ColorScheme.fromSeed(seedColor: _seed),
);

ThemeData buildDarkTheme() => _theme(
  ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
);

ThemeData _theme(ColorScheme scheme) => ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  scaffoldBackgroundColor: scheme.surface,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    scrolledUnderElevation: 0,
    toolbarHeight: 64,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide.none,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    minVerticalPadding: 8,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    height: 72,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  ),
  navigationRailTheme: NavigationRailThemeData(
    minWidth: 76,
    minExtendedWidth: 220,
    groupAlignment: -0.65,
    useIndicator: true,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
  ),
  dividerTheme: DividerThemeData(
    color: scheme.outlineVariant.withValues(alpha: .5),
    space: 1,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
