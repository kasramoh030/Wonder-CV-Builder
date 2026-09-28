import 'package:json_annotation/json_annotation.dart';

import 'analysis_report.dart';

part 'job_description.g.dart';

/// A pasted job advert and what the extractor understood from it.
///
/// Extraction is entirely rule-based and offline: the advert is matched
/// against curated skill/tool vocabularies plus structural cues (heading
/// words such as "Requirements", bullet lists after a "You will" section).
/// That keeps the feature available with no network, no account and no cost,
/// and it makes the behaviour predictable — the same advert always yields
/// the same keywords, which matters when a user compares two CV versions.
@JsonSerializable(explicitToJson: true)
class JobDescription {
  const JobDescription({
    required this.id,
    required this.rawText,
    this.resumeId,
    this.jobTitle = '',
    this.company = '',
    this.requirements = const JobRequirements(),
    this.createdAt,
  });

  final String id;
  final String? resumeId;
  final String jobTitle;
  final String company;
  final String rawText;
  final JobRequirements requirements;
  final DateTime? createdAt;

  factory JobDescription.fromJson(Map<String, dynamic> json) =>
      _$JobDescriptionFromJson(json);

  Map<String, dynamic> toJson() => _$JobDescriptionToJson(this);
}

/// Structured view of an advert.
@JsonSerializable()
class JobRequirements {
  const JobRequirements({
    this.requiredSkills = const <String>[],
    this.preferredSkills = const <String>[],
    this.technologies = const <String>[],
    this.responsibilities = const <String>[],
    this.qualifications = const <String>[],
    this.softSkills = const <String>[],
    this.atsKeywordPool = const <String>[],
    this.detectedSeniority,
    this.detectedIndustries = const <String>[],
    this.yearsRequired,
    this.educationLevel = '',
    this.languages = const <String>[],
  });

  /// Skills the advert presents as mandatory.
  final List<String> requiredSkills;

  /// Skills phrased as "nice to have", "a plus", "desirable".
  final List<String> preferredSkills;

  /// Named tools, platforms and languages.
  final List<String> technologies;

  final List<String> responsibilities;
  final List<String> qualifications;
  final List<String> softSkills;

  /// Every distinct term worth matching on, ranked by the extractor's
  /// confidence. This is the pool the keyword matcher works from.
  final List<String> atsKeywordPool;

  /// `student`…`executive` when the advert states a level, else null.
  final String? detectedSeniority;
  final List<String> detectedIndustries;

  /// Explicitly stated years of experience, when present.
  final int? yearsRequired;

  /// Free-text education requirement, e.g. "BSc in Computer Science".
  final String educationLevel;

  /// Languages the advert requires, with any stated level kept as text.
  final List<String> languages;

  factory JobRequirements.fromJson(Map<String, dynamic> json) =>
      _$JobRequirementsFromJson(json);

  Map<String, dynamic> toJson() => _$JobRequirementsToJson(this);

  bool get isEmpty => atsKeywordPool.isEmpty && requiredSkills.isEmpty;
}

/// How well a CV answers an advert, dimension by dimension.
@JsonSerializable(explicitToJson: true)
class JobMatchReport {
  const JobMatchReport({
    this.resumeId = '',
    this.jobDescriptionId = '',
    this.overall = 0,
    this.skills = 0,
    this.experience = 0,
    this.education = 0,
    this.keywords = 0,
    this.seniority = 0,
    this.domain = 0,
    this.keywordDetail,
    this.explanation = const <String, String>{},
    this.gapSkills = const <String>[],
    this.createdAt,
  });

  final String resumeId;
  final String jobDescriptionId;

  /// 0–100 scores. Each is an independent estimate; [overall] is a weighted
  /// blend, not a verdict.
  final int overall;
  final int skills;
  final int experience;
  final int education;
  final int keywords;
  final int seniority;
  final int domain;

  /// Keyword overlap detail — which terms matched and which did not.
  final KeywordAnalysis? keywordDetail;

  /// Human-readable reasoning per dimension, keyed by the dimension name so
  /// the UI can show "why" next to each number.
  final Map<String, String> explanation;

  /// Skills the advert wants that the CV never demonstrates. Surfaced with
  /// an explicit honesty warning — the app never suggests adding a skill the
  /// user may not have.
  final List<String> gapSkills;

  final DateTime? createdAt;

  factory JobMatchReport.fromJson(Map<String, dynamic> json) =>
      _$JobMatchReportFromJson(json);

  Map<String, dynamic> toJson() => _$JobMatchReportToJson(this);

  static JobMatchReport empty() => const JobMatchReport();
}
