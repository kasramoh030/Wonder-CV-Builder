import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/repositories/resume_repository.dart';
import '../data/rules/regional_rules_repository.dart';
import '../domain/analysis/analyzer_engine.dart';
import '../domain/analysis/analyzer_vocabulary.dart';
import '../domain/analysis/cv_text_index.dart';
import '../domain/analysis/job_description_analyzer.dart';
import '../domain/entities/analysis_report.dart';
import '../domain/entities/job_description.dart';
import '../domain/entities/regional_profile.dart';
import '../domain/entities/resume.dart';
import '../domain/enums/document_options.dart';
import '../domain/enums/region_code.dart';
import '../domain/rules/regional_rule_engine.dart';
import '../domain/templates/resume_template.dart';
import '../features/settings/settings_providers.dart';
import 'providers_jobs.dart';

/// The single database handle for the app's lifetime.
///
/// Opened once and closed when the provider container is disposed, so a test
/// can supply an in-memory executor through [appDatabaseProvider] and get a
/// hermetic app.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final Provider<ResumeRepository> resumeRepositoryProvider =
    Provider<ResumeRepository>(
  (Ref ref) => DriftResumeRepository(ref.watch(appDatabaseProvider)),
);

/// The CV library, live. The dashboard rebuilds whenever a document changes,
/// which is what makes "duplicate then edit" feel instant.
final StreamProvider<List<Resume>> resumeListProvider =
    StreamProvider<List<Resume>>(
  (Ref ref) => ref.watch(resumeRepositoryProvider).watchAll(),
);

final StreamProvider<Resume?> masterProfileProvider = StreamProvider<Resume?>(
  (Ref ref) => ref.watch(resumeRepositoryProvider).watchMasterProfile(),
);

/// One document, live, by id. Returns `null` for an id that no longer exists
/// rather than throwing, so a screen cannot crash on a deleted CV.
final StreamProviderFamily<Resume?, String> resumeByIdProvider =
    StreamProvider.family<Resume?, String>(
  (Ref ref, String id) => ref
      .watch(resumeRepositoryProvider)
      .watchAll(includeArchived: true)
      .map((List<Resume> all) =>
          all.where((Resume r) => r.id == id).firstOrNull),
);

final StreamProviderFamily<List<ResumeVersionInfo>, String> resumeVersionsProvider =
    StreamProvider.family<List<ResumeVersionInfo>, String>(
  (Ref ref, String resumeId) =>
      ref.watch(resumeRepositoryProvider).watchVersions(resumeId),
);

/// The template catalog is data, not a service, so it is a plain constant.
final Provider<List<ResumeTemplate>> templatesProvider =
    Provider<List<ResumeTemplate>>((Ref ref) => ResumeTemplates.all);

final Provider<AnalyzerEngine> analyzerEngineProvider =
    Provider<AnalyzerEngine>(
  (Ref ref) => AnalyzerEngine(vocabulary: ref.watch(analyzerVocabularyProvider)),
);

/// The analyser vocabulary: compiled in, optionally extended from
/// `assets/data/analyzer/vocabulary.json`. Loaded once.
final FutureProvider<AnalyzerVocabulary> analyzerVocabularyProvider =
    FutureProvider<AnalyzerVocabulary>(
  (Ref ref) => AnalyzerVocabulary.load(),
);

final Provider<JobDescriptionAnalyzer> jobAnalyzerProvider =
    Provider<JobDescriptionAnalyzer>(
  (Ref ref) => JobDescriptionAnalyzer(
    vocabulary: ref.watch(analyzerVocabularyProvider).valueOrNull ??
        AnalyzerVocabulary.standard,
  ),
);

/// The market rules for a document, resolved through the region profile.
final FutureProviderFamily<RegionalProfile, RegionCode> regionalProfileProvider =
    FutureProvider.family<RegionalProfile, RegionCode>(
  (Ref ref, RegionCode region) =>
      ref.watch(regionalRulesRepositoryProvider).load(region),
);

/// The resolved presentation plan for a document.
///
/// Everything that renders — builder, preview, PDF — reads this rather than
/// asking about countries itself, so "what does Germany expect?" is answered
/// in exactly one place.
final ProviderFamily<FormatPlan, Resume> formatPlanProvider =
    Provider.family<FormatPlan, Resume>((Ref ref, Resume resume) {
  final RegionalProfile profile =
      ref.watch(regionalRulesRepositoryProvider).cached(resume.region);
  return RegionalRuleEngine.planFor(
    profile: profile,
    resume: resume,
    template: ResumeTemplates.byId(resume.templateId),
    dateSystemOverride: ref.watch(dateSystemPreferenceProvider),
  );
});

/// The user's calendar preference, when they have expressed one.
///
/// `null` means "follow the market", which is the default: a German CV prints
/// Gregorian dates because Germany does.
final Provider<DateSystem?> dateSystemPreferenceProvider =
    Provider<DateSystem?>((Ref ref) => null);

/// Analysis of a document, run on demand and cached until the content changes.
///
/// The analyser itself is pure, so this provider only assembles its inputs:
/// the document, the market rules, the template and — when the user has
/// analysed against an advert — the job match.
final FutureProviderFamily<AnalysisReport, String> analysisProvider =
    FutureProvider.family<AnalysisReport, String>((Ref ref, String resumeId) async {
  final Resume? resume = await ref.watch(resumeByIdProvider(resumeId).future);
  if (resume == null) {
    return AnalysisReport.empty();
  }
  final RegionalProfile profile =
      await ref.watch(regionalProfileProvider(resume.region).future);
  final JobMatchReport? match = await ref.watch(jobMatchForResumeProvider(resumeId).future);

  return ref.watch(analyzerEngineProvider).analyse(
        AnalysisRequest(
          resume: resume,
          profile: profile,
          template: ResumeTemplates.byId(resume.templateId),
          jobMatch: match,
        ),
      );
});

/// The tags a CV's text index exposes, for screens that want to show what the
/// analyser actually saw.
final ProviderFamily<CvTextIndex, Resume> cvTextIndexProvider =
    Provider.family<CvTextIndex, Resume>(
  (Ref ref, Resume resume) => CvTextIndex.of(resume),
);
