import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/analysis_report.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/section_key.dart';
import '../../l10n/analysis_messages.dart';
import '../../l10n/app_localizations.dart';
import '../builder/builder_sections.dart';
import '../builder/section_editor_screen.dart';

/// The CV report.
///
/// Everything here runs on the device: the score, the ATS checks and the
/// findings are produced by rule sets that ship inside the app, so the screen
/// works with no connection and no account. An optional online pass can add
/// semantic suggestions, but it never changes these numbers without saying so,
/// and it never runs before the user has consented.
class AnalyserScreen extends ConsumerWidget {
  const AnalyserScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AnalysisReport> report = ref.watch(analysisProvider(resumeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyzerTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.analyzerRerun,
            onPressed: () => ref.invalidate(analysisProvider(resumeId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: report.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.loading, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        error: (Object error, StackTrace stack) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.somethingWentWrong,
          body: l10n.analyzerRunFirstBody,
          actionLabel: l10n.tryAgain,
          onAction: () => ref.invalidate(analysisProvider(resumeId)),
        ),
        data: (AnalysisReport data) => data.dimensions.isEmpty
            ? EmptyState(
                icon: Icons.insights_outlined,
                title: l10n.analyzerRunFirstTitle,
                body: l10n.analyzerRunFirstBody,
                actionLabel: l10n.analyzerRunAnalysis,
                onAction: () => ref.invalidate(analysisProvider(resumeId)),
              )
            : _ReportBody(resumeId: resumeId, report: data),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.resumeId, required this.report});

  final String resumeId;
  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String language = l10n.locale.languageCode;

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        _ScoreCard(report: report),
        const SizedBox(height: AppSpacing.lg),
        _SourceBadge(source: report.source),
        const SizedBox(height: AppSpacing.lg),
        _DimensionsCard(report: report),
        if (report.stats.wordCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(report: report),
        ],
        if (report.strengths.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StrengthsCard(report: report, language: language),
        ],
        if (report.atsChecks.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _AtsCard(report: report, language: language),
        ],
        const SizedBox(height: AppSpacing.lg),
        _RecommendationsCard(
          resumeId: resumeId,
          report: report,
          language: language,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _AdvancedCard(),
        const SizedBox(height: AppSpacing.lg),
        _Disclaimer(text: l10n.analyzerDisclaimer),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// The headline number.
///
/// It is presented as an approximate read of the document, next to the
/// disclaimer, because that is what it is: a rule-based estimate, not a
/// prediction of anyone's hiring decision.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});

  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Color colour = AppColors.forScore(report.totalScore);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: report.totalScore / 100,
                      strokeWidth: 8,
                      backgroundColor: colour.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(colour),
                    ),
                  ),
                  Text(
                    '${report.totalScore}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.analyzerScoreTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _summaryLine(l10n, report),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summaryLine(AppLocalizations l10n, AnalysisReport report) {
    final int critical = report.countOf(IssuePriority.critical);
    final int high = report.countOf(IssuePriority.high);
    if (critical > 0) {
      return '${l10n.priorityCritical}: $critical · ${l10n.priorityHigh}: $high';
    }
    return '${report.recommendations.length} ${l10n.analyzerRecommendations}';
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final AnalysisSource source;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool offline = source == AnalysisSource.offline;
    final String label = offline ? l10n.analyzerOfflineBadge : l10n.analyzerOnlineBadge;
    final Color colour = offline ? AppColors.offline : AppColors.online;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.12),
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                offline ? Icons.phonelink_off_rounded : Icons.cloud_done_outlined,
                size: 16,
                color: colour,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: colour),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionsCard extends StatelessWidget {
  const _DimensionsCard({required this.report});

  final AnalysisReport report;

  static String _label(AppLocalizations l10n, ScoreKind kind) => switch (kind) {
        ScoreKind.total => l10n.analyzerScoreTitle,
        ScoreKind.structure => l10n.analyzerScoreStructure,
        ScoreKind.content => l10n.analyzerScoreContent,
        ScoreKind.ats => l10n.analyzerScoreAts,
        ScoreKind.language => l10n.analyzerScoreLanguage,
        ScoreKind.jobMatch => l10n.analyzerScoreJobMatch,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<ScoreDimension> dimensions = report.dimensions
        .where((ScoreDimension d) => d.kind != ScoreKind.total)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ScoreDimension d in dimensions) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(_label(l10n, d.kind), style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    '${d.score}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.forScore(d.score),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: d.score / 100,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.forScore(d.score),
                  ),
                ),
              ),
              if (d.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  d.notes.take(2).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.report});

  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ResumeStats stats = report.stats;
    final List<String> chips = <String>[
      '${stats.wordCount} ${l10n.unitWords}',
      '${stats.bulletCount} ${l10n.unitBullets}',
      stats.estimatedPages == 1
          ? '1 ${l10n.unitPage}'
          : '${stats.estimatedPages.toStringAsFixed(1)} ${l10n.unitPages}',
      '${(stats.quantifiedRatio * 100).round()}% ${l10n.statsQuantified}',
    ];

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String chip in chips)
              Chip(
                label: Text(chip),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
          ],
        ),
      ),
    );
  }
}

class _StrengthsCard extends StatelessWidget {
  const _StrengthsCard({required this.report, required this.language});

  final AnalysisReport report;
  final String language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.analyzerStrengths, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final String code in report.strengths)
              if (AnalysisMessages.strength(language, code).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: AppColors.scoreGood,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          AnalysisMessages.strength(language, code),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AtsCard extends StatelessWidget {
  const _AtsCard({required this.report, required this.language});

  final AnalysisReport report;
  final String language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.analyzerScoreAts, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final AtsCheck check in report.atsChecks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      check.passed
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      size: 18,
                      color: check.passed ? AppColors.scoreGood : AppColors.high,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AnalysisMessages.atsCheck(language, check.code).label,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (!check.passed)
                            Text(
                              AnalysisMessages.atsCheck(language, check.code).fix,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  const _RecommendationsCard({
    required this.resumeId,
    required this.report,
    required this.language,
  });

  final String resumeId;
  final AnalysisReport report;
  final String language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<Recommendation> items = report.sortedRecommendations;

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.analyzerRecommendations, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  l10n.analyzerNoIssuesBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final Recommendation r in items)
                _RecommendationTile(
                  resumeId: resumeId,
                  recommendation: r,
                  language: language,
                ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.resumeId,
    required this.recommendation,
    required this.language,
  });

  final String resumeId;
  final Recommendation recommendation;
  final String language;

  static Color _priorityColour(IssuePriority priority) => switch (priority) {
        IssuePriority.critical => AppColors.critical,
        IssuePriority.high => AppColors.high,
        IssuePriority.medium => AppColors.medium,
        IssuePriority.low => AppColors.low,
      };

  static String _priorityLabel(AppLocalizations l10n, IssuePriority priority) =>
      switch (priority) {
        IssuePriority.critical => l10n.priorityCritical,
        IssuePriority.high => l10n.priorityHigh,
        IssuePriority.medium => l10n.priorityMedium,
        IssuePriority.low => l10n.priorityLow,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    // A rule pack can ship an advisory this build does not have wording for;
    // in that case the pack's own sentence is the honest thing to show.
    final String packText = recommendation.params['text'] ?? '';
    final bool known = AnalysisMessages.knows(language, recommendation.code);
    final AnalysisAdvice advice = known || packText.isEmpty
        ? AnalysisMessages.recommendation(language, recommendation.code)
        : (problem: packText, fix: '');
    final Map<String, String> params = <String, String>{
      ...recommendation.params,
      if (recommendation.params['section'] != null)
        'section': sectionTitle(
          SectionKey.fromId(recommendation.params['section']!),
          l10n,
        ),
    };
    final Color colour = _priorityColour(recommendation.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.14),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  _priorityLabel(l10n, recommendation.priority),
                  style: theme.textTheme.labelSmall?.copyWith(color: colour),
                ),
              ),
              const Spacer(),
              if (recommendation.section != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => SectionEditorScreen(
                        resumeId: resumeId,
                        sectionKey: recommendation.section!,
                      ),
                    ),
                  ),
                  child: Text(
                    sectionTitle(recommendation.section!, l10n),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            AnalysisMessages.fill(advice.problem, params),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (advice.fix.isNotEmpty)
            Text(
              AnalysisMessages.fill(advice.fix, params),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The optional online pass.
///
/// Kept deliberately quiet: the offline report above is complete on its own.
/// This card only explains what the online pass would add and where the key
/// lives, so nobody is pushed into sending their CV anywhere.
class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.aiTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.aiNoKeyBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.goNamed(AppRoutes.settings),
                child: Text(l10n.aiOpenSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
