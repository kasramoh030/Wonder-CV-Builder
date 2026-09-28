import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/resume_repository.dart';
import '../domain/analysis/cv_text_index.dart';
import '../domain/analysis/job_description_analyzer.dart';
import '../domain/entities/job_description.dart';
import '../domain/entities/resume.dart';
import 'providers.dart';

/// Saved job adverts, most recent first.
final StreamProviderFamily<List<JobDescriptionInfo>, String?> jobDescriptionsProvider =
    StreamProvider.family<List<JobDescriptionInfo>, String?>(
  (Ref ref, String? resumeId) =>
      ref.watch(resumeRepositoryProvider).watchJobDescriptions(resumeId: resumeId),
);

/// The advert a document is currently being matched against.
///
/// Kept per document, in memory only: an advert is a scratch input for one
/// analysis round, and persisting it silently would leave the app holding
/// text the user only pasted to see a number.
final NotifierProviderFamily<JobMatchController, JobMatchState, String>
    jobMatchControllerProvider =
    NotifierProvider.family<JobMatchController, JobMatchState, String>(
  JobMatchController.new,
);

/// The match for a document, recomputed when either side changes.
///
/// Returns `null` when no advert has been supplied, which is what keeps the
/// job-match dimension out of the score rather than faking it.
final FutureProviderFamily<JobMatchReport?, String> jobMatchForResumeProvider =
    FutureProvider.family<JobMatchReport?, String>((Ref ref, String resumeId) async {
  final JobMatchState state = ref.watch(jobMatchControllerProvider(resumeId));
  final String advert = state.advertText.trim();
  if (advert.isEmpty) return null;

  final Resume? resume = await ref.watch(resumeByIdProvider(resumeId).future);
  if (resume == null) return null;

  final JobDescriptionAnalyzer analyzer = ref.watch(jobAnalyzerProvider);
  final JobDescription parsed = analyzer.parse(
    rawText: advert,
    knownTitle: state.jobTitle,
    resumeId: resumeId,
    id: state.advertId ?? '',
  );

  return analyzer.match(
    advert: parsed,
    cv: CvTextIndex.of(resume),
    resumeId: resumeId,
  );
});

/// State of one document's job-match workspace.
class JobMatchState {
  const JobMatchState({
    this.advertText = '',
    this.jobTitle,
    this.advertId,
    this.saved = false,
    this.running = false,
  });

  final String advertText;
  final String? jobTitle;
  final String? advertId;

  /// `true` once the advert has been written to the local database, so the
  /// UI can offer it again in the next session without keeping the text in
  /// memory.
  final bool saved;
  final bool running;

  bool get hasAdvert => advertText.trim().isNotEmpty;

  JobMatchState copyWith({
    String? advertText,
    String? jobTitle,
    String? advertId,
    bool? saved,
    bool? running,
  }) =>
      JobMatchState(
        advertText: advertText ?? this.advertText,
        jobTitle: jobTitle ?? this.jobTitle,
        advertId: advertId ?? this.advertId,
        saved: saved ?? this.saved,
        running: running ?? this.running,
      );
}

/// Owns the pasted advert for one document.
class JobMatchController extends FamilyNotifier<JobMatchState, String> {
  @override
  JobMatchState build(String resumeId) => const JobMatchState();

  void setAdvert(String text, {String? jobTitle}) {
    state = state.copyWith(advertText: text, jobTitle: jobTitle, saved: false);
  }

  void clear() {
    state = const JobMatchState();
  }

  /// Persists the advert so the analysis can be reopened later.
  ///
  /// Only ever called from an explicit user action: pasting an advert is not
  /// consent to store it.
  Future<JobDescription> persist() async {
    final String text = state.advertText.trim();
    final JobDescription parsed = ref.read(jobAnalyzerProvider).parse(
          rawText: text,
          knownTitle: state.jobTitle,
          resumeId: arg,
          id: state.advertId ?? '',
        );
    await ref.read(resumeRepositoryProvider).saveJobDescription(parsed);
    state = state.copyWith(advertId: parsed.id, saved: true);
    return parsed;
  }
}
