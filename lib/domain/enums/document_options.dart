import 'package:json_annotation/json_annotation.dart';

/// Physical paper the PDF is laid out for.
///
/// The region profile chooses the default: US Letter for the United States,
/// A4 everywhere else. The user can always override it per document, because
/// plenty of candidates print a "US" CV on A4 stock at home.
enum PaperSize {
  @JsonValue('a4')
  a4,
  @JsonValue('us_letter')
  usLetter;

  String get id => this == PaperSize.a4 ? 'a4' : 'us_letter';

  static PaperSize fromId(String id) => PaperSize.values.firstWhere(
        (PaperSize p) => p.id == id,
        orElse: () => PaperSize.a4,
      );

  /// Width in PostScript points (1/72 inch), the unit the PDF engine uses.
  double get widthPt => this == PaperSize.a4 ? 595.276 : 612;

  /// Height in PostScript points.
  double get heightPt => this == PaperSize.a4 ? 841.89 : 792;

  /// Millimetre description shown in the UI.
  String get dimensionLabel => this == PaperSize.a4 ? '210 × 297 mm' : '8.5 × 11 in';
}

/// Calendar system used when *displaying and printing* dates.
///
/// Storage is always ISO-8601 Gregorian. This only affects presentation, so
/// switching systems never rewrites the underlying data.
enum DateSystem {
  @JsonValue('gregorian')
  gregorian,
  @JsonValue('jalali')
  jalali;

  static DateSystem fromId(String id) => DateSystem.values.firstWhere(
        (DateSystem d) => d.name == id,
        orElse: () => DateSystem.gregorian,
      );

  String get id => name;
}

/// Severity attached to an analyser recommendation.
///
/// Ordering matters: [index] is used to sort the recommendation list so the
/// most consequential fixes appear first.
enum IssuePriority {
  @JsonValue('critical')
  critical,
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low;

  static IssuePriority fromId(String id) => IssuePriority.values.firstWhere(
        (IssuePriority p) => p.name == id,
        orElse: () => IssuePriority.medium,
      );

  String get id => name;
}

/// Which analyser produced a report.
enum AnalysisSource {
  @JsonValue('offline')
  offline,
  @JsonValue('online')
  online;

  static AnalysisSource fromId(String id) => AnalysisSource.values.firstWhere(
        (AnalysisSource s) => s.name == id,
        orElse: () => AnalysisSource.offline,
      );

  String get id => name;
}

/// Grouping used by the template gallery.
enum TemplateCategory {
  @JsonValue('professional')
  professional,
  @JsonValue('modern')
  modern,
  @JsonValue('academic')
  academic,
  @JsonValue('regional')
  regional,
  @JsonValue('creative')
  creative;

  static TemplateCategory fromId(String id) => TemplateCategory.values.firstWhere(
        (TemplateCategory c) => c.name == id,
        orElse: () => TemplateCategory.professional,
      );

  String get id => name;
}

/// How much decoration a template applies.
///
/// This is the switch the ATS analyser reads: [atsSafe] guarantees the PDF
/// contains nothing but flowable text and rules.
enum AtsSafety {
  @JsonValue('ats_safe')
  atsSafe,
  @JsonValue('ats_friendly')
  atsFriendly,
  @JsonValue('decorative')
  decorative;

  static AtsSafety fromId(String id) => AtsSafety.values.firstWhere(
        (AtsSafety s) => s.id == id,
        orElse: () => AtsSafety.atsFriendly,
      );

  /// Matches the value written by `@JsonValue`, so a template exported to JSON
  /// and read back keeps the same safety class. Matching on `name` here used
  /// to turn a stored `ats_safe` into `ats_friendly`, which silently moved a
  /// document out of the ATS template class.
  String get id => switch (this) {
        AtsSafety.atsSafe => 'ats_safe',
        AtsSafety.atsFriendly => 'ats_friendly',
        AtsSafety.decorative => 'decorative',
      };
}

/// Theme mode preference persisted in settings.
enum AppThemeMode {
  @JsonValue('system')
  system,
  @JsonValue('light')
  light,
  @JsonValue('dark')
  dark;

  static AppThemeMode fromId(String id) => AppThemeMode.values.firstWhere(
        (AppThemeMode m) => m.name == id,
        orElse: () => AppThemeMode.system,
      );

  String get id => name;
}
