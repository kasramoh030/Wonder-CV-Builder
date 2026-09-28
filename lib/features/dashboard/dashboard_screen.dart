import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import '../shell/connectivity_banner.dart';
import 'widgets/quick_action_card.dart';

/// The home tab: every CV the user owns, plus the three things they most
/// often want to do next.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.only(end: AppSpacing.lg),
            child: Center(child: ProcessingModePill()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Placeholder for a future "re-check connectivity" pull gesture.
          await Future<void>.delayed(const Duration(milliseconds: 150));
        },
        child: ListView(
          padding: AppSpacing.screen,
          children: <Widget>[
            const _QuickActions(),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle(title: l10n.myCvs),
            const SizedBox(height: AppSpacing.md),
            const _ResumeList(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        QuickActionCard(
          icon: Icons.add_circle_outline_rounded,
          title: l10n.createNewCv,
          subtitle: l10n.onboardingWhatCreatingHint,
          emphasised: true,
          onTap: () => _createCv(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: QuickActionCard(
                icon: Icons.person_outline_rounded,
                title: l10n.masterProfile,
                subtitle: l10n.masterProfileSubtitle,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionCard(
                icon: Icons.insights_outlined,
                title: l10n.cvAnalyzer,
                subtitle: l10n.cvAnalyzerSubtitle,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: QuickActionCard(
                icon: Icons.work_outline_rounded,
                title: l10n.jobAnalyzer,
                subtitle: l10n.jobAnalyzerSubtitle,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionCard(
                icon: Icons.upload_file_outlined,
                title: l10n.importTitle,
                subtitle: l10n.importFromPdf,
                onTap: () => AppRoutes.import,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _createCv(BuildContext context) {
    // Wired to the dashboard controller in the next layer down; the import
    // is deliberately dangling until the repository lands, so this screen
    // compiles and renders on its own.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).createNewCv)),
    );
  }
}

class _ResumeList extends StatelessWidget {
  const _ResumeList();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.folder_open_rounded,
      title: l10n.noCvsTitle,
      body: l10n.noCvsBody,
      actionLabel: l10n.createNewCv,
      onAction: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createNewCv)),
        );
      },
    );
  }
}
