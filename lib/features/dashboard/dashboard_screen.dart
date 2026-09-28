import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/date_display.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/resume.dart';
import '../../domain/enums/cv_type.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_steps.dart';
import '../settings/settings_providers.dart';
import '../shell/connectivity_banner.dart';
import 'widgets/quick_action_card.dart';

/// The home tab: every CV the user owns, plus the things they most often want
/// to do next.
///
/// The library is read from the database as a stream, so duplicating or
/// deleting a document — here or in the editor — updates this screen without
/// anything having to remember to refresh it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Resume>> library = ref.watch(resumeListProvider);

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
        onRefresh: () async => ref.invalidate(resumeListProvider),
        child: ListView(
          padding: AppSpacing.screen,
          children: <Widget>[
            const _QuickActions(),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle(title: l10n.myCvs),
            const SizedBox(height: AppSpacing.md),
            library.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace stack) => Text(
                l10n.errorStorageFailure,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              data: (List<Resume> resumes) => resumes.isEmpty
                  ? _EmptyLibrary(l10n: l10n)
                  : Column(
                      children: <Widget>[
                        for (final Resume resume in resumes)
                          _ResumeCard(resume: resume, l10n: l10n),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      children: <Widget>[
        QuickActionCard(
          icon: Icons.add_circle_outline_rounded,
          title: l10n.createNewCv,
          subtitle: l10n.onboardingWhatCreatingHint,
          emphasised: true,
          onTap: () => context.pushNamed(AppRoutes.newCv),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: QuickActionCard(
                icon: Icons.person_outline_rounded,
                title: l10n.masterProfile,
                subtitle: l10n.masterProfileSubtitle,
                onTap: () => _openMasterProfile(context, ref),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionCard(
                icon: Icons.insights_outlined,
                title: l10n.cvAnalyzer,
                subtitle: l10n.cvAnalyzerSubtitle,
                onTap: () => _open(
                  context,
                  ref,
                  AppRoutes.analyserPath,
                  l10n,
                ),
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
                onTap: () => _open(
                  context,
                  ref,
                  AppRoutes.jobMatchPath,
                  l10n,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionCard(
                icon: Icons.upload_file_outlined,
                title: l10n.importTitle,
                subtitle: l10n.importFromPdf,
                onTap: () => context.go('/import'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens the analyser for the most recently edited document.
  ///
  /// Analysis is per document, so a CV has to exist first. Saying so is better
  /// than opening an empty analyser that looks broken.
  void _open(
    BuildContext context,
    WidgetRef ref,
    String Function(String resumeId) path,
    AppLocalizations l10n,
  ) {
    final List<Resume> resumes =
        ref.read(resumeListProvider).valueOrNull ?? const <Resume>[];
    if (resumes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noCvsTitle)),
      );
      return;
    }
    context.push(path(resumes.first.id));
  }

  Future<void> _openMasterProfile(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    Resume? master = ref.read(masterProfileProvider).valueOrNull;
    if (master == null) {
      final AppSettings settings =
          ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
      master = await ref.read(resumeRepositoryProvider).create(
            title: l10n.masterProfile,
            region: settings.defaultRegion,
            cvType: CvType.professionalCv,
            industry: settings.defaultIndustry,
            languageCode: settings.languageCode,
            isMasterProfile: true,
          );
    }
    if (!context.mounted) return;
    await context.push(AppRoutes.builderPath(master.id));
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.folder_open_rounded,
        title: l10n.noCvsTitle,
        body: l10n.noCvsBody,
        actionLabel: l10n.createNewCv,
        onAction: () => context.pushNamed(AppRoutes.newCv),
      );
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.resume, required this.l10n});

  final Resume resume;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = <String>[
      cvTypeLabel(l10n, resume.cvType),
      regionLabel(l10n, resume.region),
      if (resume.isMasterProfile) l10n.masterProfile,
    ].join(' · ');

    final DateTime? stamp = resume.updatedAt ?? resume.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            resume.isMasterProfile
                ? Icons.person_outline_rounded
                : Icons.description_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(resume.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          stamp == null
              ? subtitle
              : '$subtitle\n${l10n.updatedOn} ${_date(context, stamp)}',
          maxLines: 2,
        ),
        isThreeLine: true,
        onTap: () => context.push(AppRoutes.builderPath(resume.id)),
        trailing: PopupMenuButton<String>(
          onSelected: (String action) => _act(context, ref, action),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'preview',
              child: Text(l10n.previewTitle),
            ),
            PopupMenuItem<String>(
              value: 'analyse',
              child: Text(l10n.analyzerTitle),
            ),
            PopupMenuItem<String>(
              value: 'job',
              child: Text(l10n.jobAnalyzer),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'duplicate',
              child: Text(l10n.duplicate),
            ),
            PopupMenuItem<String>(value: 'delete', child: Text(l10n.delete)),
          ],
        ),
      ),
    );
  }

  /// `2026-09-29`, in the reader's own digits.
  ///
  /// Deliberately not localized through a date-format package: the app ships
  /// its own calendar layer for CV dates, and a document list does not need a
  /// second one. The stored value is always Gregorian, so this is a faithful
  /// rendition of what the database holds.
  String _date(BuildContext context, DateTime value) {
    final DateTime local = value.toLocal();
    final String raw = '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    return DateDisplay.toLocalDigits(
      raw,
      Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'preview':
        await context.push(AppRoutes.previewPath(resume.id));
      case 'analyse':
        await context.push(AppRoutes.analyserPath(resume.id));
      case 'job':
        await context.push(AppRoutes.jobMatchPath(resume.id));
      case 'duplicate':
        await ref.read(resumeRepositoryProvider).duplicate(resume.id);
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  /// Deleting is always confirmed and always archiving: the document can be
  /// brought back, which matters because the alternative — an unrecoverable
  /// tap — is how people lose a week of writing.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(l10n.privacyDeleteAllBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(resumeRepositoryProvider).archive(resume.id);
  }
}
