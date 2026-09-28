import 'package:json_annotation/json_annotation.dart';

/// Professional domain of the person the CV describes.
///
/// Drives three things: which section set is suggested, which skill taxonomy
/// the keyword matcher uses, and the vocabulary the offline analyser expects
/// to see (for example, a Legal CV that mentions "deployed" is flagged as
/// tone-inconsistent).
enum Industry {
  @JsonValue('software_engineering')
  softwareEngineering,
  @JsonValue('data_science')
  dataScience,
  @JsonValue('ai_ml')
  aiMl,
  @JsonValue('cybersecurity')
  cybersecurity,
  @JsonValue('engineering')
  engineering,
  @JsonValue('medicine')
  medicine,
  @JsonValue('finance')
  finance,
  @JsonValue('accounting')
  accounting,
  @JsonValue('marketing')
  marketing,
  @JsonValue('sales')
  sales,
  @JsonValue('design')
  design,
  @JsonValue('education')
  education,
  @JsonValue('research')
  research,
  @JsonValue('legal')
  legal,
  @JsonValue('hospitality')
  hospitality,
  @JsonValue('manufacturing')
  manufacturing,
  @JsonValue('other')
  other;

  String get id => switch (this) {
    Industry.softwareEngineering => 'software_engineering',
    Industry.dataScience => 'data_science',
    Industry.aiMl => 'ai_ml',
    Industry.cybersecurity => 'cybersecurity',
    Industry.engineering => 'engineering',
    Industry.medicine => 'medicine',
    Industry.finance => 'finance',
    Industry.accounting => 'accounting',
    Industry.marketing => 'marketing',
    Industry.sales => 'sales',
    Industry.design => 'design',
    Industry.education => 'education',
    Industry.research => 'research',
    Industry.legal => 'legal',
    Industry.hospitality => 'hospitality',
    Industry.manufacturing => 'manufacturing',
    Industry.other => 'other',
  };

  static Industry fromId(String id) => Industry.values.firstWhere(
        (Industry i) => i.id == id,
        orElse: () => Industry.other,
      );

  /// Key into `assets/data/analyzer/action_verbs.json`.
  String get verbSetId => switch (this) {
        Industry.softwareEngineering ||
        Industry.dataScience ||
        Industry.aiMl ||
        Industry.cybersecurity =>
          'technology',
        Industry.engineering || Industry.manufacturing => 'engineering',
        Industry.medicine => 'clinical',
        Industry.finance || Industry.accounting => 'finance',
        Industry.marketing || Industry.sales => 'commercial',
        Industry.design => 'design',
        Industry.education || Industry.research => 'academic',
        Industry.legal => 'legal',
        Industry.hospitality => 'service',
        Industry.other => 'general',
      };

  /// Industries where a technical skill list is expected to dominate.
  bool get isTechnical =>
      this == Industry.softwareEngineering ||
      this == Industry.dataScience ||
      this == Industry.aiMl ||
      this == Industry.cybersecurity ||
      this == Industry.engineering ||
      this == Industry.manufacturing;
}

/// Career stage, used for content expectations and seniority matching.
enum SeniorityLevel {
  @JsonValue('student')
  student,
  @JsonValue('internship')
  internship,
  @JsonValue('entry')
  entry,
  @JsonValue('junior')
  junior,
  @JsonValue('mid')
  mid,
  @JsonValue('senior')
  senior,
  @JsonValue('manager')
  manager,
  @JsonValue('executive')
  executive,
  @JsonValue('academic')
  academic;

  String get id => switch (this) {
    SeniorityLevel.student => 'student',
    SeniorityLevel.internship => 'internship',
    SeniorityLevel.entry => 'entry',
    SeniorityLevel.junior => 'junior',
    SeniorityLevel.mid => 'mid',
    SeniorityLevel.senior => 'senior',
    SeniorityLevel.manager => 'manager',
    SeniorityLevel.executive => 'executive',
    SeniorityLevel.academic => 'academic',
  };

  static SeniorityLevel fromId(String id) => SeniorityLevel.values.firstWhere(
        (SeniorityLevel s) => s.id == id,
        orElse: () => SeniorityLevel.mid,
      );

  /// Rough number of years a CV of this level is expected to show. Used by
  /// the analyser as a *soft* expectation, never as a hard filter.
  (int min, int max) get expectedYears => switch (this) {
        SeniorityLevel.student => (0, 1),
        SeniorityLevel.internship => (0, 1),
        SeniorityLevel.entry => (0, 2),
        SeniorityLevel.junior => (1, 4),
        SeniorityLevel.mid => (3, 7),
        SeniorityLevel.senior => (6, 15),
        SeniorityLevel.manager => (6, 20),
        SeniorityLevel.executive => (12, 45),
        SeniorityLevel.academic => (0, 60),
      };

  /// Ordinal used for seniority matching against a job advert.
  int get rank => index;
}
