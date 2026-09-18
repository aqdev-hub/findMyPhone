import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/app_lock/presentation/app_lock_screen.dart';
import 'features/auth/presentation/setup_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/shared/providers.dart';

class FindMyPhoneApp extends ConsumerWidget {
  const FindMyPhoneApp({super.key});

  static const _teal = Color(0xff0d7377);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingCompleteProvider);
    final setup = ref.watch(setupCompleteProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isAr = (locale?.languageCode ?? 'ar') == 'ar';

    return MaterialApp(
      title: isAr ? 'اعثر على هاتفي' : 'Find My Phone',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // Language / RTL
      locale: locale ?? (isAr ? const Locale('ar') : const Locale('en')),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: _buildTheme(Brightness.light, isAr),
      darkTheme: _buildTheme(Brightness.dark, isAr),

      builder: (context, child) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),

      home: onboarding.when(
        data: (onboardingSeen) {
          if (!onboardingSeen) return const OnboardingScreen();
          return setup.when(
            data: (complete) => complete
                ? const AppLockGate(child: HomeScreen())
                : const SetupScreen(),
            loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator())),
            error: (e, _) => Scaffold(
                body: Center(child: Text('خطأ: $e'))),
          );
        },
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
            body: Center(child: Text('خطأ: $e'))),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, bool isAr) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: brightness,
    );
    // Arabic → Tajawal, English → Poppins
    final fontFamily = isAr ? 'Tajawal' : 'Poppins';

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: fontFamily,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xff0f1117) : const Color(0xfff5f7fa),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xff161b22) : cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: isDark ? const Color(0xff1c2128) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xff21262d) : const Color(0xfff0f4f8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle:
              TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? const Color(0xff161b22) : Colors.white,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontFamily: fontFamily, fontSize: 11),
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 0.5),
    );
  }
}
