import 'package:json_annotation/json_annotation.dart';

import '../enums/document_options.dart';
import '../enums/section_key.dart';

part 'analysis_report.g.dart';

/// One scored dimension of a CV.
///
/// Every score is 0–100 and always accompanied by the evidence that produced
/// it. A number without an explanation is worse than no number at all: it
/// invites the user to game the metric instead of improving the CV.
@JsonSerializable(explicitToJson: true)
class ScoreDimension {
  const ScoreDimension({
    required this.kind,
    required this.score,
    this.weight = 1,
    this.notes = const <String>[],
  });

  final ScoreKind kind;
  final int score;

  /// Relative weight used when combining dimensions into the total. Kept as
  /// data so a region profile can adjust it (an ATS-heavy market weights
  /// [ScoreKind.ats] higher).
  final double weight;

  /// Short, human-readable evidence lines shown under the score bar.
  final List<String> notes;

  factory ScoreDimension.fromJson(Map<String, dynamic> json) =>
      _$ScoreDimensionFromJson(json);

  Map<String, dynamic> toJson() => _$ScoreDimensionToJson(this);

  double get weighted => score * weight;
}

enum ScoreKind {
  @JsonValue('total')
  total,
  @JsonValue('structure')
  structure,
  @JsonValue('content')
  content,
  @JsonValue('ats')
  ats,
  @JsonValue('language')
  language,
  @JsonValue('jobMatch')
  jobMatch;

  static ScoreKind fromId(String id) => ScoreKind.values.firstWhere(
        (ScoreKind k) => k.id == id,
        orElse: () => ScoreKind.total,
      );

  String get id => switch (this) {
        ScoreKind.total => 'total',
        ScoreKind.structure => 'structure',
        ScoreKind.content => 'content',
        ScoreKind.ats => 'ats',
        ScoreKind.language => 'language',
        ScoreKind.jobMatch => 'job_match',
      };
}

/// A single actionable finding.
///
/// [messageCode] is a stable identifier resolved to a localised sentence at
/// render time by the localisation layer. Keeping *logic* in the analyser
/// and *language* in the presentation layer is what allows the whole
/// analyser to run offline in three languages without duplicating rules.
@JsonSerializable()
class Recommendation {
  const Recommendation({
    required this.code,
    required this.priority,
    required this.category,
    this.section,
    this.params = const <String, String>{},
    this.autoFixable = false,
  });

  final String code;
  final IssuePriority priority;
  final RecommendationCategory category;

  /// Section the finding refers to, when it is section-specific. Lets the
  /// UI deep-link into the right editor.
  final SectionKey? section;

  /// Placeholders substituted into the localised message, e.g. `{'count': '3'}`.
  final Map<String, String> params;

  /// `true` when the app can offer a one-tap fix (for example removing a
  /// duplicate skill). The AI assistant never sets this flag.
  final bool autoFixable;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationToJson(this);
}

enum RecommendationCategory {
  @JsonValue('structure')
  structure,
  @JsonValue('content')
  content,
  @JsonValue('ats')
  ats,
  @JsonValue('language')
  language,
  @JsonValue('job_match')
  jobMatch,
  @JsonValue('regional')
  regional;

  static RecommendationCategory fromId(String id) =>
      RecommendationCategory.values.firstWhere(
        (RecommendationCategory c) => c.id == id,
        orElse: () => RecommendationCategory.content,
      );

  String get id => switch (this) {
        RecommendationCategory.structure => 'structure',
        RecommendationCategory.content => 'content',
        RecommendationCategory.ats => 'ats',
        RecommendationCategory.language => 'language',
        RecommendationCategory.jobMatch => 'job_match',
        RecommendationCategory.regional => 'regional',
      };
}

/// Result of a single ATS mechanical check.
@JsonSerializable()
class AtsCheck {
  const AtsCheck({
    required this.code,
    required this.passed,
    this.detail = '',
  });

  /// e.g. `ats.singleColumn`, `ats.searchableText`, `ats.standardHeadings`.
  final String code;
  final bool passed;

  /// Optional machine detail (a count, a detected font name) appended to the
  /// localised description.
  final String detail;

  factory AtsCheck.fromJson(Map<String, dynamic> json) => _$AtsCheckFromJson(json);

  Map<String, dynamic> toJson() => _$AtsCheckToJson(this);
}

/// Quantitative facts the analyser measured, kept for display and for the
/// "did my edit help?" comparison on the next run.
@JsonSerializable()
class ResumeStats {
  const ResumeStats({
    this.wordCount = 0,
    this.characterCount = 0,
    this.bulletCount = 0,
    this.actionVerbCount = 0,
    this.quantifiedBulletCount = 0,
    this.estimatedPages = 1,
    this.longestBulletWords = 0,
    this.averageBulletWords = 0,
    this.repeatedWords = const <String, int>{},
    this.fillerPhrases = const <String>[],
  });

  final int wordCount;
  final int characterCount;
  final int bulletCount;
  final int actionVerbCount;
  final int quantifiedBulletCount;
  final double estimatedPages;
  final int longestBulletWords;
  final double averageBulletWords;

  /// Word → occurrences, for words that appear suspiciously often.
  final Map<String, int> repeatedWords;

  /// Empty phrases such as "responsible for", "duties included".
  final List<String> fillerPhrases;

  factory ResumeStats.fromJson(Map<String, dynamic> json) =>
      _$ResumeStatsFromJson(json);

  Map<String, dynamic> toJson() => _$ResumeStatsToJson(this);

  /// Proportion of bullets that contain a measurable outcome (a number, a
  /// percentage or a currency amount). This is the single strongest
  /// predictor of a resume reading as "results-oriented".
  double get quantifiedRatio =>
      bulletCount == 0 ? 0 : quantifiedBulletCount / bulletCount;

  double get actionVerbRatio => bulletCount == 0 ? 0 : actionVerbCount / bulletCount;
}

/// Keyword overlap between the CV and a job advert.
@JsonSerializable()
class KeywordAnalysis {
  const KeywordAnalysis({
    this.found = const <String>[],
    this.missing = const <String>[],
    this.unverified = const <String>[],
    this.matchRatio = 0,
  });

  /// Keywords present in both the CV and the advert.
  final List<String> found;

  /// Keywords the advert asks for that the CV never mentions.
  final List<String> missing;

  /// Keywords the CV mentions that the advert does not — signal that the CV
  /// is not tailored, but not a defect.
  final List<String> unverified;

  /// 0..1 overlap used by the job-match score.
  final double matchRatio;

  factory KeywordAnalysis.fromJson(Map<String, dynamic> json) =>
      _$KeywordAnalysisFromJson(json);

  Map<String, dynamic> toJson() => _$KeywordAnalysisToJson(this);
}

/// The complete output of one analysis run.
@JsonSerializable(explicitToJson: true)
class AnalysisReport {
  const AnalysisReport({
    this.id = '',
    this.resumeId = '',
    this.source = AnalysisSource.offline,
    this.totalScore = 0,
    this.dimensions = const <ScoreDimension>[],
    this.recommendations = const <Recommendation>[],
    this.atsChecks = const <AtsCheck>[],
    this.stats = const ResumeStats(),
    this.keywords,
    this.strengths = const <String>[],
    this.createdAt,
    this.regionId = 'international',
    this.engineVersion = 1,
  });

  final String id;
  final String resumeId;

  /// Whether this report came from the offline rule engine or from an
  /// AI-assisted pass. The UI badges them differently.
  final AnalysisSource source;

  final int totalScore;
  final List<ScoreDimension> dimensions;
  final List<Recommendation> recommendations;
  final List<AtsCheck> atsChecks;
  final ResumeStats stats;
  final KeywordAnalysis? keywords;

  /// Positive findings, so the report is not purely negative.
  final List<String> strengths;

  final DateTime? createdAt;

  /// Region the CV was analysed against — affects which regional rules were
  /// applied.
  final String regionId;

  /// Incremented whenever the rule set changes, so a stored report can be
  /// recognised as stale.
  final int engineVersion;

  factory AnalysisReport.fromJson(Map<String, dynamic> json) =>
      _$AnalysisReportFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisReportToJson(this);

  static AnalysisReport empty() => const AnalysisReport();

  bool get isEmpty => totalScore == 0 && recommendations.isEmpty;

  ScoreDimension? dimension(ScoreKind kind) {
    for (final ScoreDimension d in dimensions) {
      if (d.kind == kind) return d;
    }
    return null;
  }

  /// Recommendations ordered by priority, then by appearance.
  List<Recommendation> get sortedRecommendations {
    final List<Recommendation> copy = List<Recommendation>.of(recommendations);
    copy.sort(
      (Recommendation a, Recommendation b) =>
          a.priority.index.compareTo(b.priority.index),
    );
    return copy;
  }

  int countOf(IssuePriority priority) =>
      recommendations.where((Recommendation r) => r.priority == priority).length;
}
