import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/features/shared/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read saved locale preference (if any)
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_language');

  // Detect device locale as fallback
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final initialLocale = savedLang != null
      ? Locale(savedLang)
      : (deviceLocale.languageCode == 'ar' ? const Locale('ar') : const Locale('en'));

  // Read saved theme
  final savedTheme = prefs.getString('app_theme');
  final initialTheme = switch (savedTheme) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => initialLocale),
        themeModeProvider.overrideWith((ref) => initialTheme),
      ],
      child: const _PersistentApp(),
    ),
  );
}

/// Wrapper that persists locale and theme changes to SharedPreferences.
class _PersistentApp extends ConsumerWidget {
  const _PersistentApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Persist locale changes
    ref.listen(localeProvider, (_, next) async {
      if (next != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_language', next.languageCode);
      }
    });

    // Persist theme changes
    ref.listen(themeModeProvider, (_, next) async {
      final prefs = await SharedPreferences.getInstance();
      final val = switch (next) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        _ => 'system',
      };
      await prefs.setString('app_theme', val);
    });

    return const FindMyPhoneApp();
  }
}
