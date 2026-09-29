import 'package:json_annotation/json_annotation.dart';

/// Proficiency of a technical or soft skill.
///
/// Rendered as a label, a dot scale or a bar depending on the template —
/// never as a percentage. Percentages are not comparable between candidates
/// and are actively harmful on an ATS-parsed CV, so the model does not
/// support them.
enum SkillLevel {
  @JsonValue('beginner')
  beginner,
  @JsonValue('intermediate')
  intermediate,
  @JsonValue('advanced')
  advanced,
  @JsonValue('expert')
  expert;

  static SkillLevel fromId(String id) => SkillLevel.values.firstWhere(
        (SkillLevel l) => l.name == id,
        orElse: () => SkillLevel.intermediate,
      );

  String get id => name;

  /// 0..1 fill used by dot/bar renderers.
  double get fill => switch (this) {
        SkillLevel.beginner => 0.25,
        SkillLevel.intermediate => 0.5,
        SkillLevel.advanced => 0.75,
        SkillLevel.expert => 1,
      };

  /// Number of filled dots out of five. Templates that draw dots use
  /// five because it survives being printed in greyscale.
  int get dotsOfFive => switch (this) {
        SkillLevel.beginner => 2,
        SkillLevel.intermediate => 3,
        SkillLevel.advanced => 4,
        SkillLevel.expert => 5,
      };
}

/// Proficiency of a spoken language.
///
/// The scale intentionally mirrors the Common European Framework bands
/// (A1–C2) without pretending to *be* a CEFR certificate: [fluent] maps to
/// C1 and [native] is used for a first language, which CEFR does not express.
enum LanguageLevel {
  @JsonValue('beginner')
  beginner,
  @JsonValue('intermediate')
  intermediate,
  @JsonValue('advanced')
  advanced,
  @JsonValue('fluent')
  fluent,
  @JsonValue('native')
  native;

  static LanguageLevel fromId(String id) => LanguageLevel.values.firstWhere(
        (LanguageLevel l) => l.name == id,
        orElse: () => LanguageLevel.intermediate,
      );

  String get id => name;

  /// Optional CEFR hint shown in templates that expect it (Europass-style,
  /// German applications).
  String? get cefrHint => switch (this) {
        LanguageLevel.beginner => 'A2',
        LanguageLevel.intermediate => 'B1',
        LanguageLevel.advanced => 'B2',
        LanguageLevel.fluent => 'C1',
        LanguageLevel.native => null,
      };

  double get fill => switch (this) {
        LanguageLevel.beginner => 0.2,
        LanguageLevel.intermediate => 0.4,
        LanguageLevel.advanced => 0.6,
        LanguageLevel.fluent => 0.8,
        LanguageLevel.native => 1,
      };

  /// Ordinal used when comparing the CV's languages to a job advert.
  int get rank => index;
}
