import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/app_settings.dart';
import '../domain/enums/document_options.dart';
import '../features/settings/settings_providers.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root of the widget tree.
///
/// Responsibilities are deliberately narrow: resolve locale and theme mode,
/// wire up the localisation delegates, and hand control to the router.
/// Anything heavier (database, analyser, PDF engine) is resolved lazily by
/// the screens that need it, so a cold start stays fast on cheap hardware.
class CvProApp extends ConsumerWidget {
  const CvProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final Locale locale = Locale(settings.languageCode);
    final AppLocalizations l10n = AppLocalizations.ofCode(settings.languageCode);
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => l10n.appName,
      debugShowCheckedModeBanner: false,

      // ── Localisation ─────────────────────────────────────────────────────
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: AppLocalizations.resolve,

      // ── Presentation ─────────────────────────────────────────────────────
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },

      // Accessibility: honour the system font scale but clamp it. Past ~1.4
      // the dense builder forms begin to clip, and a CV tool that becomes
      // unusable at large text sizes fails exactly the users who need it
      // most. Clamping keeps every control reachable.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      routerConfig: router,
    );
  }
}
