import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_providers.dart';
import 'connectivity_banner.dart';

/// The four-tab shell that wraps every top-level screen.
///
/// Uses [StatefulNavigationShell] from go_router, so each tab keeps its own
/// navigation stack and scroll position when the user switches away and
/// back — important in a builder where a mistake costs a form's worth of
/// typing.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextDirection direction = Directionality.of(context);

    return Scaffold(
      body: Column(
        children: <Widget>[
          const ConnectivityBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          // Tapping the active tab pops back to that tab's root, matching
          // platform conventions.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.folder_copy_outlined),
            selectedIcon: const Icon(Icons.folder_copy_rounded),
            label: l10n.myCvs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: const Icon(Icons.dashboard_customize_rounded),
            label: l10n.templates,
          ),
          NavigationDestination(
            icon: const Icon(Icons.file_download_outlined),
            selectedIcon: const Icon(Icons.file_download_rounded),
            label: l10n.importTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune_rounded),
            label: l10n.settingsTitle,
          ),
        ],
      ),
      // RTL-aware floating action button placement is handled by Material,
      // but the label is ours.
      floatingActionButton: navigationShell.currentIndex == 0
          ? null
          : null,
      floatingActionButtonLocation: direction == TextDirection.rtl
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }
}
