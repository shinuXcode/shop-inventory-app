import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/database/app_database.dart';
import 'features/shell/shell.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) =>
  throw UnimplementedError('SharedPreferences must be overridden in main'));

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!prefs.containsKey('darkMode')) return ThemeMode.system;
    return prefs.getBool('darkMode') == true ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.system;
    await ref.read(sharedPreferencesProvider).setBool('darkMode', enabled);
  }
}

class SBillApp extends ConsumerWidget {
  const SBillApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'SBILL',
    debugShowCheckedModeBanner: false,
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeMode: ref.watch(themeModeProvider),
    home: const Shell(),
  );
}
