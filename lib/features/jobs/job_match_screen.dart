import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/providers_jobs.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/resume_repository.dart';
import '../../domain/analysis/job_description_analyzer.dart';
import '../../domain/entities/analysis_report.dart';
import '../../domain/entities/job_description.dart';
import '../../l10n/app_localizations.dart';

/// Compare one CV against one job advert.
///
/// The advert is parsed locally: the title, the skills and the terminology are
/// extracted on the device, and the comparison against the CV is a keyword and
/// requirement overlap — no advert text leaves the phone unless the user later
/// asks the optional online assistant for something.
///
/// The screen deliberately separates "what the advert asks for" from "what
/// your CV shows", because the interesting output is the second list, and it
/// always carries the honesty note: a missing keyword is only worth adding if
/// the experience behind it is real.
class JobMatchScreen extends ConsumerStatefulWidget {
  const JobMatchScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  ConsumerState<JobMatchScreen> createState() => _JobMatchScreenState();
}

class _JobMatchScreenState extends ConsumerState<JobMatchScreen> {
  late final TextEditingController _advertController = TextEditingController(
    text: ref.read(jobMatchControllerProvider(widget.resumeId)).advertText,
  );

  @override
  void dispose() {
    _advertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JobMatchState state =
        ref.watch(jobMatchControllerProvider(widget.resumeId));
    final AsyncValue<JobMatchReport?> match =
        ref.watch(jobMatchForResumeProvider(widget.resumeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.jobMatchTitle),
        actions: <Widget>[
          if (state.hasAdvert)
            IconButton(
              tooltip: l10n.clear,
              onPressed: () {
                _advertController.clear();
                ref
                    .read(jobMatchControllerProvider(widget.resumeId).notifier)
                    .clear();
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screen,
        children: <Widget>[
          TextField(
            controller: _advertController,
            minLines: 6,
            maxLines: 12,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: l10n.jobDescriptionTitle,
              hintText: l10n.jobDescriptionHint,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: ref
                .read(jobMatchControllerProvider(widget.resumeId).notifier)
                .setAdvert,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.hasAdvert
                      ? () async {
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          await ref
                              .read(
                                jobMatchControllerProvider(widget.resumeId)
                                    .notifier,
                              )
                              .persist();
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.save)),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.jobAnalyze),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: state.hasAdvert
                    ? () => _fillFromClipboard()
                    : null,
                child: Text(l10n.jobPasteDescription),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!state.hasAdvert)
            EmptyState(
              icon: Icons.work_outline_rounded,
              title: l10n.jobNoDescriptionTitle,
              body: l10n.jobNoDescriptionBody,
            )
          else
            ...match.when(
              loading: () => <Widget>[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: AppSpacing.lg),
                Center(child: Text(l10n.loading)),
              ],
              error: (Object error, StackTrace stack) => <Widget>[
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.somethingWentWrong,
                  body: l10n.jobNoDescriptionBody,
                  actionLabel: l10n.tryAgain,
                  onAction: () =>
                      ref.invalidate(jobMatchForResumeProvider(widget.resumeId)),
                ),
              ],
              data: (JobMatchReport? report) => _results(context, report),
            ),
          const SizedBox(height: AppSpacing.xl),
          _SavedAdverts(resumeId: widget.resumeId),
        ],
      ),
    );
  }

  /// Pulls the advert out of the clipboard.
  ///
  /// Pasting is the normal way an advert arrives — copied from a job board in
  /// another app — and it never leaves the device.
  Future<void> _fillFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (!mounted || text == null || text.trim().isEmpty) return;
    _advertController.text = text;
    ref
        .read(jobMatchControllerProvider(widget.resumeId).notifier)
        .setAdvert(text);
  }

  List<Widget> _results(BuildContext context, JobMatchReport? report) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (report == null) return <Widget>[];
    final JobDescription advert = ref.read(jobAnalyzerProvider).parse(
          rawText:
              ref.read(jobMatchControllerProvider(widget.resumeId)).advertText,
          resumeId: widget.resumeId,
        );
    final JobRequirements requirements = advert.requirements;

    return <Widget>[
      _MatchScoreCard(report: report),
      const SizedBox(height: AppSpacing.lg),
      _DimensionCard(report: report, explanation: report.explanation),
      if (report.keywordDetail != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        _KeywordCard(detail: report.keywordDetail!),
      ],
      const SizedBox(height: AppSpacing.lg),
      _ExtractedCard(advert: advert, requirements: requirements),
      const SizedBox(height: AppSpacing.lg),
      Text(
        l10n.analyzerKeywordHonestyNote,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];
  }
}

class _MatchScoreCard extends StatelessWidget {
  const _MatchScoreCard({required this.report});

  final JobMatchReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Color colour = AppColors.forScore(report.overall);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  l10n.analyzerScoreJobMatch,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${report.overall}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colour,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: report.overall / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({required this.report, required this.explanation});

  final JobMatchReport report;
  final Map<String, String> explanation;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    // The analyser keys its reasoning by dimension, so the label and the
    // reason travel together.
    final List<({String label, String key, int score})> dimensions =
        <({String label, String key, int score})>[
      (label: l10n.jobMatchSkills, key: 'skills', score: report.skills),
      (label: l10n.jobMatchExperience, key: 'experience', score: report.experience),
      (label: l10n.jobMatchEducation, key: 'education', score: report.education),
      (label: l10n.jobMatchKeywords, key: 'keywords', score: report.keywords),
      (label: l10n.jobMatchSeniority, key: 'seniority', score: report.seniority),
      (label: l10n.jobMatchDomain, key: 'domain', score: report.domain),
    ];

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ({String label, String key, int score}) row in dimensions) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(row.label, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    '${row.score}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.forScore(row.score),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: row.score / 100,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.forScore(row.score),
                  ),
                ),
              ),
              if (explanation[row.key] != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  explanation[row.key]!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeywordCard extends StatelessWidget {
  const _KeywordCard({required this.detail});

  final KeywordAnalysis detail;

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
            Text(l10n.analyzerKeywordsFound, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (detail.found.isEmpty)
              Text('—', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final String keyword in detail.found)
                    _Chip(
                      label: JobDescriptionAnalyzer.display(keyword),
                      colour: AppColors.scoreGood,
                      icon: Icons.check_rounded,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.analyzerKeywordsMissing, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (detail.missing.isEmpty)
              Text('—', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final String keyword in detail.missing)
                    _Chip(
                      label: JobDescriptionAnalyzer.display(keyword),
                      colour: AppColors.high,
                      icon: Icons.remove_rounded,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.analyzerKeywordHonestyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractedCard extends StatelessWidget {
  const _ExtractedCard({required this.advert, required this.requirements});

  final JobDescription advert;
  final JobRequirements requirements;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<({String label, List<String> values})> groups =
        <({String label, List<String> values})>[
      (label: l10n.jobRequiredSkills, values: requirements.requiredSkills),
      (label: l10n.jobPreferredSkills, values: requirements.preferredSkills),
      (label: l10n.jobSoftSkills, values: requirements.softSkills),
      (label: l10n.fieldTechnologies, values: requirements.technologies),
      (label: l10n.jobQualifications, values: requirements.qualifications),
      (label: l10n.fieldLanguage, values: requirements.languages),
    ].where((({String label, List<String> values}) g) => g.values.isNotEmpty)
            .toList(growable: false);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.jobDescriptionTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (advert.jobTitle.isNotEmpty)
              Text(
                advert.jobTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (requirements.detectedSeniority != null)
              Text(
                '${l10n.jobSeniority}: ${requirements.detectedSeniority}',
                style: theme.textTheme.bodySmall,
              ),
            if (requirements.yearsRequired != null)
              Text(
                '${requirements.yearsRequired}+',
                style: theme.textTheme.bodySmall,
              ),
            for (final ({String label, List<String> values}) group in groups) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(group.label, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final String value in group.values.take(24))
                    _Chip(
                      label: JobDescriptionAnalyzer.display(value),
                      colour: theme.colorScheme.primary,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.colour, this.icon});

  final String label;
  final Color colour;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: colour),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}

/// Adverts the user chose to keep.
///
/// Saved only by an explicit tap: pasting an advert into the box does not
/// store it anywhere.
class _SavedAdverts extends ConsumerWidget {
  const _SavedAdverts({required this.resumeId});

  final String resumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<JobDescriptionInfo>> saved =
        ref.watch(jobDescriptionsProvider(resumeId));

    return saved.maybeWhen(
      data: (List<JobDescriptionInfo> adverts) => adverts.isEmpty
          ? const SizedBox.shrink()
          : Card(
              child: Padding(
                padding: AppSpacing.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.jobDescriptionTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final JobDescriptionInfo advert in adverts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          advert.jobTitle.isEmpty
                              ? l10n.jobDescriptionTitle
                              : advert.jobTitle,
                        ),
                        subtitle: advert.company.isEmpty
                            ? null
                            : Text(advert.company),
                        trailing: IconButton(
                          tooltip: l10n.delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => ref
                              .read(resumeRepositoryProvider)
                              .deleteJobDescription(advert.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
